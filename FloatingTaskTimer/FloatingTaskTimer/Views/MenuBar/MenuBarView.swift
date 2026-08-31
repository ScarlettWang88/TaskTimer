import AppKit
import Combine
import SwiftUI

struct MenuBarLabelView: View {
    @Bindable var taskStore: TaskStore
    @Bindable var settings: SettingsStore
    @State private var refreshDate = Date()
    private let refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let _ = refreshDate
        Group {
            if settings.menuBarDisplayMode == .iconAndDuration,
               let task = taskStore.menuBarTask,
               task.status == .running {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                    Text(settings.formatMenuBar(taskStore.duration(for: task)))
                        .monospacedDigit()
                }
                .accessibilityLabel("Running timer")
                .accessibilityValue(settings.format(taskStore.duration(for: task)))
            } else {
                Image(systemName: "timer")
                    .accessibilityLabel("Floating Task Timer")
            }
        }
        .onReceive(refreshTimer) { refreshDate = $0 }
    }
}

struct MenuBarView: View {
    @Environment(\.openSettings) private var openSettings

    @Bindable var taskStore: TaskStore
    let windowManager: WindowManager
    @Bindable var settings: SettingsStore

    @State private var newTaskName = ""
    @State private var errorMessage: String?
    @State private var refreshDate = Date()
    private let refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let _ = refreshDate
        VStack(alignment: .leading, spacing: 12) {
            if let current = taskStore.menuBarTask {
                currentTask(current)
                otherTasks(excluding: current.id)
            } else {
                Text("No unfinished tasks")
                    .foregroundStyle(.secondary)
            }

            Divider()
            quickCreate
            Divider()

            Button("Open Floating Timer") { windowManager.showWindowOnCurrentSpace() }
            Button("History") { windowManager.showHistory() }
            Button("Settings…") {
                openSettings()
                windowManager.bringSettingsToCurrentSpace()
            }
            Divider()
            Button("Quit Floating Task Timer") { NSApp.terminate(nil) }
        }
        .padding(14)
        .frame(width: 310)
        .onReceive(refreshTimer) { refreshDate = $0 }
        .alert("Task Error", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "The task change could not be saved.")
        }
        .preferredColorScheme(settings.appearance.colorScheme)
    }

    private func currentTask(_ task: TaskSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CURRENT TASK")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(task.name.isEmpty ? "Untitled Task" : task.name)
                .font(.headline)
                .lineLimit(1)
            Text(settings.format(taskStore.duration(for: task)))
                .font(.title2.monospacedDigit())

            HStack {
                Button(task.status == .running ? "Pause" : task.status == .paused ? "Resume" : "Start") {
                    if task.status == .running {
                        perform { try taskStore.pause(taskID: task.id) }
                    } else {
                        perform { try taskStore.startOrResume(taskID: task.id) }
                    }
                }
                Button("Finish") { perform { try taskStore.finish(taskID: task.id) } }
                    .disabled(task.status == .idle)
            }
        }
    }

    @ViewBuilder
    private func otherTasks(excluding currentID: UUID) -> some View {
        let others = taskStore.tasks.filter { $0.id != currentID }
        if !others.isEmpty {
            Divider()
            Text("OTHER TASKS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(others) { task in
                        HStack {
                            Button {
                                perform { try taskStore.selectTask(id: task.id) }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.name.isEmpty ? "Untitled Task" : task.name).lineLimit(1)
                                    HStack(spacing: 6) {
                                        Text(statusTitle(task.status))
                                        Text(settings.format(taskStore.duration(for: task)))
                                            .monospacedDigit()
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Button {
                                if task.status == .running {
                                    perform { try taskStore.pause(taskID: task.id) }
                                } else {
                                    perform { try taskStore.startOrResume(taskID: task.id) }
                                }
                            } label: {
                                Image(systemName: task.status == .running ? "pause.fill" : "play.fill")
                            }
                            .buttonStyle(.borderless)
                            .help(task.status == .running ? "Pause Task" : task.status == .paused ? "Resume Task" : "Start Task")
                            .accessibilityLabel(task.status == .running ? "Pause Task" : task.status == .paused ? "Resume Task" : "Start Task")
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: min(CGFloat(others.count) * 48, 170))
        }
    }

    private func statusTitle(_ status: TaskStatus) -> String {
        switch status {
        case .idle: "Idle"
        case .running: "Running"
        case .paused: "Paused"
        case .completed: "Completed"
        }
    }

    private var quickCreate: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NEW TASK")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack {
                TextField("Task name", text: $newTaskName)
                    .onSubmit(createAndStart)
                Button("Start", action: createAndStart)
            }
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func createAndStart() {
        perform { try taskStore.createTask(name: newTaskName, startImmediately: true) }
        if errorMessage == nil { newTaskName = "" }
    }

    private func perform(_ operation: () throws -> Void) {
        do { try operation() } catch { errorMessage = "The task change could not be saved." }
    }
}
