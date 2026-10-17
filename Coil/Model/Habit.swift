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

    /// Bumped on every change to entries, so cached statistics know when to recompute.
    var revision: Int = 0
    /// An SF Symbol shown next to the name; empty for none.
    var iconName: String = ""
    /// Reminder times as minutes after midnight, comma separated ("480,780").
    /// Empty means the single time in `reminderHour`/`reminderMinute` (older data).
    var reminderTimesRaw: String = ""
    /// A challenge: complete the habit for this many days starting at `challengeStartDay`. 0 = none.
    var challengeDays: Int = 0
    var challengeStartDay: Int = 0
    /// Measurable habits in minutes that can be tracked with a stopwatch or timer.
    var isTimed: Bool = false
    /// Countdown length for timed habits; 0 means a stopwatch.
    var timerMinutes: Int = 0
    /// A `HealthMetric` raw value when the habit is filled from Apple Health; empty otherwise.
    var healthMetricRaw: String = ""
    /// For yes/no habits linked to Health: the daily value that counts as done.
    var healthThreshold: Double = 0

    var group: HabitGroup?

    @Relationship(deleteRule: .cascade, inverse: \Entry.habit)
    var entries: [Entry]? = []

    @Relationship(deleteRule: .cascade, inverse: \HabitPause.habit)
    var pauses: [HabitPause]? = []

    @Relationship(deleteRule: .cascade, inverse: \TimerSession.habit)
    var sessions: [TimerSession]? = []

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

    var isQuit: Bool { kind == .quit }

    var healthMetric: HealthMetric? {
        get { HealthMetric(rawValue: healthMetricRaw) }
        set { healthMetricRaw = newValue?.rawValue ?? "" }
    }

    /// Reminder times as minutes after midnight, sorted.
    var reminderMinutes: [Int] {
        get {
            let parsed = reminderTimesRaw.split(separator: ",").compactMap { Int($0) }
            return parsed.isEmpty ? [reminderHour * 60 + reminderMinute] : parsed.sorted()
        }
        set {
            let times = Array(Set(newValue.map { min(max($0, 0), 24 * 60 - 1) })).sorted()
            reminderTimesRaw = times.map(String.init).joined(separator: ",")
            if let first = times.first {
                reminderHour = first / 60
                reminderMinute = first % 60
            }
        }
    }

    /// The challenge's days, if one is set.
    var challenge: ClosedRange<Day>? {
        guard challengeDays > 0 else { return nil }
        let start = Day(index: challengeStartDay)
        return start...start.advanced(by: challengeDays - 1)
    }

    /// Every paused day, from all pause ranges.
    var pausedDays: Set<Day> {
        var days = Set<Day>()
        for pause in livePauses {
            let lo = min(pause.startDay, pause.endDay), hi = max(pause.startDay, pause.endDay)
            guard hi - lo < 3660 else { continue }
            for index in lo...hi { days.insert(Day(index: index)) }
        }
        return days
    }

    var livePauses: [HabitPause] {
        (pauses ?? []).filter { !$0.isDeleted }
    }

    var liveSessions: [TimerSession] {
        (sessions ?? []).filter { !$0.isDeleted }
    }

    /// Whether the habit is paused on a given day.
    func isPaused(on day: Day) -> Bool {
        livePauses.contains { min($0.startDay, $0.endDay) <= day.index && day.index <= max($0.startDay, $0.endDay) }
    }

    /// Marks entries as changed so cached statistics are recomputed.
    func touch() {
        revision &+= 1
    }

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
    /// Cached; see `HabitCache`.
    @MainActor
    var dayRecords: [Day: DayRecord] {
        HabitCache.shared.dayRecords(for: self)
    }

    /// Reads every entry once into plain values and merges them by day. Reading SwiftData
    /// properties is relatively slow, so this touches each property exactly once.
    func computeDayRecords() -> [Day: DayRecord] {
        struct Raw {
            let day: Int, updatedAt: Date, state: Int, amount: Double, note: String
        }
        let raws = liveEntries.map {
            Raw(day: $0.day, updatedAt: $0.updatedAt, state: $0.stateRaw, amount: $0.amount, note: $0.note)
        }
        var result: [Day: DayRecord] = [:]
        result.reserveCapacity(raws.count)
        for raw in raws.sorted(by: { $0.updatedAt < $1.updatedAt }) {
            let day = Day(index: raw.day)
            var merged = result[day] ?? DayRecord()
            if let state = EntryState(rawValue: raw.state) {
                merged.record = EntryRecord(state: state, amount: raw.amount)
            }
            if !raw.note.isEmpty { merged.note = raw.note }
            result[day] = merged
        }
        return result
    }

    @MainActor
    var data: HabitData {
        HabitData(
            kind: kind,
            frequency: frequency,
            targetValue: targetValue,
            targetType: targetType,
            createdDay: createdDay,
            entries: dayRecords.compactMapValues(\.record),
            pausedDays: pausedDays
        )
    }

    /// Cached; recomputed only when entries or settings change.
    @MainActor
    func stats(today: Day = .today()) -> HabitStats {
        HabitCache.shared.stats(for: self, today: today)
    }

    @MainActor
    func record(on day: Day) -> EntryRecord? {
        dayRecords[day]?.record
    }

    @MainActor
    func note(on day: Day) -> String {
        dayRecords[day]?.note ?? ""
    }

    /// Days that have a note, newest first.
    @MainActor
    var notedDays: [(day: Day, note: String)] {
        dayRecords
            .filter { !$0.value.note.isEmpty }
            .map { (day: $0.key, note: $0.value.note) }
            .sorted { $0.day > $1.day }
    }

    /// Sets or clears (`nil`) the record for a day, removing any duplicates. A note on the day is kept.
    func setRecord(_ record: EntryRecord?, on day: Day, in context: ModelContext, source: EntrySource = .manual) {
        touch()
        let entry = uniqueEntry(on: day, in: context)
        if let record {
            let target = entry ?? insertEntry(on: day, in: context)
            target.record = record
            target.source = source.rawValue
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
        touch()
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

    /// The entry for a day (after merging duplicates), for code that needs its metadata.
    func entry(on day: Day, in context: ModelContext) -> Entry? {
        uniqueEntry(on: day, in: context)
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
    /// An `EntrySource` raw value: who wrote this entry.
    var source: Int = EntrySource.manual.rawValue
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

/// Who wrote an entry. Health and timer entries are recalculated automatically;
/// manual edits are never overwritten.
nonisolated enum EntrySource: Int, Sendable {
    case manual = 0
    case health = 1
    case timer = 2
}

/// A named section of the habit list, like "Morning" or "Health".
@Model
final class HabitGroup {
    var id: UUID = UUID()
    var name: String = ""
    var position: Int = 0
    var iconName: String = ""

    @Relationship(deleteRule: .nullify, inverse: \Habit.group)
    var habits: [Habit]? = []

    init(name: String = "", position: Int = 0) {
        self.name = name
        self.position = position
    }
}

/// A range of days (inclusive) when a habit is paused, e.g. a vacation.
@Model
final class HabitPause {
    var startDay: Int = 0
    var endDay: Int = 0
    var note: String = ""
    var habit: Habit?

    init(start: Day, end: Day, note: String = "") {
        startDay = start.index
        endDay = end.index
        self.note = note
    }

    var range: ClosedRange<Day> {
        Day(index: min(startDay, endDay))...Day(index: max(startDay, endDay))
    }
}

/// One stopwatch or timer run for a timed habit. `end == nil` while it is running.
@Model
final class TimerSession {
    var id: UUID = UUID()
    var start: Date = Date()
    var end: Date?
    var note: String = ""
    var habit: Habit?

    init(start: Date = Date(), end: Date? = nil) {
        self.start = start
        self.end = end
    }

    var isRunning: Bool { end == nil }

    func duration(at now: Date = Date()) -> TimeInterval {
        max(0, (end ?? now).timeIntervalSince(start))
    }
}
