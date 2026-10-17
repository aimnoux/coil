import Foundation
import SQLite3
import SwiftData
import Testing
@testable import Coil

@MainActor
struct BackupTests {
    @Test func backupRoundTrip() throws {
        let sourceContainer = Persistence.makeContainer(inMemory: true)
        let source = sourceContainer.mainContext
        let habit = Habit(name: "Read", kind: .measurable)
        habit.unit = "pages"
        habit.targetValue = 20
        habit.frequency = .weekly
        source.insert(habit)
        let today = Day.today()
        habit.setRecord(EntryRecord(state: .yes, amount: 12.5), on: today, in: source)
        habit.setRecord(.skip, on: today.advanced(by: -1), in: source)
        habit.setNote("Felt great", on: today, in: source)
        habit.setNote("Only a note", on: today.advanced(by: -2), in: source)
        let group = HabitGroup(name: "Morning")
        source.insert(group)
        habit.group = group
        habit.iconName = "book"
        habit.reminderMinutes = [480, 1260]
        habit.challengeDays = 30
        habit.challengeStartDay = today.index
        let pause = HabitPause(start: today.advanced(by: -10), end: today.advanced(by: -8), note: "Trip")
        source.insert(pause)
        pause.habit = habit
        let session = TimerSession(start: Date(timeIntervalSince1970: 1_000), end: Date(timeIntervalSince1970: 1_600))
        source.insert(session)
        session.habit = habit

        let data = try Backup.encode(Backup.make(from: [habit]))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BackupFile.self, from: data)

        let targetContainer = Persistence.makeContainer(inMemory: true)
        let target = targetContainer.mainContext
        let result = try Backup.restore(decoded, into: target)
        #expect(result.habitsAdded == 1)
        #expect(result.entriesImported == 3)

        let restored = try #require(try target.fetch(FetchDescriptor<Habit>()).first)
        #expect(restored.id == habit.id)
        #expect(restored.name == "Read")
        #expect(restored.unit == "pages")
        #expect(restored.frequency == .weekly)
        #expect(restored.record(on: today) == EntryRecord(state: .yes, amount: 12.5))
        #expect(restored.record(on: today.advanced(by: -1))?.state == .skip)
        #expect(restored.note(on: today) == "Felt great")
        #expect(restored.note(on: today.advanced(by: -2)) == "Only a note")
        #expect(restored.record(on: today.advanced(by: -2)) == nil)
        #expect(restored.group?.name == "Morning")
        #expect(restored.iconName == "book")
        #expect(restored.reminderMinutes == [480, 1260])
        #expect(restored.challengeDays == 30)
        #expect(restored.livePauses.first?.note == "Trip")
        #expect(restored.liveSessions.first?.duration() == 600)
        #expect(restored.stats().checkmark(on: today.advanced(by: -2)) == .unknown)

