import Foundation
import UserNotifications

/// Schedules per-habit reminders as repeating local notifications, one per selected weekday.
enum ReminderScheduler {
    nonisolated static let yesNoCategory = "HABIT_REMINDER"
    nonisolated static let measurableCategory = "HABIT_REMINDER_MEASURABLE"
    nonisolated static let doneAction = "DONE"
    nonisolated static let snoozeAction = "SNOOZE"
    nonisolated static let habitIDKey = "habitID"

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
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    static func reschedule(_ habit: Habit) {
        cancel(habit)
        guard habit.reminderEnabled, !habit.isArchived else { return }
        let content = makeContent(for: habit)
        for weekday in 1...7 where habit.remindsOn(weekday: weekday) {
            var components = DateComponents()
            components.weekday = weekday
            components.hour = habit.reminderHour
            components.minute = habit.reminderMinute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: identifier(habit.id, weekday: weekday),
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    static func rescheduleAll(_ habits: [Habit]) {
        center.removeAllPendingNotificationRequests()
        habits.forEach(reschedule)
    }

    static func cancel(_ habit: Habit) {
        let ids = (1...7).map { identifier(habit.id, weekday: $0) } + [snoozeIdentifier(habit.id)]
        center.removePendingNotificationRequests(withIdentifiers: ids)
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

    static func snooze(_ habit: Habit, minutes: Int) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, minutes) * 60), repeats: false)
        let request = UNNotificationRequest(
            identifier: snoozeIdentifier(habit.id),
            content: makeContent(for: habit),
            trigger: trigger
        )
        center.add(request)
    }

    private static func makeContent(for habit: Habit) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = habit.name
        content.body = habit.question.isEmpty
            ? String(localized: "Time to keep your streak going.")
            : habit.question
        content.sound = .default
        content.threadIdentifier = habit.id.uuidString
        content.categoryIdentifier = habit.isMeasurable ? measurableCategory : yesNoCategory
        content.userInfo = [habitIDKey: habit.id.uuidString]
        return content
    }

    private static func identifier(_ id: UUID, weekday: Int) -> String {
        "\(id.uuidString)-\(weekday)"
    }

    private static func snoozeIdentifier(_ id: UUID) -> String {
        "\(id.uuidString)-snooze"
    }
}
