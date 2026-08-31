import Foundation
import SwiftData

struct PersistedTaskCollection {
    var sessions: [TaskSession]
    var activeTaskID: UUID?
}

@MainActor
final class TaskSessionStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func load() throws -> PersistedTaskCollection {
        let records = try fetchSessionRecords()
        var sessions: [TaskSession] = []
        var seenIDs = Set<UUID>()
        var changed = migrateTaskGroupIDs(in: records)

        for record in records {
            guard let session = record.taskSession, seenIDs.insert(session.id).inserted else {
                modelContext.delete(record)
                changed = true
                continue
            }
            sessions.append(session)
        }

        let stateRecords = try fetchStateRecords()
        let state = stateRecords.first
        for duplicate in stateRecords.dropFirst() {
            modelContext.delete(duplicate)
            changed = true
        }

        if changed {
            try modelContext.save()
        }

        return PersistedTaskCollection(sessions: sessions, activeTaskID: state?.activeTaskID)
    }

    func save(_ session: TaskSession) throws {
        let records = try fetchSessionRecords().filter { $0.sessionID == session.id }

        if let record = records.first {
            record.update(from: session)
            for duplicate in records.dropFirst() {
                modelContext.delete(duplicate)
            }
        } else {
            modelContext.insert(PersistedTaskSession(session: session))
        }

        try modelContext.save()
    }

    func save(_ sessions: [TaskSession], activeTaskID: UUID?) throws {
        let recordsByID = Dictionary(grouping: try fetchSessionRecords(), by: \.sessionID)

        for session in sessions {
            if let records = recordsByID[session.id], let record = records.first {
                record.update(from: session)
                for duplicate in records.dropFirst() {
                    modelContext.delete(duplicate)
                }
            } else {
                modelContext.insert(PersistedTaskSession(session: session))
            }
        }

        try saveActiveTaskID(activeTaskID, savingContext: false)
        try modelContext.save()
    }

    func delete(id: UUID) throws {
        for record in try fetchSessionRecords() where record.sessionID == id {
            modelContext.delete(record)
        }
        try modelContext.save()
    }

    func delete(taskGroupID: UUID) throws {
        try delete(taskGroupIDs: [taskGroupID])
    }

    func delete(taskGroupIDs: Set<UUID>) throws {
        guard !taskGroupIDs.isEmpty else { return }
        for record in try fetchSessionRecords() {
            guard let taskGroupID = record.taskGroupID,
                  taskGroupIDs.contains(taskGroupID),
                  record.statusRawValue == TaskStatus.completed.rawValue else { continue }
            modelContext.delete(record)
        }
        try modelContext.save()
    }

    func saveActiveTaskID(_ activeTaskID: UUID?) throws {
        try saveActiveTaskID(activeTaskID, savingContext: true)
    }

    private func saveActiveTaskID(_ activeTaskID: UUID?, savingContext: Bool) throws {
        let states = try fetchStateRecords()
        if let state = states.first {
            state.activeTaskID = activeTaskID
            for duplicate in states.dropFirst() {
                modelContext.delete(duplicate)
            }
        } else {
            modelContext.insert(PersistedTaskStoreState(activeTaskID: activeTaskID))
        }

        if savingContext {
            try modelContext.save()
        }
    }

    private func fetchSessionRecords() throws -> [PersistedTaskSession] {
        let descriptor = FetchDescriptor<PersistedTaskSession>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchStateRecords() throws -> [PersistedTaskStoreState] {
        try modelContext.fetch(FetchDescriptor<PersistedTaskStoreState>())
    }

    private func migrateTaskGroupIDs(in records: [PersistedTaskSession]) -> Bool {
        let recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.sessionID, $0) })
        var neighbors: [UUID: Set<UUID>] = [:]
        for record in records {
            guard let parentID = record.continuedFromSessionID, recordsByID[parentID] != nil else {
                continue
            }
            neighbors[record.sessionID, default: []].insert(parentID)
            neighbors[parentID, default: []].insert(record.sessionID)
        }

        var visited = Set<UUID>()
        var changed = false
        for record in records where !visited.contains(record.sessionID) {
            var stack = [record.sessionID]
            var component: [PersistedTaskSession] = []
            while let id = stack.popLast() {
                guard visited.insert(id).inserted, let member = recordsByID[id] else { continue }
                component.append(member)
                stack.append(contentsOf: neighbors[id, default: []])
            }

            let groupID = component.compactMap(\.taskGroupID).first ?? UUID()
            for member in component where member.taskGroupID == nil {
                member.taskGroupID = groupID
                changed = true
            }
        }
        return changed
    }
}