        // Importing the same backup again updates instead of duplicating.
        let again = try Backup.restore(decoded, into: target)
        #expect(again.habitsAdded == 0)
        #expect(again.habitsUpdated == 1)
        #expect(try target.fetchCount(FetchDescriptor<Habit>()) == 1)
        #expect(restored.livePauses.count == 1)
        #expect(restored.liveSessions.count == 1)
        #expect(restored.liveEntries.count == 3)
    }

    @Test func importsLoopDatabase() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("loop-\(UUID()).db")
        defer { try? FileManager.default.removeItem(at: url) }
        try makeLoopDatabase(at: url)

        let backup = try LoopImporter.read(databaseAt: url)
        #expect(backup.habits.count == 2)

        let meditate = try #require(backup.habits.first { $0.name == "Meditate" })
        #expect(meditate.question == "Did you meditate?")
        #expect(meditate.notes == "Morning")
        #expect(meditate.frequencyNumerator == 3)
        #expect(meditate.frequencyDenominator == 7)
        #expect(meditate.reminderEnabled)
        #expect(meditate.reminderHour == 7)
        #expect(meditate.reminderDays == 0b111_1111)
        #expect(meditate.id == UUID(uuidString: "0123456789ABCDEF0123456789ABCDEF".inserting()))
        // YES_AUTO (1) and UNKNOWN (-1) are not imported unless they carry a note; YES, NO and SKIP are.
        #expect(meditate.entries.map(\.date) == ["2026-10-14", "2026-10-15", "2026-10-16", "2026-10-18"])
        #expect(meditate.entries.map(\.state) == [EntryState.yes.rawValue, EntryState.no.rawValue, EntryState.skip.rawValue, Entry.noState])
        #expect(meditate.entries.last?.note == "Travel day")

        let water = try #require(backup.habits.first { $0.name == "Water" })
        #expect(water.kind == HabitKind.measurable.rawValue)
        #expect(water.unit == "glasses")
        #expect(water.targetValue == 8)
        #expect(water.targetType == TargetType.atLeast.rawValue)
        #expect(water.isArchived)
        #expect(!water.reminderEnabled)
        #expect(water.entries.first?.amount == 6.5)
        #expect(water.entries.last?.state == EntryState.skip.rawValue)

        let container = Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let result = try Backup.restore(backup, into: context)
        #expect(result.habitsAdded == 2)
        #expect(result.entriesImported == 6)
    }

    @Test func loopReminderDaysStartOnSaturday() {
        // Saturday + Monday in Loop's packing → Saturday (bit 6) + Monday (bit 1) in Coil's.
        #expect(LoopImporter.reminderDays(fromLoop: 0b0000101) == (1 << 6 | 1 << 1))
        #expect(LoopImporter.reminderDays(fromLoop: 127) == 127)
    }

    // MARK: - Fixture

    private func makeLoopDatabase(at url: URL) throws {
        var db: OpaquePointer?
        try #require(sqlite3_open(url.path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }

        // 2026-10-14 00:00 UTC in milliseconds.
        let base: Int64 = 1_791_936_000_000
        let day: Int64 = 86_400_000
        let sql = """
        CREATE TABLE Habits (id integer primary key autoincrement, archived integer, color integer,
            description text, freq_den integer, freq_num integer, highlight integer, name text,
            position integer, reminder_hour integer, reminder_min integer,
            reminder_days integer not null default 127, type integer not null default 0,
            target_type integer not null default 0, target_value real not null default 0,
            unit text not null default "", question text, uuid text);
        CREATE TABLE Repetitions (id integer primary key autoincrement, habit integer not null,
            timestamp integer not null, value integer not null, notes text);
        INSERT INTO Habits VALUES (1, 0, 14, 'Morning', 7, 3, 0, 'Meditate', 0, 7, 30, 127, 0, 0, 0, '', 'Did you meditate?', '0123456789abcdef0123456789abcdef');
        INSERT INTO Habits VALUES (2, 1, 9, '', 1, 1, 0, 'Water', 1, NULL, NULL, 127, 1, 0, 8, 'glasses', 'How much water?', 'fedcba9876543210fedcba9876543210');
        INSERT INTO Repetitions (habit, timestamp, value) VALUES (1, \(base), 2);
        INSERT INTO Repetitions (habit, timestamp, value) VALUES (1, \(base + day), 0);
        INSERT INTO Repetitions (habit, timestamp, value) VALUES (1, \(base + 2 * day), 3);
        INSERT INTO Repetitions (habit, timestamp, value) VALUES (1, \(base + 3 * day), 1);
        INSERT INTO Repetitions (habit, timestamp, value, notes) VALUES (1, \(base + 4 * day), -1, 'Travel day');
        INSERT INTO Repetitions (habit, timestamp, value) VALUES (2, \(base), 6500);
        INSERT INTO Repetitions (habit, timestamp, value) VALUES (2, \(base + day), 3);
        """
        try #require(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK)
    }
}

private extension String {
    /// Formats 32 hex characters as a UUID string.
    func inserting() -> String {
        let s = Array(self)
        return "\(String(s[0..<8]))-\(String(s[8..<12]))-\(String(s[12..<16]))-\(String(s[16..<20]))-\(String(s[20..<32]))"
    }
}
