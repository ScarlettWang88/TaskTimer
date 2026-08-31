import Foundation
import SwiftData
import Testing
@testable import FloatingTaskTimer

@MainActor
@Suite("TaskStore parallel timers")
struct TaskStoreTests {
    @Test("Two tasks can run simultaneously")
    func twoTasksRunning() throws {
        let (store, _, firstID) = try makeNamedStore()
        let secondID = try store.createTask(name: "Second", startImmediately: false)

        #expect(try store.startOrResume(taskID: firstID))
        #expect(try store.startOrResume(taskID: secondID))
        #expect(Set(store.tasks.filter { $0.status == .running }.map(\.id)) == Set([firstID, secondID]))
    }

    @Test("Three tasks can run simultaneously")
    func threeTasksRunning() throws {
        let (store, _, firstID) = try makeNamedStore()
        let secondID = try store.createTask(name: "Second", startImmediately: true)
        let thirdID = try store.createTask(name: "Third", startImmediately: true)
        #expect(try store.startOrResume(taskID: firstID))

        #expect(Set(store.tasks.filter { $0.status == .running }.map(\.id)) == Set([firstID, secondID, thirdID]))
    }

    @Test("Pausing one task does not stop another")
    func pausingOneTask() throws {
        let (store, clock, firstID) = try makeNamedStore()
        let secondID = try store.createTask(name: "Second", startImmediately: true)
        #expect(try store.startOrResume(taskID: firstID))
        clock.advance(by: 20)

        #expect(try store.pause(taskID: firstID))
        clock.advance(by: 10)

        #expect(store.tasks.first { $0.id == firstID }?.status == .paused)
        #expect(store.tasks.first { $0.id == firstID }?.accumulatedActiveDuration == 20)
        let second = try #require(store.tasks.first { $0.id == secondID })
        #expect(second.status == .running)
        #expect(store.duration(for: second) == 30)
    }

    @Test("Finishing one task leaves another running")
    func finishingOneTask() throws {
        let (store, clock, firstID) = try makeNamedStore()
        let secondID = try store.createTask(name: "Second", startImmediately: true)
        #expect(try store.startOrResume(taskID: firstID))
        clock.advance(by: 15)

        #expect(try store.finish(taskID: firstID))

        #expect(!store.tasks.contains { $0.id == firstID })
        #expect(store.lastCompletedTask?.id == firstID)
        #expect(store.tasks.first { $0.id == secondID }?.status == .running)
    }

    @Test("Resetting one task leaves another running")
    func resettingOneTask() throws {
        let (store, clock, firstID) = try makeNamedStore()
        let secondID = try store.createTask(name: "Second", startImmediately: true)
        #expect(try store.startOrResume(taskID: firstID))
        clock.advance(by: 12)

        #expect(try store.reset(taskID: firstID))

        #expect(store.tasks.first { $0.id == firstID }?.status == .idle)
        #expect(store.tasks.first { $0.id == firstID }?.accumulatedActiveDuration == 0)
        #expect(store.tasks.first { $0.id == secondID }?.status == .running)
    }

    @Test("Relaunch restores multiple independently running tasks")
    func restoresMultipleRunningTasks() throws {
        let container = try makeContainer()
        let first = runningSession(name: "First", resumedOffset: 0)
        let second = runningSession(name: "Second", resumedOffset: 20)
        let third = runningSession(name: "Third", resumedOffset: 40)
        try TaskSessionStore(modelContext: ModelContext(container)).save(
            [first, second, third],
            activeTaskID: second.id
        )
        let clock = TaskStoreTestClock(now: referenceDate.addingTimeInterval(100))

        let restored = try TaskStore(
            persistence: TaskSessionStore(modelContext: ModelContext(container)),
            timerEngine: TimerEngine(timeProvider: clock)
        )

        #expect(restored.tasks.filter { $0.status == .running }.count == 3)
        #expect(restored.activeTaskID == second.id)
        #expect(restored.duration(for: try #require(restored.tasks.first { $0.id == first.id })) == 100)
        #expect(restored.duration(for: try #require(restored.tasks.first { $0.id == second.id })) == 80)
        #expect(restored.duration(for: try #require(restored.tasks.first { $0.id == third.id })) == 60)
    }

