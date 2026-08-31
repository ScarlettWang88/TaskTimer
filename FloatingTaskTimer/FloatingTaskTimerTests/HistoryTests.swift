import Foundation
import SwiftData
import Testing
@testable import FloatingTaskTimer

@MainActor
@Suite("History")
struct HistoryTests {
    @Test("Finishing one running task saves history without affecting another")
    func finishingOneOfMultipleRunningTasks() throws {
        let clock = HistoryTestClock(now: referenceDate)
        let store = try makeStore(clock: clock)
        let firstID = try #require(store.activeTaskID)
        try store.rename(taskID: firstID, name: "First")
        let secondID = try store.createTask(name: "Second", startImmediately: true)
        #expect(try store.startOrResume(taskID: firstID))
        clock.advance(by: 20)

        #expect(try store.finish(taskID: firstID))

        #expect(store.history.map(\.id) == [firstID])
        #expect(store.history.first?.status == .completed)
        #expect(store.tasks.first { $0.id == secondID }?.status == .running)
    }

    @Test("Finishing a paused task records its final paused duration")
    func finishingPausedTask() throws {
        let clock = HistoryTestClock(now: referenceDate)
        let store = try makeStore(clock: clock)
        let taskID = try #require(store.activeTaskID)
        #expect(try store.startOrResume(taskID: taskID))
        clock.advance(by: 10)
        #expect(try store.pause(taskID: taskID))
        clock.advance(by: 7)

        #expect(try store.finish(taskID: taskID))

        #expect(store.history.first?.accumulatedActiveDuration == 10)
        #expect(store.history.first?.accumulatedPausedDuration == 7)
    }

    @Test("Completed history survives relaunch")
    func historySurvivesRelaunch() throws {
        let container = try makeContainer()
        let clock = HistoryTestClock(now: referenceDate)
        let firstStore = try TaskStore(
            persistence: TaskSessionStore(modelContext: ModelContext(container)),
            timerEngine: TimerEngine(timeProvider: clock)
        )
        let taskID = try #require(firstStore.activeTaskID)
        #expect(try firstStore.startOrResume(taskID: taskID))
        clock.advance(by: 30)
        #expect(try firstStore.finish(taskID: taskID))

        let restored = try TaskStore(
            persistence: TaskSessionStore(modelContext: ModelContext(container)),
            timerEngine: TimerEngine(timeProvider: clock)
        )

        #expect(restored.history.count == 1)
        #expect(restored.history.first?.id == taskID)
        #expect(restored.history.first?.status == .completed)
        #expect(!restored.tasks.contains { $0.id == taskID })
    }

    @Test("Same-name same-day history records remain distinct and sorted")
    func duplicateNamesRemainDistinct() throws {
        let container = try makeContainer()
        let older = completedSession(
            id: UUID(),
            name: "Review",
            completedAt: referenceDate.addingTimeInterval(100)
        )
        let newer = completedSession(
            id: UUID(),
            name: "Review",
            completedAt: referenceDate.addingTimeInterval(200)
        )
        try TaskSessionStore(modelContext: ModelContext(container)).save(
            [older, newer],
            activeTaskID: nil
        )

        let store = try TaskStore(
            persistence: TaskSessionStore(modelContext: ModelContext(container))
        )

        #expect(store.history.map(\.id) == [newer.id, older.id])
        #expect(store.history.allSatisfy { $0.name == "Review" })
    }

    @Test("Legacy completed record without a start timestamp remains readable")
    func missingStartTimestamp() throws {
        let container = try makeContainer()
        let legacy = TaskSession(
            name: "Legacy",
            status: .completed,
            createdAt: referenceDate,
            firstStartedAt: nil,
            completedAt: referenceDate.addingTimeInterval(60),
            accumulatedActiveDuration: 45,
            accumulatedPausedDuration: 15
        )
        try TaskSessionStore(modelContext: ModelContext(container)).save(legacy)

        let restored = try TaskStore(
            persistence: TaskSessionStore(modelContext: ModelContext(container))
        )

        #expect(restored.history.first == legacy)
    }

    @Test("A new store has empty history")
    func emptyHistory() throws {
        let store = try makeStore(clock: HistoryTestClock(now: referenceDate))
        #expect(store.history.isEmpty)
    }

    @Test("Sessions sharing a group produce one row with summed totals and chronological log")
    func groupedHistoryTotals() throws {
        let container = try makeContainer()
        let groupID = UUID()
        var older = completedSession(id: UUID(), name: "Proposal", completedAt: referenceDate.addingTimeInterval(60))
        older.taskGroupID = groupID
        older.accumulatedPausedDuration = 5
        var newer = completedSession(id: UUID(), name: "Proposal", completedAt: referenceDate.addingTimeInterval(120))
        newer.taskGroupID = groupID
        newer.accumulatedActiveDuration = 40
        newer.accumulatedPausedDuration = 7
        try TaskSessionStore(modelContext: ModelContext(container)).save([newer, older], activeTaskID: nil)

        let store = try TaskStore(persistence: TaskSessionStore(modelContext: ModelContext(container)))
        let group = try #require(store.historyGroups.first)
        #expect(store.historyGroups.count == 1)
        #expect(group.taskGroupID == groupID)
        #expect(group.totalActiveDuration == 100)
        #expect(group.totalPausedDuration == 12)
        #expect(group.sessions.map(\.id) == [older.id, newer.id])
    }

