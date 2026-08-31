import AppKit
import Observation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class WindowManager: NSObject, NSWindowDelegate {
    static let pinnedPreferenceKey = "isTimerPinned"
    static let pinnedCollectionBehavior: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces,
        .canJoinAllApplications,
        .stationary,
    ]
    static let unpinnedCollectionBehavior: NSWindow.CollectionBehavior = [.managed]

    private(set) var isPinned: Bool

    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private var modelContainer: ModelContainer?
    @ObservationIgnored private var panel: NSPanel?

    private let frameAutosaveName = "FloatingTimerPanelFrame"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        isPinned = userDefaults.bool(forKey: Self.pinnedPreferenceKey)
        super.init()

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeSpaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    func showWindow(modelContainer: ModelContainer? = nil) {
        if let modelContainer {
            self.modelContainer = modelContainer
        }

        if panel == nil {
            guard let modelContainer = self.modelContainer else { return }
            panel = makePanel(modelContainer: modelContainer)
        }

        applyWindowBehavior()
        panel?.makeKeyAndOrderFront(nil)
    }

    func setPinned(_ pinned: Bool) {
        guard pinned != isPinned else { return }

        isPinned = pinned
        userDefaults.set(pinned, forKey: Self.pinnedPreferenceKey)
        applyWindowBehavior()
    }

    private func makePanel(modelContainer: ModelContainer) -> NSPanel {
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

        let rootView = ContentView(windowManager: self)
            .modelContainer(modelContainer)
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
