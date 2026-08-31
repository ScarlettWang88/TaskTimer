import OSLog

enum AppLogger {
    nonisolated private static let subsystem = Bundle.main.bundleIdentifier ?? "whywhy.FloatingTaskTimer"

    nonisolated static let app = Logger(subsystem: subsystem, category: "app")
    nonisolated static let timer = Logger(subsystem: subsystem, category: "timer")
    nonisolated static let persistence = Logger(subsystem: subsystem, category: "persistence")
    nonisolated static let migration = Logger(subsystem: subsystem, category: "migration")
    nonisolated static let history = Logger(subsystem: subsystem, category: "history")
    nonisolated static let export = Logger(subsystem: subsystem, category: "export")
    nonisolated static let window = Logger(subsystem: subsystem, category: "window")
    nonisolated static let settings = Logger(subsystem: subsystem, category: "settings")
}
