import SwiftUI

/// A small ring showing habit strength from 0 to 1.
struct ScoreRing: View {
    let score: Double
    let color: Color
    var lineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, score)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
        .animation(.snappy, value: score)
        .accessibilityElement()
        .accessibilityLabel("Habit strength")
        .accessibilityValue(Formatting.percent(score))
    }
}

#Preview {
    HStack {
        ScoreRing(score: 0.2, color: .orange).frame(width: 28, height: 28)
        ScoreRing(score: 0.75, color: .blue).frame(width: 28, height: 28)
        ScoreRing(score: 0.75, color: .purple, lineWidth: 10).frame(width: 90, height: 90)
    }
}
