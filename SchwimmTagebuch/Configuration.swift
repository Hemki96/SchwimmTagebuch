import Foundation

/// Zentraler Namespace für alle verwendeten UserDefaults-Keys.
enum SettingsKeys {
    static let weeklyGoal = "settings.weeklyGoal"
    static let goalTrackingEnabled = "settings.goalTrackingEnabled"
    static let reminderEnabled = "settings.reminderEnabled"
    static let reminderWeekday = "settings.reminderWeekday"
    static let autoExportEnabled = "settings.autoExportEnabled"
    static let autoExportFormat = "settings.autoExportFormat"
    static let showEquipmentBadges = "settings.showEquipmentBadges"
    static let defaultSessionMeters = "settings.defaultSessionMeters"
    static let defaultSessionDuration = "settings.defaultSessionDuration"
    static let defaultSessionBorg = "settings.defaultSessionBorg"
    static let defaultSessionOrt = "settings.defaultSessionOrt"
    static let lastBackupISO = "settings.lastBackupISO"
    static let defaultSessionIntensitaet = "settings.defaultSessionIntensitaet"
    static let cloudSyncEnabled = "settings.cloudSyncEnabled"
}

enum ExportFormat: String, CaseIterable, Identifiable, Codable {
    case json
    case csv
    case zipBundle

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV"
        case .zipBundle: return "ZIP-Bundle"
        }
    }

    var beschreibung: String {
        switch self {
        case .json: return "Enthält alle Daten strukturiert für Backups & Shortcuts."
        case .csv: return "Einfaches Tabellenformat für Tabellenkalkulationen."
        case .zipBundle: return "JSON + CSV in einer ZIP-Datei für komplette Sicherungen."
        }
    }

    var dateiendung: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        case .zipBundle: return "zip"
        }
    }
}

enum Weekday: Int, CaseIterable, Identifiable {
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    case sunday = 1

    var id: Int { rawValue }

    var titel: String {
        switch self {
        case .monday: return "Montag"
        case .tuesday: return "Dienstag"
        case .wednesday: return "Mittwoch"
        case .thursday: return "Donnerstag"
        case .friday: return "Freitag"
        case .saturday: return "Samstag"
        case .sunday: return "Sonntag"
        }
    }
}
