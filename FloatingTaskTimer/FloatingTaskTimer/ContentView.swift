import Observation
import SwiftUI

enum MainPage: String, CaseIterable, Identifiable {
    case tasks = "Tasks"
    case history = "History"

    var id: Self { self }
}

@MainActor
@Observable
final class AppNavigation {
    var selectedPage = MainPage.tasks
}

struct ContentView: View {
    @Bindable var taskStore: TaskStore
    @Bindable var windowManager: WindowManager
    @Bindable var navigation: AppNavigation
    @Bindable var settings: SettingsStore
    @State private var newTaskName = ""
    @State private var isCreatingTask = false
    @State private var persistenceErrorMessage: String?
    @State private var resetTargetID: UUID?

    var body: some View {
        Group {
            if windowManager.mode == .mini {
                MiniTimerView(
                    taskStore: taskStore,
                    windowManager: windowManager,
                    settings: settings
                )
            } else {
                expandedContent
            }
        }
        .preferredColorScheme(settings.appearance.colorScheme)
    }

    private var expandedContent: some View {
        VStack(spacing: 20) {
            titleBar

            if navigation.selectedPage == .history {
                HistoryView(taskStore: taskStore, settings: settings)
            } else {
                if let activeTask = taskStore.activeTask {
                    currentTask(taskStore: taskStore, task: activeTask)

                    if !taskStore.otherTasks.isEmpty {
                        Divider()
                        otherTasks(taskStore: taskStore)
                    }
                } else {
                    emptyTaskState
                }

                if let completed = taskStore.lastCompletedTask {
                    Divider()
                    completionSummary(completed)
                }
            }
        }
        .padding(24)
        .frame(
            minWidth: 560,
            idealWidth: 620,
            maxWidth: .infinity,
            minHeight: 520,
            maxHeight: .infinity,
            alignment: .top
        )
        .background(.background)
        .sheet(isPresented: $isCreatingTask) {
            newTaskSheet
        }
        .alert("Persistence Error", isPresented: persistenceErrorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(persistenceErrorMessage ?? "The tasks could not be saved.")
        }
        .alert("Reset timer?", isPresented: resetIsPresented) {
            Button("Cancel", role: .cancel) { resetTargetID = nil }
            Button("Reset", role: .destructive, action: confirmReset)
        } message: {
            Text("The recorded duration for this unfinished task will return to zero.")
        }
        .onAppear {
            DispatchQueue.main.async {
                windowManager.fitExpandedWindow(taskCount: taskStore.tasks.count)
            }
        }
        .onChange(of: taskStore.tasks.count) { _, taskCount in
            windowManager.fitExpandedWindow(taskCount: taskCount)
        }
    }

