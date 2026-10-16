import AppIntents
import SwiftData
import WidgetKit

/// A habit as seen by Shortcuts, Siri and widget configuration.
struct HabitEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Habit"
    static let defaultQuery = HabitQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }

    init(_ habit: Habit) {
        self.init(id: habit.id, name: habit.name)
    }
}

struct HabitQuery: EntityQuery, EntityStringQuery {
    @MainActor
    func entities(for identifiers: [HabitEntity.ID]) async throws -> [HabitEntity] {
        try HabitStore.activeHabits()
            .filter { identifiers.contains($0.id) }
            .map(HabitEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [HabitEntity] {
        try HabitStore.activeHabits()
            .filter { $0.name.localizedCaseInsensitiveContains(string) }
            .map(HabitEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [HabitEntity] {
        try HabitStore.activeHabits().map(HabitEntity.init)
    }
}

/// Data access shared by intents and widgets.
@MainActor
enum HabitStore {
    static var context: ModelContext { Persistence.shared.mainContext }

    static func activeHabits() throws -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.position)]
        )
        return try context.fetch(descriptor)
    }

    static func habit(id: UUID) throws -> Habit? {
        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }

    static func save() throws {
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// Marks a yes/no habit as done today (or un-marks it), used by interactive widgets.
struct ToggleHabitIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Habit"
    static let isDiscoverable = false

    @Parameter(title: "Habit ID")
    var habitID: String

    init() {}

    init(habitID: UUID) {
        self.habitID = habitID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: habitID), let habit = try HabitStore.habit(id: id) else {
            return .result()
        }
        let today = Day.today()
        let done = habit.stats(today: today).checkmark(on: today) == .yesManual
        habit.setRecord(done ? nil : .yes, on: today, in: HabitStore.context)
        try HabitStore.save()
        return .result()
    }
}

/// "Mark Meditate as done" from Shortcuts or Siri.
struct MarkHabitDoneIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark Habit as Done"
    static let description = IntentDescription("Checks off a habit for today.")

    @Parameter(title: "Habit")
    var habit: HabitEntity

    @Parameter(title: "Amount", description: "For measurable habits: the value to record.")
    var amount: Double?

    static var parameterSummary: some ParameterSummary {
        Summary("Mark \(\.$habit) as done") {
            \.$amount
        }
    }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let model = try HabitStore.habit(id: habit.id) else {
            throw $habit.needsValueError()
        }
        let today = Day.today()
        if model.isMeasurable {
            let value = amount ?? model.targetValue
            model.setRecord(EntryRecord(state: .yes, amount: value), on: today, in: HabitStore.context)
        } else {
            model.setRecord(.yes, on: today, in: HabitStore.context)
        }
        try HabitStore.save()
        let streak = model.stats(today: today).currentStreak?.length ?? 1
        return .result(dialog: "Done! \(model.name) streak: \(streak) days.")
    }
}

/// Reads a habit's strength and streak, e.g. "How is my Meditate habit going?".
struct HabitStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Habit Status"
    static let description = IntentDescription("Tells you a habit's strength and current streak.")

    @Parameter(title: "Habit")
    var habit: HabitEntity

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        guard let model = try HabitStore.habit(id: habit.id) else {
            throw $habit.needsValueError()
        }
        let stats = model.stats()
        let strength = Formatting.percent(stats.currentScore)
        let streak = stats.currentStreak?.length ?? 0
        let today = stats.isCompletedToday
            ? String(localized: "Already done today.")
            : String(localized: "Not done yet today.")
        return .result(
            value: stats.currentScore,
            dialog: "\(model.name): strength \(strength), streak \(streak) days. \(today)"
        )
    }
}

/// Lets the user pick which habit a widget shows.
struct SelectHabitIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose Habit"
    static let description = IntentDescription("Choose the habit to show.")

    @Parameter(title: "Habit")
    var habit: HabitEntity?

    init() {}

    init(habit: HabitEntity?) {
        self.habit = habit
    }
}
