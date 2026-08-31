import AppKit
import OSLog
import SwiftData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let logger = Logger(
        subsystem: "whywhy.FloatingTaskTimer",
        category: "Persistence"
    )

    let modelContainer: ModelContainer
    let taskStore: TaskStore
    let settingsStore: SettingsStore
    let navigation: AppNavigation
    let windowManager: WindowManager

    override init() {
        let environment = Self.makeEnvironment()
        modelContainer = environment.container
        taskStore = environment.store
        settingsStore = SettingsStore()
        navigation = AppNavigation()
        windowManager = WindowManager(
            taskStore: taskStore,
            navigation: navigation,
            settings: settingsStore
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowManager.showWindow()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if !flag {
            windowManager.showWindow()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private static func makeEnvironment() -> (container: ModelContainer, store: TaskStore) {
        let schema = Schema([
            PersistedTaskSession.self,
            PersistedTaskStoreState.self,
        ])
        let modelConfiguration = ModelConfiguration(
            "TaskSessions",
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            let store = try TaskStore(persistence: TaskSessionStore(modelContext: container.mainContext))
            return (container, store)
        } catch {
            Self.logger.error(
                "Could not open the persistent store: \(error.localizedDescription, privacy: .public)"
            )

            do {
                let fallbackConfiguration = ModelConfiguration(
                    "TaskSessionsFallback",
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
                let container = try ModelContainer(for: schema, configurations: [fallbackConfiguration])
                let store = try TaskStore(persistence: TaskSessionStore(modelContext: container.mainContext))
                return (container, store)
            } catch {
                fatalError("Could not create fallback application environment: \(error)")
            }
        }
    }
}
