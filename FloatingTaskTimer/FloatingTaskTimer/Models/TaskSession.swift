import Foundation

struct TaskSession: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var category: String?
    var status: TaskStatus

    var createdAt: Date
    var firstStartedAt: Date?
    var lastResumedAt: Date?
    var completedAt: Date?

    var accumulatedActiveDuration: TimeInterval
    var accumulatedPausedDuration: TimeInterval
    var pauseStartedAt: Date?
    var activeIntervals: [TaskActiveInterval]

    init(
        id: UUID = UUID(),
        name: String,
        category: String? = nil,
        status: TaskStatus = .idle,
        createdAt: Date = Date(),
        firstStartedAt: Date? = nil,
        lastResumedAt: Date? = nil,
        completedAt: Date? = nil,
        accumulatedActiveDuration: TimeInterval = 0,
        accumulatedPausedDuration: TimeInterval = 0,
        pauseStartedAt: Date? = nil,
        activeIntervals: [TaskActiveInterval] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.status = status
        self.createdAt = createdAt
        self.firstStartedAt = firstStartedAt
        self.lastResumedAt = lastResumedAt
        self.completedAt = completedAt
        self.accumulatedActiveDuration = accumulatedActiveDuration
        self.accumulatedPausedDuration = accumulatedPausedDuration
        self.pauseStartedAt = pauseStartedAt
        self.activeIntervals = activeIntervals
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.category == rhs.category
            && lhs.status == rhs.status
            && lhs.createdAt == rhs.createdAt
            && lhs.firstStartedAt == rhs.firstStartedAt
            && lhs.lastResumedAt == rhs.lastResumedAt
            && lhs.completedAt == rhs.completedAt
            && lhs.accumulatedActiveDuration == rhs.accumulatedActiveDuration
            && lhs.accumulatedPausedDuration == rhs.accumulatedPausedDuration
            && lhs.pauseStartedAt == rhs.pauseStartedAt
            && lhs.activeIntervals == rhs.activeIntervals
    }
}
