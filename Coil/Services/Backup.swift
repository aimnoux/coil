import CoreTransferable
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// A complete, versioned copy of all habits and entries as JSON.
nonisolated struct BackupFile: Codable, Sendable {
    var format = "coil-backup"
    var version = 1
    var exportedAt = Date()
    var habits: [BackupHabit]

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
    }

    struct BackupEntry: Codable, Sendable {
        /// ISO date, e.g. "2026-10-17".
        var date: String
        var state: Int
        var amount: Double
    }
}

nonisolated extension BackupFile: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { backup in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(Backup.fileName())
            try Backup.encode(backup).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
        .suggestedFileName { _ in Backup.fileName() }
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
        BackupFile(habits: habits.map { habit in
            BackupFile.BackupHabit(
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
                entries: habit.entriesByDay
                    .sorted { $0.key < $1.key }
                    .map { day, entry in
                        BackupFile.BackupEntry(date: CSVExport.isoDate(day), state: entry.stateRaw, amount: entry.amount)
                    }
            )
        })
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

            for entry in item.entries {
                guard let day = parseDate(entry.date), let state = EntryState(rawValue: entry.state) else { continue }
                habit.setRecord(EntryRecord(state: state, amount: entry.amount), on: day, in: context)
                result.entriesImported += 1
            }
            ReminderScheduler.reschedule(habit)
        }
        try context.save()
        return result
    }

    static func parseDate(_ string: String) -> Day? {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Day(year: parts[0], month: parts[1], day: parts[2])
    }
}

extension UTType {
    /// Loop Habit Tracker exports its full backup as an SQLite database.
    static let sqliteDatabase = UTType(filenameExtension: "db", conformingTo: .data) ?? .data
}
