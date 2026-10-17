import SwiftData
import SwiftUI

/// Creates a new habit (`habit == nil`, optionally from a template) or edits an existing one.
struct HabitEditView: View {
    let habit: Habit?
    var template: HabitDraft?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Habit.position) private var allHabits: [Habit]
    @Query(sort: \HabitGroup.position) private var groups: [HabitGroup]

    @State private var draft = HabitDraft()
    @State private var original = HabitDraft()
    @State private var notificationsDenied = false
    @State private var loaded = false
    @State private var choosingIcon = false
    @State private var newGroupName = ""
    @State private var creatingGroup = false
    @FocusState private var nameFocused: Bool

    private var isNew: Bool { habit == nil }
    private var palette: HabitColor { HabitColor(index: draft.colorIndex) }

    var body: some View {
        NavigationStack {
            Form {
                if isNew {
                    kindSection
                }
                nameSection
                colorSection
                groupSection
                switch draft.kind {
                case .yesNo: frequencySection
                case .measurable: targetSection
                case .quit: EmptyView()
                }
                challengeSection
                if HealthSync.isSupported && draft.kind != .quit {
                    healthSection
                }
                reminderSection
                notesSection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isNew ? "New Habit" : "Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!draft.isValid)
                }
            }
            .sheet(isPresented: $choosingIcon) {
                IconPicker(selection: $draft.iconName, palette: palette)
            }
            .alert("New Group", isPresented: $creatingGroup) {
                TextField("Name", text: $newGroupName)
                Button("Cancel", role: .cancel) { newGroupName = "" }
                Button("Create") { createGroup() }
            }
            .onAppear(perform: load)
        }
        .interactiveDismissDisabled(hasChanges)
    }

    // MARK: - Sections

    private var kindSection: some View {
        Section {
            Picker("Type", selection: $draft.kind.animation()) {
                Text("Yes or No").tag(HabitKind.yesNo)
                Text("Measurable").tag(HabitKind.measurable)
                Text("Quit").tag(HabitKind.quit)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        } footer: {
            switch draft.kind {
            case .yesNo: Text("Check it off when you do it. For example: did you exercise today?")
            case .measurable: Text("Track a number every day. For example: how many pages did you read?")
            case .quit: Text("Every day counts as clean until you record a slip. For example: no smoking.")
            }
        }
    }

    private var nameSection: some View {
        Section {
            HStack(spacing: 12) {
                Button {
                    choosingIcon = true
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(palette.color.opacity(0.22))
                        Image(systemName: draft.iconName.isEmpty ? "plus" : draft.iconName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(palette.ink)
                    }
                    .frame(width: 46, height: 46)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Icon")
                TextField("Name", text: $draft.name, prompt: Text(namePrompt))
                    .font(.headline)
                    .focused($nameFocused)
                    .submitLabel(.next)
            }
            TextField("Question", text: $draft.question, prompt: Text(questionPrompt), axis: .vertical)
        } footer: {
            Text("The question appears in reminders.")
        }
    }

    private var namePrompt: LocalizedStringKey {
        switch draft.kind {
        case .yesNo: "Exercise"
        case .measurable: "Read"
        case .quit: "No smoking"
        }
    }

    private var questionPrompt: LocalizedStringKey {
        switch draft.kind {
        case .yesNo: "Did you exercise today?"
        case .measurable: "How many pages did you read today?"
        case .quit: "Stayed smoke-free today?"
        }
    }

    private var colorSection: some View {
        Section("Color") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 10), spacing: 12) {
                ForEach(HabitColor.all) { color in
                    Button {
                        draft.colorIndex = color.index
                    } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 26, height: 26)
                            .overlay {
                                if color.index == draft.colorIndex {
                                    Circle()
                                        .strokeBorder(Color(.systemBackground), lineWidth: 2.5)
                                        .padding(2)
                                }
                            }
                            .overlay {
                                if color.index == draft.colorIndex {
                                    Circle().strokeBorder(color.color, lineWidth: 2).padding(-3)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(color.name))
                    .accessibilityAddTraits(color.index == draft.colorIndex ? .isSelected : [])
                }
            }
            .padding(.vertical, 6)
            .sensoryFeedback(.selection, trigger: draft.colorIndex)
        }
    }

    private var groupSection: some View {
        Section {
            Picker("Group", selection: $draft.groupID) {
                Text("None").tag(UUID?.none)
                ForEach(groups) { group in
                    Text(group.name).tag(Optional(group.id))
                }
            }
            Button("New Group…", systemImage: "folder.badge.plus") { creatingGroup = true }
        } footer: {
            Text("Groups split the habit list into sections, like Morning or Health.")
        }
    }

    private var frequencySection: some View {
        Section {
            Picker("Repeat", selection: $draft.schedule.kind.animation()) {
                ForEach(ScheduleDraft.Kind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            switch draft.schedule.kind {
            case .everyDay:
                EmptyView()
            case .everyNDays:
                Stepper(value: $draft.schedule.days, in: 2...365) {
                    LabeledContent("Every", value: String(localized: "\(draft.schedule.days) days"))
                }
            case .perWeek:
                Stepper(value: $draft.schedule.times, in: 1...6) {
                    LabeledContent("Times per week", value: draft.schedule.times, format: .number)
                }
            case .perMonth:
                Stepper(value: $draft.schedule.times, in: 1...29) {
                    LabeledContent("Times per month", value: draft.schedule.times, format: .number)
                }
            case .custom:
                Stepper(value: $draft.schedule.times, in: 1...max(1, draft.schedule.days)) {
                    LabeledContent("Times", value: draft.schedule.times, format: .number)
                }
                Stepper(value: $draft.schedule.days, in: 1...365) {
                    LabeledContent("In days", value: draft.schedule.days, format: .number)
                }
            }
        } header: {
            Text("Frequency")
        } footer: {
            Text("Habit strength takes the frequency into account: a weekly habit isn't hurt by the days it isn't due.")
        }
    }

    private var targetSection: some View {
        Section {
            Toggle("Track Time", systemImage: "stopwatch", isOn: $draft.isTimed.animation())
            if draft.isTimed {
                Stepper(value: $draft.timerMinutes, in: 0...240, step: 5) {
                    LabeledContent("Timer") {
                        Text(draft.timerMinutes == 0
                             ? String(localized: "Stopwatch")
                             : String(localized: "\(draft.timerMinutes) min"))
                    }
                }
            } else {
                TextField("Unit", text: $draft.unit, prompt: Text("pages, km, glasses…"))
            }
            Picker("Goal", selection: $draft.targetType) {
                Text("At least").tag(TargetType.atLeast)
                Text("At most").tag(TargetType.atMost)
            }
            LabeledContent(draft.isTimed ? "Target, min" : "Target") {
                TextField("Target", value: $draft.targetValue, format: .number, prompt: Text("0"))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            Picker("Period", selection: $draft.targetPeriod) {
                ForEach(TargetPeriod.allCases) { period in
                    Text(period.title).tag(period)
                }
            }
        } header: {
            Text("Target")
        } footer: {
            if draft.isTimed {
                Text("Start a stopwatch or timer from the habit screen. Every run is saved and can be edited later.")
            } else {
                Text(draft.targetType == .atLeast
                    ? "The day counts as done once you reach the target."
                    : "The day counts as done as long as you stay under the target.")
            }
        }
    }

    private var challengeSection: some View {
        Section {
            Toggle("Challenge", systemImage: "flag.checkered", isOn: Binding(
                get: { draft.challengeDays > 0 },
                set: { on in withAnimation { draft.challengeDays = on ? 30 : 0 } }
            ))
            if draft.challengeDays > 0 {
                Picker("Length", selection: $draft.challengeDays) {
                    ForEach([7, 14, 21, 30, 40, 60, 66, 90, 100, 180, 365], id: \.self) { days in
                        Text(String(localized: "\(days) days")).tag(days)
                    }
                }
            }
        } footer: {
            if draft.challengeDays > 0 {
                Text("The challenge starts today. Keep the habit every scheduled day until the end to complete it.")
            }
        }
    }

    private var healthSection: some View {
        Section {
            Picker("Apple Health", systemImage: "heart.text.square", selection: Binding(
                get: { draft.healthMetric },
                set: { metric in
                    withAnimation { draft.healthMetric = metric }
                    guard let metric else { return }
                    if draft.kind == .measurable {
                        draft.unit = String(localized: metric.unit)
                        draft.isTimed = false
                        if (draft.targetValue ?? 0) == 0 { draft.targetValue = metric.suggestedTarget }
                    } else if draft.healthThreshold == 0 {
                        draft.healthThreshold = metric.suggestedTarget
                    }
                }
            )) {
                Text("Off").tag(HealthMetric?.none)
                ForEach(HealthMetric.allCases) { metric in
                    Label { Text(metric.title) } icon: { Image(systemName: metric.systemImage) }
                        .tag(Optional(metric))
                }
            }
            if let metric = draft.healthMetric, draft.kind == .yesNo {
                LabeledContent {
                    TextField("Threshold", value: $draft.healthThreshold, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Text("Done at \(String(localized: metric.unit))")
                }
            }
        } footer: {
            if draft.healthMetric != nil {
                Text("Days are filled in automatically from Apple Health. Your own changes are kept.")
            }
        }
    }

    private var reminderSection: some View {
        Section {
            // Ask for notification permission only when the user turns a reminder on,
            // not when an existing habit with a reminder is loaded.
            Toggle("Reminder", systemImage: "bell", isOn: Binding(
                get: { draft.reminderEnabled },
                set: { enabled in
                    withAnimation { draft.reminderEnabled = enabled }
                    guard enabled else { return }
                    Task {
                        let granted = await ReminderScheduler.requestAuthorization()
                        notificationsDenied = !granted
                    }
                }
            ))
            if draft.reminderEnabled {
                ForEach(draft.reminderTimes.indices, id: \.self) { index in
                    DatePicker(
                        draft.reminderTimes.count > 1 ? String(localized: "Time \(index + 1)") : String(localized: "Time"),
                        selection: timeBinding(index),
                        displayedComponents: .hourAndMinute
                    )
                    .swipeActions {
                        if draft.reminderTimes.count > 1 {
                            Button("Delete", role: .destructive) {
                                draft.reminderTimes.remove(at: index)
                            }
                        }
                    }
                }
                if draft.reminderTimes.count < 8 {
                    Button("Add Time", systemImage: "plus.circle") {
                        let last = draft.reminderTimes.last ?? 8 * 60
                        draft.reminderTimes.append(min(last + 180, 23 * 60))
                    }
                }
                WeekdayPicker(mask: $draft.reminderDays, tint: palette.color)
            }
        } footer: {
            if draft.reminderEnabled && notificationsDenied {
                Text("Notifications are turned off for Coil. Turn them on in the Settings app to get reminders.")
                    .foregroundStyle(.red)
            } else if draft.reminderEnabled {
                Text("Reminders are skipped on days when the habit is already done or paused. Swipe a time to remove it.")
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Notes", text: $draft.notes, prompt: Text("Why this habit matters, tips, anything"), axis: .vertical)
                .lineLimit(3...8)
        }
    }

    private func timeBinding(_ index: Int) -> Binding<Date> {
        Binding(
            get: {
                let minutes = draft.reminderTimes.indices.contains(index) ? draft.reminderTimes[index] : 8 * 60
                return Calendar.current.date(from: DateComponents(hour: minutes / 60, minute: minutes % 60)) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                guard draft.reminderTimes.indices.contains(index) else { return }
                draft.reminderTimes[index] = (c.hour ?? 8) * 60 + (c.minute ?? 0)
            }
        )
    }

    // MARK: - Load & save

    private var hasChanges: Bool {
        guard loaded else { return false }
        return draft.name != original.name || draft.question != original.question || draft.notes != original.notes
            || draft.colorIndex != original.colorIndex || draft.iconName != original.iconName
            || draft.frequency != original.frequency
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let habit {
            draft = HabitDraft(habit)
        } else {
            draft = template ?? HabitDraft()
            if template == nil {
                draft.colorIndex = nextColor()
                nameFocused = true
            }
        }
        original = habit.map(HabitDraft.init) ?? HabitDraft()
    }

    /// Suggest a color that isn't used yet.
    private func nextColor() -> Int {
        let used = Set(allHabits.map(\.colorIndex))
        let preferred = [10, 0, 6, 2, 12, 9, 14, 4, 7, 11, 16, 3]
        return preferred.first { !used.contains($0) } ?? HabitColor.defaultIndex
    }

    private func createGroup() {
        let name = newGroupName.trimmingCharacters(in: .whitespaces)
        newGroupName = ""
        guard !name.isEmpty else { return }
        let group = HabitGroup(name: name, position: (groups.map(\.position).max() ?? -1) + 1)
        context.insert(group)
        draft.groupID = group.id
    }

    private func save() {
        let target: Habit
        if let habit {
            target = habit
        } else {
            target = Habit(kind: draft.kind)
            target.position = (allHabits.map(\.position).max() ?? -1) + 1
            context.insert(target)
        }
        draft.apply(to: target, groups: groups)
        ReminderScheduler.reschedule(target)
        dismiss()
    }
}

/// Editable form of a yes/no habit's frequency.
struct ScheduleDraft: Equatable {
    enum Kind: String, CaseIterable, Identifiable {
        case everyDay, everyNDays, perWeek, perMonth, custom
        var id: String { rawValue }

        var title: LocalizedStringKey {
            switch self {
            case .everyDay: "Every day"
            case .everyNDays: "Every few days"
            case .perWeek: "Times per week"
            case .perMonth: "Times per month"
            case .custom: "Custom"
            }
        }
    }

    var kind: Kind = .everyDay
    var times = 3
    var days = 2

    init() {}

    init(_ frequency: Frequency) {
        switch frequency.preset {
        case .everyDay:
            kind = .everyDay
        case .everyNDays(let n):
            kind = .everyNDays
            days = n
        case .timesPerWeek(let n):
            kind = .perWeek
            times = n
        case .timesPerMonth(let n):
            kind = .perMonth
            times = n
        case .custom(let n, let d):
            kind = .custom
            times = n
            days = d
        }
    }

    var frequency: Frequency {
        switch kind {
        case .everyDay: .daily
        case .everyNDays: Frequency(1, days)
        case .perWeek: Frequency(min(times, 7), 7)
        case .perMonth: Frequency(min(times, 30), 30)
        case .custom: Frequency(min(times, days), days)
        }
    }
}

/// The period a measurable habit's target applies to.
enum TargetPeriod: Int, CaseIterable, Identifiable {
    case day = 1, week = 7, month = 30

    var id: Int { rawValue }

    init(_ frequency: Frequency) {
        self = TargetPeriod(rawValue: frequency.denominator) ?? .day
    }

    var frequency: Frequency { Frequency(1, rawValue) }

    var title: LocalizedStringKey {
        switch self {
        case .day: "Every day"
        case .week: "Every week"
        case .month: "Every month"
        }
    }
}

/// Seven round toggles for choosing reminder weekdays.
struct WeekdayPicker: View {
    @Binding var mask: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(orderedWeekdays, id: \.self) { weekday in
                let isOn = mask & (1 << (weekday - 1)) != 0
                Button {
                    mask ^= 1 << (weekday - 1)
                } label: {
                    Text(Formatting.veryShortWeekday(weekday))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(isOn ? tint : Color(.tertiarySystemFill), in: Circle())
                        .foregroundStyle(isOn ? .white : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(Calendar.current.weekdaySymbols[weekday - 1]))
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
        .sensoryFeedback(.selection, trigger: mask)
    }

    private var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }
}

#Preview("New") {
    HabitEditView(habit: nil)
        .modelContainer(Persistence.preview)
}
