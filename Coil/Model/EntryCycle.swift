import Foundation

/// What tapping a yes/no checkmark does: unknown → done → skipped → not done → unknown.
enum EntryCycle {
    static func next(after checkmark: Checkmark, skipEnabled: Bool, showQuestionMarks: Bool) -> EntryRecord? {
        switch checkmark {
        case .unknown, .yesAuto:
            .yes
        case .yesManual:
            skipEnabled ? .skip : .no
        case .skip:
            .no
        case .no:
            // Without question marks "not done" and "unknown" look the same, so go straight back to done.
            showQuestionMarks ? nil : .yes
        }
    }
}
