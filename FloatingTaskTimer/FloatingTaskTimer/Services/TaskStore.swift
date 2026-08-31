import Foundation
import Observation

@MainActor
@Observable
final class TaskStore {
    private(set) var tasks: [TaskSession] = []
    private(set) var activeTaskID: UUID?
    private(set) var history: [TaskSession] = []

    @ObservationIgnored private let persistence: TaskSessionStore
    @ObservationIgnored private let timerEngine: TimerEngine

    init(persistence: TaskSessionStore) throws {
        self.persistence = persistence
        timerEngine = TimerEngine()
        try restore()
    }

    init(persistence: TaskSessionStore, timerEngine: TimerEngine) throws {
        self.persistence = persistence
        self.timerEngine = timerEngine
        try restore()
    }

    var activeTask: TaskSession? {
        guard let activeTaskID else { return nil }
        return tasks.first { $0.id == activeTaskID }
    }

    var otherTasks: [TaskSession] {
        tasks.filter { $0.id != activeTaskID }
    }

    var menuBarTask: TaskSession? {
        miniTask
    }

    var runningTasks: [TaskSession] {
        tasks.filter { $0.status == .running }
    }

    var miniTask: TaskSession? {
        if let activeTask, activeTask.status == .running {
            return activeTask
        }

        return runningTasks.max(by: { lhs, rhs in
            let lhsDate = lhs.lastResumedAt ?? lhs.firstStartedAt ?? lhs.createdAt
            let rhsDate = rhs.lastResumedAt ?? rhs.firstStartedAt ?? rhs.createdAt
            if lhsDate == rhsDate {
                return taskOrder(for: lhs.id) > taskOrder(for: rhs.id)
            }
            return lhsDate < rhsDate
        }) ?? activeTask
    }

    var lastCompletedTask: TaskSession? {
        history.first
    }

    var historyGroups: [HistoryGroup] {
        Dictionary(grouping: history, by: \.taskGroupID)
            .map { HistoryGroup(taskGroupID: $0.key, sessions: $0.value) }
            .sorted { ($0.lastActivityAt ?? .distantPast) > ($1.lastActivityAt ?? .distantPast) }
    }

    @discardableResult
    func createTask(name: String, startImmediately: Bool) throws -> UUID {
        let taskID: UUID
        if tasks.count == 1, let placeholder = tasks.first, isEmptyPlaceholder(placeholder) {
            tasks[0].name = normalizedName(name)
            taskID = placeholder.id
        } else {
            let session = TaskSession(name: normalizedName(name))
            tasks.append(session)
            taskID = session.id
        }
        activeTaskID = taskID

        if startImmediately {
            try startOrResume(taskID: taskID)
        } else {
            try persistAll()
        }
        return taskID
    }

    func selectTask(id: UUID) throws {
        guard tasks.contains(where: { $0.id == id }) else { return }
        activeTaskID = id
        try persistence.saveActiveTaskID(id)
    }

    func selectAdjacentRunningTask(from taskID: UUID, offset: Int) throws {
        let running = runningTasks
        guard running.count > 1 else { return }

        let currentIndex = running.firstIndex(where: { $0.id == taskID }) ?? 0
        let nextIndex = (currentIndex + offset % running.count + running.count) % running.count
        try selectTask(id: running[nextIndex].id)
    }

    @discardableResult
    func startOrResume(taskID: UUID) throws -> Bool {
        guard let targetIndex = tasks.firstIndex(where: { $0.id == taskID }) else {
            return false
        }

        let targetStatus = tasks[targetIndex].status
        guard targetStatus == .idle || targetStatus == .paused else {
            if targetStatus == .running {
                activeTaskID = taskID
                try persistence.saveActiveTaskID(taskID)
            }
            return false
        }

        activeTaskID = taskID

        let changed: Bool
        switch tasks[targetIndex].status {
        case .idle:
            tasks[targetIndex].name = normalizedName(tasks[targetIndex].name)
            changed = timerEngine.start(&tasks[targetIndex])
        case .paused:
            changed = timerEngine.resume(&tasks[targetIndex])
        case .running, .completed:
            changed = false
        }

        if changed {
            try persistAll()
        }
        return changed
    }

