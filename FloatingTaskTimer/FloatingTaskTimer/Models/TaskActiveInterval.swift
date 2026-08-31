import Foundation

struct TaskActiveInterval: Codable, Equatable, Sendable {
    var startedAt: Date
    var endedAt: Date

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.startedAt == rhs.startedAt && lhs.endedAt == rhs.endedAt
    }
}
