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
