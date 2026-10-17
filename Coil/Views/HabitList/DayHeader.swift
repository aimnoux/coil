import SwiftUI

/// A section header for the habit list: the group's name (if any) and the day labels
/// above the checkmark columns.
struct DayHeader: View {
    let days: [Day]
    let today: Day
    var isScrolledBack = false
    var title: String?
    var isCollapsed = false
    var onToggleCollapse: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            if let title {
                Button {
                    onToggleCollapse?()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .padding(.leading, 16)
                .accessibilityLabel(Text(title))
                .accessibilityValue(Text(isCollapsed ? "Collapsed" : "Expanded"))
            }
            Spacer(minLength: 8)
            if !isCollapsed {
                ForEach(days, id: \.self) { day in
                    VStack(spacing: 1) {
                        Text(Formatting.shortWeekday(day.weekday).uppercased())
                            .font(.system(size: 10, weight: .semibold))
                        Text(day.dayOfMonth == 1 || (isScrolledBack && day == days.first)
                             ? day.date().formatted(.dateTime.day().month(.abbreviated))
                             : day.date().formatted(.dateTime.day()))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .font(.system(size: 15, weight: day == today ? .bold : .regular, design: .rounded))
                    }
                    .foregroundStyle(day == today ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .frame(width: checkmarkColumnWidth)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(Formatting.fullDate(day)))
                }
            }
        }
        .padding(.vertical, 6)
    }
}
