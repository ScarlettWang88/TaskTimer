import Foundation
import SwiftData
import Testing
@testable import FloatingTaskTimer

@MainActor
@Suite("TaskSessionStore")
struct TaskSessionStoreTests {
    @Test(arguments: [TaskStatus.idle, .running, .paused, .completed])
    func roundTripsEverySessionState(status: TaskStatus) throws {
        let container = try makeContainer()
        let original = makeSession(status: status)

        try TaskSessionStore(modelContext: ModelContext(container)).save(original)
        let restored = try TaskSessionStore(modelContext: ModelContext(container)).load().sessions

        #expect(restored == [original])
    }

    @Test("A restored running session continues from its stored timestamp")
    func runningSessionRecovery() throws {
        let container = try makeContainer()
        let original = makeSession(status: .running)
        try TaskSessionStore(modelContext: ModelContext(container)).save(original)

        let loadedSessions = try TaskSessionStore(
            modelContext: ModelContext(container)
        ).load().sessions
        let restored = try #require(loadedSessions.first)
        let clock = StoreTestTimeProvider(
            now: try #require(restored.lastResumedAt).addingTimeInterval(45)
        )

        #expect(TimerEngine(timeProvider: clock).currentDuration(for: restored) == 75)
    }

    @Test("A restored paused session remains frozen")
    func pausedSessionRecovery() throws {
        let container = try makeContainer()
        let original = makeSession(status: .paused)
        try TaskSessionStore(modelContext: ModelContext(container)).save(original)

        let loadedSessions = try TaskSessionStore(
            modelContext: ModelContext(container)
        ).load().sessions
        let restored = try #require(loadedSessions.first)
        let clock = StoreTestTimeProvider(now: Date(timeIntervalSince1970: 50_000))

        #expect(TimerEngine(timeProvider: clock).currentDuration(for: restored) == 30)
    }

    @Test("Saving maintains multiple sessions and updates by ID")
    func maintainsMultipleSessions() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let store = TaskSessionStore(modelContext: context)

        let running = makeSession(status: .running)
        let idle = TaskSession(name: "Idle 2", createdAt: referenceDate)
        try store.save(running)
        try store.save(idle)
        var updated = running
        updated.name = "Updated"
        try store.save(updated)

        let records = try context.fetch(FetchDescriptor<PersistedTaskSession>())
        #expect(records.count == 2)
        #expect(Set(try store.load().sessions.map(\.id)) == Set([running.id, idle.id]))
        #expect(try store.load().sessions.first(where: { $0.id == running.id })?.name == "Updated")
    }

    @Test("A reset session restores as idle with zero durations")
    func resetSessionRecovery() throws {
        let container = try makeContainer()
        var session = makeSession(status: .running)
        let engine = TimerEngine(
            timeProvider: StoreTestTimeProvider(now: referenceDate.addingTimeInterval(90))
        )
        #expect(engine.reset(&session))

        try TaskSessionStore(modelContext: ModelContext(container)).save(session)
        let restored = try TaskSessionStore(modelContext: ModelContext(container)).load().sessions.first

        #expect(restored?.status == .idle)
        #expect(restored?.accumulatedActiveDuration == 0)
        #expect(restored?.accumulatedPausedDuration == 0)
        #expect(restored?.firstStartedAt == nil)
        #expect(restored?.lastResumedAt == nil)
    }

    @Test("An invalid record is discarded safely")
    func discardsInvalidRecord() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let record = PersistedTaskSession(session: makeSession(status: .running))
        record.statusRawValue = "unknown"
        context.insert(record)
        try context.save()

        let restored = try TaskSessionStore(modelContext: ModelContext(container)).load().sessions

        #expect(restored.isEmpty)
    }

    private var referenceDate: Date {
        Date(timeIntervalSince1970: 10_000)
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: PersistedTaskSession.self, PersistedTaskStoreState.self,
            configurations: configuration
        )
    }

    private func makeSession(status: TaskStatus) -> TaskSession {
        switch status {
        case .idle:
            return TaskSession(name: "Idle", createdAt: referenceDate)
        case .running:
            return TaskSession(
                name: "Running",
                status: .running,
                createdAt: referenceDate,
                firstStartedAt: referenceDate,
                lastResumedAt: referenceDate.addingTimeInterval(10),
                accumulatedActiveDuration: 30
            )
        case .paused:
            return TaskSession(
                name: "Paused",
                status: .paused,
                createdAt: referenceDate,
                firstStartedAt: referenceDate,
                accumulatedActiveDuration: 30,
                accumulatedPausedDuration: 5,
                pauseStartedAt: referenceDate.addingTimeInterval(40)
            )
        case .completed:
            return TaskSession(
                name: "Completed",
                status: .completed,
                createdAt: referenceDate,
                firstStartedAt: referenceDate,
                completedAt: referenceDate.addingTimeInterval(60),
                accumulatedActiveDuration: 50,
                accumulatedPausedDuration: 10
            )
        }
    }
}

private final class StoreTestTimeProvider: TimeProviding {
    let now: Date

    init(now: Date) {
        self.now = now
    }
}
