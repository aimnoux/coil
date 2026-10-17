import SwiftUI

/// Width of each day column in the habit list; shared by rows and the header.
let checkmarkColumnWidth: CGFloat = 44

struct HabitRow: View {
    let habit: Habit
    let stats: HabitStats
    let days: [Day]
    let longPressToToggle: Bool
    let showQuestionMarks: Bool
    /// While the list is in selection mode, a tap selects the row instead of opening the habit.
    var isEditing = false
    let onOpen: () -> Void
    let onTap: (Day) -> Void
    let onHint: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                HabitBadge(
                    score: stats.currentScore,
                    palette: habit.color,
                    iconName: habit.iconName,
                    size: habit.iconName.isEmpty ? 26 : 34,
                    isArchived: habit.isArchived
                )
                .frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(habit.isArchived ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                        .lineLimit(2)
                    if let running = habit.isTimed ? TimerService.activeSession(of: habit) : nil {
                        RunningTimerLabel(session: running)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(habit.color.ink)
                    } else if let subtitle {
                        subtitle
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)
            // In selection mode let the list handle taps so the whole row selects.
            .allowsHitTesting(!isEditing)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Shows statistics")
            .accessibilityIdentifier("habit-\(habit.name)")

            ForEach(days, id: \.self) { day in
                cell(for: day)
                    .frame(width: checkmarkColumnWidth, height: 44)
            }
        }
        .padding(.vertical, 4)
    }

    /// A short status line: archived, paused, clean days of a quit habit, or challenge progress.
    private var subtitle: Text? {
        let today = stats.today
        if habit.isArchived {
            return Text("\(Image(systemName: "archivebox")) \(String(localized: "Archived"))")
        }
        if stats.checkmark(on: today) == .paused {
            return Text("\(Image(systemName: "pause.circle")) \(String(localized: "Paused"))")
        }
        if let challenge = habit.challenge {
            let progress = stats.challengeProgress(challenge)
            if progress.isCompleted {
                return Text("\(Image(systemName: "flag.checkered")) \(String(localized: "Challenge completed"))")
            }
            if !progress.isOver && progress.day > 0 {
                return Text("\(Image(systemName: "flag.checkered")) \(String(localized: "Day \(progress.day) of \(progress.total)"))")
            }
        }
        if habit.isQuit {
            let clean = stats.currentStreak?.length ?? 0
            return Text("\(Image(systemName: "leaf")) \(String(localized: "\(clean) days clean"))")
        }
        return nil
    }

    /// Archived habits are drawn in neutral gray.
    private var fill: Color {
        habit.isArchived ? Color(.systemGray3) : habit.color.color
    }

    private var ink: Color {
        habit.isArchived ? Color(.secondaryLabel) : habit.color.ink
    }

    @ViewBuilder
    private func cell(for day: Day) -> some View {
        let checkmark = stats.checkmark(on: day)
        Button {
            if longPressToToggle { onHint() } else { onTap(day) }
        } label: {
            Group {
                if day < stats.start && habit.record(on: day) == nil {
                    // Before the habit existed: nothing to show, but still tappable for backfilling.
                    Circle()
                        .fill(Color(.quaternaryLabel))
                        .frame(width: 4, height: 4)
                } else if habit.isMeasurable {
                    AmountLabel(
                        amount: stats.amount(on: day),
                        unit: habit.unit,
                        checkmark: checkmark,
                        fill: fill,
                        ink: ink,
                        showQuestionMarks: showQuestionMarks
                    )
                } else {
                    CheckmarkSymbol(
                        checkmark: checkmark, fill: fill, ink: ink,
                        showQuestionMarks: showQuestionMarks, isQuit: habit.isQuit
                    )
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
        .accessibilityIdentifier("day-\(habit.name)-\(day.distance(to: stats.today))")
        .accessibilityLabel(Text(Formatting.fullDate(day)))
        .accessibilityValue(habit.isMeasurable
            ? Text(stats.amount(on: day).map { "\(Formatting.number($0)) \(habit.unit)" } ?? "—")
            : Text(checkmark.accessibilityDescription))
    }
}

/// The value shown for one day of a measurable habit: a soft pill when the target is met.
struct AmountLabel: View {
    let amount: Double?
    let unit: String
    let checkmark: Checkmark
    let fill: Color
    let ink: Color
    let showQuestionMarks: Bool

    var body: some View {
        if checkmark == .skip {
            CheckmarkSymbol(checkmark: .skip, fill: fill, ink: ink)
        } else if let amount {
            let met = checkmark.isSatisfied
            VStack(spacing: -1) {
                Text(Formatting.compact(amount))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .opacity(0.8)
                }
            }
            .foregroundStyle(met ? ink : Color(.secondaryLabel))
            .frame(width: 38, height: 34)
            .background(met ? fill.opacity(0.32) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            CheckmarkSymbol(checkmark: .unknown, fill: fill, ink: ink, showQuestionMarks: showQuestionMarks)
        }
    }
}
