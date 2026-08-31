import SwiftUI

@main
struct FloatingTaskTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra(isInserted: menuBarIsInserted) {
            MenuBarView(
                taskStore: appDelegate.taskStore,
                windowManager: appDelegate.windowManager,
                settings: appDelegate.settingsStore
            )
        } label: {
            MenuBarLabelView(
                taskStore: appDelegate.taskStore,
                settings: appDelegate.settingsStore
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(
                settings: appDelegate.settingsStore,
                windowManager: appDelegate.windowManager
            )
        }
    }

    private var menuBarIsInserted: Binding<Bool> {
        Binding(
            get: { appDelegate.settingsStore.menuBarDisplayMode != .hidden },
            set: { isInserted in
                appDelegate.settingsStore.menuBarDisplayMode = isInserted ? .iconAndDuration : .hidden
            }
        )
    }
}
