import Foundation

/// A calendar day independent of time zone: the number of days since 2001-01-01.
///
/// Entries are keyed by `Day` so that a checkmark made on "Tuesday" stays on Tuesday
/// even if the user travels or the device time zone changes.
nonisolated struct Day: Hashable, Comparable, Strideable, Codable, Sendable {
    let index: Int

    init(index: Int) {
        self.index = index
    }

    init(year: Int, month: Int, day: Int) {
        let date = Day.utc.date(from: DateComponents(year: year, month: month, day: day))!
        index = Int((date.timeIntervalSinceReferenceDate / 86_400).rounded(.down))
    }

    /// The day containing `date` in the given calendar's time zone.
    init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    static func today(calendar: Calendar = .current) -> Day {
        Day(Date(), calendar: calendar)
    }

    /// Midnight at the start of this day in the given calendar.
    func date(in calendar: Calendar = .current) -> Date {
        let c = components
        return calendar.date(from: DateComponents(year: c.year, month: c.month, day: c.day))!
    }

    var components: (year: Int, month: Int, day: Int) {
        let date = Date(timeIntervalSinceReferenceDate: Double(index) * 86_400)
        let c = Day.utc.dateComponents([.year, .month, .day], from: date)
        return (c.year!, c.month!, c.day!)
    }

    var year: Int { components.year }
    var month: Int { components.month }
    var dayOfMonth: Int { components.day }

    /// Gregorian weekday, 1 = Sunday … 7 = Saturday (same convention as `Calendar`).
    var weekday: Int {
        // 2001-01-01 (index 0) was a Monday.
        ((index + 1) % 7 + 7) % 7 + 1
    }

    var firstOfMonth: Day {
        let c = components
        return Day(year: c.year, month: c.month, day: 1)
    }

    var firstOfQuarter: Day {
        let c = components
        return Day(year: c.year, month: (c.month - 1) / 3 * 3 + 1, day: 1)
    }

    var firstOfYear: Day {
        Day(year: components.year, month: 1, day: 1)
    }

    /// First day of the week containing this day, where `firstWeekday` uses 1 = Sunday.
    func firstOfWeek(firstWeekday: Int) -> Day {
        let offset = (weekday - firstWeekday + 7) % 7
        return advanced(by: -offset)
    }

    func addingMonths(_ months: Int) -> Day {
        let c = components
        let total = c.year * 12 + (c.month - 1) + months
        let year = total / 12
        let month = total % 12 + 1
        let maxDay = Day.daysInMonth(year: year, month: month)
        return Day(year: year, month: month, day: min(c.day, maxDay))
    }

    static func daysInMonth(year: Int, month: Int) -> Int {
        let first = Day(year: year, month: month, day: 1)
        let next = month == 12 ? Day(year: year + 1, month: 1, day: 1) : Day(year: year, month: month + 1, day: 1)
        return first.distance(to: next)
    }

    static func < (lhs: Day, rhs: Day) -> Bool { lhs.index < rhs.index }
    func advanced(by n: Int) -> Day { Day(index: index + n) }
    func distance(to other: Day) -> Int { other.index - index }

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
}
