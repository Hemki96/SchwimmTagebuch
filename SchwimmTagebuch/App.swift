import SwiftUI
import SwiftData

@main
struct SchwimmTagebuchApp: App {
    init() {
        UserDefaults.standard.register(defaults: [
            SettingsKeys.weeklyGoal: 15000,
            SettingsKeys.goalTrackingEnabled: true,
            SettingsKeys.reminderEnabled: false,
            SettingsKeys.reminderWeekday: Weekday.monday.rawValue,
            SettingsKeys.autoExportEnabled: false,
            SettingsKeys.autoExportFormat: ExportFormat.json.rawValue,
            SettingsKeys.showEquipmentBadges: true,
            SettingsKeys.defaultSessionMeters: 3000,
            SettingsKeys.defaultSessionDuration: 60,
            SettingsKeys.defaultSessionBorg: 5,
            SettingsKeys.defaultSessionOrt: Ort.becken.rawValue
        ])
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, Locale(identifier: "de"))
        }
        .modelContainer(sharedContainer)
    }
}

let sharedSchema = Schema([
    TrainingSession.self, WorkoutSet.self, SetLap.self, Competition.self, RaceResult.self
])
let sharedContainer: ModelContainer = {
    do {
        let config = ModelConfiguration(schema: sharedSchema, isStoredInMemoryOnly: false)
        return try ModelContainer(for: sharedSchema, configurations: config)
    } catch {
        fatalError("ModelContainer-Fehler: \(error)")
    }
}()

struct RootView: View {
    var body: some View {
        TabView {
            CalendarView()
                .tabItem { Label("Kalender", systemImage: "calendar") }
            StatsView()
                .tabItem { Label("Statistiken", systemImage: "chart.bar") }
            SettingsView()
                .tabItem { Label("Einstellungen", systemImage: "gearshape") }
        }
        .modifier(LiquidTabBackground())
    }
}

struct LiquidTabBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
    }
}
