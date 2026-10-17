import SwiftUI

/// Current habit strength, its change over the last month and year, totals and streaks.
struct OverviewCard: View {
    let stats: HabitStats
    let palette: HabitColor
    let isMeasurable: Bool
    let unit: String

    var body: some View {
        Card("Overview") {
            HStack(spacing: 20) {
                ZStack {
                    ScoreRing(score: stats.currentScore, color: palette.color, lineWidth: 9)
                    VStack(spacing: 0) {
                        Text(Formatting.percent(stats.currentScore))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.ink)
                            .contentTransition(.numericText())
                        Text("strength")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 96, height: 96)

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                    GridRow {
                        metric(Formatting.signedPercent(monthChange), "Month", tinted: monthChange != 0)
                        metric(Formatting.signedPercent(yearChange), "Year", tinted: yearChange != 0)
                    }
                    GridRow {
                        metric(totalText, isMeasurable ? "Total" : "Times done")
                        metric(streakText(stats.currentStreak?.length), "Streak")
                    }
                }
            }
        }
    }

    private var monthChange: Double {
        stats.currentScore - stats.score(on: stats.today.addingMonths(-1))
    }

    private var yearChange: Double {
        stats.currentScore - stats.score(on: stats.today.addingMonths(-12))
    }

    private var totalText: String {
        let total = Formatting.compact(stats.total)
        return isMeasurable && !unit.isEmpty ? "\(total) \(unit)" : total
    }

    private func streakText(_ length: Int?) -> String {
        String(localized: "\(length ?? 0) days")
    }

    private func metric(_ value: String, _ label: LocalizedStringKey, tinted: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(tinted ? palette.ink : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Progress of a measurable habit towards its target for today and longer periods.
struct TargetCard: View {
    let habit: Habit
    let stats: HabitStats
    let firstWeekday: Int

    var body: some View {
        Card("Target") {
            VStack(spacing: 14) {
                ForEach(Array(periods.enumerated()), id: \.offset) { _, period in
                    row(period)
                }
            }
        }
    }

    private struct Period {
        let title: LocalizedStringKey
        let start: Day
        let days: Int
    }

    private var periods: [Period] {
        let today = stats.today
        let week = today.firstOfWeek(firstWeekday: firstWeekday)
        let month = today.firstOfMonth
        let quarter = today.firstOfQuarter
        let year = today.firstOfYear
        var result = [
            Period(title: "Today", start: today, days: 1),
            Period(title: "This week", start: week, days: 7),
            Period(title: "This month", start: month, days: Day.daysInMonth(year: today.year, month: today.month)),
            Period(title: "This quarter", start: quarter, days: quarter.distance(to: quarter.addingMonths(3))),
            Period(title: "This year", start: year, days: year.distance(to: year.addingMonths(12))),
        ]
        // A weekly or monthly target has no meaningful daily share.
        if habit.frequency.denominator >= 7 { result.removeFirst() }
        if habit.frequency.denominator >= 30 { result.removeFirst() }
        return result
    }

    private func row(_ period: Period) -> some View {
        let value = stats.sum(from: period.start, to: stats.today)
        let target = stats.target(forDays: period.days)
        let progress = target > 0 ? value / target : 1
        let isAtMost = habit.targetType == .atMost
        let good = isAtMost ? value <= target : progress >= 1
        // Going over an "at most" target shows in soft red.
        let palette = isAtMost && !good ? HabitColor(index: 0) : habit.color

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(period.title)
                    .font(.subheadline)
                Spacer()
                Text("\(Formatting.number(value)) / \(Formatting.number(target.rounded(toPlaces: 1))) \(habit.unit)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(good ? palette.ink : .secondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.color.opacity(0.22))
                    Capsule().fill(palette.color)
                        .frame(width: proxy.size.width * min(1, max(0, progress)))
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .combine)
    }
}

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10, Double(places))
        return (self * factor).rounded() / factor
    }
}
