import SwiftUI
import WidgetKit

/// Several habits with their last days and a check button each, like Loop's main screen.
struct HabitsListWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HabitsListWidget", provider: HabitsListProvider()) { entry in
            HabitsListWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Habits")
        .description("Check off today's habits from the Home Screen.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

nonisolated struct HabitsListProvider: TimelineProvider {
    func placeholder(in context: Context) -> HabitsEntry {
        HabitsEntry(date: .now, habits: WidgetHabit.placeholders)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (HabitsEntry) -> Void) {
        Task { @MainActor in
            let habits = WidgetTimeline.load()
            completion(HabitsEntry(date: .now, habits: habits.isEmpty ? WidgetHabit.placeholders : habits))
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<HabitsEntry>) -> Void) {
        Task { @MainActor in
            let entry = HabitsEntry(date: .now, habits: WidgetTimeline.load())
            completion(Timeline(entries: [entry], policy: .after(WidgetTimeline.nextRefresh())))
        }
    }
}

struct HabitsListWidgetView: View {
    let entry: HabitsEntry
    @Environment(\.widgetFamily) private var family

    private var limit: Int { family == .systemLarge ? 7 : 3 }
    private var dayCount: Int { family == .systemLarge ? 5 : 4 }

    var body: some View {
        if entry.habits.isEmpty {
            Text("Add a habit in Coil")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: family == .systemLarge ? 10 : 6) {
                header
                ForEach(entry.habits.prefix(limit)) { habit in
                    row(habit)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("Habits")
                .font(.subheadline.weight(.semibold))
            Spacer()
            ForEach((0..<dayCount).reversed(), id: \.self) { offset in
                let day = Day.today().advanced(by: -offset)
                Text(Formatting.veryShortWeekday(day.weekday))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(offset == 0 ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                    .frame(width: 30)
            }
        }
    }

    private func row(_ habit: WidgetHabit) -> some View {
        HStack(spacing: 8) {
            ScoreRing(score: habit.score, color: habit.color, lineWidth: 3)
                .frame(width: 18, height: 18)
            Text(habit.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(habit.color)
                .lineLimit(1)
            Spacer(minLength: 4)
            ForEach(Array(habit.week.suffix(dayCount).enumerated()), id: \.offset) { index, checkmark in
                if index == dayCount - 1 {
                    CheckButton(habit: habit, size: 26)
                        .frame(width: 30)
                } else {
                    Image(systemName: checkmark.isSatisfied ? "checkmark" : "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(checkmark.isSatisfied
                            ? (checkmark == .yesAuto ? habit.color.opacity(0.45) : habit.color)
                            : Color(.tertiaryLabel))
                        .frame(width: 30)
                }
            }
        }
        .widgetURL(URL(string: "coil://habit/\(habit.id.uuidString)"))
    }
}
