import SwiftUI

/// A grid of SF Symbols by theme for choosing a habit's icon.
struct IconPicker: View {
    @Binding var selection: String
    let palette: HabitColor

    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    Button {
                        selection = ""
                        dismiss()
                    } label: {
                        Label("No Icon", systemImage: "circle.slash")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    ForEach(SymbolCatalog.categories) { category in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(category.title)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(category.symbols, id: \.self) { symbol in
                                    cell(symbol)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
        }
    }

    private func cell(_ symbol: String) -> some View {
        let isSelected = symbol == selection
        return Button {
            selection = symbol
            dismiss()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(isSelected ? .white : palette.ink)
                .background(
                    isSelected ? palette.color : palette.color.opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(symbol))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The habit's strength ring with its icon in the middle.
struct HabitBadge: View {
    let score: Double
    let palette: HabitColor
    let iconName: String
    var size: CGFloat = 34
    var isArchived = false

    var body: some View {
        ZStack {
            ScoreRing(score: score, color: isArchived ? Color(.systemGray3) : palette.color, lineWidth: max(3, size * 0.1))
            if !iconName.isEmpty {
                Image(systemName: iconName)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(isArchived ? Color(.secondaryLabel) : palette.ink)
            }
        }
        .frame(width: size, height: size)
    }
}
