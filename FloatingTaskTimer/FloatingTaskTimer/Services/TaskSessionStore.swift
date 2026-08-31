import Foundation
import OSLog
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
        var changed = repairDuplicateSessionIDs(in: records)
        changed = repairLineage(in: records) || changed
        changed = migrateTaskGroupIDs(in: records) || changed

        for record in records {
            let repair = record.repairedTaskSession()
            sessions.append(repair.session)
            changed = repair.changed || changed
        }

        let stateRecords = try fetchStateRecords()
        let state = stateRecords.first
        for duplicate in stateRecords.dropFirst() {
            modelContext.delete(duplicate)
            changed = true
        }

        if changed {
            try modelContext.save()
            AppLogger.migration.notice("Persistent session repair completed records=\(records.count)")
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
        try delete(id: id, activeTaskID: nil, updateActiveTaskID: false)
    }

    func delete(id: UUID, activeTaskID: UUID?) throws {
        try delete(id: id, activeTaskID: activeTaskID, updateActiveTaskID: true)
    }

    private func delete(id: UUID, activeTaskID: UUID?, updateActiveTaskID: Bool) throws {
        for record in try fetchSessionRecords() where record.sessionID == id {
            modelContext.delete(record)
        }
        if updateActiveTaskID {
            try saveActiveTaskID(activeTaskID, savingContext: false)
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

            let groupID = component.compactMap(\.taskGroupID).min(by: uuidLess)
                ?? component.map(\.sessionID).min(by: uuidLess)
                ?? record.sessionID
            for member in component where member.taskGroupID != groupID {
                member.taskGroupID = groupID
                changed = true
            }
        }
        return changed
    }

    private func repairDuplicateSessionIDs(in records: [PersistedTaskSession]) -> Bool {
        var seen = Set<UUID>()
        var changed = false
        for record in records {
            guard seen.insert(record.sessionID).inserted else {
                let previousID = record.sessionID
                record.sessionID = UUID()
                record.continuedFromSessionID = nil
                changed = true
                AppLogger.migration.error("Reassigned duplicate session ID old=\(previousID, privacy: .public) new=\(record.sessionID, privacy: .public)")
                continue
            }
        }
        return changed
    }

    private func repairLineage(in records: [PersistedTaskSession]) -> Bool {
        var changed = false
        var recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.sessionID, $0) })
        for record in records {
            if let parentID = record.continuedFromSessionID, recordsByID[parentID] == nil {
                record.continuedFromSessionID = nil
                changed = true
                AppLogger.migration.notice("Cleared missing lineage parent session=\(record.sessionID, privacy: .public) parent=\(parentID, privacy: .public)")
            }
        }

        recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.sessionID, $0) })
        var repairedCycle = true
        while repairedCycle {
            repairedCycle = false
            for origin in records {
                var path: [UUID] = []
                var indexes: [UUID: Int] = [:]
                var current: PersistedTaskSession? = origin
                while let record = current, let parentID = record.continuedFromSessionID {
                    indexes[record.sessionID] = path.count
                    path.append(record.sessionID)
                    if let cycleStart = indexes[parentID] {
                        let cycleIDs = Array(path[cycleStart...])
                        if let breakID = cycleIDs.max(by: uuidLess), let breakRecord = recordsByID[breakID] {
                            breakRecord.continuedFromSessionID = nil
                            changed = true
                            repairedCycle = true
                            AppLogger.migration.notice("Broke lineage cycle session=\(breakID, privacy: .public) members=\(cycleIDs.count)")
                        }
                        break
                    }
                    current = recordsByID[parentID]
                }
                if repairedCycle { break }
            }
        }
        return changed
    }

    private func uuidLess(_ lhs: UUID, _ rhs: UUID) -> Bool {
        lhs.uuidString < rhs.uuidString
    }
}
