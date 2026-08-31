import SwiftUI

struct SettingsView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        TabView {
            settingsForm
                .tabItem { Label("General", systemImage: "gearshape") }
            appearanceForm
                .tabItem { Label("Appearance", systemImage: "circle.lefthalf.filled") }
            timerForm
                .tabItem { Label("Timer", systemImage: "timer") }
            menuBarForm
                .tabItem { Label("Menu Bar", systemImage: "menubar.rectangle") }
            behaviorForm
                .tabItem { Label("Behavior", systemImage: "checkmark.circle") }
        }
        .frame(width: 500, height: 260)
        .preferredColorScheme(settings.appearance.colorScheme)
    }

    private var settingsForm: some View {
        Form {
            Toggle("Always on Top by Default", isOn: $settings.alwaysOnTopDefault)
            Text("Used only when no saved current Pin state exists.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }

    private var appearanceForm: some View {
        Form {
            Picker("Appearance", selection: $settings.appearance) {
                ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .formStyle(.grouped)
    }

    private var timerForm: some View {
        Form {
            Toggle("Show Seconds", isOn: $settings.showSeconds)
            Picker("Timer Format", selection: $settings.timerDisplayFormat) {
                ForEach(TimerDisplayFormat.allCases) { Text($0.title).tag($0) }
            }
            Text("This changes display only; recorded timing precision is unchanged.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }

    private var menuBarForm: some View {
        Form {
            Picker("Menu Bar Display", selection: $settings.menuBarDisplayMode) {
                ForEach(MenuBarDisplayMode.allCases) { Text($0.title).tag($0) }
            }
            Text("If hidden, open Settings from the application menu to show it again.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }

    private var behaviorForm: some View {
        Form {
            Toggle("Confirm Before Reset", isOn: $settings.confirmBeforeReset)
            Toggle("Confirm Before Delete History", isOn: $settings.confirmBeforeHistoryDelete)
        }
        .formStyle(.grouped)
    }
}
