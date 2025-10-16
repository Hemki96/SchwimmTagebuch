import Foundation
import UserNotifications

enum ReminderService {
    private static let identifier = "weekly.training.reminder"

    static func toggleWeeklyReminder(enabled: Bool, weekday: Weekday, goalMeters: Int) async throws {
        if enabled {
            let center = UNUserNotificationCenter.current()
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
            try await scheduleReminder(on: weekday, goalMeters: goalMeters)
        } else {
            await cancelReminder()
        }
    }

    static func scheduleReminder(on weekday: Weekday, goalMeters: Int) async throws {
        let center = UNUserNotificationCenter.current()
        await cancelReminder()

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

        try await center.add(request)
    }

    static func cancelReminder() async {
        let center = UNUserNotificationCenter.current()
        await center.removePendingNotificationRequests(withIdentifiers: [identifier])
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
