import SwiftUI

/// A rounded section on the habit detail screen, styled like grouped iOS content.
struct Card<Content: View, Accessory: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let accessory: Accessory
    @ViewBuilder let content: Content

    init(
        _ title: LocalizedStringKey,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer()
                accessory
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// A compact menu for choosing a chart's time bucket.
struct BucketMenu: View {
    @Binding var selection: TimeBucket
    var options: [TimeBucket] = TimeBucket.allCases

    var body: some View {
        Menu {
            Picker("Group By", selection: $selection) {
                ForEach(options) { bucket in
                    Text(bucket.title).tag(bucket)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selection.title)
                Image(systemName: "chevron.up.chevron.down")
                    .imageScale(.small)
            }
            .font(.subheadline.weight(.medium))
        }
    }
}

extension TimeBucket {
    var title: LocalizedStringKey {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        case .quarter: "Quarter"
        case .year: "Year"
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        case .quarter: .quarter
        case .year: .year
        }
    }

    /// How many buckets fit on screen at once.
    var visibleCount: Int {
        switch self {
        case .day: 31
        case .week: 16
        case .month: 12
        case .quarter: 8
        case .year: 6
        }
    }

    /// Approximate length of one bucket in seconds, for chart domains.
    var approximateSeconds: TimeInterval {
        let day: TimeInterval = 86_400
        switch self {
        case .day: return day
        case .week: return day * 7
        case .month: return day * 30.4
        case .quarter: return day * 91.3
        case .year: return day * 365.25
        }
    }

    func label(for day: Day) -> String {
        let date = day.date()
        switch self {
        case .day: return date.formatted(.dateTime.day().month(.abbreviated))
        case .week: return date.formatted(.dateTime.day().month(.abbreviated))
        case .month: return date.formatted(.dateTime.month(.abbreviated))
        case .quarter: return date.formatted(.dateTime.quarter().year(.twoDigits))
        case .year: return date.formatted(.dateTime.year())
        }
    }
}
