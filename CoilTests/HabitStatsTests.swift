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

    @Test func weeklyHabitFillsItsWindow() {
        let s = stats([-3: .yes], frequency: .weekly)
        #expect(s.checkmark(on: day(-10)) == .unknown)
        #expect(s.checkmark(on: day(-9)) == .yesAuto)
        #expect(s.checkmark(on: day(-3)) == .yesManual)
        #expect(s.checkmark(on: day(-2)) == .yesAuto)
        #expect(s.checkmark(on: day(0)) == .yesAuto)
    }

    @Test func autoCheckmarksNeverPrecedeTheHabit() {
        let s = stats([0: .yes], frequency: .weekly, createdOffset: 0)
        #expect(s.start == day(0))
        #expect(s.checkmark(on: day(-1)) == .unknown)
    }

    @Test func threeTimesAWeekKeepsTheStreakBetweenWorkouts() {
        // Monday, Wednesday and Friday for four weeks.
        var entries: [Int: EntryRecord] = [:]
        for week in 0..<4 {
            for weekday in [0, 2, 4] { entries[-27 + week * 7 + weekday] = .yes }
        }
        let s = stats(entries, frequency: Frequency(3, 7), createdOffset: -27)
        #expect(s.checkmark(on: day(-26)) == .yesAuto) // Tuesday between workouts
        #expect(s.streaks.count == 1)
        #expect(s.streaks[0].start == day(-27))
    }

    @Test func autoCheckmarkNeedsFullNumerator() {
        let s = stats([-5: .yes, -3: .yes], frequency: Frequency(3, 7))
        #expect(s.checkmark(on: day(-2)) == .unknown)
        let s2 = stats([-5: .yes, -3: .yes, -2: .yes], frequency: Frequency(3, 7))
        #expect(s2.checkmark(on: day(-1)) == .yesAuto)
        #expect(s2.checkmark(on: day(-8)) == .yesAuto)
        #expect(s2.checkmark(on: day(-9)) == .unknown)
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

    // MARK: Pauses

    @Test func pausedDaysFreezeStrengthAndKeepStreaks() {
        let paused: Set<Day> = [day(-3), day(-2)]
        let data = HabitData(
            createdDay: day(-30),
            entries: [day(-5): .yes, day(-4): .yes, day(-1): .yes, day(0): .yes],
            pausedDays: paused
        )
        let s = HabitStats(data: data, today: today)
        #expect(s.checkmark(on: day(-2)) == .paused)
        #expect(s.score(on: day(-2)) == s.score(on: day(-4)))
        #expect(s.streaks.count == 1)
        #expect(s.streaks[0].length == 4)
    }

    @Test func checkingAPausedDayCountsIt() {
        let data = HabitData(createdDay: day(-10), entries: [day(-1): .yes], pausedDays: [day(-1)])
        #expect(HabitStats(data: data, today: today).checkmark(on: day(-1)) == .yesManual)
    }

    // MARK: Quit

    @Test func quitHabitCountsCleanDaysAndSlips() {
        let s = stats([-4: .no, -1: .no], kind: .quit, createdOffset: -10)
        #expect(s.checkmark(on: day(-5)) == .yesAuto)
        #expect(s.checkmark(on: day(-4)) == .no)
        #expect(s.slipCount == 2)
        #expect(s.lastSlip == day(-1))
        #expect(s.currentStreak?.start == day(0))
        #expect(s.bestStreaks().first?.length == 6) // days -10 … -5
        #expect(s.isCompletedToday)
    }

    @Test func quitHabitStrengthGrowsWhileClean() {
        let clean = stats([:], kind: .quit, createdOffset: -60)
        let slipping = stats([-1: .no, -3: .no, -5: .no], kind: .quit, createdOffset: -60)
        #expect(clean.currentScore > 0.9)
        #expect(slipping.currentScore < clean.currentScore)
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

struct ChallengeTests {
    let today = Day(year: 2026, month: 10, day: 17)

    @Test func challengeCountsKeptAndMissedDays() {
        let start = today.advanced(by: -4)
        let data = HabitData(
            createdDay: start,
            entries: [start: .yes, start.advanced(by: 1): .yes, start.advanced(by: 3): .yes]
        )
        let progress = HabitStats(data: data, today: today).challengeProgress(start...start.advanced(by: 29))
        #expect(progress.day == 5)
        #expect(progress.kept == 3)
        #expect(progress.missed == 1) // day 3; today isn't missed yet
        #expect(!progress.isOver)
        #expect(progress.isFailed)
    }

    @Test func finishedChallengeWithEveryDayKeptIsCompleted() {
        let start = today.advanced(by: -9)
        var entries: [Day: EntryRecord] = [:]
        for i in 0..<7 { entries[start.advanced(by: i)] = .yes }
        let data = HabitData(createdDay: start, entries: entries)
        let progress = HabitStats(data: data, today: today).challengeProgress(start...start.advanced(by: 6))
        #expect(progress.isOver)
        #expect(progress.isCompleted)
        #expect(progress.fraction == 1)
    }
}

struct RestDayTests {
    let today = Day(year: 2026, month: 10, day: 18) // Sunday

    @Test func weekendsAreRestDaysForAWeekdayHabit() {
        let weekdays = 0b011_1110
        let friday = today.advanced(by: -2), saturday = today.advanced(by: -1)
        var entries: [Day: EntryRecord] = [:]
        for i in 2...6 { entries[today.advanced(by: -i)] = EntryRecord(state: .yes, amount: 480) } // Mon–Fri
        let data = HabitData(kind: .measurable, targetValue: 480, createdDay: today.advanced(by: -6),
                             entries: entries, activeWeekdays: weekdays)
        let stats = HabitStats(data: data, today: today)
        #expect(stats.checkmark(on: saturday) == .rest)
        #expect(stats.checkmark(on: today) == .rest)
        #expect(stats.checkmark(on: friday) == .yesManual)
        // Rest days neither lower strength nor break the streak.
        #expect(stats.score(on: today) == stats.score(on: friday))
        #expect(stats.currentStreak?.length == 5)
        #expect(stats.isCompletedToday)
    }

    @Test func workingOnARestDayStillCounts() {
        let data = HabitData(createdDay: today.advanced(by: -3), entries: [today: .yes], activeWeekdays: 0b011_1110)
        #expect(HabitStats(data: data, today: today).checkmark(on: today) == .yesManual)
    }

    @Test func customTargetPeriod() {
        var draft = HabitDraft()
        draft.kind = .measurable
        draft.targetPeriod = .custom
        draft.targetDays = 3
        #expect(draft.frequency == Frequency(1, 3))
        #expect(TargetPeriod(Frequency(1, 3)) == .custom)
        #expect(ActiveDays(mask: 0b011_1110) == .weekdays)
        #expect(ActiveDays(mask: 0b000_0101) == .custom)
    }
}

@MainActor
struct TimerDurationTests {
    @Test func sessionsUnderAMinuteAreDropped() {
        let container = Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let habit = Habit(name: "Work", kind: .measurable)
        habit.isTimed = true
        context.insert(habit)
        let start = Date()
        let session = TimerService.start(habit, in: context, at: start)
        TimerService.stop(session, in: context, at: start.addingTimeInterval(40))
        #expect(habit.liveSessions.isEmpty)
        #expect(habit.record(on: Day(start)) == nil)
    }

    @Test func hoursMinutesFormat() {
        #expect(Formatting.hoursMinutes(45) == String(localized: "45 min"))
        #expect(Formatting.hoursMinutes(151) == "2h31m")
        #expect(Formatting.hoursMinutes(120) == "2h")
    }
}
