import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var windowManager: WindowManager
    @State private var session = TaskSession(name: "")
    @State private var hasRestoredSession = false
    @State private var persistenceErrorMessage: String?

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
        .task(restoreSession)
        .alert("Persistence Error", isPresented: persistenceErrorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(persistenceErrorMessage ?? "The task could not be saved.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Task")
                    .font(.headline)

                Spacer()

                Button {
                    windowManager.setPinned(!windowManager.isPinned)
                } label: {
                    Image(systemName: windowManager.isPinned ? "pin.fill" : "pin")
                }
                .buttonStyle(.plain)
                .help(windowManager.isPinned ? "Disable Always on Top" : "Keep Timer on Top")
                .accessibilityLabel(
                    windowManager.isPinned ? "Disable Always on Top" : "Keep Timer on Top"
                )
            }

            TextField("What are you working on?", text: $session.name)
                .textFieldStyle(.roundedBorder)
                .disabled(session.status != .idle || !hasRestoredSession)
                .onSubmit(start)
                .onChange(of: session.name) {
                    guard hasRestoredSession, session.status == .idle else { return }
                    persistSession()
                }
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
                .disabled(session.status != .idle || !hasRestoredSession)

            Button(pauseResumeTitle, action: pauseOrResume)
                .disabled(
                    !hasRestoredSession
                        || (session.status != .running && session.status != .paused)
                )

            Button("Reset", action: reset)
                .disabled(
                    !hasRestoredSession
                        || session.status == .idle
                        || session.status == .completed
                )

            Button("Finish", action: finish)
                .disabled(
                    !hasRestoredSession
                        || (session.status != .running && session.status != .paused)
                )
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

    private var persistenceErrorIsPresented: Binding<Bool> {
        Binding(
            get: { persistenceErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    persistenceErrorMessage = nil
                }
            }
        )
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
        if timerEngine.start(&session) {
            persistSession()
        }
    }

    private func pauseOrResume() {
        switch session.status {
        case .running:
            if timerEngine.pause(&session) {
                persistSession()
            }
        case .paused:
            if timerEngine.resume(&session) {
                persistSession()
            }
        case .idle, .completed:
            break
        }
    }

    private func reset() {
        if timerEngine.reset(&session) {
            persistSession()
        }
    }

    private func finish() {
        if timerEngine.finish(&session) {
            persistSession()
        }
    }

    private func startAnotherTask() {
        session = TaskSession(name: "")
        persistSession()
    }

    private func restoreSession() {
        guard !hasRestoredSession else { return }

        do {
            let store = TaskSessionStore(modelContext: modelContext)
            if let restoredSession = try store.load() {
                session = restoredSession
            } else {
                try store.save(session)
            }
        } catch {
            persistenceErrorMessage = "The saved task could not be restored. Changes may not survive relaunch."
        }

        hasRestoredSession = true
    }

    private func persistSession() {
        do {
            try TaskSessionStore(modelContext: modelContext).save(session)
        } catch {
            persistenceErrorMessage = "The current task could not be saved. Changes may not survive relaunch."
        }
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
    ContentView(windowManager: WindowManager())
        .modelContainer(for: PersistedTaskSession.self, inMemory: true)
}
