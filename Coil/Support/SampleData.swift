import Foundation
import SwiftData

/// Demo habits with a few months of realistic history, for previews and screenshots.
enum SampleData {
    static func insert(into context: ModelContext, today: Day = .today()) {
        var random = SeededRandom(seed: 42)

        func make(
            _ name: String,
            question: String,
            color: Int,
            kind: HabitKind = .yesNo,
            frequency: Frequency = .daily,
            unit: String = "",
            target: Double = 0,
            targetType: TargetType = .atLeast,
            days: Int,
            reminder: (Int, Int)? = nil,
            record: (Int, inout SeededRandom) -> EntryRecord?
        ) {
            let habit = Habit(name: name, kind: kind)
            habit.question = question
            habit.colorIndex = color
            habit.frequency = frequency
            habit.unit = unit
            habit.targetValue = target
            habit.targetType = targetType
            habit.createdAt = today.advanced(by: -days).date()
            if let reminder {
                habit.reminderEnabled = true
                habit.reminderHour = reminder.0
                habit.reminderMinute = reminder.1
            }
            context.insert(habit)
            let count = (try? context.fetchCount(FetchDescriptor<Habit>())) ?? 0
            habit.position = count
            for offset in 0...days {
                let day = today.advanced(by: -offset)
                if let r = record(offset, &random) {
                    habit.setRecord(r, on: day, in: context)
                }
            }
        }

        make("Meditate", question: "Did you meditate today?", color: 12, days: 160, reminder: (7, 30)) { offset, r in
            offset == 0 ? nil : (r.next() < (offset < 40 ? 0.9 : 0.65) ? .yes : nil)
        }
        make("Exercise", question: "Did you exercise today?", color: 6, frequency: Frequency(3, 7), days: 200) { offset, r in
            [1, 3, 5].contains(Day.today().advanced(by: -offset).weekday - 1) && r.next() < 0.85 ? .yes : nil
        }
        make("Read", question: "How many pages did you read?", color: 3, kind: .measurable,
             unit: "pages", target: 20, days: 120) { offset, r in
            let x = r.next()
            if x < 0.15 { return nil }
            return EntryRecord(state: .yes, amount: (Double(Int(x * 45)) + 5))
        }
        make("Wake up early", question: "Did you wake up before 7?", color: 10, days: 90, reminder: (6, 45)) { offset, r in
            let x = r.next()
            if offset == 3 { return .skip }
            return x < 0.7 ? .yes : (x < 0.8 ? .no : nil)
        }
        make("Drink water", question: "How many glasses of water?", color: 9, kind: .measurable,
             unit: "glasses", target: 8, days: 60) { offset, r in
            offset == 0 ? EntryRecord(state: .yes, amount: 5) : EntryRecord(state: .yes, amount: Double(4 + Int(r.next() * 7)))
        }
        make("Call parents", question: "Did you call your parents?", color: 14, frequency: .weekly, days: 150) { offset, r in
            offset % 7 == 2 && r.next() < 0.8 ? .yes : nil
        }
        make("Coffee", question: "How many cups of coffee?", color: 16, kind: .measurable, unit: "cups",
             target: 2, targetType: .atMost, days: 45) { offset, r in
            EntryRecord(state: .yes, amount: Double(Int(r.next() * 4)))
        }
        try? context.save()
    }
}

/// Deterministic pseudo-random numbers so demo data looks the same on every launch.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 11) / Double(1 << 53)
    }
}
