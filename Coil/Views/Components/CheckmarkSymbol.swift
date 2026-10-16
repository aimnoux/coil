import SwiftUI

/// The glyph for one day of a yes/no habit, shared by the list and the calendar.
struct CheckmarkSymbol: View {
    let checkmark: Checkmark
    let color: Color
    var showQuestionMarks = false
    var font: Font = .system(size: 17, weight: .semibold)

    var body: some View {
        Image(systemName: symbol)
            .font(font)
            .foregroundStyle(foreground)
            .contentTransition(.symbolEffect(.replace))
    }

    private var symbol: String {
        switch checkmark {
        case .yesManual, .yesAuto: "checkmark"
        case .skip: "arrow.turn.up.right"
        case .no: "xmark"
        case .unknown: showQuestionMarks ? "questionmark" : "xmark"
        }
    }

    private var foreground: AnyShapeStyle {
        switch checkmark {
        case .yesManual: AnyShapeStyle(color)
        case .yesAuto: AnyShapeStyle(color.opacity(0.45))
        case .skip: AnyShapeStyle(color.opacity(0.7))
        case .no: AnyShapeStyle(Color(.secondaryLabel))
        case .unknown: AnyShapeStyle(Color(.tertiaryLabel))
        }
    }
}

extension Checkmark {
    var accessibilityDescription: LocalizedStringKey {
        switch self {
        case .yesManual: "Done"
        case .yesAuto: "Done for this period"
        case .skip: "Skipped"
        case .no: "Not done"
        case .unknown: "No entry"
        }
    }
}
