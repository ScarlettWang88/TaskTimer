import Foundation
import SwiftData

@Model
final class PersistedTaskSession {
    var sessionID: UUID
    var name: String
    var category: String?
    var statusRawValue: String
    var createdAt: Date
    var firstStartedAt: Date?
    var lastResumedAt: Date?
    var completedAt: Date?
    var accumulatedActiveDuration: TimeInterval
    var accumulatedPausedDuration: TimeInterval
    var pauseStartedAt: Date?
    var activeIntervalsData: Data = Data()
    var updatedAt: Date

    init(session: TaskSession, updatedAt: Date = Date()) {
        sessionID = session.id
        name = session.name
        category = session.category
        statusRawValue = session.status.rawValue
        createdAt = session.createdAt
        firstStartedAt = session.firstStartedAt
        lastResumedAt = session.lastResumedAt
        completedAt = session.completedAt
        accumulatedActiveDuration = session.accumulatedActiveDuration
        accumulatedPausedDuration = session.accumulatedPausedDuration
        pauseStartedAt = session.pauseStartedAt
        activeIntervalsData = (try? JSONEncoder().encode(session.activeIntervals)) ?? Data()
        self.updatedAt = updatedAt
    }

    var taskSession: TaskSession? {
        guard
            let status = TaskStatus(rawValue: statusRawValue),
            accumulatedActiveDuration.isFinite,
            accumulatedActiveDuration >= 0,
            accumulatedPausedDuration.isFinite,
            accumulatedPausedDuration >= 0,
            hasRequiredTimestamps(for: status)
        else {
            return nil
        }

        let activeIntervals = (try? JSONDecoder().decode(
            [TaskActiveInterval].self,
            from: activeIntervalsData
        )) ?? []

        return TaskSession(
            id: sessionID,
            name: name,
            category: category,
            status: status,
            createdAt: createdAt,
            firstStartedAt: firstStartedAt,
            lastResumedAt: lastResumedAt,
            completedAt: completedAt,
            accumulatedActiveDuration: accumulatedActiveDuration,
            accumulatedPausedDuration: accumulatedPausedDuration,
            pauseStartedAt: pauseStartedAt,
            activeIntervals: activeIntervals
        )
    }

    func update(from session: TaskSession, at date: Date = Date()) {
        sessionID = session.id
        name = session.name
        category = session.category
        statusRawValue = session.status.rawValue
        createdAt = session.createdAt
        firstStartedAt = session.firstStartedAt
        lastResumedAt = session.lastResumedAt
        completedAt = session.completedAt
        accumulatedActiveDuration = session.accumulatedActiveDuration
        accumulatedPausedDuration = session.accumulatedPausedDuration
        pauseStartedAt = session.pauseStartedAt
        activeIntervalsData = (try? JSONEncoder().encode(session.activeIntervals)) ?? Data()
        updatedAt = date
    }

    private func hasRequiredTimestamps(for status: TaskStatus) -> Bool {
        switch status {
        case .idle:
            return true
        case .running:
            return firstStartedAt != nil && lastResumedAt != nil
        case .paused:
            return firstStartedAt != nil && pauseStartedAt != nil
        case .completed:
            return firstStartedAt != nil && completedAt != nil
        }
    }
}
