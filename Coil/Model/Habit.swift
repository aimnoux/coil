import Foundation
import SwiftData

// Models follow CloudKit rules so iCloud sync can be switched on later:
// every property has a default, no unique constraints, relationships are optional.

@Model
final class Habit {
    var id: UUID = UUID()
    var name: String = ""
    var question: String = ""
    var notes: String = ""
    var colorIndex: Int = HabitColor.defaultIndex
    var kindRaw: Int = HabitKind.yesNo.rawValue
    var frequencyNumerator: Int = 1
    var frequencyDenominator: Int = 1
    var unit: String = ""
    var targetValue: Double = 0
    var targetTypeRaw: Int = TargetType.atLeast.rawValue
    var reminderEnabled: Bool = false
    var reminderHour: Int = 8
    var reminderMinute: Int = 0
    /// Bitmask of weekdays for reminders: bit 0 = Sunday … bit 6 = Saturday.
    var reminderDays: Int = 0b111_1111
    var position: Int = 0
    var isArchived: Bool = false
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Entry.habit)
    var entries: [Entry]? = []

    init(name: String = "", kind: HabitKind = .yesNo) {
        self.name = name
        self.kindRaw = kind.rawValue
    }

    var kind: HabitKind {
        get { HabitKind(rawValue: kindRaw) ?? .yesNo }
        set { kindRaw = newValue.rawValue }
    }

    var frequency: Frequency {
        get { Frequency(frequencyNumerator, frequencyDenominator) }
        set {
            frequencyNumerator = newValue.numerator
            frequencyDenominator = newValue.denominator
        }
    }

    var targetType: TargetType {
        get { TargetType(rawValue: targetTypeRaw) ?? .atLeast }
        set { targetTypeRaw = newValue.rawValue }
    }

    var color: HabitColor { HabitColor(index: colorIndex) }

    var isMeasurable: Bool { kind == .measurable }

    var createdDay: Day { Day(createdAt) }

    func remindsOn(weekday: Int) -> Bool {
        reminderDays & (1 << (weekday - 1)) != 0
    }

    func setReminder(_ on: Bool, weekday: Int) {
        if on {
            reminderDays |= 1 << (weekday - 1)
        } else {
            reminderDays &= ~(1 << (weekday - 1))
        }
    }

    /// Entries keyed by day. If sync produced duplicates for a day, the newest one wins.
    var entriesByDay: [Day: Entry] {
        var result: [Day: Entry] = [:]
        for entry in liveEntries {
            let day = Day(index: entry.day)
            if let existing = result[day], existing.updatedAt >= entry.updatedAt { continue }
            result[day] = entry
        }
        return result
    }

    /// What was recorded on each day. Duplicates from sync are merged field by field:
    /// the newest checkmark and the newest non-empty note both survive.
    var dayRecords: [Day: DayRecord] {
        var result: [Day: DayRecord] = [:]
        for entry in liveEntries.sorted(by: { $0.updatedAt < $1.updatedAt }) {
            let day = Day(index: entry.day)
            var merged = result[day] ?? DayRecord()
            if let record = entry.storedRecord { merged.record = record }
            if !entry.note.isEmpty { merged.note = entry.note }
            result[day] = merged
        }
        return result
    }

    var data: HabitData {
        HabitData(
            kind: kind,
            frequency: frequency,
            targetValue: targetValue,
            targetType: targetType,
            createdDay: createdDay,
            entries: dayRecords.compactMapValues(\.record)
        )
    }

    func stats(today: Day = .today()) -> HabitStats {
        HabitStats(data: data, today: today)
    }

    func record(on day: Day) -> EntryRecord? {
        dayRecords[day]?.record
    }

    func note(on day: Day) -> String {
        dayRecords[day]?.note ?? ""
    }

    /// Days that have a note, newest first.
    var notedDays: [(day: Day, note: String)] {
        dayRecords
            .filter { !$0.value.note.isEmpty }
            .map { (day: $0.key, note: $0.value.note) }
            .sorted { $0.day > $1.day }
    }

    /// Sets or clears (`nil`) the record for a day, removing any duplicates. A note on the day is kept.
    func setRecord(_ record: EntryRecord?, on day: Day, in context: ModelContext) {
        let entry = uniqueEntry(on: day, in: context)
        if let record {
            let target = entry ?? insertEntry(on: day, in: context)
            target.record = record
            target.updatedAt = Date()
        } else if let entry {
            if entry.note.isEmpty {
                context.delete(entry)
            } else {
                entry.stateRaw = Entry.noState
                entry.updatedAt = Date()
            }
        }
    }

    /// Sets the note for a day; an empty note on a day without a checkmark removes the entry.
    func setNote(_ note: String, on day: Day, in context: ModelContext) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = uniqueEntry(on: day, in: context)
        if trimmed.isEmpty {
            guard let entry else { return }
            if entry.storedRecord == nil {
                context.delete(entry)
            } else {
                entry.note = ""
                entry.updatedAt = Date()
            }
            return
        }
        let target = entry ?? {
            let new = insertEntry(on: day, in: context)
            new.stateRaw = Entry.noState
            return new
        }()
        target.note = trimmed
        target.updatedAt = Date()
    }

    /// Entries not yet removed. SwiftData keeps deleted objects in the relationship until the next save.
    var liveEntries: [Entry] {
        (entries ?? []).filter { !$0.isDeleted }
    }

    /// The entry for a day after merging duplicates into the newest one, or `nil`.
    private func uniqueEntry(on day: Day, in context: ModelContext) -> Entry? {
        let existing = liveEntries
            .filter { $0.day == day.index }
            .sorted { $0.updatedAt > $1.updatedAt }
        guard let newest = existing.first else { return nil }
        for duplicate in existing.dropFirst() {
            // Keep what only the older copy knows before deleting it.
            if newest.storedRecord == nil, let record = duplicate.storedRecord {
                newest.record = record
            }
            if newest.note.isEmpty, !duplicate.note.isEmpty {
                newest.note = duplicate.note
            }
            context.delete(duplicate)
        }
        return newest
    }

    private func insertEntry(on day: Day, in context: ModelContext) -> Entry {
        let entry = Entry(day: day, record: .yes)
        context.insert(entry)
        entry.habit = self
        return entry
    }
}

/// The merged contents of one day: an optional checkmark and a note.
nonisolated struct DayRecord: Hashable, Sendable {
    var record: EntryRecord?
    var note: String = ""
}

@Model
final class Entry {
    /// `Day.index` of the day this entry belongs to.
    var day: Int = 0
    /// An `EntryState` raw value, or `Entry.noState` for a day that only has a note.
    var stateRaw: Int = EntryState.yes.rawValue
    var amount: Double = 0
    /// A note for this day, like Loop's checkmark notes.
    var note: String = ""
    var updatedAt: Date = Date()
    var habit: Habit?

    static let noState = 0

    init(day: Day, record: EntryRecord) {
        self.day = day.index
        self.stateRaw = record.state.rawValue
        self.amount = record.amount
    }

    var record: EntryRecord {
        get { storedRecord ?? EntryRecord(state: .yes, amount: amount) }
        set {
            stateRaw = newValue.state.rawValue
            amount = newValue.amount
        }
    }

    /// The checkmark for this day, or `nil` if the entry only holds a note.
    var storedRecord: EntryRecord? {
        EntryState(rawValue: stateRaw).map { EntryRecord(state: $0, amount: amount) }
    }
}
