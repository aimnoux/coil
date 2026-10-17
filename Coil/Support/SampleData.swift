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

        make(String(localized: "Meditate"), question: String(localized: "Did you meditate today?"), color: 12, days: 160, reminder: (7, 30)) { offset, r in
            offset == 0 ? nil : (r.next() < (offset < 40 ? 0.9 : 0.65) ? .yes : nil)
        }
        make(String(localized: "Exercise"), question: String(localized: "Did you exercise today?"), color: 6, frequency: Frequency(3, 7), days: 200) { offset, r in
            [1, 3, 5].contains(Day.today().advanced(by: -offset).weekday - 1) && r.next() < 0.85 ? .yes : nil
        }
        make(String(localized: "Read"), question: String(localized: "How many pages did you read?"), color: 3, kind: .measurable,
             unit: String(localized: "pages"), target: 20, days: 120) { offset, r in
            let x = r.next()
            if x < 0.15 { return nil }
            return EntryRecord(state: .yes, amount: (Double(Int(x * 45)) + 5))
        }
        make(String(localized: "Wake up early"), question: String(localized: "Did you wake up before 7?"), color: 10, days: 90, reminder: (6, 45)) { offset, r in
            let x = r.next()
            if offset == 3 { return .skip }
            return x < 0.7 ? .yes : (x < 0.8 ? .no : nil)
        }
        make(String(localized: "Drink water"), question: String(localized: "How many glasses of water?"), color: 9, kind: .measurable,
             unit: String(localized: "glasses"), target: 8, days: 60) { offset, r in
            offset == 0 ? EntryRecord(state: .yes, amount: 5) : EntryRecord(state: .yes, amount: Double(4 + Int(r.next() * 7)))
        }
        make(String(localized: "Call parents"), question: String(localized: "Did you call your parents?"), color: 14, frequency: .weekly, days: 150) { offset, r in
            offset % 7 == 2 && r.next() < 0.8 ? .yes : nil
        }
        make(String(localized: "Coffee"), question: String(localized: "How many cups of coffee?"), color: 16, kind: .measurable, unit: String(localized: "cups"),
             target: 2, targetType: .atMost, days: 45) { offset, r in
            EntryRecord(state: .yes, amount: Double(Int(r.next() * 4)))
        }
        make(String(localized: "No sugar"), question: String(localized: "Stayed away from sweets today?"), color: 15,
             kind: .quit, days: 75) { offset, r in
            [9, 23, 51].contains(offset) ? .no : nil
        }

        // A timed habit with stopwatch sessions.
        let yoga = Habit(name: String(localized: "Yoga"), kind: .measurable)
        yoga.question = String(localized: "How long did you practise yoga?")
        yoga.colorIndex = 7
        yoga.iconName = "figure.yoga"
        yoga.isTimed = true
        yoga.timerMinutes = 20
        yoga.unit = String(localized: "min")
        yoga.targetValue = 20
        yoga.createdAt = today.advanced(by: -40).date()
        yoga.position = 99
        context.insert(yoga)
        for offset in 1...40 where random.next() < 0.7 {
            let start = today.advanced(by: -offset).date().addingTimeInterval(7 * 3600 + random.next() * 3600)
            TimerService.addSession(to: yoga, start: start, end: start.addingTimeInterval((12 + random.next() * 18) * 60), in: context)
        }

        // Icons, groups, a challenge and a short pause, so every feature shows up.
        let all = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        func habit(_ color: Int) -> Habit? { all.first { $0.colorIndex == color } }
        let morning = HabitGroup(name: String(localized: "Morning"), position: 0)
        let health = HabitGroup(name: String(localized: "Health"), position: 1)
        context.insert(morning)
        context.insert(health)
        let setup: [(Int, String, HabitGroup)] = [
            (12, "brain.head.profile", morning),
            (10, "sunrise", morning),
            (3, "book", morning),
            (6, "figure.run", health),
            (9, "drop", health),
            (16, "cup.and.saucer", health),
            (15, "nosign", health),
            (14, "phone", morning),
            (7, "figure.yoga", morning),
        ]
        for (color, icon, group) in setup {
            habit(color)?.iconName = icon
            habit(color)?.group = group
        }
        if let read = habit(3) {
            read.challengeDays = 30
            read.challengeStartDay = today.advanced(by: -11).index
        }
        if let exercise = habit(6) {
            let pause = HabitPause(start: today.advanced(by: -30), end: today.advanced(by: -24), note: "Vacation")
            context.insert(pause)
            pause.habit = exercise
        }
        if let meditate = habit(12) {
            meditate.reminderMinutes = [7 * 60 + 30, 21 * 60]
        }

        if let meditate = try? context.fetch(FetchDescriptor<Habit>()).first(where: { $0.colorIndex == 12 }) {
            meditate.setNote(String(localized: "Twenty minutes in the park, very calm."), on: today.advanced(by: -2), in: context)
            meditate.setNote(String(localized: "Hard to focus today."), on: today.advanced(by: -9), in: context)
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
