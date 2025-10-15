import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TrainingSession.datum, order: .reverse) private var sessions: [TrainingSession]
    @Query(sort: \Competition.datum, order: .reverse) private var competitions: [Competition]
    @State private var zeigtTrainingEditor = false
    @State private var zeigtWettkampfEditor = false

    var body: some View {
        NavigationStack {
            List {
                if !sessions.isEmpty {
                    Section("Training") {
                        ForEach(sessions) { s in
                            NavigationLink {
                                SessionDetailView(session: s)
                            } label: {
                                TrainingCell(session: s)
                            }
                        }.onDelete(perform: loescheTraining)
                    }
                }
                if !competitions.isEmpty {
                    Section("Wettkämpfe") {
                        ForEach(competitions) { c in
                            NavigationLink {
                                CompetitionDetailView(comp: c)
                            } label: {
                                CompetitionCell(comp: c)
                            }
                        }.onDelete(perform: loescheWettkampf)
                    }
                }
                if sessions.isEmpty && competitions.isEmpty {
                    ContentUnavailableView("Noch keine Einträge", systemImage: "calendar.badge.plus", description: Text("Lege Training oder Wettkämpfe an."))
                }
            }
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
            .sheet(isPresented: $zeigtTrainingEditor) { SessionEditorSheet() }
            .sheet(isPresented: $zeigtWettkampfEditor) { CompetitionEditorSheet() }
        }
        .navigationTitle("Kalender")
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Material.liquidGlass, for: .navigationBar)
    }

    private func loescheTraining(at offsets: IndexSet) {
        for i in offsets { context.delete(sessions[i]) }
        try? context.save()
    }
    private func loescheWettkampf(at offsets: IndexSet) {
        for i in offsets { context.delete(competitions[i]) }
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
