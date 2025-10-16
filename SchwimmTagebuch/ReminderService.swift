import Foundation
import UserNotifications

enum ReminderService {
    private static let identifier = "weekly.training.reminder"

    static func toggleWeeklyReminder(enabled: Bool, weekday: Weekday, goalMeters: Int) async throws {
        let center = UNUserNotificationCenter.current()
        if enabled {
            let status = await center.notificationSettings()
            switch status.authorizationStatus {
            case .notDetermined:
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                if !granted {
                    throw ReminderError.authorizationDenied
                }
            case .denied:
                throw ReminderError.authorizationDenied
            default:
                break
            }
            try await scheduleReminder(on: weekday, goalMeters: goalMeters, center: center)
        } else {
            cancelReminder(center: center)
        }
    }

    static func scheduleReminder(on weekday: Weekday, goalMeters: Int) async throws {
        try await scheduleReminder(on: weekday, goalMeters: goalMeters, center: UNUserNotificationCenter.current())
    }

    private static func scheduleReminder(on weekday: Weekday, goalMeters: Int, center: UNUserNotificationCenter) async throws {
        cancelReminder(center: center)

        var dateComponents = DateComponents()
        dateComponents.weekday = weekday.rawValue
        dateComponents.hour = 18
        dateComponents.minute = 30

        let content = UNMutableNotificationContent()
        content.title = "Zeit für dein Schwimmziel"
        content.body = "Du planst \(goalMeters) m pro Woche. Eine Einheit wartet!"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try await add(request: request, center: center)
    }

    static func cancelReminder() {
        cancelReminder(center: UNUserNotificationCenter.current())
    }

    private static func cancelReminder(center: UNUserNotificationCenter) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    private static func add(request: UNNotificationRequest, center: UNUserNotificationCenter) async throws {
        try await withCheckedThrowingContinuation { continuation in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    enum ReminderError: LocalizedError {
        case authorizationDenied

        var errorDescription: String? {
            switch self {
            case .authorizationDenied:
                return "Benachrichtigungen sind deaktiviert. Aktiviere sie in den iOS-Einstellungen."
            }
        }
    }
}
