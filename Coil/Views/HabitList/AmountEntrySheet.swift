import SwiftData
import SwiftUI

/// Identifies which habit and day a measurable value is being entered for.
struct AmountEntryTarget: Identifiable {
    let habit: Habit
    let day: Day

    var id: String { "\(habit.id)-\(day.index)" }
}

/// Lets the user type the value of a measurable habit for one day.
struct AmountEntrySheet: View {
    let habit: Habit
    let day: Day

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.skipEnabled) private var skipEnabled = false
    @State private var value: Double?
    @State private var note = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        stepButton(-1, systemImage: "minus")
                        TextField("0", value: $value, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 44, weight: .semibold, design: .rounded))
                            .focused($focused)
                        stepButton(1, systemImage: "plus")
                    }
                    .listRowBackground(Color.clear)
                } footer: {
                    VStack(spacing: 4) {
                        if !habit.unit.isEmpty {
                            Text(habit.unit)
                                .font(.headline)
                                .foregroundStyle(habit.color.ink)
                        }
                        Text(Formatting.target(for: habit))
                    }
                    .frame(maxWidth: .infinity)
                }

                Section("Note") {
                    TextField("Note", text: $note, prompt: Text("How did it go?"), axis: .vertical)
                        .lineLimit(1...4)
                }

                Section {
                    if skipEnabled {
                        Button("Skip This Day", systemImage: "arrow.turn.up.right") {
                            habit.setRecord(.skip, on: day, in: context)
                            habit.setNote(note, on: day, in: context)
                            dismiss()
                        }
                    }
                    if habit.record(on: day) != nil {
                        Button("Clear Entry", systemImage: "trash", role: .destructive) {
                            habit.setRecord(nil, on: day, in: context)
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
                    Button("Save") { save() }
                        .disabled(value == nil)
                }
            }
            .onAppear {
                if let record = habit.record(on: day), record.state == .yes {
                    value = record.amount
                }
                note = habit.note(on: day)
                focused = true
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func stepButton(_ delta: Double, systemImage: String) -> some View {
        Button {
            value = max(0, (value ?? 0) + delta)
        } label: {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .frame(width: 52, height: 52)
                .background(habit.color.color.opacity(0.3), in: Circle())
                .foregroundStyle(habit.color.ink)
        }
        .buttonStyle(.borderless)
        .buttonRepeatBehavior(.enabled)
    }

    private func save() {
        guard let value else { return }
        habit.setRecord(EntryRecord(state: .yes, amount: max(0, value)), on: day, in: context)
        habit.setNote(note, on: day, in: context)
        dismiss()
    }
}
