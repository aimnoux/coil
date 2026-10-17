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

    static let shared: ModelContainer = makeContainer(inMemory: usesSampleData)

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([Habit.self, Entry.self, HabitGroup.self, HabitPause.self, TimerSession.self])
        let configuration: ModelConfiguration
        if inMemory || (isExtension && !FileManager.default.fileExists(atPath: storeURL.path)) {
            // A widget must never create the shared store: if it did before the app moved its
            // existing data into the App Group, the app would find an empty store and skip the move.
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: iCloudSyncEnabled ? .automatic : .none
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

    /// An in-memory container with demo data for SwiftUI previews.
    static var preview: ModelContainer {
        let container = makeContainer(inMemory: true)
        if (try? container.mainContext.fetchCount(FetchDescriptor<Habit>())) == 0 {
            SampleData.insert(into: container.mainContext)
        }
        return container
    }
}
