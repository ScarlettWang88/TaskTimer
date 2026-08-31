import AppKit
import OSLog
import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
    private static let exportLogger = Logger(subsystem: "whywhy.FloatingTaskTimer", category: "HistoryExport")

    @Bindable var taskStore: TaskStore
    @Bindable var settings: SettingsStore
    @State private var selectedIDs = Set<UUID>()
    @State private var detailGroup: HistoryGroup?
    @State private var renameTargetID: UUID?
    @State private var renameText = ""
    @State private var deleteTargetID: UUID?
    @State private var errorMessage: String?
    @State private var exportSuccessMessage: String?
    @State private var isExporting = false
    @State private var isPresentingSavePanel = false
    @State private var preparedSavePanel: NSSavePanel?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("History").font(.title2.weight(.semibold))
                Spacer()
                Button(exportButtonTitle, action: exportSelected)
                    .disabled(selectedIDs.isEmpty || isExporting || isPresentingSavePanel)
            }

            if taskStore.historyGroups.isEmpty {
                ContentUnavailableView("No Completed Tasks", systemImage: "clock.arrow.circlepath",
                                       description: Text("Finished tasks will appear here."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(taskStore.historyGroups, selection: $selectedIDs) {
                    TableColumn("Task") { Text($0.name).lineLimit(1) }
                    TableColumn("Last Activity") { Text(completionDate($0.lastActivityAt)) }
                        .width(min: 105, ideal: 135)
                    TableColumn("Active") {
                        Text(settings.format($0.totalActiveDuration)).monospacedDigit()
                    }.width(min: 75, ideal: 90)
                    TableColumn("Paused") {
                        Text(settings.format($0.totalPausedDuration)).monospacedDigit()
                    }.width(min: 75, ideal: 90)
                    TableColumn("Sessions") { Text("\($0.sessionCount)") }.width(60)
                }
                .contextMenu(forSelectionType: UUID.self) { ids in
                    if let id = singleID(from: ids) {
                        Button("Continue Tracking") { perform { _ = try taskStore.continueHistoryGroup(id: id) } }
                        Button("Rename") { beginRename(id: id) }
                        Button("View Log") { openGroup(id: id) }
                        Divider()
                        Button("Delete", role: .destructive) { requestDelete(id) }
                    }
                } primaryAction: { ids in
                    guard let id = singleID(from: ids) else { return }
                    openGroup(id: id)
                }
            }
        }
        .sheet(item: $detailGroup) { group in
            NavigationStack {
                HistoryDetailView(group: group, settings: settings)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { detailGroup = nil }
                        }
                    }
            }.frame(minWidth: 720, minHeight: 520)
        }
        .sheet(isPresented: renameIsPresented) { renameSheet }
        .alert("Delete all history for this task?", isPresented: deleteIsPresented) {
            Button("Cancel", role: .cancel) { deleteTargetID = nil }
            Button("Delete All", role: .destructive, action: confirmDelete)
        } message: { Text(deleteMessage) }
        .alert("History Error", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "The History change could not be completed.") }
        .alert("Export Complete", isPresented: exportSuccessIsPresented) {
            Button("OK", role: .cancel) {}
        } message: { Text(exportSuccessMessage ?? "The selected History groups were exported.") }
        .onChange(of: taskStore.historyGroups.map(\.id)) { _, availableIDs in
            selectedIDs.formIntersection(availableIDs)
        }
        .onAppear(perform: prepareSavePanelIfNeeded)
        .preferredColorScheme(settings.appearance.colorScheme)
    }

    private var renameSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Rename History Task").font(.title2.weight(.semibold))
            TextField("Task name", text: $renameText).textFieldStyle(.roundedBorder).onSubmit(confirmRename)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { renameTargetID = nil }
                Button("Rename", action: confirmRename).keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 380)
    }

    private var renameIsPresented: Binding<Bool> { presenceBinding($renameTargetID) }
    private var deleteIsPresented: Binding<Bool> { presenceBinding($deleteTargetID) }
    private var errorIsPresented: Binding<Bool> { presenceBinding($errorMessage) }
    private var exportSuccessIsPresented: Binding<Bool> { presenceBinding($exportSuccessMessage) }

    private var exportButtonTitle: String {
        if isExporting { return "Exporting…" }
        if isPresentingSavePanel { return "Opening…" }
        return "Export Selected"
    }

    private func presenceBinding<Value>(_ binding: Binding<Value?>) -> Binding<Bool> {
        Binding(get: { binding.wrappedValue != nil }, set: { if !$0 { binding.wrappedValue = nil } })
    }

    private func singleID(from ids: Set<UUID>) -> UUID? { ids.count == 1 ? ids.first : nil }

    private func beginRename(id: UUID) {
        guard let group = taskStore.historyGroups.first(where: { $0.id == id }) else { return }
        renameText = group.name
        renameTargetID = id
    }

    private func openGroup(id: UUID) { detailGroup = taskStore.historyGroups.first { $0.id == id } }

    private func confirmRename() {
        guard let id = renameTargetID else { return }
        perform { try taskStore.renameHistoryGroup(id: id, name: renameText) }
        renameTargetID = nil
    }

    private func confirmDelete() {
        guard let id = deleteTargetID else { return }
        perform { try taskStore.deleteHistoryGroup(id: id) }
        selectedIDs.remove(id)
        deleteTargetID = nil
    }

    private func requestDelete(_ id: UUID) {
        if settings.confirmBeforeHistoryDelete {
            deleteTargetID = id
        } else {
            perform { try taskStore.deleteHistoryGroup(id: id) }
            selectedIDs.remove(id)
        }
    }

    private var deleteMessage: String {
        guard let id = deleteTargetID, let group = taskStore.historyGroups.first(where: { $0.id == id }) else {
            return "This action cannot be undone."
        }
        return "This will permanently delete \(group.sessionCount) recorded session(s) for \"\(group.name)\"."
    }

    private func exportSelected() {
        let startedAt = ProcessInfo.processInfo.systemUptime
        Self.exportLogger.notice("FTT_EXPORT_REG_01 button tapped elapsed_ms=0")
        let groupIDs = selectedIDs
        guard !groupIDs.isEmpty, !isExporting, !isPresentingSavePanel else { return }
        Self.exportLogger.notice("FTT_EXPORT_REG_02 selection validated groups=\(groupIDs.count) elapsed_ms=\(elapsedMS(since: startedAt))")

        Self.exportLogger.notice("FTT_EXPORT_REG_03 snapshot creation started elapsed_ms=\(elapsedMS(since: startedAt))")
        let snapshot = taskStore.exportSnapshot(groupIDs: groupIDs)
        Self.exportLogger.notice("FTT_EXPORT_REG_04 snapshot creation finished groups=\(snapshot.groups.count) sessions=\(snapshot.sessionCount) elapsed_ms=\(elapsedMS(since: startedAt))")
        guard !snapshot.groups.isEmpty else { return }

        isPresentingSavePanel = true
        DispatchQueue.main.async {
            presentSavePanel(snapshot: snapshot, startedAt: startedAt)
        }
    }

    private func presentSavePanel(snapshot: HistoryExportSnapshot, startedAt: TimeInterval) {
        let panel: NSSavePanel
        if let preparedSavePanel {
            panel = preparedSavePanel
            Self.exportLogger.notice("FTT_EXPORT_REG_04B save panel cache hit elapsed_ms=\(elapsedMS(since: startedAt))")
        } else {
            Self.exportLogger.notice("FTT_EXPORT_REG_04A save panel initialization started elapsed_ms=\(elapsedMS(since: startedAt))")
            panel = makeSavePanel()
            preparedSavePanel = panel
            Self.exportLogger.notice("FTT_EXPORT_REG_04B save panel initialization finished elapsed_ms=\(elapsedMS(since: startedAt))")
        }
        panel.nameFieldStringValue = "FloatingTaskTimer History.xlsx"

        let completion: (NSApplication.ModalResponse) -> Void = { response in
            isPresentingSavePanel = false
            Self.exportLogger.notice("FTT_EXPORT_REG_06 save panel completion response=\(response.rawValue) elapsed_ms=\(elapsedMS(since: startedAt))")
            guard response == .OK, let url = panel.url else { return }
            isExporting = true
            Task {
                do {
                    try await Task.detached(priority: .userInitiated) {
                        try ExportService().exportXLSX(snapshot: snapshot, to: url, startedAt: startedAt)
                    }.value
                    isExporting = false
                    exportSuccessMessage = "Exported \(snapshot.groups.count) History task group(s)."
                    Self.exportLogger.notice("FTT_EXPORT_REG_10 UI completion success elapsed_ms=\(elapsedMS(since: startedAt))")
                } catch {
                    isExporting = false
                    errorMessage = error.localizedDescription
                    Self.exportLogger.error("FTT_EXPORT_REG_10 UI completion failure elapsed_ms=\(elapsedMS(since: startedAt)) error=\(error.localizedDescription, privacy: .public)")
                }
            }
        }

        if let hostWindow = NSApp.keyWindow
            ?? NSApp.mainWindow
            ?? NSApp.windows.first(where: { $0.isVisible && $0 is NSPanel }) {
            Self.exportLogger.notice("FTT_EXPORT_REG_05 save panel begin sheet elapsed_ms=\(elapsedMS(since: startedAt))")
            panel.beginSheetModal(for: hostWindow, completionHandler: completion)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            Self.exportLogger.notice("FTT_EXPORT_REG_05 save panel begin application modal elapsed_ms=\(elapsedMS(since: startedAt))")
            panel.begin(completionHandler: completion)
        }
    }

    private func prepareSavePanelIfNeeded() {
        guard preparedSavePanel == nil else { return }
        DispatchQueue.main.async {
            guard preparedSavePanel == nil, !isPresentingSavePanel else { return }
            preparedSavePanel = makeSavePanel()
            Self.exportLogger.notice("FTT_EXPORT_PREWARM save panel ready")
        }
    }

    private func makeSavePanel() -> NSSavePanel {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "xlsx")!]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        return panel
    }

    private func perform(_ operation: () throws -> Void) {
        do { try operation() } catch { errorMessage = error.localizedDescription }
    }

    private func completionDate(_ date: Date?) -> String {
        date?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown date"
    }

    private func elapsedMS(since startedAt: TimeInterval) -> Double {
        (ProcessInfo.processInfo.systemUptime - startedAt) * 1_000
    }
}
