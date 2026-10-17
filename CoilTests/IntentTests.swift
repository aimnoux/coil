import AppIntents
import Foundation
import SwiftData
import Testing
@testable import Coil

/// Runs the intents behind widget buttons, the Control Center button and Shortcuts against the
/// app's real store (the same one widgets use), then cleans up.
@MainActor
@Suite(.serialized)
struct IntentTests {
    let context = HabitStore.context

    func makeHabit(_ name: String, kind: HabitKind = .yesNo) -> Habit {
        let habit = Habit(name: name, kind: kind)
        habit.targetValue = 8
        context.insert(habit)
        try? context.save()
        return habit
    }

    func cleanUp(_ habit: Habit) {
        context.delete(habit)
        try? context.save()
    }

    @Test func widgetButtonTogglesToday() async throws {
        let habit = makeHabit("Intent toggle")
        defer { cleanUp(habit) }
        _ = try await ToggleHabitIntent(habitID: habit.id).perform()
        #expect(habit.record(on: .today())?.state == .yes)
        _ = try await ToggleHabitIntent(habitID: habit.id).perform()
        #expect(habit.record(on: .today()) == nil)
    }

    @Test func controlCenterButtonSetsDone() async throws {
        let habit = makeHabit("Intent control")
        defer { cleanUp(habit) }
        var intent = SetHabitDoneIntent(habitID: habit.id)
        intent.value = true
        _ = try await intent.perform()
        #expect(habit.record(on: .today())?.state == .yes)
        intent.value = false
        _ = try await intent.perform()
        #expect(habit.record(on: .today()) == nil)
    }

    @Test func controlCenterButtonLeavesMeasurableHabitsAlone() async throws {
        let habit = makeHabit("Intent water", kind: .measurable)
        defer { cleanUp(habit) }
        habit.setRecord(EntryRecord(state: .yes, amount: 5), on: .today(), in: context)
        var intent = SetHabitDoneIntent(habitID: habit.id)
        intent.value = true
        _ = try await intent.perform()
        #expect(habit.record(on: .today())?.amount == 5)
    }

    @Test func shortcutAddsToMeasurableAmount() async throws {
        let habit = makeHabit("Intent glasses", kind: .measurable)
        defer { cleanUp(habit) }
        var intent = MarkHabitDoneIntent()
        intent.habit = HabitEntity(habit)
        intent.amount = 2
        _ = try await intent.perform()
        _ = try await intent.perform()
        #expect(habit.record(on: .today())?.amount == 4)
    }

    @Test func entityQueryFindsHabits() async throws {
        let habit = makeHabit("Intent query")
        defer { cleanUp(habit) }
        let found = try await HabitQuery().entities(for: [habit.id])
        #expect(found.first?.name == "Intent query")
        let matched = try await HabitQuery().entities(matching: "intent q")
        #expect(matched.contains { $0.id == habit.id })
    }
}
