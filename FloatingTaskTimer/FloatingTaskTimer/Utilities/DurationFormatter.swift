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
}
