#if DEBUG
import SwiftUI
import WidgetKit

/// Debug only, compiled into the app when widgets are enabled: renders every widget with real
/// data into PNG files (Documents/WidgetGallery) so the widgets can be checked without
/// placing them on the Home Screen. Found at runtime via `NSClassFromString`.
@objc(CoilWidgetGalleryRenderer)
final class WidgetGalleryRenderer: NSObject {
    @MainActor @objc static func render() {
        let today = Day.today()
        let habits = WidgetTimeline.load()
        guard !habits.isEmpty else { return }
        let first = habits[0]
        let measurable = habits.first(where: \.isMeasurable) ?? first
        let quit = habits.first(where: \.isQuit) ?? first
        let entry = HabitsEntry(date: .now, habits: habits)
        let one = { (habit: WidgetHabit) in HabitsEntry(date: .now, habits: [habit]) }

        let allStats = ((try? HabitStore.activeHabits()) ?? []).map { $0.stats(today: today) }
        let heat = HeatmapEntry(
            date: .now, today: today, firstWeekday: Calendar.current.firstWeekday,
            values: SummaryEngine.dailyCompletion(allStats, from: today.advanced(by: -140), to: today)
        )
        let points = ((try? HabitStore.activeHabits()) ?? []).first.map { habit in
            habit.stats(today: today).scoreSeries(bucket: .week, firstWeekday: 2).suffix(16)
                .map { ChartPoint(date: $0.start.date(), score: $0.score) }
        } ?? []

        let small = CGSize(width: 170, height: 170)
        let medium = CGSize(width: 364, height: 170)
        let large = CGSize(width: 364, height: 382)
        let items: [(String, CGSize, WidgetFamily, AnyView)] = [
            ("habit-small", small, .systemSmall, AnyView(HabitWidgetView(entry: one(first), familyOverride: .systemSmall))),
            ("habits-medium", medium, .systemMedium, AnyView(HabitsListWidgetView(entry: entry, familyOverride: .systemMedium))),
            ("habits-large", large, .systemLarge, AnyView(HabitsListWidgetView(entry: entry, familyOverride: .systemLarge))),
            ("chart-medium", medium, .systemMedium, AnyView(HabitChartWidgetView(entry: ChartEntry(date: .now, habit: first, points: Array(points))))),
            ("streak-small", small, .systemSmall, AnyView(StreakWidgetView(entry: one(quit), familyOverride: .systemSmall))),
            ("progress-small", small, .systemSmall, AnyView(ProgressWidgetView(entry: one(measurable), familyOverride: .systemSmall))),
            ("heatmap-medium", medium, .systemMedium, AnyView(HeatmapWidgetView(entry: heat, familyOverride: .systemMedium))),
        ]
        let folder = URL.documentsDirectory.appending(path: "WidgetGallery", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (name, size, family, view) in items {
            _ = family
            let card = view
                .fontDesign(.rounded)
                .padding(16)
                .frame(width: size.width, height: size.height)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            let renderer = ImageRenderer(content: card)
            renderer.scale = 3
            if let data = renderer.uiImage?.pngData() {
                try? data.write(to: folder.appending(path: "\(name).png"))
            }
        }
        print("COIL-WIDGETS rendered to \(folder.path)")
    }
}
#endif