    @Test("Group delete preserves an active session with the same group identity")
    func groupDeletePreservesActiveContinuation() throws {
        let container = try makeContainer()
        let groupID = UUID()
        var completed = completedSession(id: UUID(), name: "Group", completedAt: referenceDate)
        completed.taskGroupID = groupID
        let active = TaskSession(taskGroupID: groupID, name: "Group")
        try TaskSessionStore(modelContext: ModelContext(container)).save([completed, active], activeTaskID: active.id)
        let store = try TaskStore(persistence: TaskSessionStore(modelContext: ModelContext(container)))

        try store.deleteHistoryGroup(id: groupID)

        #expect(store.historyGroups.isEmpty)
        #expect(store.tasks.contains { $0.id == active.id })
        let restored = try TaskStore(persistence: TaskSessionStore(modelContext: ModelContext(container)))
        #expect(restored.tasks.contains { $0.id == active.id })
    }

    @Test("Very long durations format without truncating hours")
    func veryLongDuration() {
        #expect(DurationFormatter.clock(123 * 3_600 + 45 * 60 + 6) == "123:45:06")
    }

    @Test("Renaming a completed record changes only its name and survives relaunch")
    func renameHistory() throws {
        let container = try makeContainer()
        let original = completedSession(
            id: UUID(),
            name: "Original",
            completedAt: referenceDate.addingTimeInterval(60)
        )
        try TaskSessionStore(modelContext: ModelContext(container)).save(original)
        let store = try TaskStore(
            persistence: TaskSessionStore(modelContext: ModelContext(container))
        )

        try store.renameHistoryGroup(id: original.taskGroupID, name: "Renamed")

        let renamed = try #require(store.history.first)
        #expect(renamed.name == "Renamed")
        #expect(renamed.id == original.id)
        #expect(renamed.completedAt == original.completedAt)
        #expect(renamed.accumulatedActiveDuration == original.accumulatedActiveDuration)

        let restored = try TaskStore(
            persistence: TaskSessionStore(modelContext: ModelContext(container))
        )
        #expect(restored.history.first?.name == "Renamed")
    }

    @Test("Deleting a completed record leaves active and other history records unchanged")
    func deleteHistory() throws {
        let container = try makeContainer()
        let first = completedSession(
            id: UUID(),
            name: "Delete",
            completedAt: referenceDate.addingTimeInterval(60)
        )
        let second = completedSession(
            id: UUID(),
            name: "Keep",
            completedAt: referenceDate.addingTimeInterval(120)
        )
        let active = TaskSession(name: "Running", status: .running, createdAt: referenceDate,
                                 firstStartedAt: referenceDate, lastResumedAt: referenceDate)
        try TaskSessionStore(modelContext: ModelContext(container)).save(
            [first, second, active],
            activeTaskID: active.id
        )
        let store = try TaskStore(
            persistence: TaskSessionStore(modelContext: ModelContext(container))
        )

        try store.deleteHistoryGroup(id: first.taskGroupID)

        #expect(store.history.map(\.id) == [second.id])
        #expect(store.tasks.first { $0.id == active.id }?.status == .running)
        let restored = try TaskStore(
            persistence: TaskSessionStore(modelContext: ModelContext(container))
        )
        #expect(restored.history.map(\.id) == [second.id])
    }

    @Test("Continuing history creates a new independent task and preserves the original")
    func continueHistory() throws {
        let container = try makeContainer()
        let original = TaskSession(
            name: "Proposal",
            category: "Work",
            status: .completed,
            createdAt: referenceDate,
            firstStartedAt: referenceDate,
            completedAt: referenceDate.addingTimeInterval(90),
            accumulatedActiveDuration: 80,
            accumulatedPausedDuration: 10
        )
        let running = TaskSession(
            name: "Other",
            status: .running,
            createdAt: referenceDate,
            firstStartedAt: referenceDate,
            lastResumedAt: referenceDate
        )
        try TaskSessionStore(modelContext: ModelContext(container)).save(
            [original, running],
            activeTaskID: running.id
        )
        let store = try TaskStore(
            persistence: TaskSessionStore(modelContext: ModelContext(container)),
            timerEngine: TimerEngine(timeProvider: HistoryTestClock(now: referenceDate))
        )

        let continuedID = try #require(try store.continueHistoryGroup(id: original.taskGroupID))
        let continued = try #require(store.tasks.first { $0.id == continuedID })

        #expect(continued.id != original.id)
        #expect(continued.name == original.name)
        #expect(continued.category == original.category)
        #expect(continued.status == .idle)
        #expect(continued.accumulatedActiveDuration == 0)
        #expect(continued.taskGroupID == original.taskGroupID)
        #expect(continued.continuedFromSessionID == original.id)
        #expect(store.history.first { $0.id == original.id } == original)
        #expect(store.tasks.first { $0.id == running.id }?.status == .running)

        let restored = try TaskStore(
            persistence: TaskSessionStore(modelContext: ModelContext(container))
        )
        #expect(restored.tasks.first { $0.id == continuedID }?.continuedFromSessionID == original.id)
    }

