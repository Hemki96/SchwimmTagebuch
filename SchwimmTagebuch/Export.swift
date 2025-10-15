import SwiftUI
import SwiftData

struct ExportSection: View {
    @Query private var sessions: [TrainingSession]
    @Query private var competitions: [Competition]
    @State private var zeigtShare = false
    @State private var exportURL: URL?

    var body: some View {
        Card("Export") {
            HStack {
                Button { exportCSV() } label: { Label("CSV exportieren", systemImage: "square.and.arrow.up") }
                Spacer()
                Button { exportJSON() } label: { Label("JSON exportieren", systemImage: "square.and.arrow.up.on.square") }
            }
        }
        .sheet(isPresented: $zeigtShare) {
            if let url = exportURL { ShareSheet(activityItems: [url]) }
        }
    }

    private func exportCSV() {
        let csvTrain = CSVBuilder.trainingsCSV(sessions)
        let csvComp = CSVBuilder.wettkampfCSV(competitions)
        let tmp = FileManager.default.temporaryDirectory
        let urlTrain = tmp.appendingPathComponent("training.csv")
        let urlComp = tmp.appendingPathComponent("wettkaempfe.csv")
        try? csvTrain.data(using: .utf8)?.write(to: urlTrain)
        try? csvComp.data(using: .utf8)?.write(to: urlComp)
        exportURL = urlTrain // Start mit Trainingsdatei
        zeigtShare = true
    }
    private func exportJSON() {
        let json = JSONBuilder.exportJSON(sessions: sessions, competitions: competitions)
        let tmp = FileManager.default.temporaryDirectory
        let url = tmp.appendingPathComponent("export.json")
        try? json.data(using: .utf8)?.write(to: url)
        exportURL = url
        zeigtShare = true
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: activityItems, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum CSVBuilder {
    static func trainingsCSV(_ list: [TrainingSession]) -> String {
        var lines = ["date,totalMeters,totalMinutes,intensity,location,notes"]
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        for s in list {
            let date = df.string(from: s.datum)
            let mins = s.gesamtDauerSek/60
            let row = "\(date),\(s.gesamtMeter),\(mins),\(s.intensitaet.titel),\(s.ort.titel),\(escapeCSV(s.notizen ?? ""))"
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
        struct S: Codable { let date: String; let totalMeters: Int; let totalDurationSec: Int; let intensity: String; let location: String; let notes: String; let sets: [SetDTO] }
        struct SetDTO: Codable { let title: String; let reps: Int; let distancePerRep: Int; let intervalSec: Int; let laps: [Int] }
        struct C: Codable { let date: String; let name: String; let venue: String; let course: String; let results: [R] }
        struct R: Codable { let stroke: String; let distance: Int; let timeSec: Int; let isPB: Bool }
        struct Root: Codable { let trainings: [S]; let competitions: [C] }

        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let trainings: [S] = sessions.map { s in
            let sets: [SetDTO] = s.sets.map { set in
                SetDTO(title: set.titel, reps: set.wiederholungen, distancePerRep: set.distanzProWdh, intervalSec: set.intervallSek, laps: set.laps.map { $0.splitSek })
            }
            return S(date: df.string(from: s.datum), totalMeters: s.gesamtMeter, totalDurationSec: s.gesamtDauerSek, intensity: s.intensitaet.titel, location: s.ort.titel, notes: s.notizen ?? "", sets: sets)
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
