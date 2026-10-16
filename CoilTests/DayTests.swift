import Foundation
import Testing
@testable import Coil

struct DayTests {
    @Test func referenceDayIsZero() {
        #expect(Day(year: 2001, month: 1, day: 1).index == 0)
    }

    @Test func componentsRoundTrip() {
        let day = Day(year: 2026, month: 10, day: 17)
        #expect(day.year == 2026)
        #expect(day.month == 10)
        #expect(day.dayOfMonth == 17)
    }

    @Test func weekday() {
        #expect(Day(year: 2001, month: 1, day: 1).weekday == 2) // Monday
        #expect(Day(year: 2026, month: 10, day: 17).weekday == 7) // Saturday
        #expect(Day(year: 2026, month: 10, day: 18).weekday == 1) // Sunday
    }

    @Test func dateConversionIgnoresTimeZone() {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        var la = Calendar(identifier: .gregorian)
        la.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        let day = Day(year: 2026, month: 3, day: 8)
        #expect(Day(day.date(in: tokyo), calendar: tokyo) == day)
        #expect(Day(day.date(in: la), calendar: la) == day)
    }

    @Test func periodStarts() {
        let day = Day(year: 2026, month: 8, day: 19) // Wednesday
        #expect(day.firstOfMonth == Day(year: 2026, month: 8, day: 1))
        #expect(day.firstOfQuarter == Day(year: 2026, month: 7, day: 1))
        #expect(day.firstOfYear == Day(year: 2026, month: 1, day: 1))
        #expect(day.firstOfWeek(firstWeekday: 2) == Day(year: 2026, month: 8, day: 17))
        #expect(day.firstOfWeek(firstWeekday: 1) == Day(year: 2026, month: 8, day: 16))
    }

    @Test func addingMonthsClampsDay() {
        #expect(Day(year: 2026, month: 1, day: 31).addingMonths(1) == Day(year: 2026, month: 2, day: 28))
        #expect(Day(year: 2026, month: 11, day: 15).addingMonths(3) == Day(year: 2027, month: 2, day: 15))
        #expect(Day.daysInMonth(year: 2028, month: 2) == 29)
    }
}

struct FrequencyTests {
    @Test func presets() {
        #expect(Frequency.daily.preset == .everyDay)
        #expect(Frequency(3, 7).preset == .timesPerWeek(3))
        #expect(Frequency(10, 30).preset == .timesPerMonth(10))
        #expect(Frequency(1, 3).preset == .everyNDays(3))
        #expect(Frequency(2, 5).preset == .custom(2, 5))
        #expect(Frequency(.timesPerWeek(4)) == Frequency(4, 7))
    }
}
