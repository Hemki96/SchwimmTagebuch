import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var sessions: [TrainingSession]
    @Query private var competitions: [Competition]
    @State private var zeigtResetAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Design") {
                    Text("Liquid-Glass-Effekt ist aktiv (Platzhalter-Material).")
                }
                Section("Daten") {
                    Button(role: .destructive) { zeigtResetAlert = true } label: { Text("Alle Daten löschen") }
                }
            }
            .alert("Alle Daten löschen?", isPresented: $zeigtResetAlert) {
                Button("Abbrechen", role: .cancel) {}
                Button("Löschen", role: .destructive) { resetData() }
            } message: {
                Text("Dies kann nicht rückgängig gemacht werden.")
            }
        }
        .navigationTitle("Einstellungen")
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Material.liquidGlass, for: .navigationBar)
    }

    private func resetData() {
        for s in sessions { context.delete(s) }
        for c in competitions { context.delete(c) }
        try? context.save()
    }
}
