import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class WindowManager: NSObject, NSWindowDelegate {
    static let pinnedPreferenceKey = SettingsStore.Keys.currentPin
    static let pinnedCollectionBehavior: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces,
        .canJoinAllApplications,
        .stationary,
    ]
    static let unpinnedCollectionBehavior: NSWindow.CollectionBehavior = [.managed]
    static let summonedUnpinnedCollectionBehavior: NSWindow.CollectionBehavior = [.moveToActiveSpace]

    private(set) var isPinned: Bool

    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private let taskStore: TaskStore?
    @ObservationIgnored private let navigation: AppNavigation
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private var panel: NSPanel?

    private let frameAutosaveName = "FloatingTimerPanelFrame"

    init(
        taskStore: TaskStore? = nil,
        navigation: AppNavigation,
        settings: SettingsStore,
        userDefaults: UserDefaults = .standard
    ) {
        self.taskStore = taskStore
        self.navigation = navigation
        self.settings = settings
        self.userDefaults = userDefaults
        let hasRuntimePin = userDefaults.object(forKey: Self.pinnedPreferenceKey) != nil
        let initialPin = hasRuntimePin
            ? userDefaults.bool(forKey: Self.pinnedPreferenceKey)
            : settings.alwaysOnTopDefault
        isPinned = initialPin
        if !hasRuntimePin {
            userDefaults.set(initialPin, forKey: Self.pinnedPreferenceKey)
        }
        super.init()

        applyAppearance(settings.appearance)

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeSpaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    convenience init(userDefaults: UserDefaults = .standard) {
        self.init(
            taskStore: nil,
            navigation: AppNavigation(),
            settings: SettingsStore(defaults: userDefaults),
            userDefaults: userDefaults
        )
    }

    func showWindow() {
        if panel == nil {
            guard let taskStore else { return }
            panel = makePanel(taskStore: taskStore)
        }

        applyWindowBehavior()
        panel?.makeKeyAndOrderFront(nil)
    }

    func showHistory() {
        navigation.selectedPage = .history
        showWindowOnCurrentSpace()
    }

    func showWindowOnCurrentSpace() {
        if panel == nil {
            guard let taskStore else { return }
            panel = makePanel(taskStore: taskStore)
        }
        guard let panel else { return }

        if isPinned {
            applyWindowBehavior()
            panel.makeKeyAndOrderFront(nil)
            return
        }

        panel.level = .normal
        panel.collectionBehavior = Self.summonedUnpinnedCollectionBehavior
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak panel] in
            guard let self, let panel, !self.isPinned else { return }
            panel.collectionBehavior = Self.unpinnedCollectionBehavior
        }
    }

    func bringSettingsToCurrentSpace() {
        // Activating the app to front Settings can otherwise bring the unpinned
        // timer panel into the active Space as a second window.
        if !isPinned {
            panel?.orderOut(nil)
        }
        locateAndBringSettingsWindow(attemptsRemaining: 10)
    }

    func applyAppearance(_ appearance: AppAppearance) {
        switch appearance {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    func setPinned(_ pinned: Bool) {
        guard pinned != isPinned else { return }

        isPinned = pinned
        userDefaults.set(pinned, forKey: Self.pinnedPreferenceKey)
        applyWindowBehavior()
    }

    private func makePanel(taskStore: TaskStore) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .resizable,
                .fullSizeContentView,
                .nonactivatingPanel,
            ],
            backing: .buffered,
            defer: false
        )

        panel.title = "Floating Task Timer"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.animationBehavior = .utilityWindow
        panel.minSize = NSSize(width: 440, height: 330)
        panel.delegate = self
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        let rootView = ContentView(
            taskStore: taskStore,
            windowManager: self,
            navigation: navigation,
            settings: settings
        )
        .preferredColorScheme(settings.appearance.colorScheme)
        panel.contentViewController = NSHostingController(rootView: rootView)

        restoreFrame(for: panel)
        panel.setFrameAutosaveName(frameAutosaveName)
        return panel
    }

    private func applyWindowBehavior() {
        guard let panel else { return }

        panel.level = isPinned ? .floating : .normal
        panel.collectionBehavior = isPinned
            ? Self.pinnedCollectionBehavior
            : Self.unpinnedCollectionBehavior

        if isPinned {
            panel.orderFrontRegardless()
        }
    }

    private func locateAndBringSettingsWindow(attemptsRemaining: Int) {
        if let settingsWindow = NSApp.windows.first(where: { window in
            guard window !== panel, !(window is NSSavePanel) else { return false }
            let identity = [window.title, window.identifier?.rawValue ?? ""]
                .joined(separator: " ")
                .lowercased()
            return identity.contains("settings") || identity.contains("preferences")
        }) {
            settingsWindow.collectionBehavior = Self.summonedUnpinnedCollectionBehavior
            NSApp.activate(ignoringOtherApps: true)
            settingsWindow.makeKeyAndOrderFront(nil)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak settingsWindow] in
                settingsWindow?.collectionBehavior = Self.unpinnedCollectionBehavior
            }
            return
        }

        guard attemptsRemaining > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.locateAndBringSettingsWindow(attemptsRemaining: attemptsRemaining - 1)
        }
    }

    @objc private func activeSpaceDidChange() {
        guard isPinned else { return }
        panel?.orderFrontRegardless()
    }

    private func restoreFrame(for panel: NSPanel) {
        let restored = panel.setFrameUsingName(frameAutosaveName)
        let isOnConnectedDisplay = NSScreen.screens.contains { screen in
            panel.frame.intersects(screen.visibleFrame)
        }

        if !restored || !isOnConnectedDisplay {
            panel.center()
        }
    }
}
