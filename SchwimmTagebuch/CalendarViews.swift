import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var context
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

    private var trainingsAmTag: [TrainingSession] {
        sessions.filter { kalender.isDate($0.datum, inSameDayAs: selectedDate) }
    }

    private var wettkaempfeAmTag: [Competition] {
        competitions.filter { kalender.isDate($0.datum, inSameDayAs: selectedDate) }
    }

    var body: some View {
        NavigationStack {
            List {
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
        guard !sessions.contains(where: { kalender.isDate($0.datum, inSameDayAs: datum) }) else { return }
        let neueSession = TrainingSession(datum: datum, meter: 0, dauerSek: 0, intensitaet: .locker)
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
                Text(session.intensitaet.titel).font(.footnote)
                Spacer()
                Text(session.datum, style: .date).font(.footnote)
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
