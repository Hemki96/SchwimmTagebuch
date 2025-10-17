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
                            Text(Zeit.formatSek(r.zeitSek, hundertstel: r.zeitHundertstel))
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

struct CompetitionEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.currentUser) private var currentUser

    @State private var datum: Date
    @State private var name = ""
    @State private var ort = ""
    @State private var bahn: Bahn = .scm25

    init(initialDate: Date = Date()) {
        _datum = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Datum", selection: $datum, displayedComponents: .date)
                TextField("Name", text: $name)
                TextField("Ort", text: $ort)
                Picker("Bahn", selection: $bahn) {
                    ForEach(Bahn.allCases) { Text($0.titel).tag($0) }
                }
            }
            .navigationTitle("Wettkampf erfassen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Speichern") { speichere() } }
            }
        }
    }

    private func speichere() {
        guard let user = currentUser else { return }
        let neu = Competition(datum: datum, name: name.isEmpty ? "Unbenannter Wettkampf" : name, ort: ort, bahn: bahn, owner: user)
        context.insert(neu)
        try? context.save()
        dismiss()
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
                Section("Rennen") {
                    Picker("Lage", selection: $lage) { ForEach(Lage.allCases) { Text($0.titel).tag($0) } }
                    Stepper("Distanz (m): \(distanz)", value: $distanz, in: 25...1500, step: 25)
                }

                Section("Zeit") {
                    RaceTimeInputView(minuten: $zeitMin, sekunden: $zeitSek, hundertstel: $zeitHund)
                }

                Section {
                    Toggle("Persönliche Bestzeit", isOn: $istPB)
                }
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
        let r = RaceResult(lage: lage, distanz: distanz, zeitSek: totalSek, zeitHundertstel: zeitHund)
        r.istPB = istPB
        r.competition = comp
        comp.results.append(r)
        try? comp.modelContext?.save()
        dismiss()
    }
}

private struct RaceTimeInputView: View {
    @Binding var minuten: Int
    @Binding var sekunden: Int
    @Binding var hundertstel: Int

    private var anzeigetext: String {
        Zeit.formatSek(minuten * 60 + sekunden, hundertstel: hundertstel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Gesamtzeit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(anzeigetext)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }

            HStack(spacing: 12) {
                TimeComponentStepper(title: "Minuten", value: $minuten, range: 0...59)
                TimeComponentStepper(title: "Sekunden", value: $sekunden, range: 0...59)
                TimeComponentStepper(title: "Hundertstel", value: $hundertstel, range: 0...99)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct TimeComponentStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    private var format: String {
        range.upperBound >= 100 ? "%03d" : "%02d"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Stepper(value: $value, in: range, step: 1) {
                Text(String(format: format, value))
                    .font(.title3.monospacedDigit())
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
        }
    }
}
