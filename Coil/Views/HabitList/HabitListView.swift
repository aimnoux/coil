import SwiftData
import SwiftUI

/// The main screen: every habit with its strength and checkmarks for the last few days.
struct HabitListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Habit.position) private var habits: [Habit]

    @AppStorage(SettingsKey.sortOrder) private var sortOrder = HabitSortOrder.manual
    @AppStorage(SettingsKey.showArchived) private var showArchived = false
    @AppStorage(SettingsKey.hideCompleted) private var hideCompleted = false
    @AppStorage(SettingsKey.todayOnRight) private var todayOnRight = false
    @AppStorage(SettingsKey.longPressToToggle) private var longPressToToggle = false
    @AppStorage(SettingsKey.skipEnabled) private var skipEnabled = false
    @AppStorage(SettingsKey.showQuestionMarks) private var showQuestionMarks = false

    @State private var path: [Habit] = []
    @State private var today = Day.today()
    @State private var listWidth: CGFloat = 400
    /// Room kept for the habit name; grows with Dynamic Type so names stay readable.
    @ScaledMetric(relativeTo: .body) private var nameWidth: CGFloat = 120
    /// How many days the checkmark columns are scrolled back from today.
    @State private var dayOffset = 0
    @State private var editMode: EditMode = .inactive
    @State private var selection = Set<UUID>()
    @State private var confirmingBulkDelete = false
    #if DEBUG
    @State private var openedScreenshotScreen = false
    #endif
    @State private var editorHabit: HabitEditorTarget?
    @State private var amountTarget: AmountEntryTarget?
    @State private var habitToDelete: Habit?
    @State private var showingSettings = false
    @State private var hint: LocalizedStringKey?

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Habits")
                .toolbar { toolbar }
                .navigationDestination(for: Habit.self) { habit in
                    HabitDetailView(habit: habit)
                }
        }
        .sheet(item: $editorHabit) { target in
            HabitEditView(habit: target.habit)
        }
        .sheet(item: $amountTarget) { target in
            AmountEntrySheet(habit: target.habit, day: target.day)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .confirmationDialog(
            "Delete this habit?",
            isPresented: Binding(get: { habitToDelete != nil }, set: { if !$0 { habitToDelete = nil } }),
            titleVisibility: .visible,
            presenting: habitToDelete
        ) { habit in
            Button("Delete \(habit.name)", role: .destructive) { delete(habit) }
        } message: { _ in
            Text("Its whole history will be deleted. This can't be undone.")
        }
        .confirmationDialog(
            "Delete \(selection.count) habits?",
            isPresented: $confirmingBulkDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deleteSelected() }
        } message: {
            Text("Their whole history will be deleted. This can't be undone.")
        }
        .overlay(alignment: .bottom) { hintBanner }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { today = .today() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            today = .today()
        }
        .onOpenURL(perform: handle)
        #if DEBUG
        .onChange(of: habits.isEmpty, initial: true) { _, isEmpty in
            // Wait until the habits have loaded before opening a screen for screenshots.
            if !isEmpty && !openedScreenshotScreen {
                openedScreenshotScreen = true
                openScreenForScreenshots()
            }
        }
        #endif
        .onChange(of: Router.shared.habitToOpen, initial: true) { _, id in
            guard let id, let habit = habits.first(where: { $0.id == id }) else { return }
            path = [habit]
            Router.shared.habitToOpen = nil
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if habits.isEmpty {
            ContentUnavailableView {
                Label("No Habits Yet", systemImage: "circle.dashed")
            } description: {
                Text("Build good habits by checking them off every day. Your progress turns into habit strength over time.")
            } actions: {
                Button("Add Habit") { editorHabit = HabitEditorTarget(habit: nil) }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            let rows = displayedRows
            List(selection: $selection) {
                Section {
                    ForEach(rows) { row in
                        habitRow(row.habit, stats: row.stats)
                            .moveDisabled(sortOrder != .manual)
                    }
                    .onMove { move(from: $0, to: $1) }
                } header: {
                    DayHeader(days: visibleDays, today: today, isScrolledBack: dayOffset > 0) {
                        withAnimation(.snappy) { dayOffset = 0 }
                    }
                    .padding(.trailing, 8)
                    .listRowInsets(EdgeInsets())
                    .contentShape(Rectangle())
                    .gesture(daySwipe)
                }
                if rows.isEmpty {
                    emptyFilterMessage
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, $editMode)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                listWidth = width
            }
        }
    }

    private func habitRow(_ habit: Habit, stats: HabitStats) -> some View {
        HabitRow(
            habit: habit,
            stats: stats,
            days: visibleDays,
            longPressToToggle: longPressToToggle,
            showQuestionMarks: showQuestionMarks,
            isEditing: editMode.isEditing,
            onOpen: { path.append(habit) },
            onTap: { day in tap(habit, stats: stats, day: day) },
            onHint: { showHint("Press and hold to check off") }
        )
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 8))
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash") { habitToDelete = habit }
                .tint(.red)
            Button(habit.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox") {
                setArchived(habit, !habit.isArchived)
            }
            .tint(.orange)
        }
        .swipeActions(edge: .leading) {
            Button("Edit", systemImage: "pencil") { editorHabit = HabitEditorTarget(habit: habit) }
                .tint(.blue)
        }
        .contextMenu {
            Button("Edit", systemImage: "pencil") { editorHabit = HabitEditorTarget(habit: habit) }
            Button(habit.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox") {
                setArchived(habit, !habit.isArchived)
            }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) { habitToDelete = habit }
        }
    }

    private var emptyFilterMessage: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text("All done for today")
                .font(.headline)
            Text("Completed habits are hidden.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private var hintBanner: some View {
        if let hint {
            Text(hint)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Settings", systemImage: "gearshape") { showingSettings = true }
        }
        if editMode.isEditing {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    withAnimation { editMode = .inactive }
                    selection.removeAll()
                }
                .bold()
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Archive", systemImage: "archivebox") { archiveSelected() }
                    .disabled(selection.isEmpty)
                Menu {
                    ForEach(HabitColor.all) { color in
                        Button {
                            recolorSelected(color.index)
                        } label: {
                            Label {
                                Text(color.name)
                            } icon: {
                                Image(systemName: "circle.fill")
                                    .foregroundStyle(color.color, color.color)
                            }
                        }
                    }
                } label: {
                    Label("Color", systemImage: "paintpalette")
                }
                .disabled(selection.isEmpty)
                Spacer()
                Button("Delete", systemImage: "trash", role: .destructive) { confirmingBulkDelete = true }
                    .disabled(selection.isEmpty)
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                filterMenu
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add Habit", systemImage: "plus") { editorHabit = HabitEditorTarget(habit: nil) }
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Sort By", selection: $sortOrder) {
                ForEach(HabitSortOrder.allCases) { order in
                    Label(order.title, systemImage: order.systemImage).tag(order)
                }
            }
            .pickerStyle(.menu)
            Section {
                Toggle("Show Archived", systemImage: "archivebox", isOn: $showArchived)
                Toggle("Hide Completed", systemImage: "checkmark.circle", isOn: $hideCompleted)
            }
            if !habits.isEmpty {
                Button(
                    sortOrder == .manual ? "Select and Reorder" : "Select Habits",
                    systemImage: "checkmark.circle"
                ) {
                    withAnimation { editMode = .active }
                }
            }
        } label: {
            Label("Sort and Filter", systemImage: "line.3.horizontal.decrease")
        }
    }

    // MARK: - Data

    /// How many day columns fit next to the score ring and the habit name.
    private var columnCount: Int {
        let available = listWidth - 50 - nameWidth
        return max(2, min(8, Int(available / checkmarkColumnWidth)))
    }

    /// Swiping the day header pages through older days, like in Loop.
    private var daySwipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                // Older days lie to the right when today is on the left, and vice versa.
                let towardsPast = todayOnRight ? value.translation.width > 0 : value.translation.width < 0
                withAnimation(.snappy) {
                    dayOffset = max(0, dayOffset + (towardsPast ? columnCount : -columnCount))
                }
            }
    }

    private var visibleDays: [Day] {
        // While selecting or reordering, rows show only names, like lists in system apps.
        if editMode.isEditing { return [] }
        let newest = today.advanced(by: -dayOffset)
        let days = (0..<columnCount).map { newest.advanced(by: -$0) }
        return todayOnRight ? days.reversed() : days
    }

    private var displayedRows: [HabitRowData] {
        var rows = habits
            .filter { showArchived || !$0.isArchived }
            .map { HabitRowData(habit: $0, stats: $0.stats(today: today)) }
        if hideCompleted {
            rows.removeAll { $0.stats.isCompletedToday }
        }
        switch sortOrder {
        case .manual:
            break
        case .name:
            rows.sort { $0.habit.name.localizedStandardCompare($1.habit.name) == .orderedAscending }
        case .color:
            rows.sort { ($0.habit.colorIndex, $0.habit.position) < ($1.habit.colorIndex, $1.habit.position) }
        case .score:
            rows.sort { $0.stats.currentScore > $1.stats.currentScore }
        case .status:
            // Habits still to do today come first.
            rows.sort { !$0.stats.isCompletedToday && $1.stats.isCompletedToday }
        }
        // Archived habits always go last.
        return rows.filter { !$0.habit.isArchived } + rows.filter { $0.habit.isArchived }
    }

    // MARK: - Actions

    private func tap(_ habit: Habit, stats: HabitStats, day: Day) {
        if habit.isMeasurable {
            amountTarget = AmountEntryTarget(habit: habit, day: day)
            return
        }
        let next = EntryCycle.next(
            after: stats.checkmark(on: day),
            skipEnabled: skipEnabled,
            showQuestionMarks: showQuestionMarks
        )
        withAnimation(.snappy) {
            habit.setRecord(next, on: day, in: context)
        }
        if day == today, next?.state == .yes {
            ReminderScheduler.removeDeliveredReminders(for: habit)
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var visible = displayedRows.map(\.habit)
        let slots = visible.compactMap { habits.firstIndex(of: $0) }
        visible.move(fromOffsets: source, toOffset: destination)
        var ordered = habits
        for (slot, habit) in zip(slots.sorted(), visible) {
            ordered[slot] = habit
        }
        for (index, habit) in ordered.enumerated() {
            habit.position = index
        }
    }

    private var selectedHabits: [Habit] {
        habits.filter { selection.contains($0.id) }
    }

    private func archiveSelected() {
        // Archive the selection, or restore it if every selected habit is already archived.
        let habits = selectedHabits
        let archive = habits.contains { !$0.isArchived }
        withAnimation {
            for habit in habits {
                habit.isArchived = archive
                ReminderScheduler.reschedule(habit)
            }
            selection.removeAll()
        }
        showHint(archive ? "Habits archived" : "Habits restored")
    }

    private func recolorSelected(_ colorIndex: Int) {
        withAnimation {
            selectedHabits.forEach { $0.colorIndex = colorIndex }
        }
    }

    private func deleteSelected() {
        withAnimation {
            for habit in selectedHabits {
                ReminderScheduler.cancel(habit)
                context.delete(habit)
            }
            selection.removeAll()
            editMode = .inactive
        }
    }

    private func setArchived(_ habit: Habit, _ archived: Bool) {
        withAnimation {
            habit.isArchived = archived
        }
        ReminderScheduler.reschedule(habit)
        showHint(archived ? "Habit archived" : "Habit restored")
    }

    private func delete(_ habit: Habit) {
        ReminderScheduler.cancel(habit)
        withAnimation {
            context.delete(habit)
        }
    }

    private func showHint(_ text: LocalizedStringKey) {
        withAnimation { hint = text }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { hint = nil }
        }
    }

    /// Handles `coil://habit/<uuid>` links from widgets and notifications.
    private func handle(_ url: URL) {
        guard url.scheme == "coil", url.host() == "habit",
              let id = UUID(uuidString: url.lastPathComponent),
              let habit = habits.first(where: { $0.id == id })
        else { return }
        path = [habit]
    }
}

