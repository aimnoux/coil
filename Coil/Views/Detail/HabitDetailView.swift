import SwiftData
import SwiftUI

/// Statistics for one habit: strength, target progress, charts, calendar, streaks and notes.
struct HabitDetailView: View {
    let habit: Habit

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKey.firstWeekday) private var storedFirstWeekday = 0
    @State private var today = Day.today()
    @State private var editing = false
    @State private var confirmingDelete = false
    @State private var amountTarget: AmountEntryTarget?
    @State private var noteTarget: DayNoteTarget?

    var body: some View {
        let stats = habit.stats(today: today)
        let firstWeekday = FirstWeekday.resolve(storedFirstWeekday)
        let color = habit.color.color

        ScrollView {
            VStack(spacing: 16) {
                DetailHeader(habit: habit)
                OverviewCard(stats: stats, color: color, isMeasurable: habit.isMeasurable, unit: habit.unit)
                if habit.isMeasurable {
                    TargetCard(habit: habit, stats: stats, firstWeekday: firstWeekday)
                }
                ScoreChartCard(stats: stats, color: color, firstWeekday: firstWeekday)
                HistoryChartCard(stats: stats, color: color, firstWeekday: firstWeekday, isMeasurable: habit.isMeasurable)
                CalendarCard(
                    habit: habit,
                    stats: stats,
                    firstWeekday: firstWeekday,
                    onEditAmount: { day in amountTarget = AmountEntryTarget(habit: habit, day: day) },
                    onEditNote: { day in noteTarget = DayNoteTarget(habit: habit, day: day) }
                )
                StreaksCard(stats: stats, color: color)
                FrequencyCard(stats: stats, color: color, firstWeekday: firstWeekday)
                DayNotesCard(habit: habit) { day in
                    noteTarget = DayNoteTarget(habit: habit, day: day)
                }
                if !habit.notes.isEmpty {
                    Card("Notes") {
                        Text(habit.notes)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.large)
        .tint(color)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { editing = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ShareLink(item: CSVExport.habitFile(habit), preview: SharePreview("\(habit.name).csv")) {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                    Button(habit.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox") {
                        habit.isArchived.toggle()
                        ReminderScheduler.reschedule(habit)
                    }
                    Divider()
                    Button("Delete Habit", systemImage: "trash", role: .destructive) {
                        confirmingDelete = true
                    }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $editing) {
            HabitEditView(habit: habit)
        }
        .sheet(item: $amountTarget) { target in
            AmountEntrySheet(habit: target.habit, day: target.day)
        }
        .sheet(item: $noteTarget) { target in
            DayNoteSheet(habit: target.habit, day: target.day)
        }
        .confirmationDialog("Delete this habit?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete \(habit.name)", role: .destructive) {
                ReminderScheduler.cancel(habit)
                dismiss()
                // Delete after the pop animation so this screen never renders a deleted habit.
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    context.delete(habit)
                }
            }
        } message: {
            Text("Its whole history will be deleted. This can't be undone.")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { today = .today() }
        }
    }
}

/// Question, frequency and reminder shown under the title.
private struct DetailHeader: View {
    let habit: Habit

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !habit.question.isEmpty {
                Text(habit.question)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            FlowLayout(spacing: 8) {
                if habit.isMeasurable {
                    Chip(text: Formatting.target(for: habit), systemImage: "target")
                } else {
                    Chip(text: Formatting.frequency(habit.frequency), systemImage: "calendar")
                }
                if let reminder = Formatting.reminder(for: habit) {
                    Chip(text: reminder, systemImage: "bell")
                }
                if habit.isArchived {
                    Chip(text: String(localized: "Archived"), systemImage: "archivebox")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

private struct Chip: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
            .foregroundStyle(.secondary)
    }
}

/// A simple layout that wraps its children onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(width: bounds.width, subviews: subviews)
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !current.indices.isEmpty && current.width + spacing + size.width > width {
                rows.append(current)
                current = Row(y: current.y + current.height + spacing)
            }
            current.width += (current.indices.isEmpty ? 0 : spacing) + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

#Preview {
    let container = Persistence.preview
    let habit = try! container.mainContext.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.position)])).first!
    return NavigationStack {
        HabitDetailView(habit: habit)
    }
    .modelContainer(container)
}
