import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Habit.position) private var habits: [Habit]

    @AppStorage(SettingsKey.theme) private var theme = AppTheme.system
    @AppStorage(SettingsKey.firstWeekday) private var firstWeekday = 0
    @AppStorage(SettingsKey.todayOnRight) private var todayOnRight = false
    @AppStorage(SettingsKey.longPressToToggle) private var longPressToToggle = false
    @AppStorage(SettingsKey.skipEnabled) private var skipEnabled = false
    @AppStorage(SettingsKey.showQuestionMarks) private var showQuestionMarks = false
    @AppStorage(SettingsKey.snoozeMinutes) private var snoozeMinutes = 15

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var importing = false
    @State private var importMessage: ImportMessage?

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                checkmarksSection
                remindersSection
                dataSection
                syncSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $importing,
                allowedContentTypes: [.json, .sqliteDatabase, .data],
                onCompletion: handleImport
            )
            .alert(item: $importMessage) { message in
                Alert(title: Text(message.title), message: Text(message.body))
            }
            .task(id: scenePhase) {
                notificationStatus = await ReminderScheduler.authorizationStatus()
            }
        }
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", systemImage: "circle.lefthalf.filled", selection: $theme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.title).tag(theme)
                }
            }
            Picker("First Day of Week", systemImage: "calendar", selection: $firstWeekday) {
                Text("System").tag(0)
                Text(Calendar.current.weekdaySymbols[1]).tag(2)
                Text(Calendar.current.weekdaySymbols[0]).tag(1)
                Text(Calendar.current.weekdaySymbols[6]).tag(7)
            }
            Toggle("Today on the Right", systemImage: "arrow.right.to.line", isOn: $todayOnRight)
        }
    }

    private var checkmarksSection: some View {
        Section {
            Toggle("Press and Hold to Check Off", systemImage: "hand.tap", isOn: $longPressToToggle)
            Toggle("Allow Skipping Days", systemImage: "arrow.turn.up.right", isOn: $skipEnabled)
            Toggle("Show Question Marks", systemImage: "questionmark", isOn: $showQuestionMarks)
        } header: {
            Text("Checkmarks")
        } footer: {
            Text("Skipped days, like a sick day or holiday, don't break your streak or lower habit strength. Question marks show days you haven't entered yet, so they look different from days you marked as not done.")
        }
    }

    private var remindersSection: some View {
        Section {
            switch notificationStatus {
            case .denied:
                Button {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    Label("Notifications Are Off", systemImage: "bell.slash")
                        .foregroundStyle(.red)
                }
            case .notDetermined:
                Button("Allow Notifications", systemImage: "bell.badge") {
                    Task {
                        await ReminderScheduler.requestAuthorization()
                        notificationStatus = await ReminderScheduler.authorizationStatus()
                    }
                }
            default:
                Label("Notifications Are On", systemImage: "bell")
            }
            Picker("Remind Me Later After", systemImage: "clock.arrow.circlepath", selection: $snoozeMinutes) {
                ForEach([5, 10, 15, 30, 60, 120], id: \.self) { minutes in
                    Text(Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                        .tag(minutes)
                }
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text("Set a reminder for each habit in its settings. From a reminder you can check off the habit or ask to be reminded later.")
        }
    }

    private var dataSection: some View {
        Section {
            ShareLink(
                items: [CSVExport.habitsFile(habits), CSVExport.checkmarksFile(habits)],
                preview: { file in SharePreview(file.name) }
            ) {
                Label("Export as CSV", systemImage: "tablecells")
            }
            .disabled(habits.isEmpty)
            ShareLink(item: Backup.make(from: habits), preview: SharePreview(Backup.fileName())) {
                Label("Export Full Backup", systemImage: "externaldrive")
            }
            .disabled(habits.isEmpty)
            Button {
                importing = true
            } label: {
                Label("Import Backup", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Data")
        } footer: {
            Text("Import a Coil backup, or the full backup (.db file) from Loop Habit Tracker for Android: in Loop, open Settings → Export full backup.")
        }
    }

    private var syncSection: some View {
        Section {
            LabeledContent {
                Text(Persistence.iCloudSyncEnabled ? "On" : "Off")
            } label: {
                Label("iCloud Sync", systemImage: "icloud")
            }
        } footer: {
            Text(Persistence.iCloudSyncEnabled
                ? "Your habits sync across your devices through your private iCloud account."
                : "Your habits are stored only on this device. Export a backup from time to time to keep them safe.")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: appVersion)
            Link(destination: URL(string: "https://github.com/aimnoux/coil/blob/main/docs/privacy-policy.md")!) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }
        } header: {
            Text("About")
        } footer: {
            Text("Coil is free, has no ads and collects no data. Inspired by Loop Habit Tracker.")
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Import

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let summary = try Backup.importFile(at: url, into: context)
                importMessage = ImportMessage(
                    title: String(localized: "Import Complete"),
                    body: String(localized: "Added \(summary.habitsAdded) habits, updated \(summary.habitsUpdated), imported \(summary.entriesImported) entries.")
                )
            } catch {
                importMessage = ImportMessage(
                    title: String(localized: "Import Failed"),
                    body: error.localizedDescription
                )
            }
        case .failure(let error):
            importMessage = ImportMessage(title: String(localized: "Import Failed"), body: error.localizedDescription)
        }
    }
}

private struct ImportMessage: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}

#Preview {
    SettingsView()
        .modelContainer(Persistence.preview)
}
