import Foundation
import SwiftData

@Model
final class PersistedTaskStoreState {
    var activeTaskID: UUID?

    init(activeTaskID: UUID? = nil) {
        self.activeTaskID = activeTaskID
    }
}
