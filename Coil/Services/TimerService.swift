import Foundation
import SwiftData
import UserNotifications

/// Starts and stops stopwatch/timer sessions for timed habits and keeps each day's
/// total in sync with its sessions.
enum TimerService {
    /// The running session of a habit, if any.
    static func activeSession(of habit: Habit) -> TimerSession? {
        habit.liveSessions.first(where: \.isRunning)
    }

    /// Sessions that started on a given day, oldest first.
    static func sessions(of habit: Habit, on day: Day) -> [TimerSession] {
        habit.liveSessions
            .filter { Day($0.start) == day }
            .sorted { $0.start < $1.start }
    }

    /// The countdown length in seconds, or `nil` for a stopwatch.
    static func countdown(of habit: Habit) -> TimeInterval? {
        habit.timerMinutes > 0 ? TimeInterval(habit.timerMinutes * 60) : nil
    }

    @discardableResult
    static func start(_ habit: Habit, in context: ModelContext, at date: Date = Date()) -> TimerSession {
        if let running = activeSession(of: habit) { return running }
        let session = TimerSession(start: date)
        context.insert(session)
        session.habit = habit
        habit.touch()
        if let countdown = countdown(of: habit) {
            scheduleFinishedNotification(for: habit, session: session, after: countdown)
        }
        return session
    }

    static func stop(_ session: TimerSession, in context: ModelContext, at date: Date = Date()) {
        guard let habit = session.habit else { return }
        var end = date
        // A countdown never runs longer than its length, even if the app wasn't open when it ended.
        if let countdown = countdown(of: habit) {
            end = min(end, session.start.addingTimeInterval(countdown))
        }
        session.end = max(end, session.start)
        cancelFinishedNotification(for: session)
        recompute(habit, days: [Day(session.start)], in: context)
    }

    /// Stops countdowns that ran out while the app was closed.
    static func finishExpiredCountdowns(in context: ModelContext, now: Date = Date()) {
        let habits = (try? context.fetch(FetchDescriptor<Habit>(predicate: #Predicate { $0.isTimed }))) ?? []
        for habit in habits {
            guard let session = activeSession(of: habit), let countdown = countdown(of: habit) else { continue }
            if now.timeIntervalSince(session.start) >= countdown {
                stop(session, in: context, at: now)
            }
        }
    }

    static func delete(_ session: TimerSession, in context: ModelContext) {
        guard let habit = session.habit else { return }
        let day = Day(session.start)
        cancelFinishedNotification(for: session)
        context.delete(session)
        recompute(habit, days: [day], in: context)
    }

    /// Adds a finished session, e.g. one the user forgot to time.
    @discardableResult
    static func addSession(to habit: Habit, start: Date, end: Date, note: String = "", in context: ModelContext) -> TimerSession {
        let session = TimerSession(start: start, end: max(start, end))
        session.note = note
        context.insert(session)
        session.habit = habit
        recompute(habit, days: [Day(start)], in: context)
        return session
    }

    /// Applies an edited start/end, moving the session's minutes between days if needed.
    static func update(_ session: TimerSession, start: Date, end: Date?, note: String, in context: ModelContext) {
        guard let habit = session.habit else { return }
        let oldDay = Day(session.start)
        session.start = start
        session.end = end.map { max($0, start) }
        session.note = note
        recompute(habit, days: [oldDay, Day(start)], in: context)
    }

    /// Sets each day's amount to the total minutes of its finished sessions.
    /// Days without sessions lose only entries the timer wrote; manual entries stay.
    static func recompute(_ habit: Habit, days: Set<Day>, in context: ModelContext) {
        for day in days {
            let finished = sessions(of: habit, on: day).filter { !$0.isRunning }
            let minutes = finished.reduce(0) { $0 + $1.duration() } / 60
            let entry = habit.entry(on: day, in: context)
            if finished.isEmpty {
                if entry?.source == EntrySource.timer.rawValue {
                    habit.setRecord(nil, on: day, in: context)
                }
            } else {
                let rounded = (minutes * 10).rounded() / 10
                habit.setRecord(EntryRecord(state: .yes, amount: rounded), on: day, in: context, source: .timer)
            }
        }
        habit.touch()
    }

    // MARK: - Notifications

    private static func scheduleFinishedNotification(for habit: Habit, session: TimerSession, after interval: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = habit.name
        content.body = String(localized: "Time's up! \(habit.timerMinutes) minutes done.")
        content.sound = .default
        content.userInfo = [ReminderScheduler.habitIDKey: habit.id.uuidString]
        let request = UNNotificationRequest(
            identifier: "timer-\(session.id.uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    private static func cancelFinishedNotification(for session: TimerSession) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timer-\(session.id.uuidString)"])
    }
}

extension Formatting {
    /// "12:05" or "1:02:05".
    static func clock(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval).rounded(.down))
        let hours = total / 3600, minutes = total % 3600 / 60, seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }

    /// "45 min" or "1 h 20 min".
    static func duration(_ interval: TimeInterval) -> String {
        Duration.seconds(max(0, interval)).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}
