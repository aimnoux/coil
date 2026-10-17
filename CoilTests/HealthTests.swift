import Foundation
import SwiftData
import Testing
@testable import Coil

@MainActor
struct HealthTests {
    @Test func measurableHabitsTakeTheDaysValue() {
        #expect(HealthSync.decision(value: 8123.4, habitKind: .measurable, threshold: 0, existingSource: nil, hasRecord: false)
            == .set(EntryRecord(state: .yes, amount: 8123.4)))
        #expect(HealthSync.decision(value: 0, habitKind: .measurable, threshold: 0, existingSource: nil, hasRecord: false) == .keep)
    }

    @Test func yesNoHabitsNeedTheThreshold() {
        #expect(HealthSync.decision(value: 7999, habitKind: .yesNo, threshold: 8000, existingSource: nil, hasRecord: false) == .keep)
        if case .set(let record) = HealthSync.decision(value: 8000, habitKind: .yesNo, threshold: 8000, existingSource: nil, hasRecord: false) {
            #expect(record.state == .yes)
        } else {
            Issue.record("Expected the day to be checked off")
        }
    }

    @Test func manualEntriesAreNeverOverwritten() {
        #expect(HealthSync.decision(value: 9000, habitKind: .measurable, threshold: 0, existingSource: .manual, hasRecord: true) == .keep)
    }

    @Test func healthEntriesAreClearedWhenTheValueDisappears() {
        #expect(HealthSync.decision(value: 0, habitKind: .yesNo, threshold: 8000, existingSource: .health, hasRecord: true) == .clear)
    }

    @Test func applyingWritesHealthEntries() {
        let container = Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let habit = Habit(name: "Steps", kind: .measurable)
        context.insert(habit)
        let day = Day.today()
        HealthSync.apply(value: 5000, to: habit, on: day, in: context)
        #expect(habit.record(on: day)?.amount == 5000)
        #expect(habit.entry(on: day, in: context)?.source == EntrySource.health.rawValue)
        // A manual edit wins over later syncs.
        habit.setRecord(EntryRecord(state: .yes, amount: 6000), on: day, in: context)
        HealthSync.apply(value: 7000, to: habit, on: day, in: context)
        #expect(habit.record(on: day)?.amount == 6000)
    }
}

struct ReviewFixTests {
    let today = Day(year: 2026, month: 10, day: 17)

    @Test func overlappingSleepIsCountedOnce() {
        let night = Date(timeIntervalSince1970: 1_800_000_000)
        let merged = HealthSync.mergeOverlaps([
            DateInterval(start: night, duration: 7 * 3600),
            DateInterval(start: night.addingTimeInterval(3600), duration: 7 * 3600),
        ])
        #expect(merged.count == 1)
        #expect(merged[0].duration == 8 * 3600)
    }

    @Test func atMostHabitsCountEmptyDaysEverywhere() {
        let data = HabitData(kind: .measurable, targetValue: 2, targetType: .atMost,
                             createdDay: today.advanced(by: -9), entries: [today.advanced(by: -3): EntryRecord(state: .yes, amount: 1)])
        let stats = HabitStats(data: data, today: today)
        #expect(stats.isKept(on: today.advanced(by: -5)))
        let list = AchievementEngine.achievements(for: stats)
        #expect(list.first { $0.kind == .streak(7) }?.isUnlocked == true)
        #expect(stats.challengeProgress(today.advanced(by: -9)...today).missed == 0)
    }

    @Test @MainActor func timerSessionsKeepManualValues() {
        let container = Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let habit = Habit(name: "Read", kind: .measurable)
        habit.isTimed = true
        context.insert(habit)
        habit.setRecord(EntryRecord(state: .yes, amount: 30), on: today, in: context)
        TimerService.addSession(to: habit, start: today.date().addingTimeInterval(3600), end: today.date().addingTimeInterval(4200), in: context)
        #expect(habit.record(on: today)?.amount == 30)
    }
}
