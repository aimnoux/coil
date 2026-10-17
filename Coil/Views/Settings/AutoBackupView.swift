import SwiftData
import SwiftUI

/// Settings for automatic backups, plus backing up and restoring by hand.
struct AutoBackupView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(AutoBackup.frequencyKey) private var frequency = AutoBackup.Frequency.weekly
    @AppStorage(AutoBackup.keepKey) private var keep = 10

    @State private var backups: [URL] = []
    @State private var restoring: URL?
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                Picker("Back Up", selection: $frequency) {
                    Text("Off").tag(AutoBackup.Frequency.off)
                    Text("Every day").tag(AutoBackup.Frequency.daily)
                    Text("Every week").tag(AutoBackup.Frequency.weekly)
                    Text("Every month").tag(AutoBackup.Frequency.monthly)
                }
                Picker("Keep", selection: $keep) {
                    Text("Last 5").tag(5)
                    Text("Last 10").tag(10)
                    Text("Last 30").tag(30)
                    Text("All").tag(0)
                }
                .onChange(of: keep) { _, _ in
                    AutoBackup.prune()
                    reload()
                }
                if let last = AutoBackup.lastBackup {
                    LabeledContent("Last Backup", value: last.formatted(date: .abbreviated, time: .shortened))
                }
            } footer: {
                Text(Persistence.iCloudSyncEnabled
                     ? "Backups are made when you open Coil and are saved in the Files app (On My iPhone → Coil → Backups) and in iCloud Drive."
                     : "Backups are made when you open Coil and are saved in the Files app: On My iPhone → Coil → Backups.")
            }

            Section {
                Button("Back Up Now", systemImage: "externaldrive.badge.plus") {
                    do {
                        try AutoBackup.backUp(in: context)
                        message = String(localized: "Backup saved.")
                    } catch {
                        message = error.localizedDescription
                    }
                    reload()
                }
            }

            if !backups.isEmpty {
                Section("Saved Backups") {
                    ForEach(backups, id: \.self) { url in
                        Button {
                            restoring = url
                        } label: {
                            LabeledContent {
                                Text(size(of: url))
                            } label: {
                                Label(url.deletingPathExtension().lastPathComponent
                                    .replacingOccurrences(of: "Coil Backup ", with: ""), systemImage: "doc")
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    .onDelete { offsets in
                        for index in offsets { try? FileManager.default.removeItem(at: backups[index]) }
                        reload()
                    }
                }
            }
        }
        .navigationTitle("Automatic Backups")
        .onAppear(perform: reload)
        .confirmationDialog(
            "Restore this backup?",
            isPresented: Binding(get: { restoring != nil }, set: { if !$0 { restoring = nil } }),
            titleVisibility: .visible,
            presenting: restoring
        ) { url in
            Button("Restore") { restore(url) }
        } message: { _ in
            Text("Habits from the backup are added back and their days merged with what you have now. Nothing is deleted.")
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private func reload() {
        backups = AutoBackup.backups()
    }

    private func size(of url: URL) -> String {
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func restore(_ url: URL) {
        do {
            let summary = try Backup.importFile(at: url, into: context)
            message = String(localized: "Added \(summary.habitsAdded) habits, updated \(summary.habitsUpdated), imported \(summary.entriesImported) entries.")
        } catch {
            message = error.localizedDescription
        }
    }
}
