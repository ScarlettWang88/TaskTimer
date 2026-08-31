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
        pauseStartedAt: Date? = nil
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
    }
}
