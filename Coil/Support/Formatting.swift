import SwiftUI

enum Formatting {
    /// Compact number for checkmark cells: 3, 2.5, 1.2k, 15k.
    static func compact(_ value: Double) -> String {
        let absValue = abs(value)
        if absValue >= 1_000_000 {
            return trimmed(value / 1_000_000) + "M"
        }
        if absValue >= 1_000 {
            return trimmed(value / 1_000) + "k"
        }
        return trimmed(value)
    }

    /// Number with up to two decimals and no trailing zeros.
    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private static func trimmed(_ value: Double) -> String {
        if abs(value) >= 100 || value == value.rounded() {
            return value.formatted(.number.precision(.fractionLength(0)).grouping(.never))
        }
        return value.formatted(.number.precision(.fractionLength(0...1)).grouping(.never))
    }

    static func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

    static func signedPercent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always(includingZero: false)))
    }

    static func time(hour: Int, minute: Int) -> String {
        let date = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    static func shortWeekday(_ weekday: Int) -> String {
        Calendar.current.shortWeekdaySymbols[weekday - 1]
    }

    static func veryShortWeekday(_ weekday: Int) -> String {
        Calendar.current.veryShortWeekdaySymbols[weekday - 1]
    }

    static func dayAndMonth(_ day: Day) -> String {
        day.date().formatted(.dateTime.day().month(.abbreviated))
    }

    static func fullDate(_ day: Day) -> String {
        day.date().formatted(date: .abbreviated, time: .omitted)
    }

    static func frequency(_ frequency: Frequency) -> String {
        switch frequency.preset {
        case .everyDay:
            String(localized: "Every day")
        case .timesPerWeek(1):
            String(localized: "Once a week")
        case .timesPerWeek(let n):
            String(localized: "\(n) times per week")
        case .timesPerMonth(1):
            String(localized: "Once a month")
        case .timesPerMonth(let n):
            String(localized: "\(n) times per month")
        case .everyNDays(let n):
            String(localized: "Every \(n) days")
        case .custom(let n, let d):
            String(localized: "\(n) times in \(d) days")
        }
    }

    /// "Every day", "Weekly", "Monthly" or "Every 3 days" — the period of a measurable target.
    static func targetPeriod(_ frequency: Frequency) -> String {
        switch frequency.denominator {
        case 1: String(localized: "per day")
        case 7: String(localized: "per week")
        case 30: String(localized: "per month")
        default: String(localized: "every \(frequency.denominator) days")
        }
    }

    static func target(for habit: Habit) -> String {
        let comparison = habit.targetType == .atLeast
            ? String(localized: "At least")
            : String(localized: "At most")
        let unit = habit.unit.isEmpty ? "" : " \(habit.unit)"
        return "\(comparison) \(number(habit.targetValue))\(unit) \(targetPeriod(habit.frequency))"
    }

    static func reminder(for habit: Habit) -> String? {
        guard habit.reminderEnabled else { return nil }
        let time = time(hour: habit.reminderHour, minute: habit.reminderMinute)
        if habit.reminderDays == 0b111_1111 { return time }
        let firstWeekday = Calendar.current.firstWeekday
        let days = (0..<7)
            .map { (firstWeekday - 1 + $0) % 7 + 1 }
            .filter(habit.remindsOn(weekday:))
            .map(shortWeekday)
            .joined(separator: ", ")
        return "\(time) · \(days)"
    }
}
