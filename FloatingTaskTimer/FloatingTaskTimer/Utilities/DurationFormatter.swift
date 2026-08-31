import Foundation

enum DurationFormatter {
    nonisolated static func clock(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        return String(
            format: "%02d:%02d:%02d",
            totalSeconds / 3_600,
            (totalSeconds % 3_600) / 60,
            totalSeconds % 60
        )
    }

    nonisolated static func compact(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    nonisolated static func display(
        _ duration: TimeInterval,
        format: TimerDisplayFormat,
        showSeconds: Bool
    ) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        let hours = totalSeconds / 3_600
        let totalMinutes = totalSeconds / 60
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        switch (format, showSeconds) {
        case (.hoursMinutesSeconds, true):
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        case (.hoursMinutesSeconds, false):
            return String(format: "%02d:%02d", hours, minutes)
        case (.minutesSeconds, true):
            return String(format: "%02d:%02d", totalMinutes, seconds)
        case (.minutesSeconds, false):
            return String(format: "%02d", totalMinutes)
        }
    }

    nonisolated static func menuBar(_ duration: TimeInterval, showSeconds: Bool) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        if showSeconds {
            return hours > 0
                ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
                : String(format: "%02d:%02d", minutes, seconds)
        }
        return String(format: "%d:%02d", hours, minutes)
    }
}
