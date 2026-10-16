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
        for entry in entries ?? [] {
            let day = Day(index: entry.day)
            if let existing = result[day], existing.updatedAt >= entry.updatedAt { continue }
            result[day] = entry
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
            entries: entriesByDay.mapValues(\.record)
        )
    }

    func stats(today: Day = .today()) -> HabitStats {
        HabitStats(data: data, today: today)
    }

    func record(on day: Day) -> EntryRecord? {
        entriesByDay[day]?.record
    }

    /// Sets or clears (`nil`) the record for a day, removing any duplicates.
    func setRecord(_ record: EntryRecord?, on day: Day, in context: ModelContext) {
        let existing = (entries ?? []).filter { $0.day == day.index }
        guard let record else {
            existing.forEach(context.delete)
            return
        }
        if let first = existing.first {
            first.record = record
            first.updatedAt = Date()
            existing.dropFirst().forEach(context.delete)
        } else {
            let entry = Entry(day: day, record: record)
            context.insert(entry)
            entry.habit = self
        }
    }
}

@Model
final class Entry {
    /// `Day.index` of the day this entry belongs to.
    var day: Int = 0
    var stateRaw: Int = EntryState.yes.rawValue
    var amount: Double = 0
    var updatedAt: Date = Date()
    var habit: Habit?

    init(day: Day, record: EntryRecord) {
        self.day = day.index
        self.stateRaw = record.state.rawValue
        self.amount = record.amount
    }

    var record: EntryRecord {
        get { EntryRecord(state: EntryState(rawValue: stateRaw) ?? .yes, amount: amount) }
        set {
            stateRaw = newValue.state.rawValue
            amount = newValue.amount
        }
    }
}
