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
            SettingsKeys.defaultSessionOrt: Ort.becken.rawValue,
            SessionKeys.currentUserID: ""
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
    AppUser.self, TrainingSession.self, WorkoutSet.self, SetLap.self, Competition.self, RaceResult.self
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
    @Environment(\.modelContext) private var context
    @AppStorage(SessionKeys.currentUserID) private var storedUserID = ""
    @State private var currentUser: AppUser?
    @State private var isLoading = true
    @State private var showsRegistration = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Benutzer wird geladen…")
            } else if let user = currentUser {
                MainTabView()
                    .environment(\.currentUser, user)
                    .environment(\.logoutAction, logout)
            } else {
                LoginView(onLogin: handleLogin, onRegisterRequested: { showsRegistration = true })
                    .sheet(isPresented: $showsRegistration) {
                        RegistrationView(onRegister: handleLogin)
                    }
            }
        }
        .task { await loadStoredUser() }
    }

    private func loadStoredUser() async {
        guard isLoading else { return }
        defer { isLoading = false }
        guard let id = UUID(uuidString: storedUserID), !storedUserID.isEmpty else { return }
        var descriptor = FetchDescriptor<AppUser>(
            predicate: #Predicate<AppUser> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        if let found = try? context.fetch(descriptor).first {
            currentUser = found
        } else {
            storedUserID = ""
        }
    }

    private func handleLogin(_ user: AppUser) {
        currentUser = user
        storedUserID = user.id.uuidString
        isLoading = false
        showsRegistration = false
    }

    private func logout() {
        storedUserID = ""
        currentUser = nil
        isLoading = false
        showsRegistration = false
    }
}

struct MainTabView: View {
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
