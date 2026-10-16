import SwiftData
import SwiftUI
import UserNotifications

/// Routes navigation requests (from notifications) to the habit list.
@Observable
final class Router {
    static let shared = Router()
    var habitToOpen: UUID?
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Task {
            // Registering categories before the user has decided can trigger the permission prompt
            // on launch, so only do it once notifications are allowed.
            if await ReminderScheduler.authorizationStatus() == .authorized {
                ReminderScheduler.registerCategories()
            }
        }
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let action = response.actionIdentifier
        // The day the reminder was delivered, so "Done" on yesterday's reminder marks yesterday.
        let deliveredAt = response.notification.date
        guard let idString = response.notification.request.content.userInfo[ReminderScheduler.habitIDKey] as? String,
              let id = UUID(uuidString: idString)
        else { return }
        await MainActor.run {
            handle(action: action, habitID: id, day: Day(deliveredAt))
        }
    }

    private func handle(action: String, habitID: UUID, day: Day) {
        let context = Persistence.shared.mainContext
        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.id == habitID })
        guard let habit = try? context.fetch(descriptor).first else { return }

        switch action {
        case ReminderScheduler.doneAction:
            habit.setRecord(.yes, on: day, in: context)
            try? context.save()
        case ReminderScheduler.snoozeAction:
            let minutes = UserDefaults.standard.object(forKey: SettingsKey.snoozeMinutes) as? Int ?? 15
            ReminderScheduler.snooze(habit, minutes: minutes)
        default:
            Router.shared.habitToOpen = habit.id
        }
    }
}
