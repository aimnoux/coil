import SwiftUI

/// The longest streaks as proportional bars with their dates.
struct StreaksCard: View {
    let stats: HabitStats
    let palette: HabitColor

    var body: some View {
        let streaks = stats.bestStreaks(limit: 8)
        let longest = streaks.first?.length ?? 1
        Card("Best Streaks") {
            if streaks.isEmpty {
                Text("No streaks yet. Check off the habit on consecutive days to start one.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(streaks, id: \.start) { streak in
                        row(streak, longest: longest)
                    }
                }
            }
        }
    }

    private func row(_ streak: Streak, longest: Int) -> some View {
        let isCurrent = streak.end >= stats.today.advanced(by: -1)
        let fraction = Double(streak.length) / Double(max(1, longest))
        return HStack(spacing: 8) {
            Text(Formatting.dayAndMonth(streak.start))
                .frame(width: 64, alignment: .trailing)
            GeometryReader { proxy in
                let width = max(36, proxy.size.width * fraction)
                Capsule()
                    .fill(isCurrent ? palette.color : palette.color.opacity(0.45))
                    .frame(width: width)
                    .overlay {
                        Text(streak.length, format: .number)
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(palette.ink)
                    }
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 24)
            Text(isCurrent ? String(localized: "Now") : Formatting.dayAndMonth(streak.end))
                .frame(width: 64, alignment: .leading)
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(streak.length) days, \(Formatting.fullDate(streak.start)) – \(Formatting.fullDate(streak.end))"))
    }
}

/// On which weekdays the habit gets done, month by month.
struct FrequencyCard: View {
    let stats: HabitStats
    let palette: HabitColor
    let firstWeekday: Int

    var body: some View {
        let counts = stats.weekdayFrequency()
        // Up to the last 12 months, but not before the habit started.
        let startMonth = stats.start.firstOfMonth
        let months = (0..<12).reversed()
            .map { stats.today.firstOfMonth.addingMonths(-$0) }
            .filter { $0 >= startMonth }
        let maxCount = max(1, counts.values.flatMap(\.values).max() ?? 1)
        Card("Frequency") {
            Grid(horizontalSpacing: 0, verticalSpacing: 6) {
                ForEach(0..<7, id: \.self) { row in
                    let weekday = (firstWeekday - 1 + row) % 7 + 1
                    GridRow {
                        Text(Formatting.shortWeekday(weekday))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .gridColumnAlignment(.leading)
                            .frame(width: 34, alignment: .leading)
                        ForEach(months, id: \.self) { month in
                            let count = counts[month]?[weekday] ?? 0
                            dot(count: count, max: maxCount)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 20)
                }
                GridRow {
                    Color.clear.frame(width: 34, height: 1)
                    ForEach(months, id: \.self) { month in
                        Text(month.date().formatted(.dateTime.month(.narrow)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func dot(count: Int, max: Int) -> some View {
        let fraction = Double(count) / Double(max)
        return Circle()
            .fill(count == 0 ? Color(.tertiarySystemFill) : palette.color.opacity(0.4 + 0.6 * fraction))
            .frame(width: count == 0 ? 5 : 6 + 12 * fraction, height: count == 0 ? 5 : 6 + 12 * fraction)
    }
}
