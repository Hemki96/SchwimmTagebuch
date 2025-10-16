import SwiftUI
import SwiftData
import Charts

struct WochenStatistik: Identifiable {
    var id: Date { wochenStart }
    let wochenStart: Date
    let meter: Int
    let dauerSek: Int
    let durchschnittBorg: Double
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
            let borgSumme = list.reduce(0) { $0 + $1.borgWert }
            let durchschnitt = list.isEmpty ? 0 : Double(borgSumme) / Double(list.count)
            result.append(WochenStatistik(wochenStart: start, meter: meter, dauerSek: dauer, durchschnittBorg: durchschnitt))
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
                    Card("Borg-Intensität je Woche") {
                        if wochen.isEmpty {
                            Text("Keine Daten")
                        } else {
                            Chart(wochen) { w in
                                LineMark(
                                    x: .value("Woche", w.wochenStart, unit: .weekOfYear),
                                    y: .value("Ø Borg", w.durchschnittBorg)
                                )
                                PointMark(
                                    x: .value("Woche", w.wochenStart, unit: .weekOfYear),
                                    y: .value("Ø Borg", w.durchschnittBorg)
                                )
                            }
                            .frame(height: 220)
                        }
                    }
                    Card("Letzte Woche im Blick") {
                        if let letzte = wochen.last {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label("\(letzte.meter) m", systemImage: "ruler")
                                    Spacer()
                                    Label("\(letzte.dauerSek/60) min", systemImage: "clock")
                                }
                                Label(String(format: "Ø Borg %.1f", letzte.durchschnittBorg), systemImage: "heart.fill")
                                    .foregroundStyle(.pink)
                            }
                        } else {
                            Text("Noch keine Trainingseinheiten erfasst.")
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
