import SwiftUI

/// Width of each day column in the habit list; shared by rows and the header.
let checkmarkColumnWidth: CGFloat = 44

struct HabitRow: View {
    let habit: Habit
    let stats: HabitStats
    let days: [Day]
    let longPressToToggle: Bool
    let showQuestionMarks: Bool
    let onOpen: () -> Void
    let onTap: (Day) -> Void
    let onHint: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                ScoreRing(score: stats.currentScore, color: tint)
                    .frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(habit.isArchived ? AnyShapeStyle(.secondary) : AnyShapeStyle(tint))
                        .lineLimit(2)
                    if habit.isArchived {
                        Label("Archived", systemImage: "archivebox")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .labelStyle(.titleAndIcon)
                    }
                }
                Spacer(minLength: 4)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Shows statistics")

            ForEach(days, id: \.self) { day in
                cell(for: day)
                    .frame(width: checkmarkColumnWidth, height: 44)
            }
        }
        .padding(.vertical, 4)
    }

    private var tint: Color {
        habit.isArchived ? .secondary : habit.color.color
    }

    @ViewBuilder
    private func cell(for day: Day) -> some View {
        let checkmark = stats.checkmark(on: day)
        Button {
            if longPressToToggle { onHint() } else { onTap(day) }
        } label: {
            Group {
                if habit.isMeasurable {
                    AmountLabel(
                        amount: stats.amount(on: day),
                        unit: habit.unit,
                        checkmark: checkmark,
                        color: tint,
                        showQuestionMarks: showQuestionMarks
                    )
                } else {
                    CheckmarkSymbol(checkmark: checkmark, color: tint, showQuestionMarks: showQuestionMarks)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                if longPressToToggle { onTap(day) }
            }
        )
        .sensoryFeedback(.selection, trigger: checkmark)
        .accessibilityLabel(Text(Formatting.fullDate(day)))
        .accessibilityValue(habit.isMeasurable
            ? Text(stats.amount(on: day).map { "\(Formatting.number($0)) \(habit.unit)" } ?? "—")
            : Text(checkmark.accessibilityDescription))
    }
}

/// The value shown for one day of a measurable habit.
struct AmountLabel: View {
    let amount: Double?
    let unit: String
    let checkmark: Checkmark
    let color: Color
    let showQuestionMarks: Bool

    var body: some View {
        VStack(spacing: 0) {
            if checkmark == .skip {
                Image(systemName: "arrow.turn.up.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color.opacity(0.7))
            } else if let amount {
                Text(Formatting.compact(amount))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(checkmark.isSatisfied ? color : Color(.secondaryLabel))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color(.secondaryLabel))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            } else {
                Image(systemName: showQuestionMarks ? "questionmark" : "minus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        }
        .padding(.horizontal, 2)
    }
}