    @discardableResult
    func pause(taskID: UUID) throws -> Bool {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return false }
        guard timerEngine.pause(&tasks[index]) else { return false }
        try persistAll()
        return true
    }

    @discardableResult
    func reset(taskID: UUID) throws -> Bool {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return false }
        guard timerEngine.reset(&tasks[index]) else { return false }
        try persistAll()
        return true
    }

    @discardableResult
    func finish(taskID: UUID) throws -> Bool {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return false }
        guard timerEngine.finish(&tasks[index]) else { return false }

        let completed = tasks.remove(at: index)
        history.append(completed)
        sortHistory()
        activeTaskID = preferredActiveTaskID()
        try persistAll(including: completed)
        return true
    }

    func delete(taskID: UUID) throws {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks.remove(at: index)
        try persistence.delete(id: taskID)

        if activeTaskID == taskID {
            activeTaskID = preferredActiveTaskID()
        }
        try persistence.saveActiveTaskID(activeTaskID)
    }

    func rename(taskID: UUID, name: String) throws {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].name = name
        try persistence.save(tasks[index])
    }

    func renameHistoryGroup(id taskGroupID: UUID, name: String) throws {
        let updatedName = normalizedName(name)
        var changedSessions: [TaskSession] = []
        for index in history.indices where history[index].taskGroupID == taskGroupID {
            history[index].name = updatedName
            changedSessions.append(history[index])
        }
        for index in tasks.indices where tasks[index].taskGroupID == taskGroupID {
            tasks[index].name = updatedName
            changedSessions.append(tasks[index])
        }
        for session in changedSessions {
            try persistence.save(session)
        }
    }

    func deleteHistoryGroup(id taskGroupID: UUID) throws {
        try deleteHistoryGroups(ids: [taskGroupID])
    }

    func deleteHistoryGroups(ids taskGroupIDs: Set<UUID>) throws {
        guard !taskGroupIDs.isEmpty else { return }
        history.removeAll { taskGroupIDs.contains($0.taskGroupID) }
        try persistence.delete(taskGroupIDs: taskGroupIDs)
    }

    @discardableResult
    func continueHistoryGroup(id taskGroupID: UUID) throws -> UUID? {
        guard let original = history
            .filter({ $0.taskGroupID == taskGroupID })
            .max(by: { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) })
        else { return nil }

        let continued = TaskSession(
            taskGroupID: taskGroupID,
            name: normalizedName(original.name),
            category: original.category,
            continuedFromSessionID: original.id
        )
        tasks.append(continued)
        activeTaskID = continued.id
        try persistAll()
        return continued.id
    }

    func historyGroups(ids: Set<UUID>) -> [HistoryGroup] {
        historyGroups.filter { ids.contains($0.taskGroupID) }
    }

    func exportSnapshot(groupIDs: Set<UUID>) -> HistoryExportSnapshot {
        guard !groupIDs.isEmpty else { return HistoryExportSnapshot(groups: []) }

        var selectedSessions: [UUID: [TaskSession]] = [:]
        for session in history where groupIDs.contains(session.taskGroupID) {
            selectedSessions[session.taskGroupID, default: []].append(session)
        }

        let groups = selectedSessions.map { taskGroupID, sessions in
            let ordered = sessions.sorted {
                ($0.completedAt ?? $0.createdAt) < ($1.completedAt ?? $1.createdAt)
            }
            let latest = ordered.last
            return HistoryExportGroupSnapshot(
                taskGroupID: taskGroupID,
                name: latest?.name ?? "Untitled Task",
                lastActivityAt: latest?.completedAt,
                totalActiveDuration: ordered.reduce(0) { $0 + $1.accumulatedActiveDuration },
                totalPausedDuration: ordered.reduce(0) { $0 + $1.accumulatedPausedDuration },
                sessions: ordered.map {
                    HistoryExportSessionSnapshot(
                        taskGroupID: $0.taskGroupID,
                        sessionID: $0.id,
                        continuedFromSessionID: $0.continuedFromSessionID,
                        name: $0.name,
                        firstStartedAt: $0.firstStartedAt,
                        completedAt: $0.completedAt,
                        activeDuration: $0.accumulatedActiveDuration,
                        pausedDuration: $0.accumulatedPausedDuration
                    )
                }
            )
        }.sorted { ($0.lastActivityAt ?? .distantPast) > ($1.lastActivityAt ?? .distantPast) }

        return HistoryExportSnapshot(groups: groups)
    }

    func historySessions(taskGroupID: UUID) -> [TaskSession] {
        historyGroups.first { $0.taskGroupID == taskGroupID }?.sessions ?? []
    }

    func duration(for task: TaskSession) -> TimeInterval {
        let completedTotal = history.lazy
            .filter { $0.taskGroupID == task.taskGroupID }
            .reduce(0) { $0 + $1.accumulatedActiveDuration }
        return completedTotal + timerEngine.currentDuration(for: task)
    }

    private func restore() throws {
        let collection = try persistence.load()
        history = collection.sessions
            .filter { $0.status == .completed }
        sortHistory()
        tasks = collection.sessions.filter { $0.status != .completed }

        let persistedActiveID = collection.activeTaskID
        if let persistedActiveID, tasks.contains(where: { $0.id == persistedActiveID }) {
            activeTaskID = persistedActiveID
        } else {
            activeTaskID = tasks.first(where: { $0.status == .running })?.id ?? tasks.first?.id
        }

        if tasks.isEmpty {
            let initialTask = TaskSession(name: "")
            tasks = [initialTask]
            activeTaskID = initialTask.id
        }

        try persistAll()
    }

    private func preferredActiveTaskID() -> UUID? {
        tasks.first(where: { $0.status == .running })?.id ?? tasks.first?.id
    }

    private func taskOrder(for id: UUID) -> Int {
        tasks.firstIndex(where: { $0.id == id }) ?? .max
    }

    private func sortHistory() {
        history.sort {
            ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
        }
    }

    private func persistAll(including additionalSession: TaskSession? = nil) throws {
        var sessions = tasks
        if let additionalSession {
            sessions.append(additionalSession)
        }
        try persistence.save(sessions, activeTaskID: activeTaskID)
    }

    private func normalizedName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Task" : trimmed
    }

    private func isEmptyPlaceholder(_ task: TaskSession) -> Bool {
        task.status == .idle
            && task.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && task.firstStartedAt == nil
            && task.accumulatedActiveDuration == 0
            && task.accumulatedPausedDuration == 0
    }
}
