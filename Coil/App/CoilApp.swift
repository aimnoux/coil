import SwiftData
import SwiftUI

@main
struct CoilApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(SettingsKey.theme) private var theme = AppTheme.system

    var body: some Scene {
        WindowGroup {
            HabitListView()
                .preferredColorScheme(theme.colorScheme)
        }
        .modelContainer(Persistence.shared)
    }
}
