import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: String { rawValue.capitalized }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum TimerDisplayFormat: String, CaseIterable, Identifiable {
    case hoursMinutesSeconds
    case minutesSeconds

    var id: Self { self }

    var title: String {
        switch self {
        case .hoursMinutesSeconds: "HH:MM:SS"
        case .minutesSeconds: "MM:SS"
        }
    }
}

enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
    case iconAndDuration
    case iconOnly
    case hidden

    var id: Self { self }

    var title: String {
        switch self {
        case .iconAndDuration: "Icon + Duration"
        case .iconOnly: "Icon Only"
        case .hidden: "Hidden"
        }
    }
}
