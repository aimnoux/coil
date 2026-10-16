import SwiftData
import SwiftUI

/// Creates a new habit (`habit == nil`) or edits an existing one.
struct HabitEditView: View {
    let habit: Habit?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Habit.position) private var allHabits: [Habit]

    @State private var kind: HabitKind = .yesNo
    @State private var name = ""
    @State private var question = ""
    @State private var notes = ""
    @State private var colorIndex = HabitColor.defaultIndex
    @State private var schedule = ScheduleDraft()
    @State private var unit = ""
    @State private var targetValue: Double? = nil
    @State private var targetType: TargetType = .atLeast
    @State private var targetPeriod: TargetPeriod = .day
    @State private var reminderEnabled = false
    @State private var reminderTime = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    @State private var reminderDays = 0b111_1111
    @State private var notificationsDenied = false
    @State private var loaded = false
    @FocusState private var nameFocused: Bool

    private var isNew: Bool { habit == nil }

    var body: some View {
        NavigationStack {
            Form {
                if isNew {
                    kindSection
                }
                nameSection
                colorSection
                if kind == .yesNo {
                    frequencySection
                } else {
                    targetSection
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
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: load)
        }
        .interactiveDismissDisabled(hasChanges)
    }

    // MARK: - Sections

    private var kindSection: some View {
        Section {
            Picker("Type", selection: $kind.animation()) {
                Text("Yes or No").tag(HabitKind.yesNo)
                Text("Measurable").tag(HabitKind.measurable)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        } footer: {
            Text(kind == .yesNo
                ? "Check it off when you do it. For example: did you exercise today?"
                : "Track a number every day. For example: how many pages did you read?")
        }
    }

    private var nameSection: some View {
        Section {
            TextField("Name", text: $name, prompt: Text(kind == .yesNo ? "Exercise" : "Read"))
                .font(.headline)
                .foregroundStyle(HabitColor(index: colorIndex).color)
                .focused($nameFocused)
                .submitLabel(.next)
            TextField(
                "Question",
                text: $question,
                prompt: Text(kind == .yesNo ? "Did you exercise today?" : "How many pages did you read today?"),
                axis: .vertical
            )
        } footer: {
            Text("The question appears in reminders.")
        }
    }

    private var colorSection: some View {
        Section("Color") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 10), spacing: 12) {
                ForEach(HabitColor.all) { color in
                    Button {
                        colorIndex = color.index
                    } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 26, height: 26)
                            .overlay {
                                if color.index == colorIndex {
                                    Circle()
                                        .strokeBorder(Color(.systemBackground), lineWidth: 2.5)
                                        .padding(2)
                                }
                            }
                            .overlay {
                                if color.index == colorIndex {
                                    Circle().strokeBorder(color.color, lineWidth: 2).padding(-3)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(color.name))
                    .accessibilityAddTraits(color.index == colorIndex ? .isSelected : [])
                }
            }
            .padding(.vertical, 6)
            .sensoryFeedback(.selection, trigger: colorIndex)
        }
    }

    private var frequencySection: some View {
        Section {
            Picker("Repeat", selection: $schedule.kind.animation()) {
                ForEach(ScheduleDraft.Kind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            switch schedule.kind {
            case .everyDay:
                EmptyView()
            case .everyNDays:
                Stepper(value: $schedule.days, in: 2...365) {
                    LabeledContent("Every", value: String(localized: "\(schedule.days) days"))
                }
            case .perWeek:
                Stepper(value: $schedule.times, in: 1...6) {
                    LabeledContent("Times per week", value: schedule.times, format: .number)
                }
            case .perMonth:
                Stepper(value: $schedule.times, in: 1...29) {
                    LabeledContent("Times per month", value: schedule.times, format: .number)
                }
            case .custom:
                Stepper(value: $schedule.times, in: 1...max(1, schedule.days)) {
                    LabeledContent("Times", value: schedule.times, format: .number)
                }
                Stepper(value: $schedule.days, in: 1...365) {
                    LabeledContent("In days", value: schedule.days, format: .number)
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
            TextField("Unit", text: $unit, prompt: Text("pages, km, glasses…"))
            Picker("Goal", selection: $targetType) {
                Text("At least").tag(TargetType.atLeast)
                Text("At most").tag(TargetType.atMost)
            }
            LabeledContent("Target") {
                TextField("Target", value: $targetValue, format: .number, prompt: Text("0"))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            Picker("Period", selection: $targetPeriod) {
                ForEach(TargetPeriod.allCases) { period in
                    Text(period.title).tag(period)
                }
            }
        } header: {
            Text("Target")
        } footer: {
            Text(targetType == .atLeast
                ? "The day counts as done once you reach the target."
                : "The day counts as done as long as you stay under the target.")
        }
    }

    private var reminderSection: some View {
        Section {
            Toggle("Reminder", isOn: $reminderEnabled.animation())
                .onChange(of: reminderEnabled) { _, enabled in
                    guard enabled else { return }
                    Task {
                        let granted = await ReminderScheduler.requestAuthorization()
                        notificationsDenied = !granted
                    }
                }
            if reminderEnabled {
                DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                WeekdayPicker(mask: $reminderDays, tint: HabitColor(index: colorIndex).color)
            }
        } footer: {
            if reminderEnabled && notificationsDenied {
                Text("Notifications are turned off for Coil. Turn them on in the Settings app to get reminders.")
                    .foregroundStyle(.red)
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Notes", text: $notes, prompt: Text("Why this habit matters, tips, anything"), axis: .vertical)
                .lineLimit(3...8)
        }
    }

    // MARK: - Load & save

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && (kind == .yesNo || (targetValue ?? -1) >= 0)
            && (!reminderEnabled || reminderDays != 0)
    }

    private var hasChanges: Bool {
        guard loaded else { return false }
        guard let habit else { return !name.isEmpty || !question.isEmpty || !notes.isEmpty }
        return name != habit.name || question != habit.question || notes != habit.notes
            || colorIndex != habit.colorIndex || frequency != habit.frequency
    }

    private var frequency: Frequency {
        kind == .yesNo ? schedule.frequency : targetPeriod.frequency
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let habit else {
            colorIndex = nextColor()
            nameFocused = true
            return
        }
        kind = habit.kind
        name = habit.name
        question = habit.question
        notes = habit.notes
        colorIndex = habit.colorIndex
        schedule = ScheduleDraft(habit.frequency)
        unit = habit.unit
        targetValue = habit.targetValue
        targetType = habit.targetType
        targetPeriod = TargetPeriod(habit.frequency)
        reminderEnabled = habit.reminderEnabled
        reminderTime = Calendar.current.date(
            from: DateComponents(hour: habit.reminderHour, minute: habit.reminderMinute)) ?? Date()
        reminderDays = habit.reminderDays
    }

    /// Suggest a color that isn't used yet.
    private func nextColor() -> Int {
        let used = Set(allHabits.map(\.colorIndex))
        let preferred = [10, 0, 6, 2, 12, 9, 14, 4, 7, 11, 16, 3]
        return preferred.first { !used.contains($0) } ?? HabitColor.defaultIndex
    }

    private func save() {
        let target: Habit
        if let habit {
            target = habit
        } else {
            target = Habit(kind: kind)
            target.position = (allHabits.map(\.position).max() ?? -1) + 1
            context.insert(target)
        }
        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        target.colorIndex = colorIndex
        target.frequency = frequency
        if kind == .measurable {
            target.unit = unit.trimmingCharacters(in: .whitespaces)
            target.targetValue = targetValue ?? 0
            target.targetType = targetType
        }
        let time = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        target.reminderEnabled = reminderEnabled
        target.reminderHour = time.hour ?? 8
        target.reminderMinute = time.minute ?? 0
        target.reminderDays = reminderDays
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
