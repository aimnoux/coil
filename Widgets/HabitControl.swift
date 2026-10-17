import AppIntents
import SwiftUI
import WidgetKit

/// A Control Center (and Lock Screen) button that checks off a chosen habit for today.
struct HabitControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: "HabitControl", provider: HabitControlProvider()) { value in
            ControlWidgetToggle(value.name, isOn: value.isDone, action: SetHabitDoneIntent(habitID: value.id)) { isOn in
                Label(isOn ? String(localized: "Done") : String(localized: "Not done"), systemImage: value.icon)
            }
            .tint(.accentColor)
        }
        .displayName("Check Off Habit")
        .description("Mark a habit as done for today.")
    }
}

nonisolated struct HabitControlValue: Sendable {
    let id: UUID
    let name: String
    let icon: String
    let isDone: Bool
}

nonisolated struct HabitControlProvider: AppIntentControlValueProvider {
    func previewValue(configuration: SelectHabitControlIntent) -> HabitControlValue {
        HabitControlValue(id: UUID(), name: configuration.habit?.name ?? String(localized: "Habit"), icon: "checkmark.circle", isDone: false)
    }

    func currentValue(configuration: SelectHabitControlIntent) async throws -> HabitControlValue {
        let id = configuration.habit?.id
        return await MainActor.run {
            let habits = (try? HabitStore.activeHabits()) ?? []
            guard let habit = habits.first(where: { $0.id == id }) ?? habits.first else {
                return HabitControlValue(id: UUID(), name: String(localized: "Habit"), icon: "checkmark.circle", isDone: false)
            }
            let today = Day.today()
            let checkmark = habit.stats(today: today).checkmark(on: today)
            return HabitControlValue(
                id: habit.id,
                name: habit.name,
                icon: habit.iconName.isEmpty ? "checkmark.circle" : habit.iconName,
                isDone: habit.isQuit ? checkmark != .no : checkmark.isSatisfied
            )
        }
    }
}
