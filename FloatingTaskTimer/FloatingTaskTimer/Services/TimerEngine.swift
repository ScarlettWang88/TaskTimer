import Foundation

protocol TimeProviding {
    var now: Date { get }
}

struct SystemTimeProvider: TimeProviding {
    var now: Date { Date() }
}

struct TimerEngine {
    private let timeProvider: any TimeProviding

    init(timeProvider: any TimeProviding = SystemTimeProvider()) {
        self.timeProvider = timeProvider
    }

    @discardableResult
    func start(_ session: inout TaskSession) -> Bool {
        guard session.status == .idle else { return false }

        let now = timeProvider.now
        session.status = .running
        session.firstStartedAt = now
        session.lastResumedAt = now
        session.completedAt = nil
        session.pauseStartedAt = nil
        return true
    }

    @discardableResult
    func pause(_ session: inout TaskSession) -> Bool {
        guard session.status == .running, let lastResumedAt = session.lastResumedAt else {
            return false
        }

        let now = timeProvider.now
        session.accumulatedActiveDuration += elapsed(from: lastResumedAt, to: now)
        session.activeIntervals.append(
            TaskActiveInterval(startedAt: lastResumedAt, endedAt: max(now, lastResumedAt))
        )
        session.status = .paused
        session.lastResumedAt = nil
        session.pauseStartedAt = now
        return true
    }

    @discardableResult
    func resume(_ session: inout TaskSession) -> Bool {
        guard session.status == .paused, let pauseStartedAt = session.pauseStartedAt else {
            return false
        }

        let now = timeProvider.now
        session.accumulatedPausedDuration += elapsed(from: pauseStartedAt, to: now)
        session.status = .running
        session.lastResumedAt = now
        session.pauseStartedAt = nil
        session.activeIntervals = []
        return true
    }

    @discardableResult
    func reset(_ session: inout TaskSession) -> Bool {
        guard session.status != .completed else { return false }

        session.status = .idle
        session.firstStartedAt = nil
        session.lastResumedAt = nil
        session.completedAt = nil
        session.accumulatedActiveDuration = 0
        session.accumulatedPausedDuration = 0
        session.pauseStartedAt = nil
        return true
    }

    @discardableResult
    func finish(_ session: inout TaskSession) -> Bool {
        let now = timeProvider.now

        switch session.status {
        case .running:
            guard let lastResumedAt = session.lastResumedAt else { return false }
            session.accumulatedActiveDuration += elapsed(from: lastResumedAt, to: now)
            session.activeIntervals.append(
                TaskActiveInterval(startedAt: lastResumedAt, endedAt: max(now, lastResumedAt))
            )
        case .paused:
            guard let pauseStartedAt = session.pauseStartedAt else { return false }
            session.accumulatedPausedDuration += elapsed(from: pauseStartedAt, to: now)
        case .idle, .completed:
            return false
        }

        session.status = .completed
        session.lastResumedAt = nil
        session.pauseStartedAt = nil
        session.completedAt = now
        return true
    }

    func currentDuration(for session: TaskSession) -> TimeInterval {
        guard session.status == .running, let lastResumedAt = session.lastResumedAt else {
            return max(0, session.accumulatedActiveDuration)
        }

        return max(0, session.accumulatedActiveDuration)
            + elapsed(from: lastResumedAt, to: timeProvider.now)
    }

    private func elapsed(from start: Date, to end: Date) -> TimeInterval {
        max(0, end.timeIntervalSince(start))
    }
}
