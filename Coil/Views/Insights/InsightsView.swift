import SwiftData
import SwiftUI

/// Statistics across all habits: period summaries, a year heatmap and achievements.
struct InsightsView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case summary, heatmap, awards
        var id: String { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .summary: "Summary"
            case .heatmap: "Heatmap"
            case .awards: "Awards"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Habit> { !$0.isArchived }, sort: \Habit.position) private var habits: [Habit]
    @AppStorage("insightsTab") private var tab = Tab.summary

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("View", selection: $tab) {
                        ForEach(Tab.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if habits.isEmpty {
                        ContentUnavailableView("No Habits Yet", systemImage: "chart.bar",
                                               description: Text("Statistics appear once you track a habit."))
                    } else {
                        switch tab {
                        case .summary: SummaryTab(habits: habits)
                        case .heatmap: HeatmapTab(habits: habits)
                        case .awards: AwardsTab(habits: habits)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Summary

private struct SummaryTab: View {
    let habits: [Habit]

    @AppStorage(SettingsKey.firstWeekday) private var storedFirstWeekday = 0
    @AppStorage("summaryBucket") private var bucket = TimeBucket.week
    @State private var offset = 0

    var body: some View {
        let firstWeekday = FirstWeekday.resolve(storedFirstWeekday)
        let today = Day.today()
        let anchor = shifted(today, by: offset)
        let range = SummaryEngine.range(for: bucket, containing: anchor, firstWeekday: firstWeekday)
        let previous = SummaryEngine.range(for: bucket, containing: shifted(today, by: offset - 1), firstWeekday: firstWeekday)
        let rows = habits.map { habit -> Row in
            let stats = habit.stats(today: today)
            return Row(
                habit: habit,
                stats: stats,
                current: SummaryEngine.result(stats, in: range),
                previous: SummaryEngine.result(stats, in: previous)
            )
        }
        let overall = SummaryEngine.overallRate(rows.map(\.current))
        let overallBefore = SummaryEngine.overallRate(rows.map(\.previous))

        VStack(spacing: 16) {
            periodHeader(range: range)

            Card("Overall") {
                HStack(spacing: 20) {
                    ZStack {
                        ScoreRing(score: overall ?? 0, color: .accentColor, lineWidth: 9)
                        Text(overall.map(Formatting.percent) ?? "—")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                    }
                    .frame(width: 96, height: 96)
                    VStack(alignment: .leading, spacing: 10) {
                        if let overall, let overallBefore {
                            let delta = overall - overallBefore
                            Label(Formatting.signedPercent(delta), systemImage: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(delta >= 0 ? HabitColor(index: 6).ink : HabitColor(index: 0).ink)
                            Text(bucket == .week ? "than the week before" : "than the month before")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(rows.reduce(0) { $0 + $1.current.kept }) check-ins")
                            .font(.subheadline.weight(.medium))
                    }
                }
            }

            highlights(rows: rows, range: range)

            Card("Habits") {
                VStack(spacing: 14) {
                    ForEach(rows.sorted { ($0.current.rate ?? -1) > ($1.current.rate ?? -1) }, id: \.habit.id) { row in
                        habitRow(row)
                    }
                }
            }
        }
    }

    struct Row {
        let habit: Habit
        let stats: HabitStats
        let current: HabitPeriodResult
        let previous: HabitPeriodResult
    }

    private func shifted(_ day: Day, by periods: Int) -> Day {
        switch bucket {
        case .week: day.advanced(by: 7 * periods)
        default: day.addingMonths(periods)
        }
    }

    private func periodHeader(range: ClosedRange<Day>) -> some View {
        VStack(spacing: 10) {
            Picker("Period", selection: $bucket) {
                Text("Week").tag(TimeBucket.week)
                Text("Month").tag(TimeBucket.month)
            }
            .pickerStyle(.segmented)
            .onChange(of: bucket) { _, _ in offset = 0 }
            HStack {
                Button("Previous", systemImage: "chevron.left") { withAnimation { offset -= 1 } }
                    .labelStyle(.iconOnly)
                Spacer()
                Text(bucket == .week
                     ? "\(Formatting.dayAndMonth(range.lowerBound)) – \(Formatting.dayAndMonth(range.upperBound))"
                     : range.lowerBound.date().formatted(.dateTime.month(.wide).year()))
                    .font(.headline)
                Spacer()
                Button("Next", systemImage: "chevron.right") { withAnimation { offset += 1 } }
                    .labelStyle(.iconOnly)
                    .disabled(offset >= 0)
            }
            .font(.title3)
        }
    }

    @ViewBuilder
    private func highlights(rows: [Row], range: ClosedRange<Day>) -> some View {
        let rated = rows.filter { $0.current.rate != nil }
        let best = rated.max { ($0.current.rate ?? 0) < ($1.current.rate ?? 0) }
        let worst = rated.count > 1 ? rated.min { ($0.current.rate ?? 0) < ($1.current.rate ?? 0) } : nil
        let weekdays = SummaryEngine.weekdayTotals(rows.map(\.stats), in: range)
        let bestWeekday = weekdays.max { $0.value < $1.value }?.key
        let minutes = rows.filter { $0.habit.isTimed }.reduce(0.0) { total, row in
            total + row.stats.sum(from: range.lowerBound, to: range.upperBound)
        }
        let longest = rows.compactMap { row in row.stats.currentStreak.map { (row.habit, $0.length) } }.max { $0.1 < $1.1 }

        Card("Highlights") {
            VStack(alignment: .leading, spacing: 12) {
                if let best, let rate = best.current.rate {
                    highlight("star.fill", "Best habit", "\(best.habit.name) · \(Formatting.percent(rate))", best.habit.color.ink)
                }
                if let worst, let rate = worst.current.rate, worst.habit.id != best?.habit.id {
                    highlight("exclamationmark.circle", "Needs attention", "\(worst.habit.name) · \(Formatting.percent(rate))", HabitColor(index: 1).ink)
                }
                if let longest, longest.1 > 1 {
                    highlight("flame.fill", "Longest current streak", "\(longest.0.name) · \(String(localized: "\(longest.1) days"))", HabitColor(index: 2).ink)
                }
                if let bestWeekday {
                    highlight("calendar", "Most productive day", Calendar.current.weekdaySymbols[bestWeekday - 1].capitalized, HabitColor(index: 10).ink)
                }
                if minutes > 0 {
                    highlight("stopwatch", "Time tracked", Formatting.duration(minutes * 60), HabitColor(index: 7).ink)
                }
            }
        }
    }

    private func highlight(_ icon: String, _ title: LocalizedStringKey, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.medium))
            }
        }
    }

    private func habitRow(_ row: Row) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                HabitBadge(score: row.stats.currentScore, palette: row.habit.color, iconName: row.habit.iconName, size: 28)
                Text(row.habit.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer()
                if let rate = row.current.rate {
                    if let before = row.previous.rate {
                        let delta = rate - before
                        if abs(delta) >= 0.01 {
                            Text(Formatting.signedPercent(delta))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(delta > 0 ? HabitColor(index: 6).ink : HabitColor(index: 0).ink)
                        }
                    }
                    Text(Formatting.percent(rate))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(row.habit.color.color.opacity(0.2))
                    Capsule().fill(row.habit.color.color)
                        .frame(width: proxy.size.width * (row.current.rate ?? 0))
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Heatmap

private struct HeatmapTab: View {
    let habits: [Habit]

    @AppStorage(SettingsKey.firstWeekday) private var storedFirstWeekday = 0
    @State private var selected: Day?

    private let cell: CGFloat = 14
    private let gap: CGFloat = 3

    var body: some View {
        let firstWeekday = FirstWeekday.resolve(storedFirstWeekday)
        let today = Day.today()
        let allStats = habits.map { $0.stats(today: today) }
        let lastWeek = today.firstOfWeek(firstWeekday: firstWeekday)
        let firstWeek = lastWeek.advanced(by: -7 * 52)
        let completion = SummaryEngine.dailyCompletion(allStats, from: firstWeek, to: today)
        let weeks = (0...52).map { firstWeek.advanced(by: 7 * $0) }

        VStack(spacing: 16) {
            Card("Last 12 Months") {
                VStack(alignment: .leading, spacing: 10) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: gap) {
                            ForEach(weeks, id: \.self) { week in
                                VStack(spacing: gap) {
                                    let first = (0..<7).map { week.advanced(by: $0) }.first { $0.dayOfMonth == 1 }
                                    Text(first.map { $0.date().formatted(.dateTime.month(.narrow)) } ?? " ")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .frame(width: cell, height: 12)
                                    ForEach(0..<7, id: \.self) { row in
                                        let day = week.advanced(by: row)
                                        square(day: day, today: today, value: completion[day])
                                    }
                                }
                            }
                        }
                    }
                    .defaultScrollAnchor(.trailing)
                    legend
                }
            }
            if let selected {
                dayDetail(selected, allStats: allStats)
            } else {
                Text("Tap a day to see what you did.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            let values = completion.values
            if !values.isEmpty {
                Card("Year in Numbers") {
                    let perfect = values.filter { $0 >= 0.999 }.count
                    let active = values.filter { $0 > 0 }.count
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Active days", value: "\(active)")
                        LabeledContent("Perfect days", value: "\(perfect)")
                        LabeledContent("Average", value: Formatting.percent(values.reduce(0, +) / Double(values.count)))
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    @ViewBuilder
    private func square(day: Day, today: Day, value: Double?) -> some View {
        let color: Color = {
            guard day <= today else { return .clear }
            guard let value else { return Color(.quaternarySystemFill) }
            if value == 0 { return Color(.systemFill) }
            return Color.accentColor.opacity(0.25 + 0.75 * value)
        }()
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color)
            .frame(width: cell, height: cell)
            .overlay {
                if day == selected {
                    RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(Color.primary, lineWidth: 1.5)
                }
            }
            .onTapGesture {
                guard day <= today else { return }
                withAnimation(.snappy) { selected = day }
            }
    }

    private var legend: some View {
        HStack(spacing: 4) {
            Text("Less").font(.caption2).foregroundStyle(.secondary)
            ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { v in
                RoundedRectangle(cornerRadius: 3)
                    .fill(v == 0 ? Color(.systemFill) : Color.accentColor.opacity(0.25 + 0.75 * v))
                    .frame(width: 12, height: 12)
            }
            Text("More").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func dayDetail(_ day: Day, allStats: [HabitStats]) -> some View {
        Card(LocalizedStringKey(Formatting.fullDate(day))) {
            VStack(spacing: 10) {
                ForEach(Array(zip(habits, allStats)), id: \.0.id) { habit, stats in
                    if stats.start <= day {
                        HStack(spacing: 10) {
                            HabitBadge(score: stats.score(on: day), palette: habit.color, iconName: habit.iconName, size: 26)
                            Text(habit.name)
                                .font(.subheadline)
                            Spacer()
                            CheckmarkSymbol(
                                checkmark: stats.checkmark(on: day),
                                fill: habit.color.color, ink: habit.color.ink,
                                isQuit: habit.isQuit, size: 24
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Awards

private struct AwardsTab: View {
    let habits: [Habit]

    @Query private var everyHabit: [Habit]

    var body: some View {
        let today = Day.today()
        let allStats = habits.map { $0.stats(today: today) }
        let global = AchievementEngine.global(habitCreationDays: everyHabit.map(\.createdDay), allStats: allStats)
        let earned: [(Habit, Achievement)] = zip(habits, allStats).flatMap { habit, stats in
            AchievementEngine.achievements(for: stats, challenge: habit.challenge)
                .filter(\.isUnlocked)
                .map { (habit, $0) }
        }
        .sorted { ($0.1.unlocked ?? today) > ($1.1.unlocked ?? today) }

        VStack(spacing: 16) {
            Card("Milestones") {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(global) { achievement in
                        VStack(spacing: 6) {
                            AchievementBadge(achievement: achievement)
                            Text(achievement.title)
                                .font(.caption2.weight(.medium))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(achievement.isUnlocked ? .primary : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            Card("Recently Earned") {
                Text("\(earned.count)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            } content: {
                if earned.isEmpty {
                    Text("Keep going — your first medal is close.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(earned.prefix(30).enumerated()), id: \.offset) { _, item in
                            HStack(spacing: 12) {
                                AchievementBadge(achievement: item.1, size: 40)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.1.title)
                                        .font(.subheadline.weight(.medium))
                                    Text(item.0.name)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let day = item.1.unlocked {
                                    Text(Formatting.dayAndMonth(day))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
