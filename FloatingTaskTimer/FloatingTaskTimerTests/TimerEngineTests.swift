import Foundation
import Testing
@testable import FloatingTaskTimer

@Suite("TimerEngine")
struct TimerEngineTests {
    @Test("Start transitions an idle session to running")
    func startFromIdle() {
        let clock = TestTimeProvider()
        let engine = TimerEngine(timeProvider: clock)
        var session = TaskSession(name: "Write report", createdAt: clock.now)

        #expect(engine.start(&session))
        #expect(session.status == .running)
        #expect(session.firstStartedAt == clock.now)
        #expect(session.lastResumedAt == clock.now)
        #expect(engine.currentDuration(for: session) == 0)
    }

    @Test("Pause captures active time")
    func pauseRunningSession() {
        let (clock, engine, initialSession) = runningSession()
        var session = initialSession

        clock.advance(by: 42)

        #expect(engine.pause(&session))
        #expect(session.status == .paused)
        #expect(session.accumulatedActiveDuration == 42)
        #expect(session.lastResumedAt == nil)
        #expect(session.pauseStartedAt == clock.now)
        #expect(engine.currentDuration(for: session) == 42)
    }

    @Test("Resume captures paused time and continues active time")
    func resumePausedSession() {
        let (clock, engine, initialSession) = runningSession()
        var session = initialSession
        clock.advance(by: 10)
        engine.pause(&session)
        clock.advance(by: 7)

        #expect(engine.resume(&session))
        #expect(session.status == .running)
        #expect(session.accumulatedActiveDuration == 10)
        #expect(session.accumulatedPausedDuration == 7)
        #expect(session.pauseStartedAt == nil)

        clock.advance(by: 5)
        #expect(engine.currentDuration(for: session) == 15)
    }

    @Test(arguments: [TaskStatus.running, .paused])
    func resetClearsTimingState(status: TaskStatus) {
        let (clock, engine, initialSession) = runningSession()
        var session = initialSession
        clock.advance(by: 12)
        engine.pause(&session)
        if status == .running {
            clock.advance(by: 3)
            engine.resume(&session)
        }

        #expect(engine.reset(&session))
        #expect(session.status == .idle)
        #expect(session.firstStartedAt == nil)
        #expect(session.lastResumedAt == nil)
        #expect(session.pauseStartedAt == nil)
        #expect(session.completedAt == nil)
        #expect(session.accumulatedActiveDuration == 0)
        #expect(session.accumulatedPausedDuration == 0)
    }

    @Test("Finish a running session captures final active interval")
    func finishRunningSession() {
        let (clock, engine, initialSession) = runningSession()
        var session = initialSession
        clock.advance(by: 30)

        #expect(engine.finish(&session))
        #expect(session.status == .completed)
        #expect(session.accumulatedActiveDuration == 30)
        #expect(session.accumulatedPausedDuration == 0)
        #expect(session.completedAt == clock.now)
        #expect(engine.currentDuration(for: session) == 30)
    }

    @Test("Finish a paused session captures final paused interval")
    func finishPausedSession() {
        let (clock, engine, initialSession) = runningSession()
        var session = initialSession
        clock.advance(by: 20)
        engine.pause(&session)
        clock.advance(by: 8)

        #expect(engine.finish(&session))
        #expect(session.status == .completed)
        #expect(session.accumulatedActiveDuration == 20)
        #expect(session.accumulatedPausedDuration == 8)
        #expect(session.completedAt == clock.now)
    }

    @Test("A reconstructed running session derives duration from its timestamp")
    func restoredRunningSession() {
        let clock = TestTimeProvider(now: Date(timeIntervalSince1970: 1_100))
        let engine = TimerEngine(timeProvider: clock)
        let session = TaskSession(
            name: "Restored",
            status: .running,
            createdAt: Date(timeIntervalSince1970: 900),
            firstStartedAt: Date(timeIntervalSince1970: 900),
            lastResumedAt: Date(timeIntervalSince1970: 1_050),
            accumulatedActiveDuration: 25
        )

        #expect(engine.currentDuration(for: session) == 75)
    }

    @Test("A reconstructed paused session does not accrue active time")
    func restoredPausedSession() {
        let clock = TestTimeProvider(now: Date(timeIntervalSince1970: 1_100))
        let engine = TimerEngine(timeProvider: clock)
        let session = TaskSession(
            name: "Restored",
            status: .paused,
            createdAt: Date(timeIntervalSince1970: 900),
            firstStartedAt: Date(timeIntervalSince1970: 900),
            accumulatedActiveDuration: 25,
            pauseStartedAt: Date(timeIntervalSince1970: 1_050)
        )

        #expect(engine.currentDuration(for: session) == 25)
    }

    @Test("A long elapsed period is calculated without timer ticks")
    func simulatedSleepPeriod() {
        let (clock, engine, session) = runningSession()

        clock.advance(by: 8 * 60 * 60)

        #expect(engine.currentDuration(for: session) == 28_800)
    }

    @Test("Invalid transitions are rejected without mutation")
    func invalidTransitions() {
        let clock = TestTimeProvider()
        let engine = TimerEngine(timeProvider: clock)
        var idle = TaskSession(name: "Idle", createdAt: clock.now)

        let originalIdle = idle
        #expect(!engine.pause(&idle))
        #expect(!engine.resume(&idle))
        #expect(!engine.finish(&idle))
        #expect(idle == originalIdle)

        #expect(engine.start(&idle))
        let running = idle
        #expect(!engine.start(&idle))
        #expect(!engine.resume(&idle))
        #expect(idle == running)

        #expect(engine.finish(&idle))
        let completed = idle
        #expect(!engine.start(&idle))
        #expect(!engine.pause(&idle))
        #expect(!engine.resume(&idle))
        #expect(!engine.reset(&idle))
        #expect(!engine.finish(&idle))
        #expect(idle == completed)
    }

    @Test("Backward wall-clock movement never produces negative duration")
    func backwardClockMovement() {
        let (clock, engine, initialSession) = runningSession()
        var session = initialSession

        clock.advance(by: -10)

        #expect(engine.currentDuration(for: session) == 0)
        #expect(engine.pause(&session))
        #expect(session.accumulatedActiveDuration == 0)
    }

    private func runningSession() -> (TestTimeProvider, TimerEngine, TaskSession) {
        let clock = TestTimeProvider()
        let engine = TimerEngine(timeProvider: clock)
        var session = TaskSession(name: "Test", createdAt: clock.now)
        engine.start(&session)
        return (clock, engine, session)
    }
}

private final class TestTimeProvider: TimeProviding {
    var now: Date

    init(now: Date = Date(timeIntervalSince1970: 1_000)) {
        self.now = now
    }

    func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}
