import SwiftUI
import SwiftData

struct SessionDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var session: TrainingSession
    @State private var zeigtSetEditor = false
    @AppStorage(SettingsKeys.showEquipmentBadges) private var showEquipmentBadges = true

    var body: some View {
        Form {
            Section("Übersicht") {
                DatePicker("Datum", selection: $session.datum, displayedComponents: .date)
                TextField("Umfang (m)", value: $session.gesamtMeter, format: .number)
                    .keyboardType(.numberPad)
                TextField("Dauer (min)", value: Binding(
                    get: { session.gesamtDauerSek/60 },
                    set: { session.gesamtDauerSek = max(0, $0*60) }
                ), format: .number)
                    .keyboardType(.numberPad)
                Picker("Intensität (Borg 1-10)", selection: $session.borgWert) {
                    ForEach(1...10, id: \.self) { Text("\($0)").tag($0) }
                }
                Picker("Ort", selection: $session.ort) {
                    ForEach(Ort.allCases) { Text($0.titel).tag($0) }
                }
                TextField("Eigenes Gefühl", text: Binding($session.gefuehl, default: ""), axis: .vertical)
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
                                if showEquipmentBadges {
                                    let equipmentTitel = set.equipment.map { TrainingEquipment(rawValue: $0)?.titel ?? $0 }
                                    if !equipmentTitel.isEmpty {
                                        Text(equipmentTitel.joined(separator: ", "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    let fokusTitel = set.technikSchwerpunkte.map { TechniqueFocus(rawValue: $0)?.titel ?? $0 }
                                    if !fokusTitel.isEmpty {
                                        Text(fokusTitel.joined(separator: ", "))
                                            .font(.caption2)
                                            .foregroundStyle(.teal)
                                    }
                                }
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
            Section("Equipment") {
                ForEach(TrainingEquipment.allCases) { option in
                    Toggle(isOn: Binding(
                        get: { set.equipment.contains(option.rawValue) },
                        set: { set.equipment.updatePresence(of: option.rawValue, include: $0) }
                    )) {
                        Label(option.titel, systemImage: option.systemImage)
                    }
                }
            }
            Section("Technik-Fokus") {
                if set.technikSchwerpunkte.isEmpty {
                    Text("Wähle die Schwerpunkte dieses Sets aus.")
                        .foregroundStyle(.secondary)
                }
                ForEach(TechniqueFocus.allCases) { fokus in
                    Toggle(isOn: Binding(
                        get: { set.technikSchwerpunkte.contains(fokus.rawValue) },
                        set: { set.technikSchwerpunkte.updatePresence(of: fokus.rawValue, include: $0) }
                    )) {
                        VStack(alignment: .leading) {
                            Text(fokus.titel)
                            Text(fokus.beschreibung)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
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
    @State private var datum: Date
    @State private var meter = 3000
    @State private var dauerMin = 60
    @State private var borg = 5
    @State private var ort: Ort = .becken
    @State private var gefuehl = ""
    @State private var notizen = ""

    init(initialDate: Date = Date()) {
        _datum = State(initialValue: initialDate)
        let defaults = UserDefaults.standard
        let meters = defaults.integer(forKey: SettingsKeys.defaultSessionMeters)
        _meter = State(initialValue: meters > 0 ? meters : 3000)
        let duration = defaults.integer(forKey: SettingsKeys.defaultSessionDuration)
        _dauerMin = State(initialValue: duration > 0 ? duration : 60)
        let borgDefault = defaults.integer(forKey: SettingsKeys.defaultSessionBorg)
        _borg = State(initialValue: borgDefault > 0 ? borgDefault : 5)
        if let ortRaw = defaults.string(forKey: SettingsKeys.defaultSessionOrt), let defaultOrt = Ort(rawValue: ortRaw) {
            _ort = State(initialValue: defaultOrt)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Datum", selection: $datum, displayedComponents: .date)
                TextField("Umfang (m)", value: $meter, format: .number)
                    .keyboardType(.numberPad)
                TextField("Dauer (min)", value: $dauerMin, format: .number)
                    .keyboardType(.numberPad)
                Picker("Intensität (Borg 1-10)", selection: $borg) {
                    ForEach(1...10, id: \.self) { Text("\($0)").tag($0) }
                }
                Picker("Ort", selection: $ort) { ForEach(Ort.allCases) { Text($0.titel).tag($0) } }
                TextField("Eigenes Gefühl", text: $gefuehl, axis: .vertical)
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
        let s = TrainingSession(
            datum: datum,
            meter: meter,
            dauerSek: dauerMin*60,
            borgWert: borg,
            notizen: notizen.isEmpty ? nil : notizen,
            ort: ort,
            gefuehl: gefuehl.isEmpty ? nil : gefuehl
        )
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
    @State private var selectedEquipment: Set<TrainingEquipment> = []
    @State private var selectedFokus: Set<TechniqueFocus> = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Titel", text: $titel)
                    Stepper("Wiederholungen: \(wdh)", value: $wdh, in: 1...200)
                    Stepper("Distanz/Wdh (m): \(dist)", value: $dist, in: 25...2000, step: 25)
                    Stepper("Intervall (s): \(interv)", value: $interv, in: 10...600)
                    TextField("Kommentar", text: $kommentar, axis: .vertical)
                }
                Section("Equipment") {
                    ForEach(TrainingEquipment.allCases) { option in
                        Toggle(isOn: Binding(
                            get: { selectedEquipment.contains(option) },
                            set: { isOn in
                                if isOn {
                                    selectedEquipment.insert(option)
                                } else {
                                    selectedEquipment.remove(option)
                                }
                            }
                        )) {
                            Label(option.titel, systemImage: option.systemImage)
                        }
                    }
                }
                Section("Technik-Fokus") {
                    ForEach(TechniqueFocus.allCases) { fokus in
                        Toggle(isOn: Binding(
                            get: { selectedFokus.contains(fokus) },
                            set: { include in
                                if include {
                                    selectedFokus.insert(fokus)
                                } else {
                                    selectedFokus.remove(fokus)
                                }
                            }
                        )) {
                            VStack(alignment: .leading) {
                                Text(fokus.titel)
                                Text(fokus.beschreibung)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Set hinzufügen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Speichern") { speichere() } }
            }
        }
    }
    private func speichere() {
        let neu = WorkoutSet(
            titel: titel,
            wiederholungen: wdh,
            distanzProWdh: dist,
            intervallSek: interv,
            equipment: selectedEquipment.map { $0.rawValue }.sorted(),
            technikSchwerpunkte: selectedFokus.map { $0.rawValue }.sorted(),
            kommentar: kommentar,
            session: session
        )
        session.sets.append(neu)
        try? session.modelContext?.save()
        dismiss()
    }
}
