import SwiftData
import SwiftUI

/// Identifies which habit and day a note is being written for.
struct DayNoteTarget: Identifiable {
    let habit: Habit
    let day: Day

    var id: String { "\(habit.id)-\(day.index)" }
}

/// Writes or edits the note for one day of a habit.
struct DayNoteSheet: View {
    let habit: Habit
    let day: Day

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Note", text: $text, prompt: Text("How did it go?"), axis: .vertical)
                        .lineLimit(4...12)
                        .focused($focused)
                } footer: {
                    Text(habit.name)
                }
                if !habit.note(on: day).isEmpty {
                    Section {
                        Button("Delete Note", systemImage: "trash", role: .destructive) {
                            habit.setNote("", on: day, in: context)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(Formatting.fullDate(day))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        habit.setNote(text, on: day, in: context)
                        dismiss()
                    }
                }
            }
            .onAppear {
                text = habit.note(on: day)
                focused = true
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Recent notes written on individual days.
struct DayNotesCard: View {
    let habit: Habit
    let onEdit: (Day) -> Void

    @State private var showingAll = false

    var body: some View {
        let notes = habit.notedDays
        if !notes.isEmpty {
            Card("Day Notes") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(showingAll ? notes : Array(notes.prefix(5)), id: \.day) { item in
                        Button {
                            onEdit(item.day)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Formatting.fullDate(item.day))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(habit.color.color)
                                Text(item.note)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                    if notes.count > 5 && !showingAll {
                        Button("Show All (\(notes.count))") {
                            withAnimation { showingAll = true }
                        }
                        .font(.subheadline.weight(.medium))
                    }
                }
            }
        }
    }
}
