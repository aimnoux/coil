import Charts
import SwiftUI

/// Habit strength over time.
struct ScoreChartCard: View {
    let stats: HabitStats
    let color: Color
    let firstWeekday: Int

    @AppStorage("scoreChartBucket") private var bucket = TimeBucket.week

    var body: some View {
        let points = stats.scoreSeries(bucket: bucket, firstWeekday: firstWeekday)
        Card("Habit Strength") {
            BucketMenu(selection: $bucket)
        } content: {
            Chart {
                ForEach(points, id: \.start) { point in
                    AreaMark(
                        x: .value("Date", point.start.date(), unit: bucket.calendarComponent),
                        y: .value("Strength", point.score)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(
                        LinearGradient(colors: [color.opacity(0.35), color.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                    )
                    LineMark(
                        x: .value("Date", point.start.date(), unit: bucket.calendarComponent),
                        y: .value("Strength", point.score)
                    )
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .foregroundStyle(color)
                }
                if let last = points.last {
                    PointMark(
                        x: .value("Date", last.start.date(), unit: bucket.calendarComponent),
                        y: .value("Strength", last.score)
                    )
                    .foregroundStyle(color)
                    .symbolSize(50)
                }
            }
            .chartYScale(domain: 0...1)
            .chartYAxis {
                AxisMarks(position: .trailing, values: [0, 0.25, 0.5, 0.75, 1]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) { Text(Formatting.percent(v)) }
                    }
                }
            }
            .chartXAxis { dateAxis(bucket) }
            .scrollableChart(count: points.count, bucket: bucket, last: points.last?.start)
            .frame(height: 200)
            .id(bucket)
        }
    }
}

/// How many times the habit was done (or the total amount) per period.
struct HistoryChartCard: View {
    let stats: HabitStats
    let color: Color
    let firstWeekday: Int
    let isMeasurable: Bool

    @AppStorage("historyChartBucket") private var bucket = TimeBucket.week

    var body: some View {
        let bars = stats.history(bucket: bucket, firstWeekday: firstWeekday)
        let maxValue = bars.map(\.value).max() ?? 0
        Card("History") {
            BucketMenu(selection: $bucket, options: [.week, .month, .quarter, .year])
        } content: {
            Chart {
                ForEach(bars, id: \.start) { bar in
                    BarMark(
                        x: .value("Date", bar.start.date(), unit: bucket.calendarComponent),
                        y: .value("Count", bar.value),
                        width: .ratio(0.7)
                    )
                    .foregroundStyle(bar.start == bars.last?.start ? color : color.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .annotation(position: .top, spacing: 2) {
                        if bar.value > 0 {
                            Text(Formatting.compact(bar.value))
                                .font(.system(size: 9, weight: .semibold).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...max(1, maxValue * 1.15))
            .chartYAxis {
                AxisMarks(position: .trailing) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartXAxis { dateAxis(bucket) }
            .scrollableChart(count: bars.count, bucket: bucket, last: bars.last?.start)
            .frame(height: 200)
            .id(bucket)
        }
    }
}

@AxisContentBuilder
func dateAxis(_ bucket: TimeBucket) -> some AxisContent {
    switch bucket {
    case .day:
        AxisMarks(values: .stride(by: .day, count: 7)) { _ in
            AxisGridLine()
            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
        }
    case .week:
        AxisMarks(values: .stride(by: .month)) { _ in
            AxisGridLine()
            AxisValueLabel(format: .dateTime.month(.abbreviated))
        }
    case .month:
        AxisMarks(values: .stride(by: .month, count: 2)) { _ in
            AxisGridLine()
            AxisValueLabel(format: .dateTime.month(.abbreviated))
        }
    case .quarter:
        AxisMarks(values: .stride(by: .quarter)) { _ in
            AxisGridLine()
            AxisValueLabel(format: .dateTime.quarter().year(.twoDigits))
        }
    case .year:
        AxisMarks(values: .stride(by: .year)) { _ in
            AxisGridLine()
            AxisValueLabel(format: .dateTime.year())
        }
    }
}

private extension View {
    /// Shows a fixed number of buckets and lets the user scroll back in time, starting at the latest one.
    @ViewBuilder
    func scrollableChart(count: Int, bucket: TimeBucket, last: Day?) -> some View {
        if count > bucket.visibleCount, let last {
            let length = bucket.approximateSeconds * Double(bucket.visibleCount)
            let end = last.date().addingTimeInterval(bucket.approximateSeconds)
            self
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: length)
                .chartScrollPosition(initialX: end.addingTimeInterval(-length))
        } else {
            self
        }
    }
}
