import SwiftUI

struct HabitDetailView: View {
    let habit: Habit

    var body: some View {
        Text(habit.name)
            .navigationTitle(habit.name)
    }
}
