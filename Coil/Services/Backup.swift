import Foundation
import SwiftData
import UniformTypeIdentifiers

/// A complete, versioned copy of all habits and entries as JSON.
nonisolated struct BackupFile: Codable, Sendable {
    var format = "coil-backup"
    var version = 2
    var exportedAt = Date()
    var habits: [BackupHabit]
    /// Added in version 2; older backups have none.
    var groups: [BackupGroup]? = nil

    struct BackupGroup: Codable, Sendable {
        var id: UUID
        var name: String
        var position: Int
        var iconName: String
    }

    struct BackupPause: Codable, Sendable {
        var start: String
        var end: String
        var note: String
    }

    struct BackupSession: Codable, Sendable {
        var id: UUID
        var start: Date
        var end: Date?
        var note: String
    }

    struct BackupHabit: Codable, Sendable {
        var id: UUID
        var name: String
        var question: String
        var notes: String
        var colorIndex: Int
        var kind: Int
        var frequencyNumerator: Int
        var frequencyDenominator: Int
        var unit: String
        var targetValue: Double
        var targetType: Int
        var reminderEnabled: Bool
        var reminderHour: Int
        var reminderMinute: Int
        var reminderDays: Int
        var position: Int
        var isArchived: Bool
        var createdAt: Date
        var entries: [BackupEntry]
        // Version 2 fields are optional so version 1 backups still decode.
        var iconName: String? = nil
        var groupID: UUID? = nil
        var reminderTimes: String? = nil
        var challengeDays: Int? = nil
        var challengeStartDay: Int? = nil
        var isTimed: Bool? = nil
        var timerMinutes: Int? = nil
        var healthMetric: String? = nil
        var healthThreshold: Double? = nil
        var activeWeekdays: Int? = nil
        var pauses: [BackupPause]? = nil
        var sessions: [BackupSession]? = nil
    }

    struct BackupEntry: Codable, Sendable {
        /// ISO date, e.g. "2026-10-17".
        var date: String
        /// An `EntryState` raw value, or 0 for a day that only has a note.
        var state: Int
        var amount: Double
        var note: String? = nil
        /// `EntrySource` raw value (version 2); missing means manual.
        var source: Int? = nil
    }
}

enum BackupError: LocalizedError {
    case unreadable
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .unreadable: String(localized: "The file couldn't be read.")
        case .unsupportedFormat: String(localized: "This isn't a Coil backup or a Loop Habit Tracker database.")
        }
    }
}

/// Summary of what an import added or changed.
struct ImportResult {
    var habitsAdded = 0
    var habitsUpdated = 0
    var entriesImported = 0
}

enum Backup {
    nonisolated static func fileName() -> String {
        "Coil Backup \(CSVExport.isoDate(.today())).json"
    }

