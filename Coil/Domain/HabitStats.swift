import Foundation

/// A plain-value copy of everything needed to compute statistics for one habit.
nonisolated struct HabitData: Sendable {
    var kind: HabitKind
    var frequency: Frequency
    var targetValue: Double
    var targetType: TargetType
    /// The day the habit was created. Statistics start at the earlier of this and the first entry.
    var createdDay: Day
    var entries: [Day: EntryRecord]

    init(
        kind: HabitKind = .yesNo,
        frequency: Frequency = .daily,
        targetValue: Double = 0,
        targetType: TargetType = .atLeast,
        createdDay: Day,
        entries: [Day: EntryRecord] = [:]
    ) {
        self.kind = kind
        self.frequency = frequency
        self.targetValue = targetValue
        self.targetType = targetType
        self.createdDay = createdDay
        self.entries = entries
    }
}

nonisolated struct Streak: Hashable, Sendable {
    var start: Day
    var end: Day
    /// Number of satisfied days; skipped days inside the streak don't count.
    var length: Int
}

nonisolated enum TimeBucket: String, CaseIterable, Identifiable, Sendable {
    case day, week, month, quarter, year

    var id: String { rawValue }

    func start(of day: Day, firstWeekday: Int) -> Day {
        switch self {
        case .day: day
        case .week: day.firstOfWeek(firstWeekday: firstWeekday)
        case .month: day.firstOfMonth
        case .quarter: day.firstOfQuarter
        case .year: day.firstOfYear
        }
    }

    func next(after start: Day) -> Day {
        switch self {
        case .day: start.advanced(by: 1)
        case .week: start.advanced(by: 7)
        case .month: start.addingMonths(1)
        case .quarter: start.addingMonths(3)
        case .year: start.addingMonths(12)
        }
    }
}

