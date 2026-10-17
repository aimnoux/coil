import AppIntents
import SwiftUI
import WidgetKit

/// One habit: strength ring, streak and a button to check it off today.
struct HabitWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "HabitWidget", intent: SelectHabitIntent.self, provider: HabitProvider()) { entry in
            HabitWidgetView(entry: entry)
                .fontDesign(.rounded)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Habit")
        .description("Check off a habit and see its strength.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

nonisolated struct HabitProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HabitsEntry {
        HabitsEntry(date: .now, habits: [WidgetHabit.placeholders[0]])
    }

    func snapshot(for configuration: SelectHabitIntent, in context: Context) async -> HabitsEntry {
        await entry(for: configuration)
    }

    func timeline(for configuration: SelectHabitIntent, in context: Context) async -> Timeline<HabitsEntry> {
        Timeline(entries: [await entry(for: configuration)], policy: .after(WidgetTimeline.nextRefresh()))
    }

    private func entry(for configuration: SelectHabitIntent) async -> HabitsEntry {
        let id = configuration.habit?.id
        let habits = await MainActor.run {
            let all = WidgetTimeline.load()
            // A habit that was picked but is now archived or deleted shows the empty state,
            // so the check button never toggles a different habit.
            guard let id else { return Array(all.prefix(1)) }
            return all.filter { $0.id == id }
        }
        return HabitsEntry(date: .now, habits: habits)
    }
}

struct HabitWidgetView: View {
    let entry: HabitsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let habit = entry.habits.first {
            switch family {
            case .accessoryCircular: circular(habit)
            case .accessoryRectangular: rectangular(habit)
            default: small(habit)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "circle.dashed")
                    .font(.title)
                Text("Add a habit in Coil")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.secondary)
        }
    }

    private func small(_ habit: WidgetHabit) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                ZStack {
                    ScoreRing(score: habit.score, color: habit.color, lineWidth: 6)
                    Text(Formatting.percent(habit.score))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(habit.ink)
                }
                .frame(width: 52, height: 52)
                Spacer()
                CheckButton(habit: habit, size: 44)
            }
            Spacer()
            Text(habit.name)
                .font(.headline)
                .lineLimit(2)
            Label {
                Text("\(habit.streak) days")
            } icon: {
                Image(systemName: "flame.fill")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .widgetURL(URL(string: "coil://habit/\(habit.id.uuidString)"))
    }

    private func circular(_ habit: WidgetHabit) -> some View {
        Gauge(value: habit.score) {
            Image(systemName: habit.isCompletedToday ? "checkmark" : "circle.dashed")
        } currentValueLabel: {
            Image(systemName: habit.isCompletedToday ? "checkmark" : "minus")
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetLabel(habit.name)
        .widgetURL(URL(string: "coil://habit/\(habit.id.uuidString)"))
    }

    private func rectangular(_ habit: WidgetHabit) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(habit.name)
                .font(.headline)
                .widgetAccentable()
            Text("Strength \(Formatting.percent(habit.score)) · \(habit.streak) days")
                .font(.caption)
            HStack(spacing: 3) {
                ForEach(Array(habit.week.enumerated()), id: \.offset) { _, checkmark in
                    Circle()
                        .fill(checkmark.isSatisfied ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .widgetURL(URL(string: "coil://habit/\(habit.id.uuidString)"))
    }
}

/// Round button that toggles today's checkmark without opening the app.
struct CheckButton: View {
    let habit: WidgetHabit
    let size: CGFloat

    var body: some View {
        if habit.isMeasurable {
            // Measurable habits need a value, so open the app instead.
            Link(destination: URL(string: "coil://habit/\(habit.id.uuidString)")!) {
                label(done: habit.isCompletedToday, text: habit.todayAmount.map(Formatting.compact))
            }
        } else {
            Button(intent: ToggleHabitIntent(habitID: habit.id)) {
                label(done: habit.today == .yesManual, text: nil)
            }
            .buttonStyle(.plain)
        }
    }

    private func label(done: Bool, text: String?) -> some View {
        ZStack {
            Circle()
                .fill(done ? habit.color : habit.color.opacity(0.25))
            if let text {
                Text(text)
                    .font(.system(size: size * 0.32, weight: .bold, design: .rounded))
                    .foregroundStyle(done ? .white : habit.ink)
                    .minimumScaleFactor(0.5)
                    .padding(4)
            } else {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(done ? .white : habit.ink.opacity(0.6))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Text(habit.name))
        .accessibilityValue(Text(done ? "Done" : "Not done"))
    }
}
