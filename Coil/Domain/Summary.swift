import Foundation

/// How one habit did over a period.
nonisolated struct HabitPeriodResult: Sendable {
    /// Days that counted (inside the habit's life, not paused or skipped).
    let considered: Int
    /// Days done (or clean, for quit habits).
    let kept: Int

    var rate: Double? { considered > 0 ? Double(kept) / Double(considered) : nil }
}

nonisolated enum SummaryEngine {
    /// The period a summary covers, from its first to its last day.
    static func range(for bucket: TimeBucket, containing day: Day, firstWeekday: Int) -> ClosedRange<Day> {
        let start = bucket.start(of: day, firstWeekday: firstWeekday)
        return start...bucket.next(after: start).advanced(by: -1)
    }

    static func result(_ stats: HabitStats, in range: ClosedRange<Day>) -> HabitPeriodResult {
        var considered = 0
        var kept = 0
        var day = max(range.lowerBound, stats.start)
        let last = min(range.upperBound, stats.today)
        while day <= last {
            let c = stats.checkmark(on: day)
            defer { day = day.advanced(by: 1) }
            if c.isNeutral { continue }
            // Today only counts once it's done, so an unfinished day doesn't drag the rate down.
            let isKept = stats.isKept(on: day)
            if day == stats.today && !isKept { continue }
            considered += 1
            if isKept { kept += 1 }
        }
        return HabitPeriodResult(considered: considered, kept: kept)
    }

    /// Overall completion across habits: total kept days over total considered days.
    static func overallRate(_ results: [HabitPeriodResult]) -> Double? {
        let considered = results.reduce(0) { $0 + $1.considered }
        guard considered > 0 else { return nil }
        return Double(results.reduce(0) { $0 + $1.kept }) / Double(considered)
    }

    /// Completions per weekday (1 = Sunday … 7 = Saturday) across habits within a range.
    static func weekdayTotals(_ allStats: [HabitStats], in range: ClosedRange<Day>) -> [Int: Int] {
        var totals: [Int: Int] = [:]
        for stats in allStats {
            var day = max(range.lowerBound, stats.start)
            while day <= min(range.upperBound, stats.today) {
                if stats.isKept(on: day) { totals[day.weekday, default: 0] += 1 }
                day = day.advanced(by: 1)
            }
        }
        return totals
    }

    /// For each day, the share of active habits that were done (0…1); `nil` before any habit existed.
    static func dailyCompletion(_ allStats: [HabitStats], from start: Day, to end: Day) -> [Day: Double] {
        var result: [Day: Double] = [:]
        var day = start
        while day <= end {
            var active = 0
            var done = 0
            for stats in allStats where stats.start <= day && day <= stats.today {
                let c = stats.checkmark(on: day)
                if c.isNeutral { continue }
                active += 1
                if stats.isKept(on: day) { done += 1 }
            }
            if active > 0 { result[day] = Double(done) / Double(active) }
            day = day.advanced(by: 1)
        }
        return result
    }
}
