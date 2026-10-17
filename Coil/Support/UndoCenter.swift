import SwiftData
import SwiftUI

/// Offers a short-lived "Undo" button after destructive or easy-to-miss actions.
@MainActor
@Observable
final class UndoCenter {
    static let shared = UndoCenter()

    struct Item: Identifiable {
        let id = UUID()
        let message: String
        let action: () -> Void
    }

    private(set) var current: Item?

    func offer(_ message: String, undo: @escaping () -> Void) {
        let item = Item(message: message, action: undo)
        withAnimation(.snappy) { current = item }
        Task {
            try? await Task.sleep(for: .seconds(5))
            if current?.id == item.id {
                withAnimation(.snappy) { current = nil }
            }
        }
    }

    func undo() {
        guard let item = current else { return }
        withAnimation(.snappy) { current = nil }
        item.action()
    }

    func dismiss() {
        withAnimation(.snappy) { current = nil }
    }

    // MARK: - Common actions

    /// Deletes habits and offers to bring them back with their whole history.
    func delete(_ habits: [Habit], in context: ModelContext) {
        guard !habits.isEmpty else { return }
        let snapshot = Backup.make(from: habits)
        let positions = Dictionary(habits.map { ($0.id, $0.position) }, uniquingKeysWith: { a, _ in a })
        let message = habits.count == 1
            ? String(localized: "Deleted “\(habits[0].name)”")
            : String(localized: "Deleted \(habits.count) habits")
        for habit in habits {
            ReminderScheduler.cancel(habit)
            context.delete(habit)
        }
        offer(message) {
            _ = try? Backup.restore(snapshot, into: context)
            let restored = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
            for habit in restored {
                if let position = positions[habit.id] { habit.position = position }
            }
        }
    }

    /// Archives or restores habits, with undo.
    func setArchived(_ habits: [Habit], _ archived: Bool) {
        guard !habits.isEmpty else { return }
        let previous = habits.map { ($0, $0.isArchived) }
        withAnimation {
            habits.forEach { $0.isArchived = archived }
        }
        habits.forEach(ReminderScheduler.reschedule)
        let message = archived
            ? (habits.count == 1 ? String(localized: "Archived “\(habits[0].name)”") : String(localized: "Habits archived"))
            : (habits.count == 1 ? String(localized: "Restored “\(habits[0].name)”") : String(localized: "Habits restored"))
        offer(message) {
            withAnimation {
                for (habit, wasArchived) in previous { habit.isArchived = wasArchived }
            }
            habits.forEach(ReminderScheduler.reschedule)
        }
    }

    /// Changes a day's record and offers to put the old one back.
    func setRecord(_ record: EntryRecord?, on day: Day, for habit: Habit, in context: ModelContext, message: String) {
        let previous = habit.record(on: day)
        habit.setRecord(record, on: day, in: context)
        offer(message) {
            habit.setRecord(previous, on: day, in: context)
        }
    }
}

/// The floating "Undo" bar shown at the bottom of the screen.
struct UndoToast: View {
    @State private var center = UndoCenter.shared

    var body: some View {
        if let item = center.current {
            HStack(spacing: 12) {
                Text(item.message)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                Spacer(minLength: 8)
                Button("Undo") { center.undo() }
                    .font(.subheadline.weight(.bold))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .gesture(DragGesture(minimumDistance: 10).onEnded { value in
                if value.translation.height > 10 { center.dismiss() }
            })
        }
    }
}
