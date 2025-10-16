import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.currentUser) private var currentUser
    @Query(sort: \TrainingSession.datum, order: .reverse) private var sessions: [TrainingSession]
    @Query(sort: \Competition.datum, order: .reverse) private var competitions: [Competition]
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
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
                stelleTrainingseinheitSicher(fuer: normalisiert)
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
                    Section("Aktuelle Woche") {
                        VStack(alignment: .leading, spacing: 8) {
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
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Material.liquidGlass)
                        )
                    }
                }
                Section {
                    DatePicker("Datum auswählen", selection: selectedDateBinding, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                }

                Section("Training") {
                    if trainingsAmTag.isEmpty {
                        Text("Keine Trainingseinheiten für diesen Tag.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(trainingsAmTag) { session in
                            NavigationLink {
                                SessionDetailView(session: session)
                            } label: {
                                TrainingCell(session: session)
                            }
                        }
                        .onDelete { offsets in
                            loescheTraining(at: offsets, aus: trainingsAmTag)
                        }
                    }
                }

                Section("Wettkämpfe") {
                    if wettkaempfeAmTag.isEmpty {
                        Text("Keine Wettkämpfe für diesen Tag.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(wettkaempfeAmTag) { wettkampf in
                            NavigationLink {
                                CompetitionDetailView(comp: wettkampf)
                            } label: {
                                CompetitionCell(comp: wettkampf)
                            }
                        }
                        .onDelete { offsets in
                            loescheWettkampf(at: offsets, aus: wettkaempfeAmTag)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
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
        .toolbarBackground(Material.liquidGlass, for: .navigationBar)
        .onAppear {
            if !hatInitialCheckAusgefuehrt {
                hatInitialCheckAusgefuehrt = true
                stelleTrainingseinheitSicher(fuer: selectedDate)
            }
        }
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

struct TrainingCell: View {
    let session: TrainingSession
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(session.gesamtMeter) m").font(.headline)
                Spacer()
                Text("\(session.gesamtDauerSek/60) min").font(.subheadline)
            }
            HStack {
                Text("Borg: \(session.borgWert)/10").font(.footnote)
                Spacer()
                Text(session.datum, style: .date).font(.footnote)
            }
            if let gefuehl = session.gefuehl, !gefuehl.isEmpty {
                Text(gefuehl)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Material.liquidGlass)
        )
    }
}

struct CompetitionCell: View {
    let comp: Competition
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(comp.name).font(.headline)
                Spacer()
                Text(comp.bahn.titel).font(.subheadline)
            }
            HStack {
                Text(comp.ort).font(.footnote)
                Spacer()
                Text(comp.datum, style: .date).font(.footnote)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Material.liquidGlass)
        )
    }
}
