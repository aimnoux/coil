import SwiftData
import SwiftUI

/// The headline for a quit habit: days clean, the record and slips.
struct QuitCard: View {
    let habit: Habit
    let stats: HabitStats

    @Environment(\.modelContext) private var context
    @State private var confirmingSlip = false

    var body: some View {
        let clean = stats.currentStreak?.length ?? 0
        let best = stats.bestStreaks(limit: 1).first?.length ?? 0
        Card("Clean Streak") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(clean, format: .number)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(habit.color.ink)
                        .contentTransition(.numericText())
                    Text("days without a slip")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 4) {
                    GridRow {
                        metric("\(best)", "Record")
                        metric("\(stats.slipCount)", "Slips")
                        metric(stats.lastSlip.map(Formatting.dayAndMonth) ?? "—", "Last slip")
                    }
                }
                Button {
                    confirmingSlip = true
                } label: {
                    Label("Record a Slip Today", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(HabitColor(index: 0).ink)
                .disabled(stats.checkmark(on: stats.today) == .no)
            }
        }
        .confirmationDialog("Record a slip today?", isPresented: $confirmingSlip, titleVisibility: .visible) {
            Button("Record Slip", role: .destructive) {
                withAnimation { habit.setRecord(.no, on: stats.today, in: context) }
            }
        } message: {
            Text("Your clean streak starts again tomorrow. Slips are part of the process.")
        }
    }

    private func metric(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Progress of a fixed-length challenge.
struct ChallengeCard: View {
    let habit: Habit
    let stats: HabitStats
    let range: ClosedRange<Day>

    var body: some View {
        let progress = stats.challengeProgress(range)
        Card("Challenge") {
            statusLabel(progress)
        } content: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(progress.isOver
                         ? String(localized: "\(progress.total) days")
                         : String(localized: "Day \(progress.day) of \(progress.total)"))
                        .font(.title2.weight(.bold))
                    Spacer()
                    Text(Formatting.percent(progress.fraction))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(habit.color.ink)
                }
                dayGrid(progress)
                HStack {
                    Label("\(progress.kept) kept", systemImage: "checkmark.circle")
                    Spacer()
                    Label("\(progress.missed) missed", systemImage: "xmark.circle")
                        .foregroundStyle(progress.missed > 0 ? HabitColor(index: 0).ink : .secondary)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                Text("\(Formatting.dayAndMonth(range.lowerBound)) – \(Formatting.dayAndMonth(range.upperBound))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func statusLabel(_ progress: ChallengeProgress) -> some View {
        if progress.isCompleted {
            Label("Completed", systemImage: "trophy.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(habit.color.ink)
        } else if progress.isOver {
            Label("Finished", systemImage: "flag.checkered")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else if progress.isFailed {
            Label("Missed a day", systemImage: "exclamationmark.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    /// One dot per challenge day.
    private func dayGrid(_ progress: ChallengeProgress) -> some View {
        let days = (0..<progress.total).map { range.lowerBound.advanced(by: $0) }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: min(progress.total, 15))
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(days, id: \.self) { day in
                let c = day <= stats.today ? stats.checkmark(on: day) : .unknown
                Circle()
                    .fill(dotColor(c, isFuture: day > stats.today))
                    .frame(height: 14)
                    .overlay {
                        if day == stats.today {
                            Circle().strokeBorder(Color.primary.opacity(0.5), lineWidth: 1.5)
                        }
                    }
            }
        }
    }

    private func dotColor(_ c: Checkmark, isFuture: Bool) -> Color {
        if isFuture { return Color(.quaternarySystemFill) }
        if c.isSatisfied { return habit.color.color }
        if c.isNeutral { return habit.color.color.opacity(0.35) }
        if c == .no || c == .unknown { return Color(.systemFill) }
        return Color(.tertiarySystemFill)
    }
}

/// Pause ranges for a habit, with a button to add one.
struct PausesCard: View {
    let habit: Habit
    let onAdd: () -> Void

    @Environment(\.modelContext) private var context

    var body: some View {
        let pauses = habit.livePauses.sorted { $0.startDay > $1.startDay }
        if !pauses.isEmpty {
            Card("Pauses") {
                Button("Add", systemImage: "plus", action: onAdd)
                    .labelStyle(.iconOnly)
            } content: {
                VStack(spacing: 10) {
                    ForEach(pauses) { pause in
                        HStack {
                            Image(systemName: "pause.circle")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(Formatting.dayAndMonth(pause.range.lowerBound)) – \(Formatting.dayAndMonth(pause.range.upperBound))")
                                    .font(.subheadline.weight(.medium))
                                if !pause.note.isEmpty {
                                    Text(pause.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                withAnimation {
                                    context.delete(pause)
                                    habit.touch()
                                }
                                ReminderScheduler.reschedule(habit)
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
    }
}

/// Creates a pause for one habit, or for every active habit (vacation mode).
struct PauseSheet: View {
    /// `nil` pauses every active habit.
    let habit: Habit?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var habits: [Habit]

    @State private var start = Date()
    @State private var end = Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date()
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("From", selection: $start, displayedComponents: .date)
                    DatePicker("To", selection: $end, in: start..., displayedComponents: .date)
                } footer: {
                    Text(habit == nil
                         ? "All active habits are paused for these days: strength and streaks stay as they are, and reminders are skipped."
                         : "Paused days don't lower habit strength or break the streak, and reminders are skipped.")
                }
                Section {
                    TextField("Note", text: $note, prompt: Text("Vacation, sick, travel…"))
                }
            }
            .navigationTitle(habit == nil ? "Vacation Mode" : "Pause Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Pause") { save() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let targets = habit.map { [$0] } ?? habits.filter { !$0.isArchived }
        for target in targets {
            let pause = HabitPause(start: Day(start), end: Day(max(start, end)), note: note)
            context.insert(pause)
            pause.habit = target
            target.touch()
        }
        ReminderScheduler.rescheduleAll(in: context)
        dismiss()
    }
}
