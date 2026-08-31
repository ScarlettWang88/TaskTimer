import Foundation
import AppKit
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
}
