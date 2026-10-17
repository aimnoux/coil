import Foundation

/// What tapping a yes/no checkmark does: unknown → done → skipped → not done → unknown.
enum EntryCycle {
    static func next(after checkmark: Checkmark, skipEnabled: Bool, showQuestionMarks: Bool) -> EntryRecord? {
        switch checkmark {
        case .unknown, .yesAuto, .paused:
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

    /// For quit habits a tap toggles between a clean day and a slip.
    static func nextForQuit(after checkmark: Checkmark) -> EntryRecord? {
        checkmark == .no ? nil : .no
    }
}
