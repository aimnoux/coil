import SwiftData
import SwiftUI

/// A year-at-a-glance grid of days (weeks as columns) that can be tapped to edit past entries.
struct CalendarCard: View {
    let habit: Habit
    let stats: HabitStats
    let firstWeekday: Int
    /// Called for measurable habits, which need a value instead of a toggle.
    let onEditAmount: (Day) -> Void

    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.skipEnabled) private var skipEnabled = false
    @AppStorage(SettingsKey.showQuestionMarks) private var showQuestionMarks = false

    private let cell: CGFloat = 30
    private let gap: CGFloat = 4

    var body: some View {
        Card("Calendar") {
            HStack(alignment: .top, spacing: gap) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: gap) {
                        ForEach(weeks, id: \.self) { weekStart in
                            column(weekStart)
                        }
                    }
                    .scrollTargetLayout()
                }
                .defaultScrollAnchor(.trailing)
                weekdayLabels
            }
            Text(habit.isMeasurable ? "Tap a day to change its value." : "Tap a day to change it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Start of every week from the habit's start (at least ~6 months back) to this week.
    private var weeks: [Day] {
        let current = stats.today.firstOfWeek(firstWeekday: firstWeekday)
        let earliest = min(stats.start, stats.today.addingMonths(-6)).firstOfWeek(firstWeekday: firstWeekday)
        let count = min(earliest.distance(to: current) / 7, 520)
        return (0...count).reversed().map { current.advanced(by: -7 * $0) }
    }

    private var weekdayLabels: some View {
        VStack(spacing: gap) {
            Text(" ").font(.caption2.weight(.semibold))
            ForEach(0..<7, id: \.self) { row in
                let weekday = (firstWeekday - 1 + row) % 7 + 1
                Text(Formatting.veryShortWeekday(weekday))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: cell)
            }
        }
    }

    private func column(_ weekStart: Day) -> some View {
        VStack(spacing: gap) {
            // Month label on the week that contains the 1st.
            let firstOfMonth = (0..<7).map { weekStart.advanced(by: $0) }.first { $0.dayOfMonth == 1 }
            Text(firstOfMonth.map { $0.date().formatted(.dateTime.month(.abbreviated)) } ?? " ")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize()
                .frame(width: cell, alignment: .leading)
            ForEach(0..<7, id: \.self) { row in
                dayCell(weekStart.advanced(by: row))
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Day) -> some View {
        if day > stats.today {
            Color.clear.frame(width: cell, height: cell)
        } else {
            let checkmark = stats.checkmark(on: day)
            let style = fill(for: day, checkmark: checkmark)
            Button {
                tap(day, checkmark: checkmark)
            } label: {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(style.background)
                    .overlay {
                        if checkmark == .skip {
                            Image(systemName: "arrow.turn.up.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(habit.color.color)
                                .offset(x: 6, y: -6)
                        }
                    }
                    .overlay {
                        Text(day.dayOfMonth, format: .number)
                            .font(.system(size: 11, weight: day == stats.today ? .bold : .medium, design: .rounded))
                            .foregroundStyle(style.foreground)
                    }
                    .overlay {
                        if day == stats.today {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.6), lineWidth: 1.5)
                        }
                    }
                    .frame(width: cell, height: cell)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(Formatting.fullDate(day)))
            .accessibilityValue(Text(checkmark.accessibilityDescription))
        }
    }

    private func fill(for day: Day, checkmark: Checkmark) -> (background: Color, foreground: Color) {
        let color = habit.color.color
        if habit.isMeasurable {
            guard let amount = stats.amount(on: day) else {
                return (Color(.tertiarySystemFill), .secondary)
            }
            let performance = HabitStats.measurablePerformance(
                amount: amount,
                target: habit.targetValue / Double(habit.frequency.denominator),
                type: habit.targetType
            )
            if performance >= 1 { return (color, .white) }
            return (color.opacity(0.15 + 0.5 * performance), .primary)
        }
        switch checkmark {
        case .yesManual: return (color, .white)
        case .yesAuto: return (color.opacity(0.4), .white)
        case .skip: return (color.opacity(0.15), .primary)
        case .no: return (Color(.systemFill), .secondary)
        case .unknown: return (Color(.tertiarySystemFill), .secondary)
        }
    }

    private func tap(_ day: Day, checkmark: Checkmark) {
        if habit.isMeasurable {
            onEditAmount(day)
            return
        }
        let next = EntryCycle.next(after: checkmark, skipEnabled: skipEnabled, showQuestionMarks: showQuestionMarks)
        withAnimation(.snappy) {
            habit.setRecord(next, on: day, in: context)
        }
    }
}
