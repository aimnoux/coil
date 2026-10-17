import SwiftData
import SwiftUI

/// Big stopwatch/countdown display with start and stop, for timed habits.
struct TimerControl: View {
    let habit: Habit

    @Environment(\.modelContext) private var context

    var body: some View {
        let session = TimerService.activeSession(of: habit)
        let countdown = TimerService.countdown(of: habit)
        let palette = habit.color
        VStack(spacing: 16) {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let elapsed = session?.duration(at: timeline.date) ?? 0
                let shown = countdown.map { max(0, $0 - elapsed) } ?? elapsed
                let progress = countdown.map { min(1, elapsed / $0) } ?? 0
                ZStack {
                    Circle()
                        .stroke(palette.color.opacity(0.22), lineWidth: 10)
                    if countdown != nil && session != nil {
                        Circle()
                            .trim(from: 0, to: max(0.001, progress))
                            .stroke(palette.color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    VStack(spacing: 4) {
                        Text(Formatting.clock(session == nil ? (countdown ?? 0) : shown))
                            .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                            .contentTransition(.numericText())
                        Text(countdown == nil ? "Stopwatch" : "Timer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 180, height: 180)
                .onChange(of: elapsed >= (countdown ?? .infinity)) { _, finished in
                    if finished, let session { TimerService.stop(session, in: context) }
                }
            }
            if let session {
                Button {
                    withAnimation { TimerService.stop(session, in: context) }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.ink)
            } else {
                Button {
                    withAnimation { TimerService.start(habit, in: context) }
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.ink)
            }
        }
        .sensoryFeedback(.impact, trigger: session == nil)
    }
}

/// Timer card on the habit screen: controls, today's total and recent sessions.
struct TimerCard: View {
    let habit: Habit
    let today: Day

    @State private var editing: TimerSession?
    @State private var adding = false

    var body: some View {
        let todays = TimerService.sessions(of: habit, on: today)
        let total = todays.reduce(0) { $0 + $1.duration() }
        let recent = habit.liveSessions.filter { !$0.isRunning }.sorted { $0.start > $1.start }.prefix(6)
        Card("Timer") {
            NavigationLink {
                SessionHistoryView(habit: habit)
            } label: {
                Text("History")
                    .font(.subheadline.weight(.medium))
            }
        } content: {
            VStack(alignment: .leading, spacing: 16) {
                TimerControl(habit: habit)
                    .frame(maxWidth: .infinity)
                LabeledContent("Today") {
                    Text(Formatting.duration(total))
                        .monospacedDigit()
                }
                .font(.subheadline)
                if !recent.isEmpty {
                    Divider()
                    ForEach(Array(recent)) { session in
                        SessionRow(session: session) { editing = session }
                    }
                }
                Button("Add Time Manually", systemImage: "plus") { adding = true }
                    .font(.subheadline)
            }
        }
        .sheet(item: $editing) { session in
            SessionEditSheet(habit: habit, session: session)
        }
        .sheet(isPresented: $adding) {
            SessionEditSheet(habit: habit, session: nil)
        }
    }
}

struct SessionRow: View {
    let session: TimerSession
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.start.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                        .font(.subheadline)
                    if !session.note.isEmpty {
                        Text(session.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text(session.isRunning ? String(localized: "Running") : Formatting.duration(session.duration()))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Every session of a timed habit, by day, with editing.
struct SessionHistoryView: View {
    let habit: Habit

    @Environment(\.modelContext) private var context
    @State private var editing: TimerSession?
    @State private var adding = false

    var body: some View {
        let byDay = Dictionary(grouping: habit.liveSessions) { Day($0.start) }
        let days = byDay.keys.sorted(by: >)
        List {
            if days.isEmpty {
                ContentUnavailableView("No Sessions Yet", systemImage: "stopwatch",
                                       description: Text("Start the timer on the habit screen."))
            }
            ForEach(days, id: \.self) { day in
                let sessions = (byDay[day] ?? []).sorted { $0.start < $1.start }
                Section {
                    ForEach(sessions) { session in
                        SessionRow(session: session) { editing = session }
                    }
                    .onDelete { offsets in
                        for index in offsets { TimerService.delete(sessions[index], in: context) }
                    }
                } header: {
                    HStack {
                        Text(Formatting.fullDate(day))
                        Spacer()
                        Text(Formatting.duration(sessions.reduce(0) { $0 + $1.duration() }))
                    }
                }
            }
        }
        .navigationTitle("Sessions")
        .toolbar {
            Button("Add", systemImage: "plus") { adding = true }
        }
        .sheet(item: $editing) { session in
            SessionEditSheet(habit: habit, session: session)
        }
        .sheet(isPresented: $adding) {
            SessionEditSheet(habit: habit, session: nil)
        }
    }
}

/// Edits a session's start, end and note — or adds a new one (`session == nil`).
struct SessionEditSheet: View {
    let habit: Habit
    let session: TimerSession?
    /// The day a new session is added to.
    var day: Day = .today()

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var start = Date().addingTimeInterval(-30 * 60)
    @State private var end = Date()
    @State private var isRunning = false
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Start", selection: $start)
                    if isRunning {
                        Toggle("Still running", isOn: $isRunning)
                    } else {
                        DatePicker("End", selection: $end, in: start...)
                    }
                    LabeledContent("Duration") {
                        Text(Formatting.duration((isRunning ? Date() : end).timeIntervalSince(start)))
                            .monospacedDigit()
                    }
                } footer: {
                    Text("Forgot to stop the timer? Set the time it really ended.")
                }
                Section {
                    TextField("Note", text: $note, prompt: Text("What did you do?"), axis: .vertical)
                }
                if let session {
                    Section {
                        Button("Delete Session", systemImage: "trash", role: .destructive) {
                            TimerService.delete(session, in: context)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(session == nil ? "Add Time" : "Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isRunning && end < start)
                }
            }
            .onAppear {
                guard let session else {
                    // New sessions default to half an hour ending now (or at noon on a past day).
                    let reference = day == .today() ? Date() : day.date().addingTimeInterval(12 * 3600)
                    start = reference.addingTimeInterval(-30 * 60)
                    end = reference
                    return
                }
                start = session.start
                end = session.end ?? Date()
                isRunning = session.isRunning
                note = session.note
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        if let session {
            TimerService.update(session, start: start, end: isRunning ? nil : end, note: note, in: context)
        } else {
            TimerService.addSession(to: habit, start: start, end: end, note: note, in: context)
        }
        dismiss()
    }
}

/// For a timed habit's day in the list: today's timer plus that day's sessions.
struct TimedDaySheet: View {
    let habit: Habit
    let day: Day

    @Environment(\.dismiss) private var dismiss
    @State private var editing: TimerSession?
    @State private var adding = false

    var body: some View {
        NavigationStack {
            List {
                if day == .today() {
                    Section {
                        TimerControl(habit: habit)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                    }
                }
                let sessions = TimerService.sessions(of: habit, on: day)
                Section {
                    ForEach(sessions) { session in
                        SessionRow(session: session) { editing = session }
                    }
                    Button("Add Time Manually", systemImage: "plus") { adding = true }
                } header: {
                    HStack {
                        Text("Sessions")
                        Spacer()
                        Text(Formatting.duration(sessions.reduce(0) { $0 + $1.duration() }))
                    }
                }
            }
            .navigationTitle(habit.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editing) { session in
                SessionEditSheet(habit: habit, session: session)
            }
            .sheet(isPresented: $adding) {
                SessionEditSheet(habit: habit, session: nil, day: day)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// "⏱ 12:34" under a habit's name while its timer runs.
struct RunningTimerLabel: View {
    let session: TimerSession

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            Label(Formatting.clock(session.duration(at: timeline.date)), systemImage: "stopwatch")
                .monospacedDigit()
        }
    }
}
