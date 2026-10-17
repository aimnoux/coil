import SwiftUI
import WidgetKit

/// Everything a widget needs to draw one habit, computed in the widget process.
nonisolated struct WidgetHabit: Identifiable, Sendable {
    let id: UUID
    let name: String
    let colorIndex: Int
    let isMeasurable: Bool
    let isQuit: Bool
    let iconName: String
    /// Target for one day (the period target spread over its days).
    let dailyTarget: Double
    let unit: String
    let score: Double
    let streak: Int
    let todayAmount: Double?
    let isCompletedToday: Bool
    /// The last seven days, oldest first.
    let week: [Checkmark]

    var color: Color { HabitColor(index: colorIndex).color }
    var ink: Color { HabitColor(index: colorIndex).ink }
    var today: Checkmark { week.last ?? .unknown }

    @MainActor
    init(_ habit: Habit, today: Day) {
        let stats = habit.stats(today: today)
        id = habit.id
        name = habit.name
        colorIndex = habit.colorIndex
        isMeasurable = habit.isMeasurable
        isQuit = habit.isQuit
        iconName = habit.iconName
        dailyTarget = habit.targetValue / Double(max(1, habit.frequency.denominator))
        unit = habit.unit
        score = stats.currentScore
        streak = stats.currentStreak?.length ?? 0
        todayAmount = stats.amount(on: today)
        isCompletedToday = stats.isCompletedToday
        week = (0..<7).reversed().map { stats.checkmark(on: today.advanced(by: -$0)) }
    }

    init(placeholderName name: String, colorIndex: Int, score: Double) {
        id = UUID()
        self.name = name
        self.colorIndex = colorIndex
        isMeasurable = false
        isQuit = false
        iconName = ""
        dailyTarget = 0
        unit = ""
        self.score = score
        streak = 12
        todayAmount = nil
        isCompletedToday = true
        week = [.yesManual, .yesManual, .no, .yesManual, .yesManual, .yesManual, .yesManual]
    }

    static let placeholders = [
        WidgetHabit(placeholderName: String(localized: "Meditate"), colorIndex: 12, score: 0.82),
        WidgetHabit(placeholderName: String(localized: "Exercise"), colorIndex: 6, score: 0.64),
        WidgetHabit(placeholderName: String(localized: "Read"), colorIndex: 3, score: 0.71),
        WidgetHabit(placeholderName: String(localized: "Wake up early"), colorIndex: 10, score: 0.45),
    ]
}

nonisolated struct HabitsEntry: TimelineEntry, Sendable {
    let date: Date
    let habits: [WidgetHabit]
}

enum WidgetTimeline {
    /// Refresh just after midnight so "today" rolls over.
    nonisolated static func nextRefresh(after date: Date = .now) -> Date {
        let tomorrow = Calendar.current.startOfDay(for: date).addingTimeInterval(86_400 + 60)
        return tomorrow
    }

    @MainActor
    static func load(ids: [UUID]? = nil) -> [WidgetHabit] {
        let today = Day.today()
        let habits = (try? HabitStore.activeHabits()) ?? []
        let selected = ids.map { ids in ids.compactMap { id in habits.first { $0.id == id } } } ?? habits
        return selected.map { WidgetHabit($0, today: today) }
    }
}