    static func make(from habits: [Habit]) -> BackupFile {
        let groups = Dictionary(habits.compactMap(\.group).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }).values
        var file = BackupFile(habits: habits.map { habit in
            let sources = Dictionary(
                habit.entriesByDay.compactMap { day, entry in entry.source == EntrySource.manual.rawValue ? nil : (day, entry.source) },
                uniquingKeysWith: { a, _ in a }
            )
            var item = BackupFile.BackupHabit(
                id: habit.id,
                name: habit.name,
                question: habit.question,
                notes: habit.notes,
                colorIndex: habit.colorIndex,
                kind: habit.kindRaw,
                frequencyNumerator: habit.frequencyNumerator,
                frequencyDenominator: habit.frequencyDenominator,
                unit: habit.unit,
                targetValue: habit.targetValue,
                targetType: habit.targetTypeRaw,
                reminderEnabled: habit.reminderEnabled,
                reminderHour: habit.reminderHour,
                reminderMinute: habit.reminderMinute,
                reminderDays: habit.reminderDays,
                position: habit.position,
                isArchived: habit.isArchived,
                createdAt: habit.createdAt,
                entries: habit.dayRecords
                    .sorted { $0.key < $1.key }
                    .map { day, item in
                        BackupFile.BackupEntry(
                            date: CSVExport.isoDate(day),
                            state: item.record?.state.rawValue ?? Entry.noState,
                            amount: item.record?.amount ?? 0,
                            note: item.note.isEmpty ? nil : item.note,
                            source: sources[day]
                        )
                    }
            )
            item.iconName = habit.iconName
            item.groupID = habit.group?.id
            item.reminderTimes = habit.reminderTimesRaw
            item.challengeDays = habit.challengeDays
            item.challengeStartDay = habit.challengeStartDay
            item.isTimed = habit.isTimed
            item.timerMinutes = habit.timerMinutes
            item.healthMetric = habit.healthMetricRaw
            item.healthThreshold = habit.healthThreshold
            item.activeWeekdays = habit.activeWeekdays
            item.pauses = habit.livePauses.map {
                BackupFile.BackupPause(
                    start: CSVExport.isoDate($0.range.lowerBound),
                    end: CSVExport.isoDate($0.range.upperBound),
                    note: $0.note
                )
            }
            item.sessions = habit.liveSessions.map {
                BackupFile.BackupSession(id: $0.id, start: $0.start, end: $0.end, note: $0.note)
            }
            return item
        })
        file.groups = groups
            .sorted { $0.position < $1.position }
            .map { BackupFile.BackupGroup(id: $0.id, name: $0.name, position: $0.position, iconName: $0.iconName) }
        return file
    }

    nonisolated static func encode(_ backup: BackupFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    /// Imports a Coil JSON backup or a Loop Habit Tracker `.db` file.
    /// Habits that already exist (same id) are updated and their entries merged.
    static func importFile(at url: URL, into context: ModelContext) throws -> ImportResult {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { throw BackupError.unreadable }

        let backup: BackupFile
        if data.starts(with: Array("SQLite format 3".utf8)) {
            backup = try LoopImporter.read(databaseAt: url)
        } else {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard let decoded = try? decoder.decode(BackupFile.self, from: data),
                  decoded.format == "coil-backup"
            else { throw BackupError.unsupportedFormat }
            backup = decoded
        }
        return try restore(backup, into: context)
    }

    static func restore(_ backup: BackupFile, into context: ModelContext) throws -> ImportResult {
        var result = ImportResult()

        // Groups first, so habits can point at them.
        var groupsByID = Dictionary(
            try context.fetch(FetchDescriptor<HabitGroup>()).map { ($0.id, $0) },
            uniquingKeysWith: { a, _ in a }
        )
        for item in backup.groups ?? [] where groupsByID[item.id] == nil {
            let group = HabitGroup(name: item.name, position: item.position)
            group.id = item.id
            group.iconName = item.iconName
            context.insert(group)
            groupsByID[item.id] = group
        }

        let existing = try context.fetch(FetchDescriptor<Habit>())
        var byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var nextPosition = (existing.map(\.position).max() ?? -1) + 1

        for item in backup.habits {
            let habit: Habit
            if let found = byID[item.id] {
                habit = found
                result.habitsUpdated += 1
            } else {
                habit = Habit()
                habit.id = item.id
                habit.position = nextPosition
                nextPosition += 1
                context.insert(habit)
                byID[item.id] = habit
                result.habitsAdded += 1
            }
            habit.name = item.name
            habit.question = item.question
            habit.notes = item.notes
            habit.colorIndex = item.colorIndex
            habit.kindRaw = item.kind
            habit.frequencyNumerator = max(1, item.frequencyNumerator)
            habit.frequencyDenominator = max(1, item.frequencyDenominator)
            habit.unit = item.unit
            habit.targetValue = item.targetValue
            habit.targetTypeRaw = item.targetType
            habit.reminderEnabled = item.reminderEnabled
            habit.reminderHour = item.reminderHour
            habit.reminderMinute = item.reminderMinute
            habit.reminderDays = item.reminderDays
            habit.isArchived = item.isArchived
            habit.createdAt = min(habit.createdAt, item.createdAt)
            if let icon = item.iconName { habit.iconName = icon }
            if let groupID = item.groupID { habit.group = groupsByID[groupID] }
            if let times = item.reminderTimes { habit.reminderTimesRaw = times }
            if let days = item.challengeDays {
                habit.challengeDays = days
                habit.challengeStartDay = item.challengeStartDay ?? habit.challengeStartDay
            }
            if let timed = item.isTimed { habit.isTimed = timed }
            if let minutes = item.timerMinutes { habit.timerMinutes = minutes }
            if let metric = item.healthMetric { habit.healthMetricRaw = metric }
            if let threshold = item.healthThreshold { habit.healthThreshold = threshold }
            if let days = item.activeWeekdays { habit.activeWeekdays = days }

            let knownPauses = Set(habit.livePauses.map { "\($0.startDay)-\($0.endDay)" })
            for pause in item.pauses ?? [] {
                guard let start = parseDate(pause.start), let end = parseDate(pause.end),
                      !knownPauses.contains("\(start.index)-\(end.index)") else { continue }
                let model = HabitPause(start: start, end: end, note: pause.note)
                context.insert(model)
                model.habit = habit
            }
            let knownSessions = Set(habit.liveSessions.map(\.id))
            for session in item.sessions ?? [] where !knownSessions.contains(session.id) {
                let model = TimerSession(start: session.start, end: session.end)
                model.id = session.id
                model.note = session.note
                context.insert(model)
                model.habit = habit
            }

            // Look entries up by day once instead of scanning the relationship per entry.
            var existingEntries = habit.entriesByDay
            for entry in item.entries {
                let state = EntryState(rawValue: entry.state)
                let note = entry.note ?? ""
                guard let day = parseDate(entry.date), state != nil || !note.isEmpty else { continue }
                let target: Entry
                if let existing = existingEntries[day] {
                    target = existing
                } else {
                    target = Entry(day: day, record: .yes)
                    target.stateRaw = Entry.noState
                    context.insert(target)
                    target.habit = habit
                    existingEntries[day] = target
                }
                if let state {
                    target.record = EntryRecord(state: state, amount: entry.amount)
                    target.source = entry.source ?? EntrySource.manual.rawValue
                }
                if !note.isEmpty {
                    target.note = note
                }
                target.updatedAt = Date()
                result.entriesImported += 1
            }
            habit.touch()
        }
        try context.save()
        ReminderScheduler.rescheduleAll(in: context)
        return result
    }

    static func parseDate(_ string: String) -> Day? {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              (1900...2200).contains(parts[0]),
              (1...12).contains(parts[1]),
              (1...Day.daysInMonth(year: parts[0], month: parts[1])).contains(parts[2])
        else { return nil }
        return Day(year: parts[0], month: parts[1], day: parts[2])
    }
}

extension UTType {
    /// Loop Habit Tracker exports its full backup as an SQLite database.
    static let sqliteDatabase = UTType(filenameExtension: "db", conformingTo: .data) ?? .data
}
