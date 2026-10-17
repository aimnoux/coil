import Foundation
import SwiftData

enum Persistence {
    /// On when the project is generated with `COIL_ICLOUD=true xcodegen` (needs a paid
    /// Apple Developer account). See docs/ICLOUD.md for the full checklist.
    #if ICLOUD
    static let iCloudSyncEnabled = true
    #else
    static let iCloudSyncEnabled = false
    #endif

    /// Shared with the widget extension when the app is built with widgets (see docs/WIDGETS.md).
    nonisolated static let appGroupID = "group.com.maxouni.coil"

    /// Launch with `-sampleData` to use a throwaway in-memory store filled with demo habits.
    static let usesSampleData = ProcessInfo.processInfo.arguments.contains("-sampleData")

    /// UI tests launch with `-uiTesting` to get an empty in-memory store.
    static let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")

    static let shared: ModelContainer = makeContainer(inMemory: usesSampleData || isUITesting)

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([Habit.self, Entry.self, HabitGroup.self, HabitPause.self, TimerSession.self])
        let configuration: ModelConfiguration
        if inMemory || (isExtension && !FileManager.default.fileExists(atPath: storeURL.path)) {
            // A widget must never create the shared store: if it did before the app moved its
            // existing data into the App Group, the app would find an empty store and skip the move.
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else {
            let sync = !isExtension && shouldSyncWithICloud()
            configuration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: sync ? .automatic : .none
            )
        }
        do {
            let container: ModelContainer
            do {
                container = try ModelContainer(for: schema, configurations: configuration)
            } catch where !inMemory && iCloudSyncEnabled {
                // A misconfigured iCloud container shouldn't lock people out of their habits:
                // fall back to the same store without sync.
                let local = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
                container = try ModelContainer(for: schema, configurations: local)
            }
            let seedsStore = ProcessInfo.processInfo.arguments.contains("-seedSampleData")
            if (inMemory && usesSampleData)
                || (seedsStore && (try? container.mainContext.fetchCount(FetchDescriptor<Habit>())) == 0) {
                // `-seedSampleData` fills an empty on-disk store, e.g. to try widgets in the simulator.
                SampleData.insert(into: container.mainContext)
            }
            return container
        } catch {
            fatalError("Could not create the habit store: \(error)")
        }
    }

    // MARK: - iCloud safety

    private static let iCloudTokenKey = "lastICloudAccountToken"

    /// Whether to open the store with CloudKit mirroring right now.
    ///
    /// Core Data's CloudKit mirroring clears local mirrored data when it starts without an
    /// iCloud account or after the account changes (the data stays in iCloud). So sync is only
    /// turned on while an account is signed in, and before the first start with a new account the
    /// store files are copied aside, so nothing can be lost.
    static func shouldSyncWithICloud() -> Bool {
        guard iCloudSyncEnabled else { return false }
        guard let token = FileManager.default.ubiquityIdentityToken else { return false }
        let tokenData = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
        let previous = UserDefaults.standard.data(forKey: iCloudTokenKey)
        if tokenData != previous {
            copyStoreAside(reason: previous == nil ? "before-icloud" : "icloud-account-changed")
            UserDefaults.standard.set(tokenData, forKey: iCloudTokenKey)
        }
        return true
    }

    /// Copies the store files to Documents/Backups/<reason> <date>/ (visible in the Files app).
    static func copyStoreAside(reason: String) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storeURL.path) else { return }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HHmmss"
        let folder = URL.documentsDirectory
            .appending(path: "Backups/\(reason) \(formatter.string(from: Date()))", directoryHint: .isDirectory)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        for suffix in ["", "-shm", "-wal"] {
            let from = URL(fileURLWithPath: storeURL.path + suffix)
            if fm.fileExists(atPath: from.path) {
                try? fm.copyItem(at: from, to: folder.appending(path: from.lastPathComponent))
            }
        }
    }

    /// The store lives in the App Group container when the app has one (so widgets can read it),
    /// otherwise in Application Support.
    static var storeURL: URL {
        let local = URL.applicationSupportDirectory.appending(path: "default.store")
        guard let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return local
        }
        let shared = group.appending(path: "Coil.store")
        if !isExtension {
            moveStoreIfNeeded(from: local, to: shared)
        }
        return shared
    }

    /// True inside the widget extension, which only reads and toggles existing data.
    static let isExtension = Bundle.main.bundlePath.hasSuffix(".appex")

    /// Moves an existing local store into the App Group the first time widgets are enabled.
    private static func moveStoreIfNeeded(from source: URL, to destination: URL) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: destination.path), fm.fileExists(atPath: source.path) else { return }
        for suffix in ["", "-shm", "-wal"] {
            let from = URL(fileURLWithPath: source.path + suffix)
            let to = URL(fileURLWithPath: destination.path + suffix)
            if fm.fileExists(atPath: from.path) {
                try? fm.copyItem(at: from, to: to)
            }
        }
    }

    private static var pendingSave: Task<Void, Never>?

    /// Saves shortly after a change, so a check-in survives even if the app is closed right away.
    /// Changes in quick succession are written together.
    static func saveSoon(_ context: ModelContext) {
        pendingSave?.cancel()
        pendingSave = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, context.hasChanges else { return }
            try? context.save()
        }
    }

    /// An in-memory container with demo data for SwiftUI previews.
    static var preview: ModelContainer {
        let container = makeContainer(inMemory: true)
        if (try? container.mainContext.fetchCount(FetchDescriptor<Habit>())) == 0 {
            SampleData.insert(into: container.mainContext)
        }
        return container
    }
}
