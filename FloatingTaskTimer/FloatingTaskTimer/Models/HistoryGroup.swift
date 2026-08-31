import Foundation

struct HistoryGroup: Identifiable, Equatable, Sendable {
    let taskGroupID: UUID
    let name: String
    let category: String?
    let lastActivityAt: Date?
    let totalActiveDuration: TimeInterval
    let totalPausedDuration: TimeInterval
    let sessions: [TaskSession]

    nonisolated var id: UUID { taskGroupID }
    nonisolated var sessionCount: Int { sessions.count }

    init(taskGroupID: UUID, sessions: [TaskSession]) {
        let ordered = sessions.sorted {
            ($0.completedAt ?? $0.createdAt) < ($1.completedAt ?? $1.createdAt)
        }
        let latest = ordered.last
        self.taskGroupID = taskGroupID
        name = latest?.name ?? "Untitled Task"
        category = ordered.reversed().compactMap(\.category).first
        lastActivityAt = latest?.completedAt
        totalActiveDuration = ordered.reduce(0) { $0 + $1.accumulatedActiveDuration }
        totalPausedDuration = ordered.reduce(0) { $0 + $1.accumulatedPausedDuration }
        self.sessions = ordered
    }
}
