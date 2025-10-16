import SwiftUI
import SwiftData

struct ExportSection: View {
    @Environment(\.currentUser) private var currentUser
    @Query private var sessions: [TrainingSession]
    @Query private var competitions: [Competition]
    @State private var zeigtShare = false
    @State private var exportURL: URL?
    @State private var zeigtFehler = false
    @State private var fehlertext = ""
    @AppStorage(SettingsKeys.autoExportEnabled) private var autoExportEnabled = false
    @AppStorage(SettingsKeys.autoExportFormat) private var autoExportFormatRaw = ExportFormat.json.rawValue
    @AppStorage(SettingsKeys.lastBackupISO) private var lastBackupISO = ""

    private var autoExportFormat: ExportFormat { ExportFormat(rawValue: autoExportFormatRaw) ?? .json }
    private var letzteSicherungstext: String {
        guard let date = ISO8601DateFormatter().date(from: lastBackupISO) else { return "Noch keine Sicherung" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var body: some View {
        Card("Export & Sync") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button { exportCSV() } label: { Label("CSV exportieren", systemImage: "square.and.arrow.up") }
                    Spacer()
                    Button { exportJSON() } label: { Label("JSON exportieren", systemImage: "square.and.arrow.up.on.square") }
                }
                Divider()
                Toggle("Automatische Sicherung aktiv", isOn: $autoExportEnabled)
                Picker("Standardformat", selection: $autoExportFormatRaw) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.titel).tag(format.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                Button { fuehreSchnellSyncAus() } label: {
                    Label("Jetzt synchronisieren", systemImage: "arrow.clockwise")
                }
                .disabled(filteredSessions.isEmpty && filteredCompetitions.isEmpty)
                Text("Letzte Sicherung: \(letzteSicherungstext)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $zeigtShare) {
            if let url = exportURL { ShareSheet(activityItems: [url]) }
        }
        .alert("Export fehlgeschlagen", isPresented: $zeigtFehler) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(fehlertext)
        }
        .onChange(of: autoExportEnabled) { _, neu in
            guard neu else { return }
            fuehreSchnellSyncAus()
        }
    }

    private func exportCSV() {
        let csvTrain = CSVBuilder.trainingsCSV(filteredSessions)
        let csvComp = CSVBuilder.wettkampfCSV(filteredCompetitions)
        let tmp = FileManager.default.temporaryDirectory
        let urlTrain = tmp.appendingPathComponent("training.csv")
        let urlComp = tmp.appendingPathComponent("wettkaempfe.csv")
        try? csvTrain.data(using: .utf8)?.write(to: urlTrain)
        try? csvComp.data(using: .utf8)?.write(to: urlComp)
        exportURL = urlTrain // Start mit Trainingsdatei
        zeigtShare = true
    }
    private func exportJSON() {
        let json = JSONBuilder.exportJSON(sessions: filteredSessions, competitions: filteredCompetitions)
        let tmp = FileManager.default.temporaryDirectory
        let url = tmp.appendingPathComponent("export.json")
        try? json.data(using: .utf8)?.write(to: url)
        exportURL = url
        zeigtShare = true
    }

    private func fuehreSchnellSyncAus() {
        do {
            let url = try AutoBackupService.performBackup(
                sessions: filteredSessions,
                competitions: filteredCompetitions,
                format: autoExportFormat
            )
            lastBackupISO = ISO8601DateFormatter().string(from: Date())
            if autoExportEnabled {
                // Silent Sync: kein Share-Sheet, aber Erfolg melden über Text.
                exportURL = nil
            } else {
                exportURL = url
                zeigtShare = true
            }
        } catch {
            fehlertext = error.localizedDescription
            zeigtFehler = true
        }
    }

    private var filteredSessions: [TrainingSession] {
        guard let userID = currentUser?.id else { return [] }
        return sessions.filter { $0.owner?.id == userID }
    }

