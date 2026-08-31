import Foundation
import SwiftData

@Model
final class PersistedTaskSession {
    var sessionID: UUID
    var taskGroupID: UUID?
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
    var continuedFromSessionID: UUID?
    var updatedAt: Date

    init(session: TaskSession, updatedAt: Date = Date()) {
        sessionID = session.id
        taskGroupID = session.taskGroupID
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
        continuedFromSessionID = session.continuedFromSessionID
        self.updatedAt = updatedAt
    }

    var taskSession: TaskSession? {
        repairedTaskSession().session
    }

    func repairedTaskSession() -> (session: TaskSession, changed: Bool) {
        var changed = false
        var status = TaskStatus(rawValue: statusRawValue) ?? .idle
        if TaskStatus(rawValue: statusRawValue) == nil {
            statusRawValue = status.rawValue
            changed = true
        }

        let safeActiveDuration = accumulatedActiveDuration.isFinite
            ? max(0, accumulatedActiveDuration) : 0
        let safePausedDuration = accumulatedPausedDuration.isFinite
            ? max(0, accumulatedPausedDuration) : 0
        if safeActiveDuration != accumulatedActiveDuration {
            accumulatedActiveDuration = safeActiveDuration
            changed = true
        }
        if safePausedDuration != accumulatedPausedDuration {
            accumulatedPausedDuration = safePausedDuration
            changed = true
        }

        var safeFirstStartedAt = firstStartedAt
        var safeLastResumedAt = lastResumedAt
        var safePauseStartedAt = pauseStartedAt
        var safeCompletedAt = completedAt
        switch status {
        case .idle:
            break
        case .running:
            if safeFirstStartedAt == nil {
                safeFirstStartedAt = safeLastResumedAt ?? createdAt
                changed = true
            }
            if safeLastResumedAt == nil {
                status = .paused
                safePauseStartedAt = updatedAt
                statusRawValue = status.rawValue
                changed = true
            }
        case .paused:
            if safeFirstStartedAt == nil {
                safeFirstStartedAt = createdAt
                changed = true
            }
            if safePauseStartedAt == nil {
                safePauseStartedAt = updatedAt
                changed = true
            }
        case .completed:
            if safeCompletedAt == nil {
                safeCompletedAt = updatedAt
                changed = true
            }
            safeLastResumedAt = nil
            safePauseStartedAt = nil
        }

        let decodedIntervals: [TaskActiveInterval]
        do {
            decodedIntervals = try JSONDecoder().decode([TaskActiveInterval].self, from: activeIntervalsData)
        } catch {
            decodedIntervals = []
            if !activeIntervalsData.isEmpty { changed = true }
        }
        let safeIntervals = decodedIntervals.map {
            TaskActiveInterval(startedAt: $0.startedAt, endedAt: max($0.startedAt, $0.endedAt))
        }
        if safeIntervals != decodedIntervals { changed = true }

        let safeGroupID = taskGroupID ?? sessionID
        if taskGroupID == nil {
            taskGroupID = safeGroupID
            changed = true
        }

        let session = TaskSession(
            id: sessionID,
            taskGroupID: safeGroupID,
            name: name,
            category: category,
            status: status,
            createdAt: createdAt,
            firstStartedAt: safeFirstStartedAt,
            lastResumedAt: safeLastResumedAt,
            completedAt: safeCompletedAt,
            accumulatedActiveDuration: safeActiveDuration,
            accumulatedPausedDuration: safePausedDuration,
            pauseStartedAt: safePauseStartedAt,
            activeIntervals: safeIntervals,
            continuedFromSessionID: continuedFromSessionID
        )
        if changed { update(from: session, at: updatedAt) }
        return (session, changed)
    }

    func update(from session: TaskSession, at date: Date = Date()) {
        sessionID = session.id
        taskGroupID = session.taskGroupID
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
        continuedFromSessionID = session.continuedFromSessionID
        updatedAt = date
    }

}
