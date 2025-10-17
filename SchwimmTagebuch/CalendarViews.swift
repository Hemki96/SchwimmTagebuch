import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.currentUser) private var currentUser
    @Query(sort: \TrainingSession.datum, order: .reverse) private var sessions: [TrainingSession]
    @Query(sort: \Competition.datum, order: .reverse) private var competitions: [Competition]
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var angezeigterMonat = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    @State private var zeigtTrainingEditor = false
    @State private var zeigtWettkampfEditor = false
    @State private var hatInitialCheckAusgefuehrt = false

    private var kalender: Calendar { Calendar.current }

    private var selectedDateBinding: Binding<Date> {
        Binding(
            get: { selectedDate },
            set: { newValue in
                let normalisiert = kalender.startOfDay(for: newValue)
                selectedDate = normalisiert
                angezeigterMonat = kalender.date(from: kalender.dateComponents([.year, .month], from: normalisiert)) ?? normalisiert
            }
        )
    }

    private var userSessions: [TrainingSession] {
        guard let userID = currentUser?.id else { return [] }
        return sessions.filter { $0.owner?.id == userID }
    }

    private var userCompetitions: [Competition] {
        guard let userID = currentUser?.id else { return [] }
        return competitions.filter { $0.owner?.id == userID }
    }

    private var trainingsAmTag: [TrainingSession] {
        userSessions.filter { kalender.isDate($0.datum, inSameDayAs: selectedDate) }
    }

    private var wettkaempfeAmTag: [Competition] {
        userCompetitions.filter { kalender.isDate($0.datum, inSameDayAs: selectedDate) }
    }

    private var trainingstage: Set<Date> {
        Set(userSessions.map { kalender.startOfDay(for: $0.datum) })
    }

    private var wettkampfTage: Set<Date> {
        Set(userCompetitions.map { kalender.startOfDay(for: $0.datum) })
    }

    private var aktuelleWochenStatistik: (meter: Int, minuten: Int, sessions: Int, durchschnittBorg: Double, gefuehle: [String])? {
        guard let intervall = kalender.dateInterval(of: .weekOfYear, for: Date()) else { return nil }
        let dieserWoche = userSessions.filter { intervall.contains($0.datum) }
        guard !dieserWoche.isEmpty else { return nil }
        let meter = dieserWoche.reduce(0) { $0 + $1.gesamtMeter }
        let minuten = dieserWoche.reduce(0) { $0 + $1.gesamtDauerSek } / 60
        let borgSumme = dieserWoche.reduce(0) { $0 + $1.borgWert }
        let durchschnitt = Double(borgSumme) / Double(dieserWoche.count)
        let gefuehle = dieserWoche.compactMap { s -> String? in
            guard let text = s.gefuehl?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            return text
        }
        return (meter, minuten, dieserWoche.count, durchschnitt, gefuehle)
    }

    var body: some View {
        NavigationStack {
            List {
                if let woche = aktuelleWochenStatistik {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("\(woche.meter) m", systemImage: "ruler")
                                Spacer()
                                Label("\(woche.minuten) min", systemImage: "clock")
                            }
                            HStack {
                                Label(String(format: "Ø Borg %.1f", woche.durchschnittBorg), systemImage: "heart.fill")
                                Spacer()
                                Label("\(woche.sessions) Einheiten", systemImage: "figure.swim")
                            }
                            if let stimmung = woche.gefuehle.first {
                                Label(stimmung, systemImage: "face.smiling")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .glassCard(contentPadding: 20)
                    } header: {
                        SectionHeaderLabel("Aktuelle Woche", systemImage: "sparkles")
                    }
                    .glassListRow()
                }

                Section {
                    CalendarMonthView(
                        selectedDate: selectedDateBinding,
                        displayedMonth: $angezeigterMonat,
                        calendar: kalender,
                        trainingstage: trainingstage,
                        wettkampfTage: wettkampfTage,
                        onDayDoubleTap: { datum in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedDateBinding.wrappedValue = datum
                            }
                            stelleTrainingseinheitSicher(fuer: kalender.startOfDay(for: datum))
                        }
                    )
                    .glassCard(contentPadding: 12)
                } header: {
                    SectionHeaderLabel("Datum auswählen", systemImage: "calendar")
                }
                .glassListRow()

                Section {
                    if trainingsAmTag.isEmpty {
                        ContentUnavailableHint(title: "Kein Training", subtitle: "Erfasse eine Einheit, um den Tag zu füllen.", systemImage: "figure.swim")
                            .glassListRow()
                    } else {
                        ForEach(trainingsAmTag) { session in
                            NavigationLink {
                                SessionDetailView(session: session)
                            } label: {
                                TrainingCell(session: session)
                            }
                            .buttonStyle(.plain)
                            .glassListRow()
                        }
                        .onDelete { offsets in
                            loescheTraining(at: offsets, aus: trainingsAmTag)
                        }
                    }
                } header: {
                    SectionHeaderLabel("Training", systemImage: "figure.swim")
                }

                Section {
                    if wettkaempfeAmTag.isEmpty {
                        ContentUnavailableHint(title: "Keine Wettkämpfe", subtitle: "Plane deine nächsten Rennen und bleibe motiviert.", systemImage: "stopwatch")
                            .glassListRow()
                    } else {
                        ForEach(wettkaempfeAmTag) { wettkampf in
                            NavigationLink {
                                CompetitionDetailView(comp: wettkampf)
                            } label: {
                                CompetitionCell(comp: wettkampf)
                            }
                            .buttonStyle(.plain)
                            .glassListRow()
                        }
                        .onDelete { offsets in
                            loescheWettkampf(at: offsets, aus: wettkaempfeAmTag)
                        }
                    }
                } header: {
                    SectionHeaderLabel("Wettkämpfe", systemImage: "trophy")
                }
            }
            .listStyle(.plain)
            .listSectionSpacing(24)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button { zeigtTrainingEditor = true } label: { Label("Training erfassen", systemImage: "figure.swim") }
                        Button { zeigtWettkampfEditor = true } label: { Label("Wettkampf erfassen", systemImage: "stopwatch") }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $zeigtTrainingEditor) { SessionEditorSheet(initialDate: selectedDate) }
            .sheet(isPresented: $zeigtWettkampfEditor) { CompetitionEditorSheet(initialDate: selectedDate) }
        }
        .navigationTitle("Kalender")
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.barMaterial, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .onAppear {
            if !hatInitialCheckAusgefuehrt {
                hatInitialCheckAusgefuehrt = true
                stelleTrainingseinheitSicher(fuer: selectedDate)
            }
        }
        .appSurfaceBackground()
    }

    private func stelleTrainingseinheitSicher(fuer datum: Date) {
        guard let user = currentUser else { return }
        let vorhandene = userSessions
        guard !vorhandene.contains(where: { kalender.isDate($0.datum, inSameDayAs: datum) }) else { return }
        let neueSession = TrainingSession(datum: datum, meter: 0, dauerSek: 0, borgWert: 5, owner: user)
        context.insert(neueSession)
        try? context.save()
    }

    private func loescheTraining(at offsets: IndexSet, aus liste: [TrainingSession]) {
        let zuLoeschen = offsets.map { liste[$0] }
        zuLoeschen.forEach(context.delete)
        try? context.save()
    }

    private func loescheWettkampf(at offsets: IndexSet, aus liste: [Competition]) {
        let zuLoeschen = offsets.map { liste[$0] }
        zuLoeschen.forEach(context.delete)
        try? context.save()
    }
}

