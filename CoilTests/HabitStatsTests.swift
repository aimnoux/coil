import Foundation
import Testing
@testable import Coil

struct HabitStatsTests {
    let today = Day(year: 2026, month: 10, day: 17)

    func day(_ offset: Int) -> Day { today.advanced(by: offset) }

    func stats(
        _ entries: [Int: EntryRecord],
        frequency: Frequency = .daily,
        kind: HabitKind = .yesNo,
        target: Double = 0,
        targetType: TargetType = .atLeast,
        createdOffset: Int = -30
    ) -> HabitStats {
        let data = HabitData(
            kind: kind,
            frequency: frequency,
            targetValue: target,
            targetType: targetType,
            createdDay: day(createdOffset),
            entries: Dictionary(uniqueKeysWithValues: entries.map { (day($0.key), $0.value) })
        )
        return HabitStats(data: data, today: today)
    }

    // MARK: Checkmarks

    @Test func manualAndUnknownCheckmarks() {
        let s = stats([0: .yes, -1: .no, -2: .skip])
        #expect(s.checkmark(on: day(0)) == .yesManual)
        #expect(s.checkmark(on: day(-1)) == .no)
        #expect(s.checkmark(on: day(-2)) == .skip)
        #expect(s.checkmark(on: day(-3)) == .unknown)
    }

    @Test func weeklyHabitFillsRestOfWindow() {
        let s = stats([-3: .yes], frequency: .weekly)
        #expect(s.checkmark(on: day(-4)) == .unknown)
        #expect(s.checkmark(on: day(-3)) == .yesManual)
        #expect(s.checkmark(on: day(-2)) == .yesAuto)
        #expect(s.checkmark(on: day(0)) == .yesAuto)
    }

    @Test func autoCheckmarkNeedsFullNumerator() {
        let s = stats([-5: .yes, -3: .yes], frequency: Frequency(3, 7))
        #expect(s.checkmark(on: day(-2)) == .unknown)
        let s2 = stats([-5: .yes, -3: .yes, -2: .yes], frequency: Frequency(3, 7))
        #expect(s2.checkmark(on: day(-1)) == .yesAuto)
    }

    // MARK: Score

    @Test func scoreGrowsWithRepetitionsAndDecaysWithMisses() {
        var entries: [Int: EntryRecord] = [:]
        for i in -20...0 { entries[i] = .yes }
        let s = stats(entries)
        #expect(s.score(on: day(-10)) < s.score(on: day(0)))
        #expect(s.currentScore > 0.5)
        #expect(s.currentScore <= 1)

        let missed = stats(entries.filter { $0.key < -2 })
        #expect(missed.currentScore < s.currentScore)
        #expect(missed.currentScore > 0.4) // a few missed days don't erase progress
    }

    @Test func skipLeavesScoreUnchanged() {
        let s = stats([-3: .yes, -2: .yes, -1: .skip])
        #expect(s.score(on: day(-1)) == s.score(on: day(-2)))
    }

    @Test func emptyHabitScoresZero() {
        #expect(stats([:]).currentScore == 0)
    }

    @Test func weeklyHabitDoneEveryWeekConverges() {
        var entries: [Int: EntryRecord] = [:]
        for week in 0..<60 { entries[-week * 7] = .yes }
        let s = stats(entries, frequency: .weekly, createdOffset: -420)
        #expect(s.currentScore > 0.9)
    }

    // MARK: Streaks

    @Test func streaksBridgeSkipsAndIgnoreUnmarkedToday() {
        let s = stats([-6: .yes, -5: .yes, -4: .skip, -3: .yes, -1: .yes])
        let streaks = s.streaks
        #expect(streaks.count == 2)
        #expect(streaks[0].start == day(-6))
        #expect(streaks[0].end == day(-3))
        #expect(streaks[0].length == 3)
        #expect(streaks[1].length == 1)
        #expect(s.currentStreak?.start == day(-1))
        #expect(s.bestStreaks().first?.length == 3)
    }

    @Test func noCurrentStreakAfterMissedDay() {
        let s = stats([-3: .yes, -2: .yes])
        #expect(s.currentStreak == nil)
    }

    // MARK: Measurable

    @Test func measurableAtLeast() {
        let s = stats(
            [0: EntryRecord(state: .yes, amount: 10), -1: EntryRecord(state: .yes, amount: 4)],
            kind: .measurable, target: 8)
        #expect(s.checkmark(on: day(0)) == .yesManual)
        #expect(s.checkmark(on: day(-1)) == .no)
        #expect(s.checkmark(on: day(-2)) == .unknown)
        #expect(s.isCompletedToday)
        #expect(s.total == 14)
        #expect(s.amount(on: day(-1)) == 4)
    }

    @Test func measurableAtMost() {
        let s = stats(
            [0: EntryRecord(state: .yes, amount: 2), -1: EntryRecord(state: .yes, amount: 6)],
            kind: .measurable, target: 3, targetType: .atMost)
        #expect(s.checkmark(on: day(0)) == .yesManual)
        #expect(s.checkmark(on: day(-1)) == .no)
    }

    @Test func measurableWeeklyTargetUsesRollingSum() {
        let s = stats(
            [-2: EntryRecord(state: .yes, amount: 3), 0: EntryRecord(state: .yes, amount: 3)],
            frequency: .weekly, kind: .measurable, target: 5)
        #expect(s.checkmark(on: day(-2)) == .no)
        #expect(s.checkmark(on: day(0)) == .yesManual)
        #expect(s.target(forDays: 7) == 5)
    }

    // MARK: History

    @Test func historyByMonth() {
        let s = stats([0: .yes, -1: .yes, -20: .yes], createdOffset: -40)
        let history = s.history(bucket: .month, firstWeekday: 2)
        #expect(history.last?.start == Day(year: 2026, month: 10, day: 1))
        #expect(history.last?.value == 2)
        #expect(history.dropLast().last?.value == 1)
    }

    @Test func scoreSeriesEndsWithCurrentScore() {
        let s = stats([0: .yes, -1: .yes])
        let series = s.scoreSeries(bucket: .week, firstWeekday: 2)
        #expect(series.last?.score == s.currentScore)
    }
}
