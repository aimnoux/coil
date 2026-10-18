import Foundation

/// How often a habit should be performed: `numerator` times every `denominator` days.
nonisolated struct Frequency: Hashable, Codable, Sendable {
    var numerator: Int
    var denominator: Int

    init(_ numerator: Int, _ denominator: Int) {
        self.denominator = max(1, denominator)
        // More repetitions than days could never be completed.
        self.numerator = min(max(1, numerator), self.denominator)
    }

    static let daily = Frequency(1, 1)
    static let weekly = Frequency(1, 7)

    var timesPerDay: Double { Double(numerator) / Double(denominator) }

    /// The friendly way to describe and edit a frequency.
    enum Preset: Hashable, Sendable {
        case everyDay
        case everyNDays(Int)
        case timesPerWeek(Int)
        case timesPerMonth(Int)
        case custom(Int, Int)
    }

    var preset: Preset {
        switch (numerator, denominator) {
        case (1, 1): .everyDay
        case (_, 7): .timesPerWeek(numerator)
        case (_, 30): .timesPerMonth(numerator)
        case (1, _): .everyNDays(denominator)
        default: .custom(numerator, denominator)
        }
    }

    init(_ preset: Preset) {
        switch preset {
        case .everyDay: self.init(1, 1)
        case .everyNDays(let n): self.init(1, n)
        case .timesPerWeek(let n): self.init(n, 7)
        case .timesPerMonth(let n): self.init(n, 30)
        case .custom(let n, let d): self.init(n, d)
        }
    }
}

nonisolated enum HabitKind: Int, Codable, Sendable, CaseIterable {
    case yesNo = 0
    case measurable = 1
    /// Quitting a bad habit: every day counts as clean unless a slip is recorded (as `.no`).
    case quit = 2
}

nonisolated enum TargetType: Int, Codable, Sendable, CaseIterable {
    case atLeast = 0
    case atMost = 1
}

/// What the user recorded for a single day. A missing record means "unknown".
nonisolated enum EntryState: Int, Codable, Sendable {
    case yes = 1
    case no = 2
    case skip = 3
}

nonisolated struct EntryRecord: Hashable, Codable, Sendable {
    var state: EntryState
    /// The measured amount for measurable habits; ignored for yes/no habits.
    var amount: Double

    init(state: EntryState, amount: Double = 0) {
        self.state = state
        self.amount = amount
    }

    static let yes = EntryRecord(state: .yes)
    static let no = EntryRecord(state: .no)
    static let skip = EntryRecord(state: .skip)
}

/// What a day looks like in the UI, after applying the habit's frequency.
nonisolated enum Checkmark: Hashable, Sendable {
    /// The user marked the day as done.
    case yesManual
    /// Not marked, but the frequency target was already met in this period.
    case yesAuto
    case skip
    /// The user explicitly marked the day as not done.
    case no
    case unknown
    /// The habit was paused (vacation, sickness): neutral for strength and streaks.
    case paused
    /// Not one of the habit's days (e.g. a weekend for a weekdays-only habit): neutral too.
    case rest

    var isSatisfied: Bool { self == .yesManual || self == .yesAuto }

    /// Days that neither count nor break a streak.
    var isNeutral: Bool { self == .skip || self == .paused || self == .rest }
}