    private var filteredCompetitions: [Competition] {
        guard let userID = currentUser?.id else { return [] }
        return competitions.filter { $0.owner?.id == userID }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: activityItems, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum CSVBuilder {
    static func trainingsCSV(_ list: [TrainingSession]) -> String {
        var lines = ["date,totalMeters,totalMinutes,borg,location,feeling,notes,equipment,technique"]
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        for s in list {
            let date = df.string(from: s.datum)
            let mins = s.gesamtDauerSek/60
            let equipment = Set(s.sets.flatMap { $0.equipment }).compactMap { TrainingEquipment(rawValue: $0)?.titel ?? $0 }.sorted().joined(separator: "; ")
            let technik = Set(s.sets.flatMap { $0.technikSchwerpunkte }).compactMap { TechniqueFocus(rawValue: $0)?.titel ?? $0 }.sorted().joined(separator: "; ")
            let row = "\(date),\(s.gesamtMeter),\(mins),\(s.borgWert),\(s.ort.titel),\(escapeCSV(s.gefuehl ?? "")),\(escapeCSV(s.notizen ?? "")),\(escapeCSV(equipment)),\(escapeCSV(technik))"
            lines.append(row)
        }
        return lines.joined(separator: "\n")
    }
    static func wettkampfCSV(_ comps: [Competition]) -> String {
        var lines = ["date,name,venue,course,stroke,distance,timeSec,rank,isPB"]
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        for c in comps {
            for r in c.results {
                let date = df.string(from: c.datum)
                let row = "\(date),\(c.name),\(escapeCSV(c.ort)),\(c.bahn.titel),\(r.lage.titel),\(r.distanz),\(r.zeitSek),\(r.platz ?? 0),\(r.istPB)"
                lines.append(row)
            }
        }
        return lines.joined(separator: "\n")
    }
    private static func escapeCSV(_ v: String) -> String {
        // RFC 4180 style: wrap in quotes if value contains comma, quote, or newline; double quotes inside
        let needsQuoting = v.contains(",") || v.contains("\n") || v.contains("\"")
        if needsQuoting {
            let escaped = v.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return v
    }
}

enum JSONBuilder {
    static func exportJSON(sessions: [TrainingSession], competitions: [Competition]) -> String {
        struct S: Codable { let date: String; let totalMeters: Int; let totalDurationSec: Int; let borg: Int; let location: String; let feeling: String; let notes: String; let equipment: [String]; let technique: [String]; let sets: [SetDTO] }
        struct SetDTO: Codable { let title: String; let reps: Int; let distancePerRep: Int; let intervalSec: Int; let equipment: [String]; let technique: [String]; let laps: [Int] }
        struct C: Codable { let date: String; let name: String; let venue: String; let course: String; let results: [R] }
        struct R: Codable { let stroke: String; let distance: Int; let timeSec: Int; let isPB: Bool }
        struct Root: Codable { let trainings: [S]; let competitions: [C] }

        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let trainings: [S] = sessions.map { s in
            let sets: [SetDTO] = s.sets.map { set in
                let equipment = set.equipment.compactMap { TrainingEquipment(rawValue: $0)?.titel ?? $0 }
                let technik = set.technikSchwerpunkte.compactMap { TechniqueFocus(rawValue: $0)?.titel ?? $0 }
                return SetDTO(title: set.titel, reps: set.wiederholungen, distancePerRep: set.distanzProWdh, intervalSec: set.intervallSek, equipment: equipment, technique: technik, laps: set.laps.map { $0.splitSek })
            }
            let equipment = Array(Set(s.sets.flatMap { $0.equipment.compactMap { TrainingEquipment(rawValue: $0)?.titel ?? $0 } })).sorted()
            let technik = Array(Set(s.sets.flatMap { $0.technikSchwerpunkte.compactMap { TechniqueFocus(rawValue: $0)?.titel ?? $0 } })).sorted()
            return S(
                date: df.string(from: s.datum),
                totalMeters: s.gesamtMeter,
                totalDurationSec: s.gesamtDauerSek,
                borg: s.borgWert,
                location: s.ort.titel,
                feeling: s.gefuehl ?? "",
                notes: s.notizen ?? "",
                equipment: equipment,
                technique: technik,
                sets: sets
            )
        }
        let comps: [C] = competitions.map { c in
            let rs: [R] = c.results.map { r in R(stroke: r.lage.titel, distance: r.distanz, timeSec: r.zeitSek, isPB: r.istPB) }
            return C(date: df.string(from: c.datum), name: c.name, venue: c.ort, course: c.bahn.titel, results: rs)
        }
        let root = Root(trainings: trainings, competitions: comps)
        let data = try! JSONEncoder().encode(root)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
