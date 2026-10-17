import SwiftData
import SwiftUI
import WidgetKit

@main
struct CoilApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(SettingsKey.theme) private var theme = AppTheme.system
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HabitListView()
                .overlay(alignment: .bottom) { UndoToast() }
                .fontDesign(.rounded)
                .preferredColorScheme(theme.colorScheme)
                .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
                    // Changes synced from iCloud or written by the widget bypass `Habit.touch()`.
                    HabitCache.shared.invalidateAll()
                }
                .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
                    // Keep home screen widgets in step with changes made in the app.
                    WidgetCenter.shared.reloadAllTimelines()
                }
        }
        .modelContainer(Persistence.shared)
        .onChange(of: scenePhase) { _, phase in
            // Write everything before iOS suspends or closes the app.
            if phase != .active, Persistence.shared.mainContext.hasChanges {
                try? Persistence.shared.mainContext.save()
            }
        }
    }
}
