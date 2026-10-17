import SwiftData
import SwiftUI

/// Create, rename, reorder and delete habit groups.
struct GroupsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \HabitGroup.position) private var groups: [HabitGroup]

    @State private var editing: HabitGroup?
    @State private var creating = false
    @State private var name = ""

    var body: some View {
        List {
            Section {
                ForEach(groups) { group in
                    Button {
                        name = group.name
                        editing = group
                    } label: {
                        LabeledContent {
                            Text("\(group.habits?.filter { !$0.isDeleted }.count ?? 0)")
                        } label: {
                            Label(group.name, systemImage: "folder")
                        }
                    }
                    .foregroundStyle(.primary)
                }
                .onMove(perform: move)
                .onDelete(perform: delete)

                Button("New Group", systemImage: "plus") {
                    name = ""
                    creating = true
                }
            } footer: {
                Text("Groups split the habit list into sections. Deleting a group keeps its habits.")
            }
        }
        .navigationTitle("Groups")
        .toolbar { EditButton() }
        .alert("New Group", isPresented: $creating) {
            TextField("Name", text: $name)
            Button("Cancel", role: .cancel) {}
            Button("Create") { create() }
        }
        .alert("Rename Group", isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
            TextField("Name", text: $name)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = name.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { editing?.name = trimmed }
            }
        }
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        context.insert(HabitGroup(name: trimmed, position: (groups.map(\.position).max() ?? -1) + 1))
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = groups
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, group) in ordered.enumerated() { group.position = index }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(groups[index]) }
    }
}
