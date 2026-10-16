import Foundation
import SQLite3

/// Reads the full backup (`.db`) exported by Loop Habit Tracker for Android
/// (Settings → Export full backup) and converts it into a Coil backup.
///
/// Only the documented database format is used; no Loop code is involved.
enum LoopImporter {
    static func read(databaseAt url: URL) throws -> BackupFile {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            throw BackupError.unreadable
        }
        defer { sqlite3_close(db) }

        let columns = columnNames(of: "Habits", in: db)
        guard !columns.isEmpty else { throw BackupError.unsupportedFormat }

        var habits: [Int64: BackupFile.BackupHabit] = [:]
        var order: [Int64] = []

        try query(db, "SELECT * FROM Habits ORDER BY position") { row in
            let id = row.int("id")
            let isMeasurable = row.int("type") == 1
            let reminderHour = row.optionalInt("reminder_hour")
            let uuid = row.string("uuid").flatMap(uuid(fromHex:)) ?? UUID()
            // Before database version 23, the question was stored in `description`.
            let question = columns.contains("question") ? row.string("question") ?? "" : row.string("description") ?? ""
            let notes = columns.contains("question") ? row.string("description") ?? "" : ""
            habits[id] = BackupFile.BackupHabit(
                id: uuid,
                name: row.string("name") ?? "",
                question: question,
                notes: notes,
                colorIndex: colorIndex(fromLoop: Int(row.int("color"))),
                kind: isMeasurable ? HabitKind.measurable.rawValue : HabitKind.yesNo.rawValue,
                frequencyNumerator: max(1, Int(row.int("freq_num"))),
                frequencyDenominator: max(1, Int(row.int("freq_den"))),
                unit: row.string("unit") ?? "",
                targetValue: row.double("target_value"),
                targetType: Int(row.int("target_type")) == 1 ? TargetType.atMost.rawValue : TargetType.atLeast.rawValue,
                reminderEnabled: reminderHour.map { $0 >= 0 } ?? false,
                reminderHour: Int(max(0, reminderHour ?? 8)),
                reminderMinute: Int(max(0, row.optionalInt("reminder_min") ?? 0)),
                reminderDays: reminderDays(fromLoop: Int(row.optionalInt("reminder_days") ?? 127)),
                position: Int(row.int("position")),
                isArchived: row.int("archived") != 0,
                createdAt: Date(),
                entries: []
            )
            order.append(id)
        }

        try query(db, "SELECT habit, timestamp, value FROM Repetitions ORDER BY timestamp") { row in
            let habitID = row.int("habit")
            guard var habit = habits[habitID] else { return }
            // Timestamps are milliseconds at UTC midnight.
            let day = Day(index: Int(row.int("timestamp") / 86_400_000) - 11_323)
            let value = row.int("value")
            let entry: BackupFile.BackupEntry?
            if habit.kind == HabitKind.measurable.rawValue {
                // Amounts are stored multiplied by 1000.
                entry = value >= 0
                    ? BackupFile.BackupEntry(date: CSVExport.isoDate(day), state: EntryState.yes.rawValue, amount: Double(value) / 1000)
                    : nil
            } else {
                switch value {
                case 2: entry = BackupFile.BackupEntry(date: CSVExport.isoDate(day), state: EntryState.yes.rawValue, amount: 0)
                case 3: entry = BackupFile.BackupEntry(date: CSVExport.isoDate(day), state: EntryState.skip.rawValue, amount: 0)
                case 0: entry = BackupFile.BackupEntry(date: CSVExport.isoDate(day), state: EntryState.no.rawValue, amount: 0)
                default: entry = nil // automatic or unknown values are recomputed by Coil
                }
            }
            if let entry {
                habit.entries.append(entry)
                if let date = Backup.parseDate(entry.date)?.date(), date < habit.createdAt {
                    habit.createdAt = date
                }
                habits[habitID] = habit
            }
        }

        return BackupFile(habits: order.compactMap { habits[$0] })
    }

    /// Loop's 20 colors mapped to the closest color in Coil's palette.
    static func colorIndex(fromLoop index: Int) -> Int {
        let map = [0, 1, 2, 3, 4, 5, 6, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 19, 18, 19]
        return map.indices.contains(index) ? map[index] : HabitColor.defaultIndex
    }

    /// Loop packs reminder days starting with Saturday; Coil starts with Sunday.
    static func reminderDays(fromLoop mask: Int) -> Int {
        if mask & 0b111_1111 == 0b111_1111 { return 0b111_1111 }
        var result = 0
        for loopBit in 0..<7 where mask & (1 << loopBit) != 0 {
            let weekday = loopBit == 0 ? 7 : loopBit // 0 = Saturday, 1 = Sunday … 6 = Friday
            result |= 1 << (weekday - 1)
        }
        return result
    }

    /// Loop stores UUIDs as 32 hex characters without dashes.
    static func uuid(fromHex hex: String) -> UUID? {
        let clean = hex.lowercased().filter(\.isHexDigit)
        guard clean.count >= 32 else { return nil }
        let s = Array(clean.prefix(32))
        let formatted = "\(String(s[0..<8]))-\(String(s[8..<12]))-\(String(s[12..<16]))-\(String(s[16..<20]))-\(String(s[20..<32]))"
        return UUID(uuidString: formatted)
    }

    // MARK: - SQLite helpers

    private struct Row {
        let statement: OpaquePointer
        let columns: [String: Int32]

        func int(_ name: String) -> Int64 {
            guard let i = columns[name] else { return 0 }
            return sqlite3_column_int64(statement, i)
        }

        func optionalInt(_ name: String) -> Int64? {
            guard let i = columns[name], sqlite3_column_type(statement, i) != SQLITE_NULL else { return nil }
            return sqlite3_column_int64(statement, i)
        }

        func double(_ name: String) -> Double {
            guard let i = columns[name] else { return 0 }
            return sqlite3_column_double(statement, i)
        }

        func string(_ name: String) -> String? {
            guard let i = columns[name], let text = sqlite3_column_text(statement, i) else { return nil }
            return String(cString: text)
        }
    }

    private static func query(_ db: OpaquePointer, _ sql: String, _ body: (Row) throws -> Void) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw BackupError.unsupportedFormat
        }
        defer { sqlite3_finalize(statement) }
        var columns: [String: Int32] = [:]
        for i in 0..<sqlite3_column_count(statement) {
            columns[String(cString: sqlite3_column_name(statement, i)).lowercased()] = i
        }
        while sqlite3_step(statement) == SQLITE_ROW {
            try body(Row(statement: statement, columns: columns))
        }
    }

    private static func columnNames(of table: String, in db: OpaquePointer) -> Set<String> {
        var names = Set<String>()
        try? query(db, "PRAGMA table_info(\(table))") { row in
            if let name = row.string("name") { names.insert(name.lowercased()) }
        }
        return names
    }
}
