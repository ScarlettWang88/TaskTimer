import AppKit
import OSLog
import SwiftData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let modelContainer: ModelContainer
    let taskStore: TaskStore
    let settingsStore: SettingsStore
    let navigation: AppNavigation
    let windowManager: WindowManager
    private let startupPersistenceWarning: String?

    override init() {
        let isUITesting = ProcessInfo.processInfo.environment["FTT_UI_TESTING"] == "1"
        let environment = Self.makeEnvironment(isStoredInMemoryOnly: isUITesting)
        modelContainer = environment.container
        taskStore = environment.store
        startupPersistenceWarning = environment.warning
        let isolatedDefaults = isUITesting
            ? UserDefaults(suiteName: "whywhy.FloatingTaskTimer.UITests") ?? .standard
            : .standard
        if isUITesting {
            isolatedDefaults.removePersistentDomain(forName: "whywhy.FloatingTaskTimer.UITests")
        }
        settingsStore = SettingsStore(defaults: isolatedDefaults)
        navigation = AppNavigation()
        windowManager = WindowManager(
            taskStore: taskStore,
            navigation: navigation,
            settings: settingsStore,
            userDefaults: isolatedDefaults
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowManager.showWindowOnCurrentSpace()
        if let startupPersistenceWarning {
            windowManager.presentPersistenceWarning(startupPersistenceWarning)
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        // A visible timer may belong to another Space. Always summon the one
        // retained panel so reopening the app never navigates the user back to
        // the panel's previous desktop or full-screen Space.
        windowManager.showWindowOnCurrentSpace()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private static func makeEnvironment(isStoredInMemoryOnly: Bool = false) -> (
        container: ModelContainer,
        store: TaskStore,
        warning: String?
    ) {
        let schema = Schema([
            PersistedTaskSession.self,
            PersistedTaskStoreState.self,
        ])
        let modelConfiguration = ModelConfiguration(
            "TaskSessions",
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            let store = try TaskStore(persistence: TaskSessionStore(modelContext: container.mainContext))
            return (container, store, nil)
        } catch {
            AppLogger.persistence.fault(
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
                return (
                    container,
                    store,
                    "The local task database could not be opened. This launch is using temporary storage, so changes will not survive after the app quits. Quit the app and preserve your existing Application Support data before troubleshooting."
                )
            } catch {
                fatalError("Could not create fallback application environment: \(error)")
            }
        }
    }
}