    private var titleBar: some View {
        HStack {
            Picker("Page", selection: $navigation.selectedPage) {
                ForEach(MainPage.allCases) { page in
                    Text(page.rawValue).tag(page)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)

            Spacer()

            if navigation.selectedPage == .tasks {
                Button {
                    newTaskName = ""
                    isCreatingTask = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("New Task")
                .accessibilityLabel("New Task")
            }

            Button {
                windowManager.showMiniMode()
            } label: {
                Image(systemName: "rectangle.compress.vertical")
            }
            .buttonStyle(.plain)
            .help("Enter Mini Timer")
            .accessibilityLabel("Enter Mini Timer")

            Button {
                windowManager.toggleFullScreen()
            } label: {
                Image(systemName: windowManager.isFullScreen
                    ? "arrow.down.right.and.arrow.up.left"
                    : "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.plain)
            .help(windowManager.isFullScreen ? "Exit Full Screen" : "Enter Full Screen")
            .accessibilityLabel(
                windowManager.isFullScreen ? "Exit Full Screen" : "Enter Full Screen"
            )

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
    }

    private func currentTask(taskStore: TaskStore, task: TaskSession) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("CURRENT")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button(role: .destructive) {
                    perform { try taskStore.delete(taskID: task.id) }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete Current Task")
                .accessibilityLabel("Delete Current Task")
            }

            TextField("What are you working on?", text: taskNameBinding(taskStore, task.id))
                .textFieldStyle(.roundedBorder)
                .disabled(task.status != .idle)
                .onSubmit { perform { try taskStore.startOrResume(taskID: task.id) } }
                .accessibilityLabel("Current task name")

            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Text(settings.format(taskStore.duration(for: task)))
                    .font(.system(size: 52, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Elapsed time")
                    .accessibilityValue(settings.format(taskStore.duration(for: task)))
            }

            HStack(spacing: 12) {
                Button("Start") {
                    perform { try taskStore.startOrResume(taskID: task.id) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(task.status != .idle)

                Button(task.status == .paused ? "Resume" : "Pause") {
                    if task.status == .paused {
                        perform { try taskStore.startOrResume(taskID: task.id) }
                    } else {
                        perform { try taskStore.pause(taskID: task.id) }
                    }
                }
                .disabled(task.status != .running && task.status != .paused)

                Button("Reset") {
                    requestReset(task.id)
                }
                .disabled(task.status == .idle)

                Button("Finish") {
                    perform { try taskStore.finish(taskID: task.id) }
                }
                .disabled(task.status != .running && task.status != .paused)
            }
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
    }

    private func otherTasks(taskStore: TaskStore) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OTHER TASKS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TimelineView(.periodic(from: .now, by: 1)) { _ in
                VStack(spacing: 4) {
                    ForEach(taskStore.otherTasks) { task in
                        taskRow(taskStore: taskStore, task: task)
                    }
                }
            }
        }
    }

    private var emptyTaskState: some View {
        VStack(spacing: 12) {
            Text("No Unfinished Tasks")
                .font(.title3.weight(.semibold))
            Button("New Task") {
                newTaskName = ""
                isCreatingTask = true
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }

    private func taskRow(taskStore: TaskStore, task: TaskSession) -> some View {
        HStack(spacing: 10) {
            Button {
                perform { try taskStore.selectTask(id: task.id) }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.name.isEmpty ? "Untitled Task" : task.name)
                            .lineLimit(1)
                        Text(statusLabel(task.status))
                            .font(.caption)
                            .foregroundStyle(statusColor(task.status))
                    }

                    Spacer()

                    Text(settings.format(taskStore.duration(for: task)))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
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

            Button {
                requestReset(task.id)
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .disabled(task.status == .idle)
            .help("Reset Task")

            Button {
                perform { try taskStore.finish(taskID: task.id) }
            } label: {
                Image(systemName: "checkmark")
            }
            .buttonStyle(.borderless)
            .disabled(task.status == .idle)
            .help("Finish Task")

            Button(role: .destructive) {
                perform { try taskStore.delete(taskID: task.id) }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete Task")
        }
        .padding(.vertical, 5)
    }

    private func completionSummary(_ session: TaskSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(session.name)
                    .lineLimit(1)
            }
            Spacer()
            Text(settings.format(session.accumulatedActiveDuration))
                .monospacedDigit()
        }
    }

    private var newTaskSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("New Task")
                .font(.title2.weight(.semibold))

            TextField("Task name", text: $newTaskName)
                .textFieldStyle(.roundedBorder)
                .onSubmit { createTask(startImmediately: true) }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    isCreatingTask = false
                }
                Button("Create") {
                    createTask(startImmediately: false)
                }
                Button("Create & Start") {
                    createTask(startImmediately: true)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 380)
    }

    private var persistenceErrorIsPresented: Binding<Bool> {
        Binding(
            get: { persistenceErrorMessage != nil },
            set: { if !$0 { persistenceErrorMessage = nil } }
        )
    }

    private var resetIsPresented: Binding<Bool> {
        Binding(
            get: { resetTargetID != nil },
            set: { if !$0 { resetTargetID = nil } }
        )
    }

    private func requestReset(_ taskID: UUID) {
        if settings.confirmBeforeReset {
            resetTargetID = taskID
        } else {
            perform { try taskStore.reset(taskID: taskID) }
        }
    }

    private func confirmReset() {
        guard let taskID = resetTargetID else { return }
        perform { try taskStore.reset(taskID: taskID) }
        resetTargetID = nil
    }

    private func taskNameBinding(_ store: TaskStore, _ taskID: UUID) -> Binding<String> {
        Binding(
            get: { store.tasks.first(where: { $0.id == taskID })?.name ?? "" },
            set: { newValue in perform { try store.rename(taskID: taskID, name: newValue) } }
        )
    }

    private func createTask(startImmediately: Bool) {
        perform { try taskStore.createTask(name: newTaskName, startImmediately: startImmediately) }
        isCreatingTask = false
        newTaskName = ""
    }

    private func perform(_ operation: () throws -> Void) {
        do {
            try operation()
        } catch {
            persistenceErrorMessage = "The task change could not be saved."
        }
    }

    private func statusLabel(_ status: TaskStatus) -> String {
        switch status {
        case .idle: "Idle"
        case .running: "Running"
        case .paused: "Paused"
        case .completed: "Completed"
        }
    }

    private func statusColor(_ status: TaskStatus) -> Color {
        status == .running ? .green : .secondary
    }

}
