import Foundation
import AppKit
import SwiftData
import Testing
@testable import FloatingTaskTimer

@MainActor
@Suite("WindowManager")
struct WindowManagerTests {
    @Test("Pin state persists without touching a window")
    func pinStatePersists() {
        let suiteName = "WindowManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstManager = WindowManager(userDefaults: defaults)
        #expect(!firstManager.isPinned)

        firstManager.setPinned(true)
        #expect(firstManager.isPinned)
        #expect(defaults.bool(forKey: WindowManager.pinnedPreferenceKey))

        let restoredManager = WindowManager(userDefaults: defaults)
        #expect(restoredManager.isPinned)

        restoredManager.setPinned(false)
        #expect(!restoredManager.isPinned)
        #expect(!defaults.bool(forKey: WindowManager.pinnedPreferenceKey))
    }

    @Test("Always on Top default seeds Pin only when no runtime Pin exists")
    func alwaysOnTopDefaultPrecedence() {
        let suiteName = "WindowManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsStore(defaults: defaults)
        settings.alwaysOnTopDefault = true
        let seeded = WindowManager(
            taskStore: nil,
            navigation: AppNavigation(),
            settings: settings,
            userDefaults: defaults
        )
        #expect(seeded.isPinned)

        seeded.setPinned(false)
        settings.alwaysOnTopDefault = true
        let restored = WindowManager(
            taskStore: nil,
            navigation: AppNavigation(),
            settings: settings,
            userDefaults: defaults
        )
        #expect(!restored.isPinned)
    }

    @Test("Pinned window joins other applications in full-screen Spaces")
    func pinnedWindowCollectionBehavior() {
        let behavior = WindowManager.pinnedCollectionBehavior

        #expect(behavior.contains(.canJoinAllSpaces))
        #expect(behavior.contains(.canJoinAllApplications))
        #expect(behavior.contains(.stationary))
        #expect(!behavior.contains(.fullScreenAuxiliary))
        #expect(!behavior.contains(.managed))
    }

    @Test("Unpinned window uses normal managed Space behavior")
    func unpinnedWindowCollectionBehavior() {
        let behavior = WindowManager.unpinnedCollectionBehavior

        #expect(behavior == [.managed])
        #expect(!behavior.contains(.canJoinAllSpaces))
        #expect(!behavior.contains(.canJoinAllApplications))
        #expect(!behavior.contains(.stationary))
        #expect(!behavior.contains(.fullScreenAuxiliary))
    }

    @Test("Explicitly summoned unpinned window moves to the active Space")
    func summonedUnpinnedWindowCollectionBehavior() {
        let behavior = WindowManager.summonedUnpinnedCollectionBehavior

        #expect(behavior == [.moveToActiveSpace])
        #expect(!behavior.contains(.canJoinAllSpaces))
        #expect(!behavior.contains(.fullScreenAuxiliary))
    }

    @Test("Window mode persists and mode changes preserve Pin")
    func modePersistsWithoutChangingPin() {
        let suiteName = "WindowManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let manager = WindowManager(userDefaults: defaults)
        manager.setPinned(true)
        manager.showMiniMode()

        #expect(manager.mode == .mini)
        #expect(manager.isPinned)

        let restored = WindowManager(userDefaults: defaults)
        #expect(restored.mode == .mini)
        #expect(restored.isPinned)

        restored.showExpandedMode()
        #expect(restored.mode == .expanded)
        #expect(restored.isPinned)
    }

    @Test("Mini defaults to the visible frame top-right")
    func miniTopRightPlacement() {
        let visible = NSRect(x: 100, y: 50, width: 1_200, height: 800)
        let frame = WindowManager.topRightFrame(
            size: WindowManager.miniContentSize,
            visibleFrame: visible
        )

        #expect(frame.maxX == visible.maxX - WindowManager.windowEdgeMargin)
        #expect(frame.maxY == visible.maxY - WindowManager.windowEdgeMargin)
        #expect(visible.contains(frame))
    }

    @Test("A valid moved Mini frame restores unchanged")
    func movedMiniFrameRestores() {
        let visible = NSRect(x: 0, y: 0, width: 1_440, height: 900)
        let moved = NSRect(x: 320, y: 280, width: 300, height: 116)

        let repaired = WindowManager.repairedFrame(
            moved,
            targetSize: WindowManager.miniContentSize,
            visibleFrames: [visible],
            fallbackVisibleFrame: visible
        )

        #expect(repaired == moved)
    }

    @Test("A frame from a disconnected monitor repairs to the fallback screen")
    func disconnectedMonitorFrameRepairs() {
        let fallback = NSRect(x: 0, y: 0, width: 1_440, height: 900)
        let disconnected = NSRect(x: 3_000, y: 400, width: 300, height: 116)

        let repaired = WindowManager.repairedFrame(
            disconnected,
            targetSize: WindowManager.miniContentSize,
            visibleFrames: [fallback],
            fallbackVisibleFrame: fallback
        )

        #expect(fallback.contains(repaired))
        #expect(repaired.maxX == fallback.maxX - WindowManager.windowEdgeMargin)
        #expect(repaired.maxY == fallback.maxY - WindowManager.windowEdgeMargin)
    }

    @Test("Native full-screen uses primary behavior without changing Pin semantics")
    func nativeFullScreenBehavior() {
        let behavior = WindowManager.nativeFullScreenCollectionBehavior
        #expect(behavior == [.fullScreenPrimary])
        #expect(!behavior.contains(.canJoinAllSpaces))
        #expect(WindowManager.pinnedCollectionBehavior.contains(.canJoinAllApplications))
    }

    @Test("Repeated display requests retain one timer window")
    func noDuplicateTimerWindows() throws {
        let suiteName = "WindowManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let container = try ModelContainer(
            for: PersistedTaskSession.self, PersistedTaskStoreState.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = try TaskStore(
            persistence: TaskSessionStore(modelContext: ModelContext(container))
        )
        let manager = WindowManager(
            taskStore: store,
            navigation: AppNavigation(),
            settings: SettingsStore(defaults: defaults),
            userDefaults: defaults
        )

        manager.showWindow()
        manager.showMiniMode()
        manager.showExpandedMode()
        manager.showWindow()

        #expect(manager.managedTimerWindowCount == 1)
    }
}
