import SwiftData
import SwiftUI
import WidgetKit

@main
struct CoilApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(SettingsKey.theme) private var theme = AppTheme.system

    var body: some Scene {
        WindowGroup {
            HabitListView()
                .fontDesign(.rounded)
                .preferredColorScheme(theme.colorScheme)
                .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
                    // Keep home screen widgets in step with changes made in the app.
                    WidgetCenter.shared.reloadAllTimelines()
                }
        }
        .modelContainer(Persistence.shared)
    }
}
