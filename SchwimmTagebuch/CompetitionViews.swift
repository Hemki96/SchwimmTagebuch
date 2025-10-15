import SwiftUI
import SwiftData

struct CompetitionDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var comp: Competition
    @State private var zeigtErgebnisEditor = false

    var body: some View {
        Form {
            Section("Veranstaltung") {
                DatePicker("Datum", selection: $comp.datum, displayedComponents: .date)
                TextField("Name", text: $comp.name)
                TextField("Ort", text: $comp.ort)
                Picker("Bahn", selection: $comp.bahn) {
                    ForEach(Bahn.allCases) { Text($0.titel).tag($0) }
                }
            }
            Section("Ergebnisse") {
                if comp.results.isEmpty {
                    Text("Noch keine Ergebnisse")
                } else {
                    ForEach(comp.results) { r in
                        HStack {
                            Text("\(r.distanz) m \(r.lage.titel)")
                            Spacer()
                            Text(Zeit.formatSek(r.zeitSek))
                            if r.istPB { Image(systemName: "star.fill").foregroundStyle(.yellow) }
                        }
                    }
                    .onDelete { idx in comp.results.remove(atOffsets: idx) }
                }
                Button { zeigtErgebnisEditor = true } label: { Label("Ergebnis hinzufügen", systemImage: "plus.circle") }
            }
        }
        .navigationTitle("Wettkampf")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Speichern") { try? context.save() } } }
        .sheet(isPresented: $zeigtErgebnisEditor) { RaceResultEditorSheet(comp: comp) }
    }
}

struct RaceResultEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var comp: Competition
    @State private var lage: Lage = .freistil
    @State private var distanz: Int = 100
    @State private var zeitMin: Int = 1
    @State private var zeitSek: Int = 5
    @State private var zeitHund: Int = 0
    @State private var istPB: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Picker("Lage", selection: $lage) { ForEach(Lage.allCases) { Text($0.titel).tag($0) } }
                Stepper("Distanz (m): \(distanz)", value: $distanz, in: 25...1500, step: 25)
                HStack {
                    Stepper("Min: \(zeitMin)", value: $zeitMin, in: 0...59)
                    Stepper("Sek: \(zeitSek)", value: $zeitSek, in: 0...59)
                    Stepper("Hundertstel: \(zeitHund)", value: $zeitHund, in: 0...99)
                }
                Toggle("Persönliche Bestzeit", isOn: $istPB)
            }
            .navigationTitle("Ergebnis erfassen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Speichern") { speichere() } }
            }
        }
    }
    private func speichere() {
        let totalSek = zeitMin*60 + zeitSek
        let r = RaceResult(lage: lage, distanz: distanz, zeitSek: totalSek)
        r.istPB = istPB
        r.competition = comp
        comp.results.append(r)
        try? comp.modelContext?.save()
        dismiss()
    }
}
