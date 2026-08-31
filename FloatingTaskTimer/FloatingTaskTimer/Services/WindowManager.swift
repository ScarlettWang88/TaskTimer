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
    static let nativeFullScreenCollectionBehavior: NSWindow.CollectionBehavior = [.fullScreenPrimary]
    static let miniContentSize = NSSize(width: 300, height: 116)
    static let expandedContentSize = NSSize(width: 620, height: 560)
    static let windowEdgeMargin: CGFloat = 16

    private(set) var isPinned: Bool
    private(set) var mode: TimerWindowMode
    private(set) var isFullScreen = false

    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private let taskStore: TaskStore?
    @ObservationIgnored private let navigation: AppNavigation
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private var panel: NSPanel?
    @ObservationIgnored private var pendingModeAfterFullScreen: TimerWindowMode?
    @ObservationIgnored private var isApplyingStoredFrame = false

    private let frameAutosaveName = "FloatingTimerPanelFrame"

    var managedTimerWindowCount: Int { panel == nil ? 0 : 1 }

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
        mode = TimerWindowMode(
            rawValue: userDefaults.string(forKey: SettingsStore.Keys.timerWindowMode) ?? ""
        ) ?? .expanded
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
            fitExpandedWindow(taskCount: taskStore.tasks.count)
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
            fitExpandedWindow(taskCount: taskStore.tasks.count)
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

    func showMiniMode() {
        requestMode(.mini)
    }

    func showExpandedMode() {
        requestMode(.expanded)
    }

    func fitExpandedWindow(taskCount: Int) {
        guard mode == .expanded, !isFullScreen, let panel else { return }
        guard let visibleFrame = (panel.screen ?? NSScreen.main)?.visibleFrame else { return }

        let additionalRows = CGFloat(max(0, taskCount - 1))
        let desiredWidth = min(
            Self.expandedContentSize.width,
            visibleFrame.width - Self.windowEdgeMargin * 2
        )
        let desiredHeight = min(
            Self.expandedContentSize.height + additionalRows * 48,
            visibleFrame.height - Self.windowEdgeMargin * 2
        )
        guard desiredWidth > panel.frame.width || desiredHeight > panel.frame.height else { return }

        var frame = panel.frame
        let topEdge = frame.maxY
        frame.size.width = max(frame.width, desiredWidth)
        frame.size.height = max(frame.height, desiredHeight)
        frame.origin.y = topEdge - frame.height
        frame = Self.repairedFrame(
            frame,
            targetSize: frame.size,
            visibleFrames: NSScreen.screens.map(\.visibleFrame),
            fallbackVisibleFrame: visibleFrame
        )

        isApplyingStoredFrame = true
        panel.setFrame(frame, display: true)
        isApplyingStoredFrame = false
        saveFrame(for: .expanded)
    }

    func toggleFullScreen() {
        guard mode == .expanded else {
            showExpandedMode()
            return
        }
        guard let panel else { return }

        if isFullScreen {
            panel.toggleFullScreen(nil)
        } else {
            saveFrame(for: .expanded)
            panel.styleMask.insert([.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView])
            panel.titleVisibility = .visible
            panel.titlebarAppearsTransparent = false
            panel.standardWindowButton(.closeButton)?.isHidden = false
            panel.standardWindowButton(.miniaturizeButton)?.isHidden = false
            panel.standardWindowButton(.zoomButton)?.isHidden = false
            panel.level = .normal
            panel.collectionBehavior = Self.nativeFullScreenCollectionBehavior
            panel.styleMask.remove(.nonactivatingPanel)
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            panel.toggleFullScreen(nil)
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
        if !isFullScreen {
            applyWindowBehavior()
        }
    }

    private func makePanel(taskStore: TaskStore) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentSize(for: mode)),
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

        configurePanel(for: mode)
        restoreFrame(for: mode, on: panel)
        return panel
    }

    private func applyWindowBehavior() {
        guard let panel, !isFullScreen else { return }

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

    private func requestMode(_ requestedMode: TimerWindowMode) {
        guard requestedMode != mode else { return }
        if isFullScreen {
            pendingModeAfterFullScreen = requestedMode
            panel?.toggleFullScreen(nil)
            return
        }
        applyMode(requestedMode)
    }

    private func applyMode(_ newMode: TimerWindowMode) {
        guard let panel else {
            mode = newMode
            persistMode()
            return
        }

        saveFrame(for: mode)
        let previousScreen = panel.screen ?? NSScreen.main
        mode = newMode
        persistMode()
        configurePanel(for: newMode)
        restoreFrame(for: newMode, on: panel, preferredScreen: previousScreen)
        if newMode == .expanded {
            fitExpandedWindow(taskCount: taskStore?.tasks.count ?? 0)
        }
        applyWindowBehavior()
    }

    private func configurePanel(for mode: TimerWindowMode) {
        guard let panel else { return }

        switch mode {
        case .mini:
            panel.styleMask.remove([.titled, .closable, .miniaturizable])
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.minSize = Self.miniContentSize
            panel.maxSize = Self.miniContentSize
        case .expanded:
            panel.styleMask.insert([
                .titled, .closable, .miniaturizable, .resizable, .fullSizeContentView,
                .nonactivatingPanel,
            ])
            panel.titleVisibility = .visible
            panel.titlebarAppearsTransparent = false
            panel.standardWindowButton(.closeButton)?.isHidden = false
            panel.standardWindowButton(.miniaturizeButton)?.isHidden = false
            panel.standardWindowButton(.zoomButton)?.isHidden = false
            panel.minSize = NSSize(width: 560, height: 500)
            panel.maxSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }
    }

    private func contentSize(for mode: TimerWindowMode) -> NSSize {
        mode == .mini ? Self.miniContentSize : Self.expandedContentSize
    }

    private func persistMode() {
        userDefaults.set(mode.rawValue, forKey: SettingsStore.Keys.timerWindowMode)
    }

    private func frameKey(for mode: TimerWindowMode) -> String {
        switch mode {
        case .mini: SettingsStore.Keys.miniWindowFrame
        case .expanded: SettingsStore.Keys.expandedWindowFrame
        }
    }

    private func saveFrame(for mode: TimerWindowMode) {
        guard let panel, !isApplyingStoredFrame, !isFullScreen else { return }
        userDefaults.set(NSStringFromRect(panel.frame), forKey: frameKey(for: mode))
    }

    private func storedFrame(for mode: TimerWindowMode) -> NSRect? {
        guard let value = userDefaults.string(forKey: frameKey(for: mode)) else { return nil }
        let frame = NSRectFromString(value)
        guard frame.width > 0, frame.height > 0 else { return nil }
        return frame
    }

    private func restoreFrame(
        for mode: TimerWindowMode,
        on panel: NSPanel,
        preferredScreen: NSScreen? = nil
    ) {
        let screens = NSScreen.screens
        let fallbackScreen = preferredScreen ?? panel.screen ?? NSScreen.main ?? screens.first
        let targetSize = contentSize(for: mode)
        let targetFrame: NSRect

        if let stored = storedFrame(for: mode) {
            targetFrame = Self.repairedFrame(
                stored,
                targetSize: targetSize,
                visibleFrames: screens.map(\.visibleFrame),
                fallbackVisibleFrame: fallbackScreen?.visibleFrame
            )
        } else if mode == .expanded, panel.setFrameUsingName(frameAutosaveName) {
            targetFrame = Self.repairedFrame(
                panel.frame,
                targetSize: nil,
                visibleFrames: screens.map(\.visibleFrame),
                fallbackVisibleFrame: fallbackScreen?.visibleFrame
            )
        } else if let visibleFrame = fallbackScreen?.visibleFrame {
            targetFrame = Self.topRightFrame(
                size: targetSize,
                visibleFrame: visibleFrame,
                margin: Self.windowEdgeMargin
            )
        } else {
            targetFrame = NSRect(origin: panel.frame.origin, size: targetSize)
        }

        isApplyingStoredFrame = true
        panel.setFrame(targetFrame, display: true)
        isApplyingStoredFrame = false
    }

    static func topRightFrame(
        size: NSSize,
        visibleFrame: NSRect,
        margin: CGFloat = 16
    ) -> NSRect {
        let safeWidth = min(size.width, max(1, visibleFrame.width - margin * 2))
        let safeHeight = min(size.height, max(1, visibleFrame.height - margin * 2))
        return NSRect(
            x: visibleFrame.maxX - safeWidth - margin,
            y: visibleFrame.maxY - safeHeight - margin,
            width: safeWidth,
            height: safeHeight
        )
    }

    static func repairedFrame(
        _ savedFrame: NSRect,
        targetSize: NSSize?,
        visibleFrames: [NSRect],
        fallbackVisibleFrame: NSRect?
    ) -> NSRect {
        let size = targetSize ?? savedFrame.size
        if let containingFrame = visibleFrames.max(by: {
            intersectionArea($0, savedFrame) < intersectionArea($1, savedFrame)
        }), intersectionArea(containingFrame, savedFrame) > 0 {
            return clampedFrame(origin: savedFrame.origin, size: size, inside: containingFrame)
        }

        guard let fallback = fallbackVisibleFrame ?? visibleFrames.first else {
            return NSRect(origin: savedFrame.origin, size: size)
        }
        return topRightFrame(size: size, visibleFrame: fallback)
    }

    private static func clampedFrame(origin: NSPoint, size: NSSize, inside visibleFrame: NSRect) -> NSRect {
        let width = min(size.width, visibleFrame.width)
        let height = min(size.height, visibleFrame.height)
        let x = min(max(origin.x, visibleFrame.minX), visibleFrame.maxX - width)
        let y = min(max(origin.y, visibleFrame.minY), visibleFrame.maxY - height)
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private static func intersectionArea(_ lhs: NSRect, _ rhs: NSRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }

    func windowDidMove(_ notification: Notification) {
        saveFrame(for: mode)
    }

    func windowDidResize(_ notification: Notification) {
        guard mode == .expanded else { return }
        saveFrame(for: .expanded)
    }

    func windowWillEnterFullScreen(_ notification: Notification) {
        isFullScreen = true
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        isFullScreen = true
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        isFullScreen = false
        panel?.styleMask.insert(.nonactivatingPanel)
        configurePanel(for: mode)
        applyWindowBehavior()

        if let pendingModeAfterFullScreen {
            self.pendingModeAfterFullScreen = nil
            applyMode(pendingModeAfterFullScreen)
        }
    }

    @objc private func activeSpaceDidChange() {
        guard isPinned, !isFullScreen else { return }
        panel?.orderFrontRegardless()
    }
}
