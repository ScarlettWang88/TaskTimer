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

    @Test("Continuation lineage round trips and absent legacy lineage remains nil")
    func continuationLineageRoundTrip() throws {
        let container = try makeContainer()
        let originID = UUID()
        var continued = makeSession(status: .idle)
        continued.continuedFromSessionID = originID
        let legacy = TaskSession(name: "Legacy", createdAt: referenceDate)
        try TaskSessionStore(modelContext: ModelContext(container)).save(
            [continued, legacy],
            activeTaskID: nil
        )

        let restored = try TaskSessionStore(
            modelContext: ModelContext(container)
        ).load().sessions

        #expect(restored.first { $0.id == continued.id }?.continuedFromSessionID == originID)
        #expect(restored.first { $0.id == legacy.id }?.continuedFromSessionID == nil)
    }

    @Test("Legacy records receive stable distinct group IDs without name merging")
    func migratesLegacyGroupIDs() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let first = PersistedTaskSession(session: TaskSession(name: "Same", createdAt: referenceDate))
        let second = PersistedTaskSession(session: TaskSession(name: "Same", createdAt: referenceDate))
        first.taskGroupID = nil
        second.taskGroupID = nil
        context.insert(first)
        context.insert(second)
        try context.save()

        let store = TaskSessionStore(modelContext: context)
        let firstLoad = try store.load().sessions
        let secondLoad = try store.load().sessions

        #expect(Set(firstLoad.map(\.taskGroupID)).count == 2)
        #expect(Dictionary(uniqueKeysWithValues: firstLoad.map { ($0.id, $0.taskGroupID) })
                == Dictionary(uniqueKeysWithValues: secondLoad.map { ($0.id, $0.taskGroupID) }))
    }

    @Test("Legacy continuation lineage reconstructs one stable group")
    func migratesLegacyContinuationChain() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let origin = TaskSession(name: "Chain", status: .completed, createdAt: referenceDate,
                                 completedAt: referenceDate)
        let child = TaskSession(name: "Chain", status: .completed, createdAt: referenceDate,
                                completedAt: referenceDate, continuedFromSessionID: origin.id)
        let originRecord = PersistedTaskSession(session: origin)
        let childRecord = PersistedTaskSession(session: child)
        originRecord.taskGroupID = nil
        childRecord.taskGroupID = nil
        context.insert(originRecord)
        context.insert(childRecord)
        try context.save()

        let restored = try TaskSessionStore(modelContext: context).load().sessions

        #expect(Set(restored.map(\.taskGroupID)).count == 1)
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
