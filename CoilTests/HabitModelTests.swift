import Foundation
import SwiftData
import Testing
@testable import Coil

@MainActor
struct HabitModelTests {
    let container = Persistence.makeContainer(inMemory: true)
    var context: ModelContext { container.mainContext }
    let today = Day(year: 2026, month: 10, day: 17)

    func makeHabit() -> Habit {
        let habit = Habit(name: "Run")
        context.insert(habit)
        return habit
    }

    @Test func clearingACheckmarkKeepsTheNote() {
        let habit = makeHabit()
        habit.setRecord(.yes, on: today, in: context)
        habit.setNote("5 km", on: today, in: context)
        habit.setRecord(nil, on: today, in: context)
        #expect(habit.record(on: today) == nil)
        #expect(habit.note(on: today) == "5 km")
        #expect(habit.liveEntries.count == 1)
    }

    @Test func clearingTheNoteOfANoteOnlyDayRemovesTheEntry() {
        let habit = makeHabit()
        habit.setNote("Rest day", on: today, in: context)
        #expect(habit.record(on: today) == nil)
        habit.setNote("  ", on: today, in: context)
        #expect(habit.liveEntries.isEmpty)
    }

    @Test func noteOnlyDaysDontCountAsDone() {
        let habit = makeHabit()
        habit.setNote("Thinking about it", on: today, in: context)
        let stats = HabitStats(data: habit.data, today: today)
        #expect(stats.checkmark(on: today) == .unknown)
        #expect(stats.total == 0)
    }

    @Test func settingARecordTwiceDoesNotDuplicate() {
        let habit = makeHabit()
        habit.setRecord(.yes, on: today, in: context)
        habit.setRecord(.skip, on: today, in: context)
        #expect(habit.liveEntries.count == 1)
        #expect(habit.record(on: today)?.state == .skip)
    }

    @Test func newestDuplicateWins() {
        let habit = makeHabit()
        // Simulate two devices writing the same day before syncing.
        let old = Entry(day: today, record: .no)
        old.updatedAt = Date(timeIntervalSince1970: 1)
        let new = Entry(day: today, record: .yes)
        new.updatedAt = Date(timeIntervalSince1970: 2)
        [old, new].forEach { context.insert($0); $0.habit = habit }
        #expect(habit.record(on: today)?.state == .yes)

        habit.setNote("merged", on: today, in: context)
        #expect(habit.liveEntries.count == 1)
        #expect(habit.record(on: today)?.state == .yes)
    }
}

extension HabitModelTests {
    @Test func syncDuplicatesKeepBothNoteAndCheckmark() {
        let habit = makeHabit()
        // Device A wrote a note, device B checked the same day; the note is newer.
        let check = Entry(day: today, record: .yes)
        check.updatedAt = Date(timeIntervalSince1970: 1)
        let note = Entry(day: today, record: .yes)
        note.stateRaw = Entry.noState
        note.note = "Before work"
        note.updatedAt = Date(timeIntervalSince1970: 2)
        [check, note].forEach { context.insert($0); $0.habit = habit }

        #expect(habit.record(on: today)?.state == .yes)
        #expect(habit.note(on: today) == "Before work")

        // Editing the day merges the duplicates instead of losing one of them.
        habit.setNote("Before work, 30 min", on: today, in: context)
        #expect(habit.liveEntries.count == 1)
        #expect(habit.record(on: today)?.state == .yes)
    }
}

struct ImportHelpersTests {
    @Test func stableUUIDIsStable() {
        #expect(LoopImporter.stableUUID("loop-1-Run") == LoopImporter.stableUUID("loop-1-Run"))
        #expect(LoopImporter.stableUUID("loop-1-Run") != LoopImporter.stableUUID("loop-2-Run"))
    }

    @Test func parseDateRejectsNonsense() {
        #expect(Backup.parseDate("2026-10-17") == Day(year: 2026, month: 10, day: 17))
        #expect(Backup.parseDate("2026-02-30") == nil)
        #expect(Backup.parseDate("99999999-01-01") == nil)
        #expect(Backup.parseDate("garbage") == nil)
    }

    @Test func csvEscapesLineBreaks() {
        #expect(CSVExport.escape("a\r\nb") == "\"a\r\nb\"")
        #expect(CSVExport.escape("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(CSVExport.escape("plain") == "plain")
    }

    @Test func frequencyNeverExceedsItsPeriod() {
        #expect(Frequency(10, 7) == Frequency(7, 7))
        #expect(Frequency(0, 0) == .daily)
    }
}

struct EntryCycleTests {
    @Test func cycleWithSkipAndQuestionMarks() {
        #expect(EntryCycle.next(after: .unknown, skipEnabled: true, showQuestionMarks: true) == .yes)
        #expect(EntryCycle.next(after: .yesManual, skipEnabled: true, showQuestionMarks: true) == .skip)
        #expect(EntryCycle.next(after: .skip, skipEnabled: true, showQuestionMarks: true) == .no)
        #expect(EntryCycle.next(after: .no, skipEnabled: true, showQuestionMarks: true) == nil)
    }

    @Test func simpleCycleTogglesBetweenDoneAndNotDone() {
        #expect(EntryCycle.next(after: .yesManual, skipEnabled: false, showQuestionMarks: false) == .no)
        #expect(EntryCycle.next(after: .no, skipEnabled: false, showQuestionMarks: false) == .yes)
        #expect(EntryCycle.next(after: .yesAuto, skipEnabled: false, showQuestionMarks: false) == .yes)
    }
}