    @Test("Multiple continued tasks can run simultaneously")
    func multipleContinuedTasksRun() throws {
        let clock = HistoryTestClock(now: referenceDate)
        let container = try makeContainer()
        let original = completedSession(
            id: UUID(),
            name: "Repeat",
            completedAt: referenceDate.addingTimeInterval(60)
        )
        try TaskSessionStore(modelContext: ModelContext(container)).save(original)
        let store = try TaskStore(
            persistence: TaskSessionStore(modelContext: ModelContext(container)),
            timerEngine: TimerEngine(timeProvider: clock)
        )

        let firstID = try #require(try store.continueHistoryGroup(id: original.taskGroupID))
        let secondID = try #require(try store.continueHistoryGroup(id: original.taskGroupID))
        #expect(try store.startOrResume(taskID: firstID))
        #expect(try store.startOrResume(taskID: secondID))

        #expect(Set(store.tasks.filter { $0.status == .running }.map(\.id))
                .isSuperset(of: [firstID, secondID]))
        #expect(store.history.first { $0.id == original.id } == original)
    }

    @Test("Finishing a continuation grows one group without double counting its prior total")
    func finishingContinuationPreservesSessions() throws {
        let clock = HistoryTestClock(now: referenceDate.addingTimeInterval(100))
        let container = try makeContainer()
        var original = completedSession(id: UUID(), name: "Repeat", completedAt: referenceDate)
        original.accumulatedActiveDuration = 60
        try TaskSessionStore(modelContext: ModelContext(container)).save(original)
        let store = try TaskStore(
            persistence: TaskSessionStore(modelContext: ModelContext(container)),
            timerEngine: TimerEngine(timeProvider: clock)
        )
        let continuedID = try #require(try store.continueHistoryGroup(id: original.taskGroupID))
        #expect(try store.startOrResume(taskID: continuedID))
        clock.advance(by: 25)
        #expect(try store.finish(taskID: continuedID))

        let group = try #require(store.historyGroups.first)
        #expect(store.historyGroups.count == 1)
        #expect(group.sessionCount == 2)
        #expect(group.totalActiveDuration == 85)
        #expect(Set(group.sessions.map(\.id)) == [original.id, continuedID])
        #expect(group.sessions.last?.continuedFromSessionID == original.id)
    }

    @Test("History lookup returns only selected records in history order")
    func selectedHistoryLookup() throws {
        let container = try makeContainer()
        let first = completedSession(
            id: UUID(),
            name: "First",
            completedAt: referenceDate.addingTimeInterval(60)
        )
        let second = completedSession(
            id: UUID(),
            name: "Second",
            completedAt: referenceDate.addingTimeInterval(120)
        )
        let excluded = completedSession(
            id: UUID(),
            name: "Excluded",
            completedAt: referenceDate.addingTimeInterval(180)
        )
        try TaskSessionStore(modelContext: ModelContext(container)).save(
            [first, second, excluded],
            activeTaskID: nil
        )
        let store = try TaskStore(
            persistence: TaskSessionStore(modelContext: ModelContext(container))
        )

        #expect(store.historyGroups(ids: [first.taskGroupID, second.taskGroupID]).map(\.taskGroupID)
                == [second.taskGroupID, first.taskGroupID])
        #expect(store.historyGroups(ids: []).isEmpty)
        let snapshot = store.exportSnapshot(groupIDs: [first.taskGroupID, second.taskGroupID])
        #expect(Set(snapshot.groups.map(\.taskGroupID)) == [first.taskGroupID, second.taskGroupID])
        #expect(snapshot.sessionCount == 2)
        #expect(!snapshot.groups.flatMap(\.sessions).contains { $0.sessionID == excluded.id })
    }

    private var referenceDate: Date {
        Date(timeIntervalSince1970: 20_000)
    }

    private func makeStore(clock: HistoryTestClock) throws -> TaskStore {
        try TaskStore(
            persistence: TaskSessionStore(modelContext: ModelContext(try makeContainer())),
            timerEngine: TimerEngine(timeProvider: clock)
        )
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: PersistedTaskSession.self, PersistedTaskStoreState.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func completedSession(id: UUID, name: String, completedAt: Date) -> TaskSession {
        TaskSession(
            id: id,
            name: name,
            status: .completed,
            createdAt: referenceDate,
            firstStartedAt: referenceDate,
            completedAt: completedAt,
            accumulatedActiveDuration: 60
        )
    }
}

private final class HistoryTestClock: TimeProviding {
    var now: Date
    init(now: Date) { self.now = now }
    func advance(by interval: TimeInterval) { now = now.addingTimeInterval(interval) }
}
