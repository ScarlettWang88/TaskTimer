import Foundation
import Observation

@MainActor
@Observable
final class TaskStore {
    private(set) var tasks: [TaskSession] = []
    private(set) var activeTaskID: UUID?
    private(set) var lastCompletedTask: TaskSession?

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
        lastCompletedTask = completed
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

    func duration(for task: TaskSession) -> TimeInterval {
        timerEngine.currentDuration(for: task)
    }

    private func restore() throws {
        let collection = try persistence.load()
        lastCompletedTask = collection.sessions
            .filter { $0.status == .completed }
            .max { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
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
