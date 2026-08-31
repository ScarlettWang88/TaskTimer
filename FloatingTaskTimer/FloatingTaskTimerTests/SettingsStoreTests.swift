import Foundation
import SwiftData
import Testing
@testable import FloatingTaskTimer

@MainActor
@Suite("Settings")
struct SettingsStoreTests {
    @Test("Default values match the product specification")
    func defaults() {
        withDefaults { defaults in
            let settings = SettingsStore(defaults: defaults)
            #expect(settings.appearance == .system)
            #expect(settings.showSeconds)
            #expect(settings.timerDisplayFormat == .hoursMinutesSeconds)
            #expect(settings.menuBarDisplayMode == .iconAndDuration)
            #expect(settings.confirmBeforeReset)
            #expect(settings.confirmBeforeHistoryDelete)
            #expect(!settings.alwaysOnTopDefault)
        }
    }

    @Test("Preferences and enum values persist")
    func persistence() {
        withDefaults { defaults in
            let first = SettingsStore(defaults: defaults)
            first.appearance = .dark
            first.showSeconds = false
            first.timerDisplayFormat = .minutesSeconds
            first.menuBarDisplayMode = .iconOnly
            first.confirmBeforeReset = false
            first.confirmBeforeHistoryDelete = false
            first.alwaysOnTopDefault = true

            let restored = SettingsStore(defaults: defaults)
            #expect(restored.appearance == .dark)
            #expect(!restored.showSeconds)
            #expect(restored.timerDisplayFormat == .minutesSeconds)
            #expect(restored.menuBarDisplayMode == .iconOnly)
            #expect(!restored.confirmBeforeReset)
            #expect(!restored.confirmBeforeHistoryDelete)
            #expect(restored.alwaysOnTopDefault)
        }
    }

    @Test("Invalid enum values recover to defaults")
    func invalidEnums() {
        withDefaults { defaults in
            defaults.set("invalid", forKey: SettingsStore.Keys.appearance)
            defaults.set("invalid", forKey: SettingsStore.Keys.timerDisplayFormat)
            defaults.set("invalid", forKey: SettingsStore.Keys.menuBarDisplayMode)
            let settings = SettingsStore(defaults: defaults)
            #expect(settings.appearance == .system)
            #expect(settings.timerDisplayFormat == .hoursMinutesSeconds)
            #expect(settings.menuBarDisplayMode == .iconAndDuration)
        }
    }

    @Test("Timer display includes or hides seconds without changing precision")
    func displayFormatting() {
        withDefaults { defaults in
            let settings = SettingsStore(defaults: defaults)
            let duration: TimeInterval = 5_025.9
            #expect(settings.format(duration) == "01:23:45")
            settings.showSeconds = false
            #expect(settings.format(duration) == "01:23")
            #expect(duration == 5_025.9)
        }
    }

    @Test("Minutes format is consistent below and above one hour")
    func minutesFormatting() {
        withDefaults { defaults in
            let settings = SettingsStore(defaults: defaults)
            settings.timerDisplayFormat = .minutesSeconds
            #expect(settings.format(1_425) == "23:45")
            #expect(settings.format(5_025) == "83:45")
            settings.showSeconds = false
            #expect(settings.format(5_025) == "83")
        }
    }

    @Test("Changing settings does not mutate simultaneous timers")
    func settingsDoNotMutateTimers() throws {
        let container = try ModelContainer(
            for: PersistedTaskSession.self, PersistedTaskStoreState.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = try TaskStore(persistence: TaskSessionStore(modelContext: ModelContext(container)))
        let firstID = try #require(store.activeTaskID)
        let secondID = try store.createTask(name: "Second", startImmediately: true)
        try store.startOrResume(taskID: firstID)

        withDefaults { defaults in
            let settings = SettingsStore(defaults: defaults)
            settings.appearance = .light
            settings.showSeconds = false
            settings.confirmBeforeReset = false
        }

        #expect(store.tasks.first { $0.id == firstID }?.status == .running)
        #expect(store.tasks.first { $0.id == secondID }?.status == .running)
    }

    private func withDefaults(_ operation: (UserDefaults) throws -> Void) rethrows {
        let suite = "SettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try operation(defaults)
    }
}
