import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// A CSV file that can be shared with `ShareLink`.
nonisolated struct CSVFile: Transferable, Sendable {
    let name: String
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { file in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(file.name)
            try file.text.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
        .suggestedFileName { $0.name }
    }
}

/// Spreadsheet exports, in a format close to Loop's: one row per day.
enum CSVExport {
    /// Date, value and habit strength for every day of one habit, newest first.
    static func habitFile(_ habit: Habit) -> CSVFile {
        let stats = habit.stats()
        var lines = ["Date,Value,Strength,Note"]
        var day = stats.today
        while day >= stats.start {
            let note = escape(habit.note(on: day))
            lines.append("\(isoDate(day)),\(value(for: habit, stats: stats, day: day)),\(format(stats.score(on: day))),\(note)")
            day = day.advanced(by: -1)
        }
        return CSVFile(name: "\(safeFileName(habit.name)).csv", text: lines.joined(separator: "\n") + "\n")
    }

    /// A list of all habits with their settings.
    static func habitsFile(_ habits: [Habit]) -> CSVFile {
        var lines = ["Position,Name,Question,Type,Frequency Numerator,Frequency Denominator,Unit,Target,Target Type,Color,Archived,Notes"]
        for habit in habits {
            let fields: [String] = [
                "\(habit.position + 1)",
                escape(habit.name),
                escape(habit.question),
                habit.isMeasurable ? "Measurable" : "YesNo",
                "\(habit.frequencyNumerator)",
                "\(habit.frequencyDenominator)",
                escape(habit.unit),
                format(habit.targetValue),
                habit.targetType == .atLeast ? "AtLeast" : "AtMost",
                "\(habit.colorIndex)",
                habit.isArchived ? "true" : "false",
                escape(habit.notes),
            ]
            lines.append(fields.joined(separator: ","))
        }
        return CSVFile(name: "Habits.csv", text: lines.joined(separator: "\n") + "\n")
    }

    /// One column per habit and one row per day, newest first.
    static func checkmarksFile(_ habits: [Habit]) -> CSVFile {
        let today = Day.today()
        let all = habits.map { ($0, $0.stats(today: today)) }
        let start = all.map(\.1.start).min() ?? today
        var lines = [(["Date"] + habits.map { escape($0.name) }).joined(separator: ",")]
        var day = today
        while day >= start {
            let values = all.map { habit, stats in day < stats.start ? "" : value(for: habit, stats: stats, day: day) }
            lines.append(([isoDate(day)] + values).joined(separator: ","))
            day = day.advanced(by: -1)
        }
        return CSVFile(name: "Checkmarks.csv", text: lines.joined(separator: "\n") + "\n")
    }

    private static func value(for habit: Habit, stats: HabitStats, day: Day) -> String {
        if habit.isMeasurable {
            if habit.record(on: day)?.state == .skip { return "SKIP" }
            return stats.amount(on: day).map(format) ?? ""
        }
        switch stats.checkmark(on: day) {
        case .yesManual: return "YES"
        case .yesAuto: return "YES_AUTO"
        case .skip: return "SKIP"
        case .no: return "NO"
        case .unknown: return ""
        }
    }

    nonisolated static func isoDate(_ day: Day) -> String {
        let c = day.components
        return String(format: "%04d-%02d-%02d", c.year, c.month, c.day)
    }

    private static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.4f", value)
    }

    static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func safeFileName(_ name: String) -> String {
        let cleaned = name.components(separatedBy: CharacterSet(charactersIn: "/\\?%*|\"<>:")).joined(separator: "-")
        return cleaned.isEmpty ? "Habit" : cleaned
    }
}
