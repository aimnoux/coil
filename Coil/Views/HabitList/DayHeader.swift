import SwiftUI

/// Weekday and date labels above the checkmark columns.
struct DayHeader: View {
    let days: [Day]
    let today: Day

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            ForEach(days, id: \.self) { day in
                VStack(spacing: 1) {
                    Text(Formatting.shortWeekday(day.weekday).uppercased())
                        .font(.system(size: 10, weight: .semibold))
                    Text(day.dayOfMonth, format: .number)
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
