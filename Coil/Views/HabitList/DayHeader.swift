import SwiftUI

/// Weekday and date labels above the checkmark columns.
struct DayHeader: View {
    let days: [Day]
    let today: Day
    var isScrolledBack = false
    var onBackToToday: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            if isScrolledBack {
                Button(action: onBackToToday) {
                    Label("Today", systemImage: "arrow.uturn.backward")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .padding(.leading, 16)
                .transition(.opacity)
            }
            Spacer(minLength: 0)
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
        .padding(.vertical, 6)
    }
}
