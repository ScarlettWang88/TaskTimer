import AppKit
import OSLog
import SwiftData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let logger = Logger(
        subsystem: "whywhy.FloatingTaskTimer",
        category: "Persistence"
    )

    private var windowManager: WindowManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let windowManager = WindowManager()
        self.windowManager = windowManager
        windowManager.showWindow(modelContainer: makeModelContainer())
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if !flag {
            windowManager?.showWindow()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func makeModelContainer() -> ModelContainer {
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
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
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
                return try ModelContainer(for: schema, configurations: [fallbackConfiguration])
            } catch {
                fatalError("Could not create fallback ModelContainer: \(error)")
            }
        }
    }
}
