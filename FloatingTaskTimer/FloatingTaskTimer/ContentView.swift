import SwiftUI

struct ContentView: View {
    @State private var session = TaskSession(name: "")

    private let timerEngine = TimerEngine()

    var body: some View {
        VStack(spacing: 28) {
            header
            timerDisplay
            controls

            if session.status == .completed {
                Divider()
                completionSummary
            }
        }
        .padding(32)
        .frame(minWidth: 440, idealWidth: 500, minHeight: 330)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Task")
                .font(.headline)

            TextField("What are you working on?", text: $session.name)
                .textFieldStyle(.roundedBorder)
                .disabled(session.status != .idle)
                .onSubmit(start)
                .accessibilityLabel("Task name")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var timerDisplay: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let duration = formattedDuration(timerEngine.currentDuration(for: session))

            Text(duration)
                .font(.system(size: 56, weight: .medium, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityLabel("Elapsed time")
                .accessibilityValue(duration)
        }
        .frame(maxWidth: .infinity)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button("Start", action: start)
                .keyboardShortcut(.defaultAction)
                .disabled(session.status != .idle)

            Button(pauseResumeTitle, action: pauseOrResume)
                .disabled(session.status != .running && session.status != .paused)

            Button("Reset", action: reset)
                .disabled(session.status == .idle || session.status == .completed)

            Button("Finish", action: finish)
                .disabled(session.status != .running && session.status != .paused)
        }
        .controlSize(.large)
    }

    private var completionSummary: some View {
        VStack(spacing: 18) {
            Text("Task Complete")
                .font(.title2.weight(.semibold))

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                summaryRow("Task", value: session.name)
                summaryRow("Active Time", value: formattedDuration(session.accumulatedActiveDuration))
                summaryRow("Paused Time", value: formattedDuration(session.accumulatedPausedDuration))

                if let firstStartedAt = session.firstStartedAt {
                    summaryRow("Started", value: firstStartedAt.formatted(date: .omitted, time: .shortened))
                }

                if let completedAt = session.completedAt {
                    summaryRow("Finished", value: completedAt.formatted(date: .omitted, time: .shortened))
                }
            }

            Button("Start Another Task", action: startAnotherTask)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
    }

    private var pauseResumeTitle: String {
        session.status == .paused ? "Resume" : "Pause"
    }

    @ViewBuilder
    private func summaryRow(_ label: String, value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }

    private func start() {
        guard session.status == .idle else { return }

        let trimmedName = session.name.trimmingCharacters(in: .whitespacesAndNewlines)
        session.name = trimmedName.isEmpty ? "Untitled Task" : trimmedName
        timerEngine.start(&session)
    }

    private func pauseOrResume() {
        switch session.status {
        case .running:
            timerEngine.pause(&session)
        case .paused:
            timerEngine.resume(&session)
        case .idle, .completed:
            break
        }
    }

    private func reset() {
        timerEngine.reset(&session)
    }

    private func finish() {
        timerEngine.finish(&session)
    }

    private func startAnotherTask() {
        session = TaskSession(name: "")
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

#Preview {
    ContentView()
}