/// Computes checkmarks, habit strength, streaks and history for one habit.
///
/// Habit strength is an exponential moving average of daily performance: each day the
/// previous score decays and today's performance (0…1) is mixed in. The decay rate depends
/// on the frequency, so a weekly habit isn't punished for the six days it isn't due.
/// Skipped days leave the score unchanged.
nonisolated struct HabitStats: Sendable {
    let data: HabitData
    let today: Day
    /// First day with statistics. Days before it have score 0 and no checkmarks.
    let start: Day

    private let checkmarks: [Checkmark]
    /// Performance for each day, 0…1, from the rolling window of `frequency.denominator` days.
    private let performance: [Double]
    private let scores: [Double]

    init(data: HabitData, today: Day = .today()) {
        self.data = data
        self.today = today

        let firstEntry = data.entries.keys.filter { $0 <= today }.min()
        let start = min(firstEntry ?? data.createdDay, data.createdDay, today)
        self.start = start

        let count = start.distance(to: today) + 1
        let numerator = data.frequency.numerator
        let window = data.frequency.denominator

        var manualYes = [Bool](repeating: false, count: count)
        var amounts = [Double](repeating: 0, count: count)
        var states = [EntryState?](repeating: nil, count: count)
        for (day, record) in data.entries where day >= start && day <= today {
            let i = start.distance(to: day)
            states[i] = record.state
            if record.state == .yes {
                manualYes[i] = true
                amounts[i] = record.amount
            }
        }

        var performance = [Double](repeating: 0, count: count)
        var checkmarks = [Checkmark](repeating: .unknown, count: count)
        var rollingYes = 0
        var rollingAmount = 0.0
        for i in 0..<count {
            rollingYes += manualYes[i] ? 1 : 0
            rollingAmount += amounts[i]
            if i >= window {
                rollingYes -= manualYes[i - window] ? 1 : 0
                rollingAmount -= amounts[i - window]
            }

            switch data.kind {
            case .yesNo:
                performance[i] = min(1, Double(rollingYes) / Double(numerator))
                switch states[i] {
                case .yes: checkmarks[i] = .yesManual
                case .skip: checkmarks[i] = .skip
                case .no: checkmarks[i] = .no
                case nil: checkmarks[i] = rollingYes >= numerator ? .yesAuto : .unknown
                }
            case .measurable:
                performance[i] = HabitStats.measurablePerformance(
                    amount: rollingAmount, target: data.targetValue, type: data.targetType)
                switch states[i] {
                case .skip: checkmarks[i] = .skip
                default: checkmarks[i] = performance[i] >= 1 ? .yesManual : .no
                }
            }
        }

        let multiplier = pow(0.5, data.frequency.timesPerDay.squareRoot() / 13)
        var scores = [Double](repeating: 0, count: count)
        var previous = 0.0
        for i in 0..<count {
            if checkmarks[i] != .skip {
                previous = previous * multiplier + performance[i] * (1 - multiplier)
            }
            scores[i] = previous
        }

        self.checkmarks = checkmarks
        self.performance = performance
        self.scores = scores
    }

    static func measurablePerformance(amount: Double, target: Double, type: TargetType) -> Double {
        switch type {
        case .atLeast:
            guard target > 0 else { return 1 }
            return min(1, max(0, amount / target))
        case .atMost:
            if amount <= target { return 1 }
            guard target > 0 else { return 0 }
            return max(0, target / amount)
        }
    }

    private func offset(_ day: Day) -> Int? {
        guard day >= start, day <= today else { return nil }
        return start.distance(to: day)
    }

    // MARK: - Per-day values

    func checkmark(on day: Day) -> Checkmark {
        if data.kind == .measurable, data.entries[day] == nil, day <= today {
            // Show measurable days without data as unknown, even if the window is satisfied.
            return .unknown
        }
        guard let i = offset(day) else { return .unknown }
        return checkmarks[i]
    }

    func amount(on day: Day) -> Double? {
        guard let record = data.entries[day], record.state == .yes else { return nil }
        return record.amount
    }

    func score(on day: Day) -> Double {
        if day > today { return scores.last ?? 0 }
        guard let i = offset(day) else { return 0 }
        return scores[i]
    }

    var currentScore: Double { scores.last ?? 0 }

    /// Whether today's target is met (manually, automatically, or skipped).
    var isCompletedToday: Bool {
        let c = checkmarks.last ?? .unknown
        if data.kind == .measurable {
            return c == .skip || (amount(on: today) != nil && (performance.last ?? 0) >= 1)
        }
        return c.isSatisfied || c == .skip
    }

    /// Total number of times done (yes/no) or the total amount (measurable).
    var total: Double {
        data.entries.values.reduce(0) { sum, r in
            guard r.state == .yes else { return sum }
            return sum + (data.kind == .measurable ? r.amount : 1)
        }
    }

    // MARK: - Streaks

    /// All streaks, oldest first. Skipped days continue a streak but don't add to its length.
    var streaks: [Streak] {
        var result: [Streak] = []
        var current: Streak?
        for (i, c) in checkmarks.enumerated() {
            let day = start.advanced(by: i)
            let satisfied = data.kind == .measurable
                ? (c != .skip && performance[i] >= 1 && (data.targetType == .atMost || data.entries[day] != nil))
                : c.isSatisfied
            if satisfied {
                if current == nil { current = Streak(start: day, end: day, length: 0) }
                current!.end = day
                current!.length += 1
            } else if c == .skip, current != nil {
                current!.end = day
            } else if let s = current {
                // Don't break today's streak just because today isn't marked yet.
                if day == today && c == .unknown { continue }
                result.append(s)
                current = nil
            }
        }
        if let s = current { result.append(s) }
        return result
    }

    var currentStreak: Streak? {
        guard let last = streaks.last, last.end >= today.advanced(by: -1) else { return nil }
        return last
    }

    /// The longest streaks, longest first; ties go to the most recent.
    func bestStreaks(limit: Int = 10) -> [Streak] {
        streaks
            .sorted { $0.length != $1.length ? $0.length > $1.length : $0.end > $1.end }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Series for charts

    /// Score at the end of each bucket, oldest first, covering the habit's whole history.
    func scoreSeries(bucket: TimeBucket, firstWeekday: Int) -> [(start: Day, score: Double)] {
        var result: [(Day, Double)] = []
        var bucketStart = bucket.start(of: start, firstWeekday: firstWeekday)
        while bucketStart <= today {
            let next = bucket.next(after: bucketStart)
            let end = min(next.advanced(by: -1), today)
            result.append((bucketStart, score(on: end)))
            bucketStart = next
        }
        return result
    }

    /// Times done (or total amount) in each bucket, oldest first.
    func history(bucket: TimeBucket, firstWeekday: Int) -> [(start: Day, value: Double)] {
        var sums: [Day: Double] = [:]
        for (day, record) in data.entries where record.state == .yes && day <= today {
            let key = bucket.start(of: day, firstWeekday: firstWeekday)
            sums[key, default: 0] += data.kind == .measurable ? record.amount : 1
        }
        var result: [(Day, Double)] = []
        var bucketStart = bucket.start(of: start, firstWeekday: firstWeekday)
        while bucketStart <= today {
            result.append((bucketStart, sums[bucketStart] ?? 0))
            bucketStart = bucket.next(after: bucketStart)
        }
        return result
    }

    /// Times done per weekday (1 = Sunday … 7 = Saturday) for each month, keyed by the first day of the month.
    func weekdayFrequency() -> [Day: [Int: Int]] {
        var result: [Day: [Int: Int]] = [:]
        for (day, record) in data.entries where record.state == .yes && day <= today {
            result[day.firstOfMonth, default: [:]][day.weekday, default: 0] += 1
        }
        return result
    }

    /// Sum of amounts (or times done) between two days, inclusive.
    func sum(from: Day, to: Day) -> Double {
        data.entries.reduce(0) { total, item in
            let (day, record) = item
            guard record.state == .yes, day >= from, day <= to else { return total }
            return total + (data.kind == .measurable ? record.amount : 1)
        }
    }

    /// The target for a period of `days` days, scaled from the habit's frequency.
    func target(forDays days: Int) -> Double {
        let perDay = data.kind == .measurable
            ? data.targetValue / Double(data.frequency.denominator)
            : data.frequency.timesPerDay
        return perDay * Double(days)
    }
}
