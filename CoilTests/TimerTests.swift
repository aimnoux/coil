import Foundation
import SwiftData
import Testing
@testable import Coil

@MainActor
struct TimerTests {
    let container = Persistence.makeContainer(inMemory: true)
    var context: ModelContext { container.mainContext }
    let day = Day(year: 2026, month: 10, day: 15)

    func makeHabit(countdown: Int = 0) -> Habit {
        let habit = Habit(name: "Yoga", kind: .measurable)
        habit.isTimed = true
        habit.timerMinutes = countdown
        habit.targetValue = 20
        habit.createdAt = day.advanced(by: -5).date()
        context.insert(habit)
        return habit
    }

    func at(_ hour: Double, on day: Day? = nil) -> Date {
        (day ?? self.day).date().addingTimeInterval(hour * 3600)
    }

    @Test func stopwatchSessionsAddUpForTheDay() {
        let habit = makeHabit()
        let first = TimerService.start(habit, in: context, at: at(7))
        TimerService.stop(first, in: context, at: at(7.25))
        let second = TimerService.start(habit, in: context, at: at(19))
        TimerService.stop(second, in: context, at: at(19.5))
        #expect(habit.record(on: day)?.amount == 45)
        #expect(TimerService.activeSession(of: habit) == nil)
    }

    @Test func countdownNeverRunsPastItsLength() {
        let habit = makeHabit(countdown: 20)
        let session = TimerService.start(habit, in: context, at: at(7))
        // Stopped an hour later, e.g. the app was closed: only the 20 minutes count.
        TimerService.stop(session, in: context, at: at(8))
        #expect(session.duration() == 20 * 60)
        #expect(habit.record(on: day)?.amount == 20)
    }

    @Test func expiredCountdownsAreFinishedOnLaunch() throws {
        let habit = makeHabit(countdown: 10)
        TimerService.start(habit, in: context, at: at(7))
        try context.save()
        TimerService.finishExpiredCountdowns(in: context, now: at(9))
        #expect(TimerService.activeSession(of: habit) == nil)
        #expect(habit.record(on: day)?.amount == 10)
    }

    @Test func editingASessionFixesAForgottenStopAndMovesDays() {
        let habit = makeHabit()
        let session = TimerService.start(habit, in: context, at: at(22))
        TimerService.stop(session, in: context, at: at(30)) // forgot it overnight: 8 hours
        #expect(habit.record(on: day)?.amount == 480)
        TimerService.update(session, start: at(22), end: at(22.5), note: "Evening", in: context)
        #expect(habit.record(on: day)?.amount == 30)

        let tomorrow = day.advanced(by: 1)
        TimerService.update(session, start: at(8, on: tomorrow), end: at(8.5, on: tomorrow), note: "", in: context)
        #expect(habit.record(on: day) == nil)
        #expect(habit.record(on: tomorrow)?.amount == 30)
    }

    @Test func deletingSessionsKeepsManualEntries() {
        let habit = makeHabit()
        habit.setRecord(EntryRecord(state: .yes, amount: 15), on: day.advanced(by: -1), in: context)
        let session = TimerService.addSession(to: habit, start: at(7), end: at(7.5), in: context)
        TimerService.delete(session, in: context)
        #expect(habit.record(on: day) == nil)
        #expect(habit.record(on: day.advanced(by: -1))?.amount == 15)
    }
}
