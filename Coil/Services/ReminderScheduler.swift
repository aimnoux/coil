import Foundation
import SwiftData
import UserNotifications

/// Schedules reminders as individual notifications for the coming days.
///
/// Repeating notifications can't be skipped for a single day, so instead each reminder is
/// scheduled for a specific date. That lets Coil leave out days when the habit is already done
/// or paused. iOS keeps at most 64 pending notifications, so the number of days scheduled ahead
/// shrinks as the number of reminders grows; the schedule is refreshed every time the app
/// becomes active and whenever a habit changes.
enum ReminderScheduler {
    nonisolated static let yesNoCategory = "HABIT_REMINDER"
    nonisolated static let measurableCategory = "HABIT_REMINDER_MEASURABLE"
    nonisolated static let doneAction = "DONE"
    nonisolated static let snoozeAction = "SNOOZE"
    nonisolated static let habitIDKey = "habitID"
    nonisolated static let dayKey = "day"

    /// Leave a little room under the system limit of 64 for snoozes and timers.
    static let budget = 58
    static let maxDaysAhead = 14

    private static var center: UNUserNotificationCenter { .current() }

    static func registerCategories() {
        let done = UNNotificationAction(
            identifier: doneAction,
            title: String(localized: "Done"),
            options: [],
            icon: UNNotificationActionIcon(systemImageName: "checkmark")
        )
        let snooze = UNNotificationAction(
            identifier: snoozeAction,
            title: String(localized: "Remind Me Later"),
            options: [],
            icon: UNNotificationActionIcon(systemImageName: "clock")
        )
        center.setNotificationCategories([
            UNNotificationCategory(identifier: yesNoCategory, actions: [done, snooze], intentIdentifiers: []),
            UNNotificationCategory(identifier: measurableCategory, actions: [snooze], intentIdentifiers: []),
        ])
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if granted { registerCategories() }
        return granted
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Rebuilds the whole schedule from the current habits.
    static func rescheduleAll(in context: ModelContext, today: Day = .today()) {
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        let plan = makePlan(habits: habits, today: today, now: Date())
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let stale = await center.pendingNotificationRequests()
                .map(\.identifier)
                .filter { $0.hasPrefix("reminder-") }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            for request in plan { center.add(request) }
        }
    }

    /// Call after a habit changed; reschedules everything so the shared budget stays fair.
    static func reschedule(_ habit: Habit) {
        guard let context = habit.modelContext else { return }
        rescheduleAll(in: context)
    }

    static func cancel(_ habit: Habit) {
        let prefix = "reminder-\(habit.id.uuidString)"
        let snoozeID = "snooze-\(habit.id.uuidString)"
        center.getPendingNotificationRequests { pending in
            let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) } + [snoozeID]
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
        removeDeliveredReminders(for: habit)
    }

    /// The habit was done on a day: drop that day's remaining reminders and clear shown ones.
    static func habitCompleted(_ habit: Habit, on day: Day) {
        let prefix = "reminder-\(habit.id.uuidString)-\(day.index)-"
        center.getPendingNotificationRequests { pending in
            let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
        removeDeliveredReminders(for: habit)
    }

    /// Clears reminders already shown for a habit, e.g. once it's checked off.
    static func removeDeliveredReminders(for habit: Habit) {
        let id = habit.id.uuidString
        center.getDeliveredNotifications { notifications in
            let ids = notifications
                .filter { $0.request.content.userInfo[habitIDKey] as? String == id }
                .map(\.request.identifier)
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    static func snooze(_ habit: Habit, minutes: Int, day: Day) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, minutes) * 60), repeats: false)
        let request = UNNotificationRequest(
            identifier: "snooze-\(habit.id.uuidString)",
            content: makeContent(for: habit, day: day),
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: - Planning

    /// One planned reminder, before it becomes a notification request (exposed for tests).
    struct PlannedReminder: Equatable {
        let habitID: UUID
        let day: Day
        let minute: Int
    }

    /// Which reminders to schedule: future times only, skipping done and paused days,
    /// soonest first, within the notification budget.
    static func plannedReminders(habits: [Habit], today: Day, now: Date) -> [PlannedReminder] {
        let active = habits.filter { $0.reminderEnabled && !$0.isArchived && $0.reminderDays != 0 }
        let perDay = active.reduce(0) { $0 + $1.reminderMinutes.count }
        guard perDay > 0 else { return [] }
        let daysAhead = max(1, min(maxDaysAhead, budget / perDay))
        let calendar = Calendar.current
        let nowMinute = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)

        var result: [PlannedReminder] = []
        for habit in active {
            let doneToday = habit.stats(today: today).isCompletedToday && !habit.isQuit
            for offset in 0..<daysAhead {
                let day = today.advanced(by: offset)
                guard habit.remindsOn(weekday: day.weekday), !habit.isPaused(on: day) else { continue }
                if offset == 0 && doneToday { continue }
                for minute in habit.reminderMinutes {
                    if offset == 0 && minute <= nowMinute { continue }
                    result.append(PlannedReminder(habitID: habit.id, day: day, minute: minute))
                }
            }
        }
        result.sort { ($0.day, $0.minute) < ($1.day, $1.minute) }
        return Array(result.prefix(budget))
    }

    private static func makePlan(habits: [Habit], today: Day, now: Date) -> [UNNotificationRequest] {
        let byID = Dictionary(habits.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return plannedReminders(habits: habits, today: today, now: now).compactMap { planned in
            guard let habit = byID[planned.habitID] else { return nil }
            var components = Calendar.current.dateComponents([.year, .month, .day], from: planned.day.date())
            components.hour = planned.minute / 60
            components.minute = planned.minute % 60
            return UNNotificationRequest(
                identifier: "reminder-\(habit.id.uuidString)-\(planned.day.index)-\(planned.minute)",
                content: makeContent(for: habit, day: planned.day),
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
        }
    }

    private static func makeContent(for habit: Habit, day: Day) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = habit.name
        if habit.isQuit {
            let clean = habit.stats().currentStreak?.length ?? 0
            content.body = habit.question.isEmpty
                ? String(localized: "\(clean) clean days. Keep going!")
                : habit.question
        } else {
            content.body = habit.question.isEmpty
                ? String(localized: "Time to keep your streak going.")
                : habit.question
        }
        content.sound = .default
        content.threadIdentifier = habit.id.uuidString
        content.categoryIdentifier = habit.isMeasurable || habit.isQuit ? measurableCategory : yesNoCategory
        content.userInfo = [habitIDKey: habit.id.uuidString, dayKey: day.index]
        return content
    }
}
