import SwiftUI

/// The first step of adding a habit: start from scratch or from one of the templates.
struct TemplatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var category = HabitTemplates.categories[0].id
    @State private var path: [TemplateRoute] = []

    enum TemplateRoute: Hashable {
        case custom
        case template(HabitTemplate)
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    NavigationLink(value: TemplateRoute.custom) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Create Your Own")
                                    .font(.headline)
                                Text("Start from a blank habit")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "plus")
                                .font(.headline)
                                .frame(width: 36, height: 36)
                                .background(Color.accentColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }

                if query.isEmpty {
                    Section {
                        categoryPicker
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                    if let current = HabitTemplates.categories.first(where: { $0.id == category }) {
                        Section(current.title.text) {
                            ForEach(current.templates) { template in row(template) }
                        }
                    }
                } else {
                    ForEach(HabitTemplates.categories) { category in
                        let matches = category.templates.filter { $0.matches(query) }
                        if !matches.isEmpty {
                            Section(category.title.text) {
                                ForEach(matches) { template in row(template) }
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: Text("Search \(HabitTemplates.count) templates"))
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
            .navigationDestination(for: TemplateRoute.self) { route in
                switch route {
                case .custom:
                    HabitEditView(habit: nil, onFinish: { dismiss() })
                case .template(let template):
                    HabitEditView(habit: nil, template: template.draft, onFinish: { dismiss() })
                }
            }
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HabitTemplates.categories) { item in
                    let isSelected = item.id == category
                    Button {
                        withAnimation(.snappy) { category = item.id }
                    } label: {
                        Label(item.title.text, systemImage: item.icon)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground),
                                in: Capsule()
                            )
                            .foregroundStyle(isSelected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    private func row(_ template: HabitTemplate) -> some View {
        let palette = HabitColor(index: template.color)
        return NavigationLink(value: TemplateRoute.template(template)) {
            HStack(spacing: 12) {
                Image(systemName: template.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.ink)
                    .frame(width: 36, height: 36)
                    .background(palette.color.opacity(0.25), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name.text)
                        .font(.body.weight(.medium))
                    HStack(spacing: 6) {
                        Text(template.summary)
                        if template.timed {
                            Image(systemName: "stopwatch")
                        }
                        if template.health != nil && HealthSync.isSupported {
                            Image(systemName: "heart.fill")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
        }
    }
}
