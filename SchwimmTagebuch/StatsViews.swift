import SwiftUI
import SwiftData
import Charts

struct WochenStatistik: Identifiable {
    var id: Date { wochenStart }
    let wochenStart: Date
    let meter: Int
    let dauerSek: Int
    let nachIntensitaet: [Intensitaet: Int]
}

struct StatsView: View {
    @Query(sort: \TrainingSession.datum) private var sessions: [TrainingSession]
    var wochen: [WochenStatistik] {
        var result: [WochenStatistik] = []
        let cal = Calendar(identifier: .iso8601)
        let grouped = Dictionary(grouping: sessions) { s in cal.dateInterval(of: .weekOfYear, for: s.datum)!.start }
        for (start, list) in grouped {
            let meter = list.reduce(0) { $0 + $1.gesamtMeter }
            let dauer = list.reduce(0) { $0 + $1.gesamtDauerSek }
            var nachInt: [Intensitaet: Int] = [:]
            for s in list { nachInt[s.intensitaet, default: 0] += s.gesamtMeter }
            result.append(WochenStatistik(wochenStart: start, meter: meter, dauerSek: dauer, nachIntensitaet: nachInt))
        }
        return result.sorted { $0.wochenStart < $1.wochenStart }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Card("Wochenmeter") {
                        Chart(wochen) { w in
                            BarMark(x: .value("Woche", w.wochenStart, unit: .weekOfYear), y: .value("Meter", w.meter))
                        }
                        .frame(height: 220)
                    }
                    Card("Intensitätsverteilung (letzte Woche)") {
                        if let letzte = wochen.last {
                            let paare = letzte.nachIntensitaet.map { ($0.key.titel, $0.value) }.sorted { $0.0 < $1.0 }
                            Chart(paare, id: \.0) { p in
                                SectorMark(angle: .value("Meter", p.1))
                                    .annotation(position: .overlay) { Text(p.0).font(.caption2) }
                            }
                            .frame(height: 220)
                        } else {
                            Text("Keine Daten")
                        }
                    }
                    ExportSection()
                }
                .padding()
            }
        }
        .navigationTitle("Statistiken")
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Material.liquidGlass, for: .navigationBar)
    }
}

// Re-usable Liquid-Card
struct Card<Content: View>: View {
    let titel: String
    @ViewBuilder var content: Content
    init(_ titel: String, @ViewBuilder content: () -> Content) {
        self.titel = titel; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titel).font(.headline)
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Material.liquidGlass)
        )
    }
}
