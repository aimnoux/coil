import AppIntents

/// Phrases that work with Siri and appear in the Shortcuts app without any setup.
struct CoilShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: MarkHabitDoneIntent(),
            phrases: [
                "Mark \(\.$habit) as done in \(.applicationName)",
                "Check off \(\.$habit) in \(.applicationName)",
                "I did \(\.$habit) in \(.applicationName)",
            ],
            shortTitle: "Mark as Done",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: HabitStatusIntent(),
            phrases: [
                "How is \(\.$habit) going in \(.applicationName)",
                "\(.applicationName) status of \(\.$habit)",
            ],
            shortTitle: "Habit Status",
            systemImageName: "chart.line.uptrend.xyaxis"
        )
    }
}
