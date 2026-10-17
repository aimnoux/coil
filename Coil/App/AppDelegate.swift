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
        useRoundedNavigationTitles()
        Task {
            // Registering categories before the user has decided can trigger the permission prompt
            // on launch, so only do it once notifications are allowed.
            if await ReminderScheduler.authorizationStatus() == .authorized {
                ReminderScheduler.registerCategories()
            }
        }
        return true
    }

    /// Navigation bar titles are UIKit text, so `.fontDesign(.rounded)` doesn't reach them.
    private func useRoundedNavigationTitles() {
        func rounded(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
            let base = UIFont.preferredFont(forTextStyle: style)
            let font = UIFont.systemFont(ofSize: base.pointSize, weight: weight)
            guard let descriptor = font.fontDescriptor.withDesign(.rounded) else { return font }
            return UIFont(descriptor: descriptor, size: base.pointSize)
        }
        let appearance = UINavigationBar.appearance()
        appearance.largeTitleTextAttributes = [.font: rounded(.largeTitle, weight: .bold)]
        appearance.titleTextAttributes = [.font: rounded(.headline, weight: .semibold)]
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
        let userInfo = response.notification.request.content.userInfo
        let plannedDay = userInfo[ReminderScheduler.dayKey] as? Int
        guard let idString = userInfo[ReminderScheduler.habitIDKey] as? String,
              let id = UUID(uuidString: idString)
        else { return }
        await MainActor.run {
            handle(action: action, habitID: id, day: plannedDay.map(Day.init(index:)) ?? Day(deliveredAt))
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
            ReminderScheduler.habitCompleted(habit, on: day)
        case ReminderScheduler.snoozeAction:
            let minutes = UserDefaults.standard.object(forKey: SettingsKey.snoozeMinutes) as? Int ?? 15
            ReminderScheduler.snooze(habit, minutes: minutes, day: day)
        default:
            Router.shared.habitToOpen = habit.id
        }
    }
}
