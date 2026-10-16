import SwiftUI

/// Files prepared for sharing, created only when the user asks to export.
struct SharedFiles: Identifiable {
    let id = UUID()
    let urls: [URL]
}

/// The system share sheet for local files.
struct ShareSheet: UIViewControllerRepresentable {
    let files: SharedFiles

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: files.urls, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

extension CSVFile {
    /// Writes the file to a fresh temporary folder and returns its URL.
    func write() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

extension BackupFile {
    func write() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(Backup.fileName())
        try Backup.encode(self).write(to: url, options: .atomic)
        return url
    }
}
