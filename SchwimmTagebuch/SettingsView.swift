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
    @AppStorage(SettingsKeys.defaultSessionIntensitaet) private var defaultSessionIntensitaetRaw = ""
    @AppStorage(SettingsKeys.cloudSyncEnabled) private var cloudSyncEnabled = false
    @AppStorage(SettingsKeys.lastBackupISO) private var lastBackupISO = ""

    private var reminderWeekday: Binding<Weekday> {
        Binding(
            get: { Weekday(rawValue: reminderWeekdayRaw) ?? .monday },
            set: { reminderWeekdayRaw = $0.rawValue }
        )
    }
    private var defaultIntensitaet: Binding<Intensitaet?> {
        Binding(
            get: { Intensitaet(rawValue: defaultSessionIntensitaetRaw) },
            set: { newValue in defaultSessionIntensitaetRaw = newValue?.rawValue ?? "" }
        )
    }
    private var autoExportFormat: ExportFormat { ExportFormat(rawValue: autoExportFormatRaw) ?? .json }
    private var lastBackupDescription: String {
        guard let date = ISO8601DateFormatter().date(from: lastBackupISO) else { return "Noch keine Sicherung" }
        let formatter = DateFormatter(); formatter.dateStyle = .medium; formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    @State private var reminderFehlerText = ""
    @State private var zeigtReminderFehler = false
    @State private var cloudSyncStatusText = ""
    @State private var cloudSyncFehlerText = ""
    @State private var zeigtCloudSyncFehler = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Benutzer") {
                    if let user = currentUser {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.displayName)
                                .font(.headline)
                            Text(user.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let logoutAction {
                            Button("Abmelden", role: .destructive, action: logoutAction)
                        }
                    } else {
                        Text("Kein Benutzer angemeldet")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Profil & Ziele") {
                    Toggle("Ziel-Tracking aktiv", isOn: $goalTrackingEnabled)
                    if goalTrackingEnabled {
                        Stepper(value: $weeklyGoal, in: 1000...100_000, step: 500) {
                            Text("Wöchentliches Ziel: \(weeklyGoal.formatted()) m")
                        }
                        Toggle("Wöchentliche Erinnerung", isOn: $reminderEnabled)
                        if reminderEnabled {
                            Picker("Erinnerungstag", selection: reminderWeekday) {
                                ForEach(Weekday.allCases) { day in
                                    Text(day.titel).tag(day)
                                }
                            }
                            Text("Benachrichtigung: \(reminderWeekday.wrappedValue.titel) um 18:30 Uhr")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Trainings-Defaults") {
                    Stepper(value: $defaultSessionMeters, in: 500...20_000, step: 250) {
                        Text("Standardumfang: \(defaultSessionMeters) m")
                    }
                    Stepper(value: $defaultSessionDuration, in: 10...240, step: 5) {
                        Text("Standarddauer: \(defaultSessionDuration) min")
                    }
                    Stepper(value: $defaultSessionBorg, in: 1...10) {
                        Text("Standard-Borg: \(defaultSessionBorg)")
                    }
                    Picker("Standard-Ort", selection: $defaultSessionOrtRaw) {
                        ForEach(Ort.allCases) { ort in
                            Text(ort.titel).tag(ort.rawValue)
                        }
                    }
                    Picker("Standard-Intensität", selection: defaultIntensitaet) {
                        Text("Keine").tag(Intensitaet?.none)
                        ForEach(Intensitaet.allCases) { option in
                            Text(option.titel).tag(Intensitaet?.some(option))
                        }
                    }
                }
                Section("Darstellung") {
                    Toggle("Equipment & Technik im Überblick zeigen", isOn: $showEquipmentBadges)
                    Text("Liquid-Glass-Effekt mit Farbverlauf ist aktiv.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Export & Synchronisation") {
                    Toggle("Automatische Sicherung aktivieren", isOn: $autoExportEnabled)
                    Picker("Exportformat", selection: $autoExportFormatRaw) {
                        ForEach(ExportFormat.allCases) { format in
                            Text(format.titel).tag(format.rawValue)
                        }
                    }
                    Text(autoExportFormat.beschreibung)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        starteBackup()
                    } label: {
                        Label("Backup jetzt erstellen", systemImage: "externaldrive")
                    }
                    .disabled(userSessions.isEmpty && userCompetitions.isEmpty)
                    Text("Letzte Sicherung: \(lastBackupDescription)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("Backup zusätzlich in iCloud Drive sichern", isOn: $cloudSyncEnabled)
                    if !cloudSyncStatusText.isEmpty {
                        Text(cloudSyncStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if cloudSyncEnabled {
                        Text("Wird nach dem nächsten Backup mit iCloud Drive synchronisiert.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
        .navigationTitle("Einstellungen")
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Material.liquidGlass, for: .navigationBar)
        .onChange(of: reminderEnabled) { neuerWert in
            Task { await aktualisiereReminder(enabled: neuerWert) }
        }
        .onChange(of: reminderWeekday.wrappedValue) { _ in
            Task { await aktualisiereReminder(enabled: reminderEnabled) }
        }
        .onChange(of: cloudSyncEnabled) { enabled in
            if !enabled {
                cloudSyncStatusText = ""
            } else if let backupURL {
                do {
                    let cloudURL = try CloudSyncService.synchronize(localBackup: backupURL)
                    cloudSyncStatusText = "In iCloud gespeichert als \(cloudURL.lastPathComponent)"
                } catch {
                    cloudSyncFehlerText = error.localizedDescription
                    zeigtCloudSyncFehler = true
                }
            }
        }
        .alert("Erinnerung nicht möglich", isPresented: $zeigtReminderFehler) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(reminderFehlerText)
        }
        .alert("Cloud-Sync fehlgeschlagen", isPresented: $zeigtCloudSyncFehler) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(cloudSyncFehlerText)
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
            if cloudSyncEnabled {
                do {
                    let cloudURL = try CloudSyncService.synchronize(localBackup: url)
                    cloudSyncStatusText = "In iCloud gespeichert als \(cloudURL.lastPathComponent)"
                } catch {
                    cloudSyncFehlerText = error.localizedDescription
                    zeigtCloudSyncFehler = true
                }
            }
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

    @MainActor
    private func aktualisiereReminder(enabled: Bool) async {
        do {
            try await ReminderService.toggleWeeklyReminder(enabled: enabled, weekday: reminderWeekday.wrappedValue, goalMeters: weeklyGoal)
        } catch {
            reminderFehlerText = error.localizedDescription
            zeigtReminderFehler = true
            reminderEnabled = false
        }
    }
}