    @Test("Relaunch preserves mixed running and paused tasks")
    func restoresMixedStates() throws {
        let container = try makeContainer()
        let running = runningSession(name: "Running", resumedOffset: 25)
        let paused = pausedSession(name: "Paused")
        try TaskSessionStore(modelContext: ModelContext(container)).save(
            [running, paused],
            activeTaskID: paused.id
        )
        let clock = TaskStoreTestClock(now: referenceDate.addingTimeInterval(100))

        let restored = try TaskStore(
            persistence: TaskSessionStore(modelContext: ModelContext(container)),
            timerEngine: TimerEngine(timeProvider: clock)
        )

        let restoredRunning = try #require(restored.tasks.first { $0.id == running.id })
        let restoredPaused = try #require(restored.tasks.first { $0.id == paused.id })
        #expect(restoredRunning.status == .running)
        #expect(restored.duration(for: restoredRunning) == 75)
        #expect(restoredPaused.status == .paused)
        #expect(restored.duration(for: restoredPaused) == 30)
        #expect(restored.activeTaskID == paused.id)
    }

    @Test("Rapid operations on different tasks remain independent")
    func rapidIndependentOperations() throws {
        let (store, clock, firstID) = try makeNamedStore()
        let secondID = try store.createTask(name: "Second", startImmediately: false)
        let thirdID = try store.createTask(name: "Third", startImmediately: false)

        #expect(try store.startOrResume(taskID: firstID))
        #expect(try store.startOrResume(taskID: secondID))
        clock.advance(by: 5)
        #expect(try store.pause(taskID: firstID))
        #expect(try store.startOrResume(taskID: thirdID))
        #expect(try store.pause(taskID: secondID))
        #expect(try store.startOrResume(taskID: firstID))

        #expect(Set(store.tasks.filter { $0.status == .running }.map(\.id)) == Set([firstID, thirdID]))
        #expect(store.tasks.first { $0.id == secondID }?.status == .paused)
    }

    @Test("Completed active intervals are retained for future overlap analytics")
    func retainsActiveIntervals() throws {
        let (store, clock, firstID) = try makeNamedStore()
        #expect(try store.startOrResume(taskID: firstID))
        clock.advance(by: 8)
        #expect(try store.pause(taskID: firstID))

        let task = try #require(store.tasks.first { $0.id == firstID })
        #expect(task.activeIntervals == [
            TaskActiveInterval(
                startedAt: referenceDate,
                endedAt: referenceDate.addingTimeInterval(8)
            )
        ])
    }

    private var referenceDate: Date { Date(timeIntervalSince1970: 10_000) }

    private func makeNamedStore() throws -> (TaskStore, TaskStoreTestClock, UUID) {
        let clock = TaskStoreTestClock(now: referenceDate)
        let store = try TaskStore(
            persistence: TaskSessionStore(modelContext: ModelContext(try makeContainer())),
            timerEngine: TimerEngine(timeProvider: clock)
        )
        let firstID = try #require(store.activeTaskID)
        try store.rename(taskID: firstID, name: "First")
        return (store, clock, firstID)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: PersistedTaskSession.self, PersistedTaskStoreState.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func runningSession(name: String, resumedOffset: TimeInterval) -> TaskSession {
        TaskSession(
            name: name,
            status: .running,
            createdAt: referenceDate,
            firstStartedAt: referenceDate,
            lastResumedAt: referenceDate.addingTimeInterval(resumedOffset)
        )
    }

    private func pausedSession(name: String) -> TaskSession {
        TaskSession(
            name: name,
            status: .paused,
            createdAt: referenceDate,
            firstStartedAt: referenceDate,
            accumulatedActiveDuration: 30,
            pauseStartedAt: referenceDate.addingTimeInterval(30)
        )
    }
}

private final class TaskStoreTestClock: TimeProviding {
    var now: Date
    init(now: Date) { self.now = now }
    func advance(by interval: TimeInterval) { now = now.addingTimeInterval(interval) }
}
