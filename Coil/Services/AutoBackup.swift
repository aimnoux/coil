import Foundation
import SwiftData

/// Writes a full backup on a schedule into the app's Documents folder (visible in the Files app
/// under On My iPhone → Coil → Backups) and, when iCloud is enabled, into iCloud Drive too.
///
/// Backups are made when the app becomes active and the last one is older than the chosen
/// interval — habit apps are opened daily, which is more dependable than background tasks.
enum AutoBackup {
    enum Frequency: String, CaseIterable, Identifiable {
        case off, daily, weekly, monthly

        var id: String { rawValue }

        var interval: TimeInterval? {
            switch self {
            case .off: nil
            case .daily: 86_400
            case .weekly: 7 * 86_400
            case .monthly: 30 * 86_400
            }
        }
    }

    static let frequencyKey = "autoBackupFrequency"
    static let keepKey = "autoBackupKeep"
    static let lastKey = "autoBackupLast"

    static var frequency: Frequency {
        Frequency(rawValue: UserDefaults.standard.string(forKey: frequencyKey) ?? "") ?? .weekly
    }

    /// How many automatic backups to keep (0 = all).
    static var keep: Int {
        UserDefaults.standard.object(forKey: keepKey) as? Int ?? 10
    }

    static var lastBackup: Date? {
        UserDefaults.standard.object(forKey: lastKey) as? Date
    }

    static var folder: URL {
        URL.documentsDirectory.appending(path: "Backups", directoryHint: .isDirectory)
    }

    /// Makes a backup if one is due.
    @discardableResult
    static func runIfDue(in context: ModelContext, now: Date = Date()) -> URL? {
        // Never write demo data over real backups.
        guard !Persistence.usesSampleData, let interval = frequency.interval else { return nil }
        if let last = lastBackup, now.timeIntervalSince(last) < interval { return nil }
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        guard !habits.isEmpty else { return nil }
        return try? backUp(in: context, now: now)
    }

    /// Writes a backup now and prunes old ones.
    @discardableResult
    static func backUp(in context: ModelContext, now: Date = Date()) throws -> URL {
        let habits = (try? context.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.position)]))) ?? []
        let data = try Backup.encode(Backup.make(from: habits))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HHmmss"
        let stamp = formatter.string(from: now)
        let url = folder.appending(path: "Coil Backup \(stamp).json")
        try data.write(to: url, options: .atomic)
        UserDefaults.standard.set(now, forKey: lastKey)
        prune()
        copyToICloudDrive(url)
        return url
    }

    /// Automatic backups, newest first.
    static func backups() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.creationDateKey]
        )) ?? []
        return urls
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    static func prune() {
        guard keep > 0 else { return }
        for url in backups().dropFirst(keep) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func copyToICloudDrive(_ url: URL) {
        guard Persistence.iCloudSyncEnabled else { return }
        Task.detached(priority: .background) {
            guard let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return }
            let folder = container.appending(path: "Documents/Backups", directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let destination = folder.appending(path: url.lastPathComponent)
            try? FileManager.default.removeItem(at: destination)
            try? FileManager.default.copyItem(at: url, to: destination)
        }
    }
}
