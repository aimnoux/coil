import Charts
import SwiftUI
import WidgetKit

// MARK: - Streak

/// A habit's current streak (or clean days for a quit habit).
struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "StreakWidget", intent: SelectHabitIntent.self, provider: HabitProvider()) { entry in
            StreakWidgetView(entry: entry)
                .fontDesign(.rounded)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Streak")
        .description("Days in a row — or days clean for a habit you're quitting.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryInline])
    }
}

struct StreakWidgetView: View {
    let entry: HabitsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let habit = entry.habits.first {
            switch family {
            case .accessoryCircular:
                VStack(spacing: 0) {
                    Image(systemName: habit.isQuit ? "leaf.fill" : "flame.fill")
                        .font(.caption)
                    Text(habit.streak, format: .number)
                        .font(.title2.weight(.bold))
                        .minimumScaleFactor(0.5)
                }
                .widgetAccentable()
                .widgetURL(URL(string: "coil://habit/\(habit.id.uuidString)"))
            case .accessoryInline:
                Label(
                    habit.isQuit ? "\(habit.name): \(habit.streak) clean" : "\(habit.name): \(habit.streak) in a row",
                    systemImage: habit.isQuit ? "leaf.fill" : "flame.fill"
                )
            default:
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: habit.iconName.isEmpty ? (habit.isQuit ? "leaf.fill" : "flame.fill") : habit.iconName)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(habit.ink)
                        Spacer()
                        Text(Formatting.percent(habit.score))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(habit.streak, format: .number)
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(habit.ink)
                        .minimumScaleFactor(0.5)
                    Text(habit.isQuit ? "days clean" : "days in a row")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(habit.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                .widgetURL(URL(string: "coil://habit/\(habit.id.uuidString)"))
            }
        } else {
            Text("Add a habit in Coil")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Progress

/// Today's progress towards a measurable habit's target.
struct ProgressWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ProgressWidget", intent: SelectHabitIntent.self, provider: HabitProvider()) { entry in
            ProgressWidgetView(entry: entry)
                .fontDesign(.rounded)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Progress")
        .description("Today's progress towards a habit's target.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct ProgressWidgetView: View {
    let entry: HabitsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let habit = entry.habits.first {
            let amount = habit.todayAmount ?? (habit.isCompletedToday ? 1 : 0)
            let target = habit.dailyTarget > 0 ? habit.dailyTarget : 1
            let fraction = min(1, amount / target)
            if family == .accessoryCircular {
                Gauge(value: fraction) {
                    Image(systemName: habit.iconName.isEmpty ? "target" : habit.iconName)
                } currentValueLabel: {
                    Text(Formatting.compact(amount))
                }
                .gaugeStyle(.accessoryCircular)
                .widgetURL(URL(string: "coil://habit/\(habit.id.uuidString)"))
            } else {
                VStack(spacing: 8) {
                    ZStack {
                        ScoreRing(score: fraction, color: habit.color, lineWidth: 9)
                        VStack(spacing: 0) {
                            Text(Formatting.compact(amount))
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(habit.ink)
                            Text("of \(Formatting.compact(target)) \(habit.unit)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    Text(habit.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                .widgetURL(URL(string: "coil://habit/\(habit.id.uuidString)"))
            }
        } else {
            Text("Add a habit in Coil")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Heatmap

/// The share of habits done each day, for the last weeks.
struct HeatmapWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HeatmapWidget", provider: HeatmapProvider()) { entry in
            HeatmapWidgetView(entry: entry)
                .fontDesign(.rounded)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Heatmap")
        .description("How many of your habits you did each day.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

nonisolated struct HeatmapEntry: TimelineEntry, Sendable {
    let date: Date
    let today: Day
    let firstWeekday: Int
    let values: [Day: Double]
}

nonisolated struct HeatmapProvider: TimelineProvider {
    func placeholder(in context: Context) -> HeatmapEntry {
        let today = Day.today()
        var values: [Day: Double] = [:]
        for i in 0..<140 { values[today.advanced(by: -i)] = Double((i * 37) % 100) / 100 }
        return HeatmapEntry(date: .now, today: today, firstWeekday: Calendar.current.firstWeekday, values: values)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (HeatmapEntry) -> Void) {
        Task { @MainActor in completion(load()) }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<HeatmapEntry>) -> Void) {
        Task { @MainActor in
            completion(Timeline(entries: [load()], policy: .after(WidgetTimeline.nextRefresh())))
        }
    }

    @MainActor
    private func load() -> HeatmapEntry {
        let today = Day.today()
        let habits = (try? HabitStore.activeHabits()) ?? []
        let stats = habits.map { $0.stats(today: today) }
        let values = SummaryEngine.dailyCompletion(stats, from: today.advanced(by: -7 * 26), to: today)
        return HeatmapEntry(date: .now, today: today, firstWeekday: Calendar.current.firstWeekday, values: values)
    }
}

struct HeatmapWidgetView: View {
    let entry: HeatmapEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let weeksShown = family == .systemLarge ? 20 : 18
        let lastWeek = entry.today.firstOfWeek(firstWeekday: entry.firstWeekday)
        let weeks = (0..<weeksShown).reversed().map { lastWeek.advanced(by: -7 * $0) }
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Coil")
                    .font(.headline)
                Spacer()
                if let todayValue = entry.values[entry.today] {
                    Text("Today \(Formatting.percent(todayValue))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            GeometryReader { proxy in
                let gap: CGFloat = 3
                let size = min((proxy.size.width - gap * CGFloat(weeksShown - 1)) / CGFloat(weeksShown),
                               (proxy.size.height - gap * 6) / 7)
                HStack(spacing: gap) {
                    ForEach(weeks, id: \.self) { week in
                        VStack(spacing: gap) {
                            ForEach(0..<7, id: \.self) { row in
                                let day = week.advanced(by: row)
                                RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                                    .fill(color(day))
                                    .frame(width: size, height: size)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func color(_ day: Day) -> Color {
        guard day <= entry.today else { return .clear }
        guard let value = entry.values[day] else { return Color(.quaternarySystemFill) }
        if value == 0 { return Color(.systemFill) }
        return Color.accentColor.opacity(0.25 + 0.75 * value)
    }
}
