import Foundation

/// A milestone for one habit (or for all habits), computed from history.
nonisolated struct Achievement: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case streak(Int)
        case cleanStreak(Int)
        case completions(Int)
        case strength(Int)
        case perfectMonth
        case comeback
        case challenge(Int)
        case habitsCreated(Int)
        case allDoneInADay
    }

    let kind: Kind
    /// When it was earned; `nil` while still locked.
    let unlocked: Day?
    /// 0…1 towards earning it (1 once unlocked).
    let progress: Double

    var id: Kind { kind }
    var isUnlocked: Bool { unlocked != nil }

    /// Bronze, silver or gold, for the badge color.
    var tier: Int {
        switch kind {
        case .streak(let n), .cleanStreak(let n): n >= 100 ? 2 : (n >= 21 ? 1 : 0)
        case .completions(let n): n >= 250 ? 2 : (n >= 50 ? 1 : 0)
        case .strength(let p): p >= 95 ? 2 : (p >= 80 ? 1 : 0)
        case .perfectMonth, .challenge: 2
        case .comeback: 1
        case .habitsCreated(let n): n >= 10 ? 2 : (n >= 5 ? 1 : 0)
        case .allDoneInADay: 1
        }
    }
}

nonisolated enum AchievementEngine {
    static let streakSteps = [3, 7, 14, 21, 30, 50, 66, 100, 200, 365]
    static let completionSteps = [1, 10, 25, 50, 100, 250, 500, 1000]
    static let strengthSteps = [50, 80, 95]

    /// Everything a habit can earn, in display order.
    static func achievements(for stats: HabitStats, challenge: ClosedRange<Day>? = nil) -> [Achievement] {
        let today = stats.today
        var days: [Day] = []
        var day = stats.start
        while day <= today {
            days.append(day)
            day = day.advanced(by: 1)
        }
        let checkmarks = days.map(stats.checkmark(on:))
        let isQuit = stats.data.kind == .quit

        // Day each streak length is first reached (neutral days bridge, like streaks).
        var streakReached: [Int: Day] = [:]
        var run = 0
        var longest = 0
        for (i, c) in checkmarks.enumerated() {
            if satisfied(c, stats: stats, day: days[i]) {
                run += 1
            } else if c.isNeutral || (days[i] == today && c == .unknown) {
                continue
            } else {
                run = 0
            }
            if run > longest {
                for n in (longest + 1)...run { streakReached[n] = streakReached[n] ?? days[i] }
                longest = run
            }
        }
        let currentRun = stats.currentStreak?.length ?? 0

        var result: [Achievement] = streakSteps.map { n in
            let kind: Achievement.Kind = isQuit ? .cleanStreak(n) : .streak(n)
            return Achievement(kind: kind, unlocked: streakReached[n], progress: min(1, Double(max(currentRun, 0)) / Double(n)))
        }

        if !isQuit {
            var done = 0
            var completionReached: [Int: Day] = [:]
            for (i, c) in checkmarks.enumerated() where c == .yesManual || (stats.data.kind == .measurable && c.isSatisfied) {
                done += 1
                if completionSteps.contains(done) { completionReached[done] = days[i] }
            }
            result += completionSteps.map { n in
                Achievement(kind: .completions(n), unlocked: completionReached[n], progress: min(1, Double(done) / Double(n)))
            }
        }

        var strengthReached: [Int: Day] = [:]
        for d in days {
            let score = stats.score(on: d) * 100
            for p in strengthSteps where strengthReached[p] == nil && score >= Double(p) - 0.0001 {
                strengthReached[p] = d
            }
        }
        result += strengthSteps.map { p in
            Achievement(kind: .strength(p), unlocked: strengthReached[p], progress: min(1, stats.currentScore * 100 / Double(p)))
        }

        result.append(perfectMonth(days: days, checkmarks: checkmarks, stats: stats))
        if !isQuit {
            result.append(comeback(days: days, checkmarks: checkmarks, stats: stats))
        }

        if let challenge {
            let progress = stats.challengeProgress(challenge)
            result.append(Achievement(
                kind: .challenge(progress.total),
                unlocked: progress.isCompleted ? challenge.upperBound : nil,
                progress: progress.fraction
            ))
        }
        return result
    }

    /// Achievements across all habits.
    static func global(habitCreationDays: [Day], allStats: [HabitStats]) -> [Achievement] {
        let sorted = habitCreationDays.sorted()
        var result = [1, 5, 10].map { n in
            Achievement(
                kind: .habitsCreated(n),
                unlocked: sorted.count >= n ? sorted[n - 1] : nil,
                progress: min(1, Double(sorted.count) / Double(n))
            )
        }
        // The first day every habit that existed was done (needs at least two habits).
        var allDone: Day?
        if allStats.count >= 2, let start = allStats.map(\.start).min(), let today = allStats.first?.today {
            var day = start
            while day <= today, allDone == nil {
                let active = allStats.filter { $0.start <= day }
                if active.count >= 2 && active.allSatisfy({ satisfied($0.checkmark(on: day), stats: $0, day: day) }) {
                    allDone = day
                }
                day = day.advanced(by: 1)
            }
        }
        result.append(Achievement(kind: .allDoneInADay, unlocked: allDone, progress: allDone == nil ? 0 : 1))
        return result
    }

    private static func satisfied(_ c: Checkmark, stats: HabitStats, day: Day) -> Bool {
        stats.isKept(on: day)
    }

    /// Every day of a full calendar month done (neutral days allowed).
    private static func perfectMonth(days: [Day], checkmarks: [Checkmark], stats: HabitStats) -> Achievement {
        var byMonth: [Day: (kept: Int, total: Int)] = [:]
        for (i, d) in days.enumerated() {
            let month = d.firstOfMonth
            var value = byMonth[month] ?? (0, 0)
            value.total += 1
            if satisfied(checkmarks[i], stats: stats, day: d) || checkmarks[i].isNeutral { value.kept += 1 }
            byMonth[month] = value
        }
        let complete = byMonth
            .filter { month, value in
                value.total == Day.daysInMonth(year: month.year, month: month.month) && value.kept == value.total
            }
            .keys.min()
        let unlocked = complete.map { Day(year: $0.year, month: $0.month, day: Day.daysInMonth(year: $0.year, month: $0.month)) }
        let current = byMonth[stats.today.firstOfMonth]
        let progress = unlocked != nil ? 1 : Double(current?.kept ?? 0) / Double(Day.daysInMonth(year: stats.today.year, month: stats.today.month))
        return Achievement(kind: .perfectMonth, unlocked: unlocked, progress: progress)
    }

    /// Back on track: a 7-day streak after a gap of at least 7 days.
    private static func comeback(days: [Day], checkmarks: [Checkmark], stats: HabitStats) -> Achievement {
        var gap = 0
        var run = 0
        var hadGap = false
        var started = false
        for (i, c) in checkmarks.enumerated() {
            if satisfied(c, stats: stats, day: days[i]) {
                // Only a break after the habit got going counts, not a slow start.
                if gap >= 7 && started { hadGap = true }
                started = true
                gap = 0
                run += 1
                if hadGap && run >= 7 {
                    return Achievement(kind: .comeback, unlocked: days[i], progress: 1)
                }
            } else if !c.isNeutral {
                gap += 1
                run = 0
                hadGap = false
            }
        }
        return Achievement(kind: .comeback, unlocked: nil, progress: hadGap ? Double(run) / 7 : 0)
    }
}
