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
        let restored = try TaskSessionStore(modelContext: ModelContext(container)).load()

        #expect(restored == original)
    }

    @Test("A restored running session continues from its stored timestamp")
    func runningSessionRecovery() throws {
        let container = try makeContainer()
        let original = makeSession(status: .running)
        try TaskSessionStore(modelContext: ModelContext(container)).save(original)

        let loadedSession = try TaskSessionStore(
            modelContext: ModelContext(container)
        ).load()
        let restored = try #require(loadedSession)
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

        let loadedSession = try TaskSessionStore(
            modelContext: ModelContext(container)
        ).load()
        let restored = try #require(loadedSession)
        let clock = StoreTestTimeProvider(now: Date(timeIntervalSince1970: 50_000))

        #expect(TimerEngine(timeProvider: clock).currentDuration(for: restored) == 30)
    }

    @Test("Saving replaces the current session instead of duplicating it")
    func maintainsOneCurrentSession() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let store = TaskSessionStore(modelContext: context)

        try store.save(makeSession(status: .running))
        let resetSession = TaskSession(name: "Reset", createdAt: referenceDate)
        try store.save(resetSession)

        let records = try context.fetch(FetchDescriptor<PersistedTaskSession>())
        #expect(records.count == 1)
        #expect(try store.load() == resetSession)
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
        let restored = try TaskSessionStore(modelContext: ModelContext(container)).load()

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

        let restored = try TaskSessionStore(modelContext: ModelContext(container)).load()

        #expect(restored == nil)
    }

    private var referenceDate: Date {
        Date(timeIntervalSince1970: 10_000)
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: PersistedTaskSession.self,
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
