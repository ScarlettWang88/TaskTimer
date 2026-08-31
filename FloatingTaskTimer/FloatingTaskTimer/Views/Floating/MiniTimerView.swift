import SwiftUI

struct MiniTimerView: View {
    @Bindable var taskStore: TaskStore
    @Bindable var windowManager: WindowManager
    @Bindable var settings: SettingsStore

    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(displayedTask?.name.nilIfEmpty ?? "No active task")
                    .font(.headline)
                    .lineLimit(1)

                Spacer(minLength: 4)

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

            HStack(spacing: 10) {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(formattedDuration)
                        .font(.system(size: 30, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .accessibilityLabel("Elapsed time")
                        .accessibilityValue(formattedDuration)
                }

                Spacer(minLength: 4)

                if taskStore.runningTasks.count > 1, let displayedTask {
                    taskSwitchButton(systemName: "chevron.left", offset: -1, taskID: displayedTask.id)
                    taskSwitchButton(systemName: "chevron.right", offset: 1, taskID: displayedTask.id)
                }

                if let displayedTask {
                    Button {
                        perform {
                            if displayedTask.status == .running {
                                try taskStore.pause(taskID: displayedTask.id)
                            } else {
                                try taskStore.startOrResume(taskID: displayedTask.id)
                            }
                        }
                    } label: {
                        Image(systemName: displayedTask.status == .running ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(.plain)
                    .help(displayedTask.status == .running ? "Pause Task" : "Resume Task")
                    .accessibilityLabel(displayedTask.status == .running ? "Pause Task" : "Resume Task")
                }

                Button {
                    windowManager.showExpandedMode()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.plain)
                .help("Open Full Timer")
                .accessibilityLabel("Open Full Timer")
            }
        }
        .padding(12)
        .frame(width: WindowManager.miniContentSize.width, height: WindowManager.miniContentSize.height)
        .alert("Task Error", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "The task change could not be saved.")
        }
    }

    private var displayedTask: TaskSession? {
        taskStore.miniTask
    }

    private var formattedDuration: String {
        guard let displayedTask else { return settings.format(0) }
        return settings.format(taskStore.duration(for: displayedTask))
    }

    private func taskSwitchButton(systemName: String, offset: Int, taskID: UUID) -> some View {
        Button {
            perform { try taskStore.selectAdjacentRunningTask(from: taskID, offset: offset) }
        } label: {
            Image(systemName: systemName)
        }
        .buttonStyle(.plain)
        .help(offset < 0 ? "Previous Running Task" : "Next Running Task")
        .accessibilityLabel(offset < 0 ? "Previous Running Task" : "Next Running Task")
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func perform(_ operation: () throws -> Void) {
        do {
            try operation()
        } catch {
            errorMessage = "The task change could not be saved."
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