struct HabitRowData: Identifiable {
    let habit: Habit
    let stats: HabitStats
    var id: UUID { habit.id }
}

#if DEBUG
extension HabitListView {
    /// `-screenshotHabit <n>` opens the n-th habit, `-screenshotEditor YES` edits the first habit,
    /// `-screenshotSelect YES` starts selection mode with two habits selected.
    /// Used to take App Store screenshots from the command line (see docs/APP_STORE.md).
    fileprivate func openScreenForScreenshots() {
        let arguments = UserDefaults.standard
        if arguments.object(forKey: "screenshotHabit") != nil {
            let index = arguments.integer(forKey: "screenshotHabit")
            if habits.indices.contains(index) { path = [habits[index]] }
        }
        if arguments.bool(forKey: "screenshotEditor") {
            editorHabit = HabitEditorTarget(habit: habits.first)
        }
        if arguments.bool(forKey: "screenshotSelect") {
            editMode = .active
            selection = Set(habits.prefix(2).map(\.id))
        }
    }
}
#endif

/// A habit to edit, or `nil` to create a new one.
struct HabitEditorTarget: Identifiable {
    let habit: Habit?
    var id: String { habit.map { "\($0.id)" } ?? "new" }
}

#Preview {
    HabitListView()
        .modelContainer(Persistence.preview)
}
