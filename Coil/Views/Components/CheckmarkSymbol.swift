import SwiftUI

/// A soft round badge for one day of a yes/no habit, shared by the list and widgets.
struct CheckmarkSymbol: View {
    let checkmark: Checkmark
    /// The pastel fill of the habit's color.
    let fill: Color
    /// The deeper shade, for glyphs drawn on light tints.
    let ink: Color
    var showQuestionMarks = false
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            switch checkmark {
            case .yesManual:
                Circle().fill(fill)
                glyph("checkmark", scale: 0.44, weight: .bold)
                    .foregroundStyle(.white)
            case .yesAuto:
                Circle().fill(fill.opacity(0.3))
                glyph("checkmark", scale: 0.4, weight: .semibold)
                    .foregroundStyle(ink.opacity(0.75))
            case .skip:
                Circle().strokeBorder(fill, style: StrokeStyle(lineWidth: 1.8, dash: [3, 3]))
                glyph("arrow.right", scale: 0.36, weight: .semibold)
                    .foregroundStyle(ink.opacity(0.8))
            case .no:
                glyph("xmark", scale: 0.3, weight: .semibold)
                    .foregroundStyle(Color(.tertiaryLabel))
            case .unknown:
                if showQuestionMarks {
                    glyph("questionmark", scale: 0.34, weight: .semibold)
                        .foregroundStyle(Color(.tertiaryLabel))
                } else {
                    Circle()
                        .fill(Color(.quaternaryLabel))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .frame(width: size, height: size)
        .animation(.snappy(duration: 0.2), value: checkmark)
    }

    private func glyph(_ name: String, scale: CGFloat, weight: Font.Weight) -> some View {
        Image(systemName: name)
            .font(.system(size: size * scale, weight: weight, design: .rounded))
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
