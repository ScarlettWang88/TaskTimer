import SwiftUI

@main
struct FloatingTaskTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                taskStore: appDelegate.taskStore,
                windowManager: appDelegate.windowManager
            )
        } label: {
            MenuBarLabelView(taskStore: appDelegate.taskStore)
        }
        .menuBarExtraStyle(.window)

        Settings {
            EmptyView()
        }
    }
}
