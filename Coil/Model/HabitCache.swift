import Foundation
import SwiftData

/// Remembers each habit's merged day records and statistics until the habit changes.
///
/// Reading thousands of SwiftData entries on every render is slow, so results are keyed by the
/// habit's `revision` (bumped on every entry change) plus the settings that affect statistics.
/// Changes that arrive from outside (iCloud, the widget) clear the whole cache.
@MainActor
final class HabitCache {
    static let shared = HabitCache()

    private struct RecordsValue {
        let revision: Int
        let records: [Day: DayRecord]
    }

    private struct StatsKey: Hashable {
        let id: PersistentIdentifier
        let revision: Int
        let settings: String
        let today: Day
    }

    private var records: [PersistentIdentifier: RecordsValue] = [:]
    private var stats: [StatsKey: HabitStats] = [:]

    func dayRecords(for habit: Habit) -> [Day: DayRecord] {
        let id = habit.persistentModelID
        let revision = habit.revision
        if let cached = records[id], cached.revision == revision {
            return cached.records
        }
        let computed = habit.computeDayRecords()
        records[id] = RecordsValue(revision: revision, records: computed)
        return computed
    }

    func stats(for habit: Habit, today: Day) -> HabitStats {
        let key = StatsKey(
            id: habit.persistentModelID,
            revision: habit.revision,
            settings: settingsSignature(habit),
            today: today
        )
        if let cached = stats[key] { return cached }
        if stats.count > 400 { stats.removeAll(keepingCapacity: true) }
        let computed = HabitStats(data: habit.data, today: today)
        stats[key] = computed
        return computed
    }

    /// Forgets everything, e.g. after changes synced from another device.
    func invalidateAll() {
        records.removeAll()
        stats.removeAll()
    }

    private func settingsSignature(_ habit: Habit) -> String {
        let pauses = habit.livePauses.map { "\($0.startDay)-\($0.endDay)" }.sorted().joined(separator: ",")
        return "\(habit.kindRaw)|\(habit.frequencyNumerator)/\(habit.frequencyDenominator)|\(habit.targetValue)|"
            + "\(habit.targetTypeRaw)|\(habit.createdDay.index)|\(habit.activeWeekdays)|\(pauses)"
    }
}
