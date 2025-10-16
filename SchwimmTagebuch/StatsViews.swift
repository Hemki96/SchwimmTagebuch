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

struct EquipmentUsage: Identifiable {
    let equipment: TrainingEquipment
    let count: Int
    var id: String { equipment.rawValue }
}

struct TechniqueUsage: Identifiable {
    let focus: TechniqueFocus
    let count: Int
    var id: String { focus.rawValue }
}

struct StatsView: View {
    @Environment(\.currentUser) private var currentUser
    @Query(sort: \TrainingSession.datum) private var sessions: [TrainingSession]
    @AppStorage(SettingsKeys.goalTrackingEnabled) private var goalTrackingEnabled = true
    @AppStorage(SettingsKeys.weeklyGoal) private var weeklyGoal = 15000

    var wochen: [WochenStatistik] {
        var result: [WochenStatistik] = []
        let cal = Calendar(identifier: .iso8601)
        let grouped = Dictionary(grouping: filteredSessions) { s in cal.dateInterval(of: .weekOfYear, for: s.datum)!.start }
        for (start, list) in grouped {
            let meter = list.reduce(0) { $0 + $1.gesamtMeter }
            let dauer = list.reduce(0) { $0 + $1.gesamtDauerSek }
            let borgSumme = list.reduce(0) { $0 + $1.borgWert }
            let durchschnitt = list.isEmpty ? 0 : Double(borgSumme) / Double(list.count)
            result.append(WochenStatistik(wochenStart: start, meter: meter, dauerSek: dauer, durchschnittBorg: durchschnitt))
        }
        return result.sorted { $0.wochenStart < $1.wochenStart }
    }

    var equipmentStats: [EquipmentUsage] {
        var counts: [TrainingEquipment: Int] = [:]
        for set in filteredSessions.flatMap({ $0.sets }) {
            for item in set.equipment.compactMap({ TrainingEquipment(rawValue: $0) }) {
                counts[item, default: 0] += 1
            }
        }
        return counts.map { EquipmentUsage(equipment: $0.key, count: $0.value) }.sorted { $0.count > $1.count }
    }

    var techniqueStats: [TechniqueUsage] {
        var counts: [TechniqueFocus: Int] = [:]
        for set in filteredSessions.flatMap({ $0.sets }) {
            for item in set.technikSchwerpunkte.compactMap({ TechniqueFocus(rawValue: $0) }) {
                counts[item, default: 0] += 1
            }
        }
        return counts.map { TechniqueUsage(focus: $0.key, count: $0.value) }.sorted { $0.count > $1.count }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 24) {
                    if goalTrackingEnabled {
                        Card("Wochenziel", systemImage: "target") {
                            if let letzte = wochen.last {
                                let progress = min(1.0, Double(letzte.meter) / Double(max(weeklyGoal, 1)))
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Aktuelle Woche: \(letzte.meter) m von \(weeklyGoal) m")
                                        .font(.subheadline.weight(.semibold))
                                    ProgressView(value: progress) {
                                        Text("Fortschritt")
                                    }
                                    .tint(AppTheme.accent)
                                    Text("\(Int(progress * 100)) % erreicht")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text("Lege Trainings an, um dein Wochenziel zu verfolgen.")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Card("Wochenmeter", systemImage: "chart.bar") {
                        Chart(wochen) { w in
                            BarMark(x: .value("Woche", w.wochenStart, unit: .weekOfYear), y: .value("Meter", w.meter))
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .weekOfYear))
                        }
                        .frame(height: 220)
                    }
                    Card("Borg-Intensität je Woche", systemImage: "heart.text.square") {
                        if wochen.isEmpty {
                            Text("Keine Daten")
                                .foregroundStyle(.secondary)
                        } else {
                            Chart(wochen) { w in
                                LineMark(
                                    x: .value("Woche", w.wochenStart, unit: .weekOfYear),
                                    y: .value("Ø Borg", w.durchschnittBorg)
                                )
                                AreaMark(
                                    x: .value("Woche", w.wochenStart, unit: .weekOfYear),
                                    y: .value("Ø Borg", w.durchschnittBorg)
                                )
                                .foregroundStyle(Gradient(colors: [AppTheme.accent.opacity(0.4), .clear]))
                                PointMark(
                                    x: .value("Woche", w.wochenStart, unit: .weekOfYear),
                                    y: .value("Ø Borg", w.durchschnittBorg)
                                )
                            }
                            .frame(height: 220)
                        }
                    }
                    Card("Letzte Woche im Blick", systemImage: "figure.swim") {
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
                                .foregroundStyle(.secondary)
                        }
                    }
                    Card("Equipment-Fokus", systemImage: "tuningfork") {
                        if equipmentStats.isEmpty {
                            Text("Noch keine Equipment-Daten erfasst.")
                                .foregroundStyle(.secondary)
                        } else {
                            Chart(equipmentStats) { item in
                                BarMark(
                                    x: .value("Einsätze", item.count),
                                    y: .value("Equipment", item.equipment.titel)
                                )
                                .foregroundStyle(AppTheme.accent.gradient)
                            }
                            .frame(height: max(160, CGFloat(equipmentStats.count) * 32))
                        }
                    }
                    Card("Technik-Schwerpunkte", systemImage: "waveform.path.ecg") {
                        if techniqueStats.isEmpty {
                            Text("Noch keine Technik-Fokusse erfasst.")
                                .foregroundStyle(.secondary)
                        } else {
                            Chart(techniqueStats) { item in
                                LineMark(
                                    x: .value("Fokus", item.focus.titel),
                                    y: .value("Anzahl", item.count)
                                )
                                PointMark(
                                    x: .value("Fokus", item.focus.titel),
                                    y: .value("Anzahl", item.count)
                                )
                                .foregroundStyle(AppTheme.accent)
                            }
                            .frame(height: 220)
                        }
                    }
                    ExportSection()
                        .padding(.bottom, 12)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
            }
        }
        .navigationTitle("Statistiken")
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.barMaterial, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .appSurfaceBackground()
    }

    private var filteredSessions: [TrainingSession] {
        guard let userID = currentUser?.id else { return [] }
        return sessions.filter { $0.owner?.id == userID }
    }
}

// Re-usable glass card following the refreshed visual language.
struct Card<Content: View>: View {
    let title: String
    let systemImage: String?
    @ViewBuilder var content: Content

    init(_ title: String, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let systemImage {
                Label(title, systemImage: systemImage)
                    .font(.title3.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.primary)
            } else {
                Text(title)
                    .font(.title3.weight(.semibold))
            }
            content
        }
        .glassCard()
    }
}
