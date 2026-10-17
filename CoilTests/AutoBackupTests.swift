import Foundation
import SwiftData
import Testing
@testable import Coil

@MainActor
@Suite(.serialized)
struct AutoBackupTests {
    let container = Persistence.makeContainer(inMemory: true)
    var context: ModelContext { container.mainContext }

    init() {
        try? FileManager.default.removeItem(at: AutoBackup.folder)
        UserDefaults.standard.removeObject(forKey: AutoBackup.lastKey)
        UserDefaults.standard.set(AutoBackup.Frequency.daily.rawValue, forKey: AutoBackup.frequencyKey)
        UserDefaults.standard.set(3, forKey: AutoBackup.keepKey)
    }

    @Test func backsUpWhenDueAndKeepsOnlyTheNewest() throws {
        context.insert(Habit(name: "Read"))
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(AutoBackup.runIfDue(in: context, now: start) != nil)
        // Not due again an hour later.
        #expect(AutoBackup.runIfDue(in: context, now: start.addingTimeInterval(3600)) == nil)
        for day in 1...4 {
            #expect(AutoBackup.runIfDue(in: context, now: start.addingTimeInterval(Double(day) * 86_400 + 60)) != nil)
        }
        #expect(AutoBackup.backups().count == 3)

        // The newest backup restores into an empty store.
        let fresh = Persistence.makeContainer(inMemory: true)
        let url = try #require(AutoBackup.backups().first)
        let result = try Backup.importFile(at: url, into: fresh.mainContext)
        #expect(result.habitsAdded == 1)
        try? FileManager.default.removeItem(at: AutoBackup.folder)
    }

    @Test func offMeansNoBackups() {
        UserDefaults.standard.set(AutoBackup.Frequency.off.rawValue, forKey: AutoBackup.frequencyKey)
        context.insert(Habit(name: "Read"))
        #expect(AutoBackup.runIfDue(in: context) == nil)
    }
}
