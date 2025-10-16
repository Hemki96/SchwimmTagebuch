import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.currentUser) private var currentUser
    @Environment(\.logoutAction) private var logoutAction
    @Query private var sessions: [TrainingSession]
    @Query private var competitions: [Competition]
    @State private var zeigtResetAlert = false
    @State private var zeigtShareSheet = false
    @State private var backupURL: URL?
    @State private var zeigtBackupFehler = false
    @State private var backupFehlerText = ""
    @AppStorage(SettingsKeys.weeklyGoal) private var weeklyGoal = 15000
    @AppStorage(SettingsKeys.goalTrackingEnabled) private var goalTrackingEnabled = true
    @AppStorage(SettingsKeys.reminderEnabled) private var reminderEnabled = false
    @AppStorage(SettingsKeys.reminderWeekday) private var reminderWeekdayRaw = Weekday.monday.rawValue
    @AppStorage(SettingsKeys.autoExportEnabled) private var autoExportEnabled = false
    @AppStorage(SettingsKeys.autoExportFormat) private var autoExportFormatRaw = ExportFormat.json.rawValue
    @AppStorage(SettingsKeys.showEquipmentBadges) private var showEquipmentBadges = true
    @AppStorage(SettingsKeys.defaultSessionMeters) private var defaultSessionMeters = 3000
    @AppStorage(SettingsKeys.defaultSessionDuration) private var defaultSessionDuration = 60
    @AppStorage(SettingsKeys.defaultSessionBorg) private var defaultSessionBorg = 5
    @AppStorage(SettingsKeys.defaultSessionOrt) private var defaultSessionOrtRaw = Ort.becken.rawValue
    @AppStorage(SettingsKeys.lastBackupISO) private var lastBackupISO = ""

    private var reminderWeekday: Binding<Weekday> {
        Binding(
            get: { Weekday(rawValue: reminderWeekdayRaw) ?? .monday },
            set: { reminderWeekdayRaw = $0.rawValue }
        )
    }
    private var autoExportFormat: ExportFormat { ExportFormat(rawValue: autoExportFormatRaw) ?? .json }
    private var lastBackupDescription: String {
        guard let date = ISO8601DateFormatter().date(from: lastBackupISO) else { return "Noch keine Sicherung" }
        let formatter = DateFormatter(); formatter.dateStyle = .medium; formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 24) {
                    SettingsSection(title: "Benutzer", systemImage: "person.circle") {
                        if let user = currentUser {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(user.displayName)
                                    .font(.title3.weight(.semibold))
                                Text(user.email)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            if let logoutAction {
                                Button(role: .destructive, action: logoutAction) {
                                    Label("Abmelden", systemImage: "rectangle.portrait.and.arrow.right")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red.opacity(0.8))
                            }
                        } else {
                            Text("Kein Benutzer angemeldet")
                                .foregroundStyle(.secondary)
                        }
                    }

                    SettingsSection(title: "Profil & Ziele", systemImage: "target") {
                        Toggle("Ziel-Tracking aktiv", isOn: $goalTrackingEnabled)
                        if goalTrackingEnabled {
                            Divider()
                            Stepper(value: $weeklyGoal, in: 1000...100_000, step: 500) {
                                Text("Wöchentliches Ziel: \(weeklyGoal.formatted()) m")
                                    .font(.body.weight(.semibold))
                            }
                            Divider()
                            Toggle("Wöchentliche Erinnerung", isOn: $reminderEnabled)
                            if reminderEnabled {
                                Picker("Erinnerungstag", selection: reminderWeekday) {
                                    ForEach(Weekday.allCases) { day in
                                        Text(day.titel).tag(day)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                    }

                    SettingsSection(title: "Trainings-Defaults", systemImage: "figure.pool.swim") {
                        Stepper(value: $defaultSessionMeters, in: 500...20_000, step: 250) {
                            Text("Standardumfang: \(defaultSessionMeters) m")
                                .font(.body.weight(.semibold))
                        }
                        Divider()
                        Stepper(value: $defaultSessionDuration, in: 10...240, step: 5) {
                            Text("Standarddauer: \(defaultSessionDuration) min")
                                .font(.body.weight(.semibold))
                        }
                        Divider()
                        Stepper(value: $defaultSessionBorg, in: 1...10) {
                            Text("Standard-Borg: \(defaultSessionBorg)")
                                .font(.body.weight(.semibold))
                        }
                        Divider()
                        Picker("Standard-Ort", selection: $defaultSessionOrtRaw) {
                            ForEach(Ort.allCases) { ort in
                                Text(ort.titel).tag(ort.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    SettingsSection(title: "Darstellung", systemImage: "sparkles.rectangle.stack") {
                        Toggle("Equipment & Technik im Überblick zeigen", isOn: $showEquipmentBadges)
                        Text("Liquid-Glass-Effekt ist aktiv und folgt dem neuen iOS 26-Design.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    SettingsSection(title: "Export & Synchronisation", systemImage: "arrow.triangle.2.circlepath") {
                        Toggle("Automatische Sicherung aktivieren", isOn: $autoExportEnabled)
                        Divider()
                        Picker("Exportformat", selection: $autoExportFormatRaw) {
                            ForEach(ExportFormat.allCases) { format in
                                Text(format.titel).tag(format.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text(autoExportFormat.beschreibung)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Divider()
                        Button {
                            starteBackup()
                        } label: {
                            Label("Backup jetzt erstellen", systemImage: "externaldrive")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(userSessions.isEmpty && userCompetitions.isEmpty)
                        .tint(AppTheme.accent)
                        Text("Letzte Sicherung: \(lastBackupDescription)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    SettingsSection(title: "Datenverwaltung", systemImage: "trash") {
                        Button(role: .destructive) {
                            zeigtResetAlert = true
                        } label: {
                            Label("Alle Daten löschen", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
            }
        }
        .navigationTitle("Einstellungen")
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.barMaterial, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .appSurfaceBackground()
        .alert("Alle Daten löschen?", isPresented: $zeigtResetAlert) {
            Button("Abbrechen", role: .cancel) {}
            Button("Löschen", role: .destructive) { resetData() }
        } message: {
            Text("Dies kann nicht rückgängig gemacht werden.")
        }
        .sheet(isPresented: $zeigtShareSheet) {
            if let backupURL {
                ShareSheet(activityItems: [backupURL])
            }
        }
        .alert("Backup fehlgeschlagen", isPresented: $zeigtBackupFehler) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(backupFehlerText)
        }
    }

    private func resetData() {
        let eigeneSessions = userSessions
        let eigeneWettkaempfe = userCompetitions
        for s in eigeneSessions { context.delete(s) }
        for c in eigeneWettkaempfe { context.delete(c) }
        try? context.save()
    }

    private func starteBackup() {
        do {
            let url = try AutoBackupService.performBackup(sessions: userSessions, competitions: userCompetitions, format: autoExportFormat)
            lastBackupISO = ISO8601DateFormatter().string(from: Date())
            backupURL = url
            zeigtShareSheet = true
        } catch {
            backupFehlerText = error.localizedDescription
            zeigtBackupFehler = true
        }
    }

    private var userSessions: [TrainingSession] {
        guard let userID = currentUser?.id else { return [] }
        return sessions.filter { $0.owner?.id == userID }
    }

    private var userCompetitions: [Competition] {
        guard let userID = currentUser?.id else { return [] }
        return competitions.filter { $0.owner?.id == userID }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderLabel(title, systemImage: systemImage)
            VStack(alignment: .leading, spacing: 16) {
                content
            }
        }
        .glassCard()
        .tint(AppTheme.accent)
    }
}
