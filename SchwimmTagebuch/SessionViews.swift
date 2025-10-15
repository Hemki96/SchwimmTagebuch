import SwiftUI
import SwiftData

struct SessionDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var session: TrainingSession
    @State private var zeigtSetEditor = false

    var body: some View {
        Form {
            Section("Übersicht") {
                DatePicker("Datum", selection: $session.datum, displayedComponents: .date)
                Stepper("Umfang (m): \(session.gesamtMeter)", value: $session.gesamtMeter, in: 0...60000, step: 50)
                Stepper("Dauer (min): \(session.gesamtDauerSek/60)", value: Binding(
                    get: { session.gesamtDauerSek/60 },
                    set: { session.gesamtDauerSek = $0*60 }
                ), in: 0...600)
                Picker("Intensität", selection: $session.intensitaet) {
                    ForEach(Intensitaet.allCases) { Text($0.titel).tag($0) }
                }
                Picker("Ort", selection: $session.ort) {
                    ForEach(Ort.allCases) { Text($0.titel).tag($0) }
                }
                TextField("Notizen", text: Binding($session.notizen, default: ""), axis: .vertical)
            }
            Section("Sets") {
                if session.sets.isEmpty {
                    Text("Noch keine Sets")
                } else {
                    ForEach(session.sets) { set in
                        NavigationLink {
                            SetDetailView(set: set)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(set.titel).font(.headline)
                                Text("\(set.wiederholungen)×\(set.distanzProWdh) m @ \(set.intervallSek)s").font(.footnote)
                            }
                        }
                    }
                    .onDelete { idx in session.sets.remove(atOffsets: idx) }
                }
                Button { zeigtSetEditor = true } label: { Label("Set hinzufügen", systemImage: "plus.circle") }
            }
        }
        .navigationTitle("Training")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Speichern") { try? context.save() }
            }
        }
        .sheet(isPresented: $zeigtSetEditor) {
            SetEditorSheet(session: session)
        }
    }
}

struct SetDetailView: View {
    @Bindable var set: WorkoutSet
    var body: some View {
        Form {
            Section("Details") {
                TextField("Titel", text: $set.titel)
                Stepper("Wiederholungen: \(set.wiederholungen)", value: $set.wiederholungen, in: 1...200)
                Stepper("Distanz/Wdh (m): \(set.distanzProWdh)", value: $set.distanzProWdh, in: 25...2000, step: 25)
                Stepper("Intervall (s): \(set.intervallSek)", value: $set.intervallSek, in: 10...600)
                TextField("Kommentar", text: Binding($set.kommentar, default: ""), axis: .vertical)
            }
            Section("Splits (s)") {
                ForEach(set.laps) { lap in
                    HStack {
                        Text("#\(lap.index+1)")
                        Spacer()
                        Text("\(lap.splitSek) s")
                    }
                }
            }
        }
        .navigationTitle("Set")
    }
}

struct SessionEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var datum = Date()
    @State private var meter = 3000
    @State private var dauerMin = 60
    @State private var intens: Intensitaet = .schwelle
    @State private var ort: Ort = .becken
    @State private var notizen = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Datum", selection: $datum, displayedComponents: .date)
                Stepper("Umfang (m): \(meter)", value: $meter, in: 0...60000, step: 50)
                Stepper("Dauer (min): \(dauerMin)", value: $dauerMin, in: 0...600)
                Picker("Intensität", selection: $intens) { ForEach(Intensitaet.allCases) { Text($0.titel).tag($0) } }
                Picker("Ort", selection: $ort) { ForEach(Ort.allCases) { Text($0.titel).tag($0) } }
                TextField("Notizen", text: $notizen, axis: .vertical)
            }
            .navigationTitle("Training erfassen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Speichern") { speichere() } }
            }
        }
    }
    private func speichere() {
        let s = TrainingSession(datum: datum, meter: meter, dauerSek: dauerMin*60, intensitaet: intens, notizen: notizen, ort: ort)
        context.insert(s)
        try? context.save()
        dismiss()
    }
}

struct SetEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: TrainingSession
    @State private var titel = "10×100 Freistil"
    @State private var wdh = 10
    @State private var dist = 100
    @State private var interv = 100
    @State private var kommentar = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Titel", text: $titel)
                Stepper("Wiederholungen: \(wdh)", value: $wdh, in: 1...200)
                Stepper("Distanz/Wdh (m): \(dist)", value: $dist, in: 25...2000, step: 25)
                Stepper("Intervall (s): \(interv)", value: $interv, in: 10...600)
                TextField("Kommentar", text: $kommentar, axis: .vertical)
            }
            .navigationTitle("Set hinzufügen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Speichern") { speichere() } }
            }
        }
    }
    private func speichere() {
        let neu = WorkoutSet(titel: titel, wiederholungen: wdh, distanzProWdh: dist, intervallSek: interv, kommentar: kommentar, session: session)
        session.sets.append(neu)
        try? session.modelContext?.save()
        dismiss()
    }
}
