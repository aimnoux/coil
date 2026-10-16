import Foundation
import SwiftData

enum Persistence {
    /// Flip to `true` once the app has the iCloud capability (paid Apple Developer Program).
    /// See ICLOUD.md for the full checklist.
    static let iCloudSyncEnabled = false

    /// Launch with `-sampleData` to use a throwaway in-memory store filled with demo habits.
    static let usesSampleData = ProcessInfo.processInfo.arguments.contains("-sampleData")

    static let shared: ModelContainer = makeContainer(inMemory: usesSampleData)

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([Habit.self, Entry.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: iCloudSyncEnabled && !inMemory ? .automatic : .none
        )
        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            if inMemory && usesSampleData {
                SampleData.insert(into: container.mainContext)
            }
            return container
        } catch {
            fatalError("Could not create the habit store: \(error)")
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
