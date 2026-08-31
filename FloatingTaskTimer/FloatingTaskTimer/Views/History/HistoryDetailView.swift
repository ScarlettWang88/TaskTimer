import SwiftUI

struct HistoryDetailView: View {
    let group: HistoryGroup
    @Bindable var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Form {
                LabeledContent("Task", value: group.name)
                LabeledContent("Total Active Time", value: settings.format(group.totalActiveDuration))
                LabeledContent("Total Paused Time", value: settings.format(group.totalPausedDuration))
                LabeledContent("Sessions", value: "\(group.sessionCount)")
            }
            .formStyle(.grouped)
            .frame(height: 190)

            Text("Session Log").font(.headline)

            Table(group.sessions) {
                TableColumn("#") { session in
                    Text("\((group.sessions.firstIndex(where: { $0.id == session.id }) ?? 0) + 1)")
                }.width(28)
                TableColumn("Date") { session in Text(date(session.completedAt)) }
                TableColumn("Start") { session in Text(time(session.firstStartedAt)) }
                TableColumn("Finish") { session in Text(time(session.completedAt)) }
                TableColumn("Active") { session in
                    Text(settings.format(session.accumulatedActiveDuration)).monospacedDigit()
                }
                TableColumn("Paused") { session in
                    Text(settings.format(session.accumulatedPausedDuration)).monospacedDigit()
                }
                TableColumn("Status") { session in Text(session.status.rawValue.capitalized) }
            }

            DisclosureGroup("Session identifiers") {
                ForEach(Array(group.sessions.enumerated()), id: \.element.id) { offset, session in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Session \(offset + 1): \(session.id.uuidString)")
                        if let parent = session.continuedFromSessionID {
                            Text("Continued from: \(parent.uuidString)")
                        }
                    }
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                }
            }
        }
        .padding()
        .navigationTitle(group.name)
    }

    private func date(_ value: Date?) -> String {
        value?.formatted(date: .abbreviated, time: .omitted) ?? "Unavailable"
    }

    private func time(_ value: Date?) -> String {
        value?.formatted(date: .omitted, time: .shortened) ?? "Unavailable"
    }
}
