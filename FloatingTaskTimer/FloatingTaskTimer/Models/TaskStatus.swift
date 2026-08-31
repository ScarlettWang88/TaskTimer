import Foundation

enum TaskStatus: String, Codable, CaseIterable {
    case idle
    case running
    case paused
    case completed
}
