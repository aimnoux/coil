import SwiftUI

/// Keys and option types for user preferences stored with `@AppStorage`.
enum SettingsKey {
    static let theme = "theme"
    static let firstWeekday = "firstWeekday"
    static let todayOnRight = "todayOnRight"
    static let longPressToToggle = "longPressToToggle"
    static let skipEnabled = "skipEnabled"
    static let showQuestionMarks = "showQuestionMarks"
    static let sortOrder = "sortOrder"
    static let sortAscending = "sortAscending"
    static let showArchived = "showArchived"
    static let hideCompleted = "hideCompleted"
    static let snoozeMinutes = "snoozeMinutes"
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

enum HabitSortOrder: String, CaseIterable, Identifiable {
    case manual, name, color, score, status

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .manual: "Manual"
        case .name: "Name"
        case .color: "Color"
        case .score: "Score"
        case .status: "Status"
        }
    }

    var systemImage: String {
        switch self {
        case .manual: "hand.draw"
        case .name: "textformat"
        case .color: "paintpalette"
        case .score: "chart.line.uptrend.xyaxis"
        case .status: "checkmark.circle"
        }
    }
}

/// First day of the week: 0 follows the system locale, otherwise 1 = Sunday … 7 = Saturday.
enum FirstWeekday {
    static func resolve(_ stored: Int) -> Int {
        stored == 0 ? Calendar.current.firstWeekday : stored
    }
}
