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
        let exports = ExportDataFactory.sessions(list)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var lines = ["date,totalMeters,totalMinutes,borg,location,feeling,notes,equipment,technique"]
        for session in exports {
            let row = [
                session.dateString(using: formatter),
                String(session.totalMeters),
                String(session.totalMinutes),
                String(session.borg),
                CSVFormatter.escape(session.locationTitle),
                CSVFormatter.escape(session.feeling),
                CSVFormatter.escape(session.notes),
                CSVFormatter.escape(session.equipmentSummaryString),
                CSVFormatter.escape(session.techniqueSummaryString)
            ].joined(separator: ",")
            lines.append(row)
        }
        return lines.joined(separator: "\n")
    }

    static func wettkampfCSV(_ competitions: [Competition]) -> String {
        let exports = ExportDataFactory.competitions(competitions)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var lines = ["date,name,venue,course,stroke,distance,timeSec,rank,isPB"]
        for competition in exports {
            for result in competition.results {
                let row = [
                    competition.dateString(using: formatter),
                    CSVFormatter.escape(competition.name),
                    CSVFormatter.escape(competition.venue),
                    CSVFormatter.escape(competition.courseTitle),
                    CSVFormatter.escape(result.strokeTitle),
                    String(result.distance),
                    String(result.timeSec),
                    String(result.rank ?? 0),
                    String(result.isPersonalBest)
                ].joined(separator: ",")
                lines.append(row)
            }
        }
        return lines.joined(separator: "\n")
    }
}

enum JSONBuilder {
    static func exportJSON(sessions: [TrainingSession], competitions: [Competition]) -> String {
        struct TrainingDTO: Codable {
            let date: String
            let totalMeters: Int
            let totalDurationSec: Int
            let borg: Int
            let location: String
            let feeling: String
            let notes: String
            let equipment: [String]
            let technique: [String]
            let sets: [SetDTO]
        }

        struct SetDTO: Codable {
            let title: String
            let reps: Int
            let distancePerRep: Int
            let intervalSec: Int
            let equipment: [String]
            let technique: [String]
            let laps: [Int]
        }

        struct CompetitionDTO: Codable {
            let date: String
            let name: String
            let venue: String
            let course: String
            let results: [ResultDTO]
        }

        struct ResultDTO: Codable {
            let stroke: String
            let distance: Int
            let timeSec: Int
            let isPB: Bool
        }

        struct Root: Codable {
            let trainings: [TrainingDTO]
            let competitions: [CompetitionDTO]
        }

        let sessionExports = ExportDataFactory.sessions(sessions)
        let competitionExports = ExportDataFactory.competitions(competitions)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let trainings: [TrainingDTO] = sessionExports.map { session in
            TrainingDTO(
                date: session.dateString(using: formatter),
                totalMeters: session.totalMeters,
                totalDurationSec: session.totalDurationSec,
                borg: session.borg,
                location: session.locationTitle,
                feeling: session.feeling,
                notes: session.notes,
                equipment: session.equipmentSummary,
                technique: session.techniqueSummary,
                sets: session.sets.map { set in
                    SetDTO(
                        title: set.title,
                        reps: set.repetitions,
                        distancePerRep: set.distancePerRep,
                        intervalSec: set.intervalSec,
                        equipment: set.equipment,
                        technique: set.technique,
                        laps: set.laps
                    )
                }
            )
        }

        let competitionsDTO: [CompetitionDTO] = competitionExports.map { competition in
            CompetitionDTO(
                date: competition.dateString(using: formatter),
                name: competition.name,
                venue: competition.venue,
                course: competition.courseTitle,
                results: competition.results.map { result in
                    ResultDTO(
                        stroke: result.strokeTitle,
                        distance: result.distance,
                        timeSec: result.timeSec,
                        isPB: result.isPersonalBest
                    )
                }
            )
        }

        let root = Root(trainings: trainings, competitions: competitionsDTO)
        guard
            let data = try? JSONEncoder().encode(root),
            let jsonString = String(data: data, encoding: .utf8)
        else { return "{}" }
        return jsonString
    }
}
