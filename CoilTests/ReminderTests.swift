import Foundation
import SwiftData
import Testing
@testable import Coil

@MainActor
struct ReminderTests {
    let container = Persistence.makeContainer(inMemory: true)
    var context: ModelContext { container.mainContext }
    let today = Day(year: 2026, month: 10, day: 17) // Saturday

    func noon(_ day: Day) -> Date { day.date().addingTimeInterval(12 * 3600) }

    func makeHabit(times: [Int]) -> Habit {
        let habit = Habit(name: "Water")
        habit.createdAt = today.advanced(by: -10).date()
        habit.reminderEnabled = true
        habit.reminderMinutes = times
        context.insert(habit)
        return habit
    }

    @Test func schedulesEveryTimeForTheComingDaysButNotThePast() {
        let habit = makeHabit(times: [9 * 60, 13 * 60, 18 * 60])
        let plan = ReminderScheduler.plannedReminders(habits: [habit], today: today, now: noon(today))
        // At noon today only 13:00 and 18:00 are still ahead.
        #expect(plan.filter { $0.day == today }.map(\.minute) == [13 * 60, 18 * 60])
        #expect(plan.filter { $0.day == today.advanced(by: 1) }.count == 3)
        #expect(plan.count <= ReminderScheduler.budget)
    }

    @Test func skipsTodayOnceDone() {
        let habit = makeHabit(times: [18 * 60])
        habit.setRecord(.yes, on: today, in: context)
        let plan = ReminderScheduler.plannedReminders(habits: [habit], today: today, now: noon(today))
        #expect(!plan.contains { $0.day == today })
        #expect(plan.contains { $0.day == today.advanced(by: 1) })
    }

    @Test func skipsPausedDaysAndUnselectedWeekdays() {
        let habit = makeHabit(times: [18 * 60])
        let pause = HabitPause(start: today.advanced(by: 1), end: today.advanced(by: 2))
        context.insert(pause)
        pause.habit = habit
        habit.reminderDays = 0b111_1110 // no Sundays
        let plan = ReminderScheduler.plannedReminders(habits: [habit], today: today, now: noon(today))
        let days = Set(plan.map(\.day))
        #expect(!days.contains(today.advanced(by: 1)))
        #expect(!days.contains(today.advanced(by: 2)))
        #expect(!plan.contains { $0.day.weekday == 1 })
    }

    @Test func staysWithinTheNotificationBudget() {
        let habits = (0..<10).map { _ in makeHabit(times: [8 * 60, 12 * 60, 20 * 60]) }
        let plan = ReminderScheduler.plannedReminders(habits: habits, today: today, now: today.date())
        #expect(plan.count <= ReminderScheduler.budget)
        // Soonest first, so tomorrow is never dropped in favour of next week.
        #expect(plan.contains { $0.day == today })
    }

    @Test func storesMultipleReminderTimes() {
        let habit = makeHabit(times: [20 * 60, 8 * 60, 8 * 60])
        #expect(habit.reminderMinutes == [8 * 60, 20 * 60])
        #expect(habit.reminderHour == 8)
    }
}