struct CalendarMonthView: View {
    @Binding var selectedDate: Date
    @Binding var displayedMonth: Date
    let calendar: Calendar
    let trainingstage: Set<Date>
    let wettkampfTage: Set<Date>
    let onDayDoubleTap: (Date) -> Void

    private var tageDesMonats: [Date?] {
        guard
            let monatsIntervall = calendar.dateInterval(of: .month, for: displayedMonth),
            let tage = calendar.range(of: .day, in: .month, for: monatsIntervall.start)
        else { return [] }

        var werte: [Date?] = []
        let ersterWochentag = calendar.component(.weekday, from: monatsIntervall.start)
        let offset = ((ersterWochentag - calendar.firstWeekday) + 7) % 7
        werte.append(contentsOf: Array(repeating: nil, count: offset))

        for tag in tage {
            if let datum = calendar.date(byAdding: .day, value: tag - 1, to: monatsIntervall.start) {
                werte.append(datum)
            }
        }

        let rest = werte.count % 7
        if rest != 0 {
            werte.append(contentsOf: Array(repeating: nil, count: 7 - rest))
        }

        return werte
    }

    private var wochentagsSymbole: [String] {
        var symbole = calendar.veryShortWeekdaySymbols
        let startIndex = (calendar.firstWeekday - 1 + symbole.count) % symbole.count
        if startIndex > 0 {
            let prefix = symbole[..<startIndex]
            symbole.removeFirst(startIndex)
            symbole.append(contentsOf: prefix)
        }
        return symbole
    }

