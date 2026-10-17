import Foundation
import SwiftData
import Testing
@testable import Coil

/// Ten years of history for twenty habits: everything the list and detail screens compute
/// must stay fast enough to run on every render.
@MainActor
struct PerformanceTests {
    let container = Persistence.makeContainer(inMemory: true)

    func makeHistory(habits: Int = 20, days: Int = 3650) -> [Habit] {
        let context = container.mainContext
        let today = Day.today()
        var random = SeededRandom(seed: 7)
        var result: [Habit] = []
        for h in 0..<habits {
            let habit = Habit(name: "Habit \(h)", kind: h % 3 == 0 ? .measurable : .yesNo)
            habit.targetValue = 10
            habit.frequency = h % 2 == 0 ? .daily : Frequency(3, 7)
            habit.createdAt = today.advanced(by: -days).date()
            context.insert(habit)
            for offset in 0..<days where random.next() < 0.7 {
                let entry = Entry(day: today.advanced(by: -offset), record: EntryRecord(state: .yes, amount: Double(Int(random.next() * 20))))
                context.insert(entry)
                entry.habit = habit
            }
            result.append(habit)
        }
        return result
    }

    func time(_ label: String, _ body: () -> Void) -> Duration {
        let clock = ContinuousClock()
        let elapsed = clock.measure(body)
        print("⏱ \(label): \(elapsed)")
        return elapsed
    }

    @Test func listScreenStatsForTwentyHabitsWithTenYears() {
        let habits = makeHistory()
        let today = Day.today()
        let elapsed = time("list stats (20 habits × 10 years)") {
            for habit in habits {
                let stats = habit.stats(today: today)
                _ = stats.currentScore
                _ = stats.isCompletedToday
                for offset in 0..<7 { _ = stats.checkmark(on: today.advanced(by: -offset)) }
            }
        }
        #expect(elapsed < .milliseconds(400))

        // A second render with nothing changed comes from the cache.
        let cached = time("list stats, cached") {
            for habit in habits { _ = habit.stats(today: today).currentScore }
        }
        #expect(cached < .milliseconds(20))
    }

    @Test func detailScreenForTenYears() {
        let habit = makeHistory(habits: 1)[0]
        let today = Day.today()
        let elapsed = time("detail screen (10 years)") {
            let stats = habit.stats(today: today)
            _ = stats.scoreSeries(bucket: .week, firstWeekday: 2)
            _ = stats.history(bucket: .month, firstWeekday: 2)
            _ = stats.bestStreaks()
            _ = stats.currentStreak
            _ = stats.weekdayFrequency()
            _ = habit.notedDays
            for offset in 0..<370 { _ = stats.checkmark(on: today.advanced(by: -offset)) }
        }
        #expect(elapsed < .milliseconds(150))
    }
}
