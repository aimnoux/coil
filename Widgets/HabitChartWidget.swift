import Charts
import SwiftUI
import WidgetKit

/// A habit's strength over the last months, like Loop's score widget.
struct HabitChartWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "HabitChartWidget", intent: SelectHabitIntent.self, provider: HabitChartProvider()) { entry in
            HabitChartWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Habit Strength")
        .description("See how a habit's strength changes over time.")
        .supportedFamilies([.systemMedium])
    }
}

nonisolated struct ChartEntry: TimelineEntry, Sendable {
    let date: Date
    let habit: WidgetHabit?
    /// Weekly strength for the last 16 weeks, oldest first.
    let points: [ChartPoint]
}

nonisolated struct ChartPoint: Identifiable, Sendable {
    let date: Date
    let score: Double
    var id: Date { date }
}

nonisolated struct HabitChartProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ChartEntry {
        let points = (0..<16).map { week in
            ChartPoint(
                date: Date.now.addingTimeInterval(Double(week - 15) * 7 * 86_400),
                score: 0.3 + 0.5 * Double(week) / 15
            )
        }
        return ChartEntry(date: .now, habit: WidgetHabit.placeholders[0], points: points)
    }

    func snapshot(for configuration: SelectHabitIntent, in context: Context) async -> ChartEntry {
        await entry(for: configuration)
    }

    func timeline(for configuration: SelectHabitIntent, in context: Context) async -> Timeline<ChartEntry> {
        Timeline(entries: [await entry(for: configuration)], policy: .after(WidgetTimeline.nextRefresh()))
    }

    private func entry(for configuration: SelectHabitIntent) async -> ChartEntry {
        let id = configuration.habit?.id
        return await MainActor.run {
            let habits = (try? HabitStore.activeHabits()) ?? []
            let selected = id.map { id in habits.first { $0.id == id } } ?? habits.first
            guard let habit = selected else {
                return ChartEntry(date: .now, habit: nil, points: [])
            }
            let today = Day.today()
            let stats = habit.stats(today: today)
            let firstWeekday = Calendar.current.firstWeekday
            let points = stats.scoreSeries(bucket: .week, firstWeekday: firstWeekday)
                .suffix(16)
                .map { ChartPoint(date: $0.start.date(), score: $0.score) }
            return ChartEntry(date: .now, habit: WidgetHabit(habit, today: today), points: Array(points))
        }
    }
}

struct HabitChartWidgetView: View {
    let entry: ChartEntry

    var body: some View {
        if let habit = entry.habit {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.name)
                        .font(.headline)
                        .foregroundStyle(habit.color)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    Text(Formatting.percent(habit.score))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(habit.color)
                    Text("strength")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label {
                        Text("\(habit.streak) days")
                    } icon: {
                        Image(systemName: "flame.fill")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                }
                .frame(width: 100, alignment: .leading)

                Chart(entry.points) { point in
                    AreaMark(x: .value("Date", point.date), y: .value("Strength", point.score))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(
                            LinearGradient(colors: [habit.color.opacity(0.35), habit.color.opacity(0.02)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    LineMark(x: .value("Date", point.date), y: .value("Strength", point.score))
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .foregroundStyle(habit.color)
                }
                .chartYScale(domain: 0...1)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
            }
            .widgetURL(URL(string: "coil://habit/\(habit.id.uuidString)"))
        } else {
            Text("Add a habit in Coil")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