    private var monatsTitel: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    verschiebeMonat(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .padding(8)
                        .background(Circle().fill(.thinMaterial))
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monatsTitel.capitalized)
                    .font(.title3.weight(.semibold))

                Spacer()

                Button {
                    verschiebeMonat(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.semibold))
                        .padding(8)
                        .background(Circle().fill(.thinMaterial))
                }
                .buttonStyle(.plain)
            }

            HStack {
                ForEach(wochentagsSymbole, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 12) {
                ForEach(Array(tageDesMonats.enumerated()), id: \.offset) { _, datum in
                    if let datum {
                        CalendarDayButton(
                            date: datum,
                            calendar: calendar,
                            isSelected: calendar.isDate(datum, inSameDayAs: selectedDate),
                            hasTraining: trainingstage.contains(calendar.startOfDay(for: datum)),
                            hasCompetition: wettkampfTage.contains(calendar.startOfDay(for: datum)),
                            onSelect: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedDate = calendar.startOfDay(for: datum)
                                }
                            },
                            onDoubleTap: {
                                onDayDoubleTap(datum)
                            }
                        )
                    } else {
                        Color.clear.frame(height: 56)
                    }
                }
            }

            HStack(spacing: 16) {
                KalenderLegendePill(farbe: AppTheme.accent, titel: "Training")
                KalenderLegendePill(farbe: .orange, titel: "Wettkampf")
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func verschiebeMonat(_ delta: Int) {
        guard let neuerMonat = calendar.date(byAdding: DateComponents(month: delta), to: displayedMonth) else { return }
        let normalisiert = calendar.date(from: calendar.dateComponents([.year, .month], from: neuerMonat)) ?? neuerMonat
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = normalisiert
        }
    }
}

private struct CalendarDayButton: View {
    let date: Date
    let calendar: Calendar
    let isSelected: Bool
    let hasTraining: Bool
    let hasCompetition: Bool
    let onSelect: () -> Void
    let onDoubleTap: () -> Void

    private var tagNummer: String {
        let tag = calendar.component(.day, from: date)
        return String(tag)
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isSelected ? AppTheme.accent : .clear)
                    .overlay(
                        Circle()
                            .stroke(AppTheme.accent, lineWidth: (!isSelected && calendar.isDateInToday(date)) ? 1.5 : 0)
                    )
                    .frame(width: 38, height: 38)

                Text(tagNummer)
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
            }

            HStack(spacing: 4) {
                if hasTraining {
                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: 6, height: 6)
                }
                if hasCompetition {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(height: 8)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .contentShape(Rectangle())
        .highPriorityGesture(
            TapGesture(count: 2)
                .onEnded { onDoubleTap() }
        )
        .gesture(
            TapGesture()
                .onEnded { onSelect() }
        )
    }
}

private struct KalenderLegendePill: View {
    let farbe: Color
    let titel: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(farbe)
                .frame(width: 8, height: 8)
            Text(titel)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

struct TrainingCell: View {
    let session: TrainingSession
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(session.gesamtMeter) m")
                    .font(.title3.bold())
                Spacer()
                Text("\(session.gesamtDauerSek/60) min")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Label("Borg \(session.borgWert)/10", systemImage: "heart.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.pink)
                Spacer()
                Text(session.datum, style: .date)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let gefuehl = session.gefuehl, !gefuehl.isEmpty {
                Text(gefuehl)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .glassCard(contentPadding: 16)
    }
}

struct CompetitionCell: View {
    let comp: Competition
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(comp.name)
                    .font(.title3.bold())
                Spacer()
                Text(comp.bahn.titel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Label(comp.ort, systemImage: "mappin.and.ellipse")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(comp.datum, style: .date)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .glassCard(contentPadding: 16)
    }
}
