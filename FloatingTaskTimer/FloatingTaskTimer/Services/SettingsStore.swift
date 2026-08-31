import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class SettingsStore {
    enum Keys {
        static let appearance = "settings.appearance"
        static let showSeconds = "settings.showSeconds"
        static let timerDisplayFormat = "settings.timerDisplayFormat"
        static let menuBarDisplayMode = "settings.menuBarDisplayMode"
        static let confirmBeforeReset = "settings.confirmBeforeReset"
        static let confirmBeforeHistoryDelete = "settings.confirmBeforeHistoryDelete"
        static let alwaysOnTopDefault = "settings.alwaysOnTopDefault"
        static let currentPin = "isTimerPinned"
        static let timerWindowMode = "window.timerMode"
        static let miniWindowFrame = "window.miniFrame"
        static let expandedWindowFrame = "window.expandedFrame"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var appearance: AppAppearance { didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) } }
    var showSeconds: Bool { didSet { defaults.set(showSeconds, forKey: Keys.showSeconds) } }
    var timerDisplayFormat: TimerDisplayFormat {
        didSet { defaults.set(timerDisplayFormat.rawValue, forKey: Keys.timerDisplayFormat) }
    }
    var menuBarDisplayMode: MenuBarDisplayMode {
        didSet { defaults.set(menuBarDisplayMode.rawValue, forKey: Keys.menuBarDisplayMode) }
    }
    var confirmBeforeReset: Bool {
        didSet { defaults.set(confirmBeforeReset, forKey: Keys.confirmBeforeReset) }
    }
    var confirmBeforeHistoryDelete: Bool {
        didSet { defaults.set(confirmBeforeHistoryDelete, forKey: Keys.confirmBeforeHistoryDelete) }
    }
    var alwaysOnTopDefault: Bool {
        didSet { defaults.set(alwaysOnTopDefault, forKey: Keys.alwaysOnTopDefault) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.appearance: AppAppearance.system.rawValue,
            Keys.showSeconds: true,
            Keys.timerDisplayFormat: TimerDisplayFormat.hoursMinutesSeconds.rawValue,
            Keys.menuBarDisplayMode: MenuBarDisplayMode.iconAndDuration.rawValue,
            Keys.confirmBeforeReset: true,
            Keys.confirmBeforeHistoryDelete: true,
            Keys.alwaysOnTopDefault: false,
        ])

        let storedAppearance = defaults.string(forKey: Keys.appearance) ?? ""
        appearance = AppAppearance(rawValue: storedAppearance) ?? .system
        if AppAppearance(rawValue: storedAppearance) == nil {
            AppLogger.settings.notice("Invalid appearance preference; using system")
        }
        showSeconds = defaults.bool(forKey: Keys.showSeconds)
        let storedTimerFormat = defaults.string(forKey: Keys.timerDisplayFormat) ?? ""
        timerDisplayFormat = TimerDisplayFormat(rawValue: storedTimerFormat) ?? .hoursMinutesSeconds
        if TimerDisplayFormat(rawValue: storedTimerFormat) == nil {
            AppLogger.settings.notice("Invalid timer format preference; using HH:MM:SS")
        }
        let storedMenuMode = defaults.string(forKey: Keys.menuBarDisplayMode) ?? ""
        menuBarDisplayMode = MenuBarDisplayMode(rawValue: storedMenuMode) ?? .iconAndDuration
        if MenuBarDisplayMode(rawValue: storedMenuMode) == nil {
            AppLogger.settings.notice("Invalid menu bar preference; using icon and duration")
        }
        confirmBeforeReset = defaults.bool(forKey: Keys.confirmBeforeReset)
        confirmBeforeHistoryDelete = defaults.bool(forKey: Keys.confirmBeforeHistoryDelete)
        alwaysOnTopDefault = defaults.bool(forKey: Keys.alwaysOnTopDefault)
    }

    func format(_ duration: TimeInterval) -> String {
        DurationFormatter.display(
            duration,
            format: timerDisplayFormat,
            showSeconds: showSeconds
        )
    }

    func formatMenuBar(_ duration: TimeInterval) -> String {
        DurationFormatter.menuBar(duration, showSeconds: showSeconds)
    }
}
