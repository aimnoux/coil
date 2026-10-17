import Foundation
import Testing
@testable import Coil

struct AchievementTests {
    let today = Day(year: 2026, month: 10, day: 17)

    func stats(_ doneOffsets: [Int], kind: HabitKind = .yesNo, created: Int = -60, extra: [Int: EntryRecord] = [:]) -> HabitStats {
        var entries: [Day: EntryRecord] = [:]
        for o in doneOffsets { entries[today.advanced(by: o)] = .yes }
        for (o, r) in extra { entries[today.advanced(by: o)] = r }
        return HabitStats(data: HabitData(kind: kind, createdDay: today.advanced(by: created), entries: entries), today: today)
    }

    func find(_ list: [Achievement], _ kind: Achievement.Kind) -> Achievement? {
        list.first { $0.kind == kind }
    }

    @Test func streakMilestonesUnlockOnTheRightDay() {
        let list = AchievementEngine.achievements(for: stats(Array(-9...0)))
        #expect(find(list, .streak(3))?.unlocked == today.advanced(by: -7))
        #expect(find(list, .streak(7))?.unlocked == today.advanced(by: -3))
        #expect(find(list, .streak(14))?.unlocked == nil)
        #expect(abs((find(list, .streak(14))?.progress ?? 0) - 10.0 / 14) < 0.001)
    }

    @Test func completionsCountEveryCheckIn() {
        let list = AchievementEngine.achievements(for: stats([-30, -20, -10, -5, -1]))
        #expect(find(list, .completions(1))?.unlocked == today.advanced(by: -30))
        #expect(find(list, .completions(10))?.isUnlocked == false)
    }

    @Test func quitHabitsEarnCleanStreaks() {
        let list = AchievementEngine.achievements(for: stats([], kind: .quit, created: -20, extra: [-10: .no]))
        #expect(find(list, .cleanStreak(7))?.isUnlocked == true)
        #expect(find(list, .completions(1)) == nil)
    }

    @Test func perfectMonthNeedsEveryDayOfAFullMonth() {
        // September 2026 fully done.
        let september = Day(year: 2026, month: 9, day: 1)
        let offsets = (0..<30).map { september.advanced(by: $0) }.map { today.index - $0.index }.map { -$0 }
        let list = AchievementEngine.achievements(for: stats(offsets, created: -60))
        #expect(find(list, .perfectMonth)?.unlocked == Day(year: 2026, month: 9, day: 30))
    }

    @Test func comebackAfterABreak() {
        let list = AchievementEngine.achievements(for: stats(Array(-40...(-35)) + Array(-7...(-1)), created: -45))
        #expect(find(list, .comeback)?.unlocked == today.advanced(by: -1))
        // A slow start isn't a comeback.
        let fresh = AchievementEngine.achievements(for: stats(Array(-7...(-1)), created: -45))
        #expect(find(fresh, .comeback)?.isUnlocked == false)
    }

    @Test func globalAchievements() {
        let a = stats([0, -1]), b = stats([0])
        let list = AchievementEngine.global(habitCreationDays: [today, today.advanced(by: -3)], allStats: [a, b])
        #expect(list.first { $0.kind == .habitsCreated(1) }?.unlocked == today.advanced(by: -3))
        #expect(list.first { $0.kind == .habitsCreated(5) }?.isUnlocked == false)
        #expect(list.first { $0.kind == .allDoneInADay }?.unlocked == today)
    }
}
