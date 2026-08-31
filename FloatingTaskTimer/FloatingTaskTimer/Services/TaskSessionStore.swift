import Foundation
import SwiftData

@MainActor
final class TaskSessionStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func load() throws -> TaskSession? {
        let records = try fetchRecords()

        guard let currentRecord = records.first else {
            return nil
        }

        for duplicate in records.dropFirst() {
            modelContext.delete(duplicate)
        }

        guard let session = currentRecord.taskSession else {
            modelContext.delete(currentRecord)
            try modelContext.save()
            return nil
        }

        if records.count > 1 {
            try modelContext.save()
        }

        return session
    }

    func save(_ session: TaskSession) throws {
        let records = try fetchRecords()

        if let currentRecord = records.first {
            currentRecord.update(from: session)

            for duplicate in records.dropFirst() {
                modelContext.delete(duplicate)
            }
        } else {
            modelContext.insert(PersistedTaskSession(session: session))
        }

        try modelContext.save()
    }

    private func fetchRecords() throws -> [PersistedTaskSession] {
        let descriptor = FetchDescriptor<PersistedTaskSession>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
}
