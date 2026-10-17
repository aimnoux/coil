import Foundation
import SwiftData
import SwiftUI

/// Everything the habit editor can change, as plain values. Templates produce drafts too.
struct HabitDraft {
    var kind: HabitKind = .yesNo
    var name = ""
    var question = ""
    var notes = ""
    var colorIndex = HabitColor.defaultIndex
    var iconName = ""
    var schedule = ScheduleDraft()
    var unit = ""
    var targetValue: Double? = nil
    var targetType: TargetType = .atLeast
    var targetPeriod: TargetPeriod = .day
    var isTimed = false
    var timerMinutes = 0
    var reminderEnabled = false
    /// Minutes after midnight.
    var reminderTimes: [Int] = [8 * 60]
    var reminderDays = 0b111_1111
    var challengeDays = 0
    var healthMetric: HealthMetric?
    var healthThreshold: Double = 0
    var groupID: UUID?

    init() {}

    @MainActor
    init(_ habit: Habit) {
        kind = habit.kind
        name = habit.name
        question = habit.question
        notes = habit.notes
        colorIndex = habit.colorIndex
        iconName = habit.iconName
        schedule = ScheduleDraft(habit.frequency)
        unit = habit.unit
        targetValue = habit.targetValue
        targetType = habit.targetType
        targetPeriod = TargetPeriod(habit.frequency)
        isTimed = habit.isTimed
        timerMinutes = habit.timerMinutes
        reminderEnabled = habit.reminderEnabled
        reminderTimes = habit.reminderMinutes
        reminderDays = habit.reminderDays
        challengeDays = habit.challengeDays
        healthMetric = habit.healthMetric
        healthThreshold = habit.healthThreshold
        groupID = habit.group?.id
    }

    var frequency: Frequency {
        switch kind {
        case .yesNo: schedule.frequency
        case .measurable: targetPeriod.frequency
        case .quit: .daily
        }
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && (kind != .measurable || (targetValue ?? -1) >= 0)
            && (!reminderEnabled || (reminderDays != 0 && !reminderTimes.isEmpty))
    }

    /// Writes the draft into a habit. Changing the challenge length restarts it today.
    @MainActor
    func apply(to habit: Habit, groups: [HabitGroup]) {
        habit.kind = kind
        habit.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.colorIndex = colorIndex
        habit.iconName = iconName
        habit.frequency = frequency
        if kind == .measurable {
            habit.unit = isTimed ? String(localized: "min") : unit.trimmingCharacters(in: .whitespaces)
            habit.targetValue = targetValue ?? 0
            habit.targetType = targetType
            habit.isTimed = isTimed
            habit.timerMinutes = isTimed ? timerMinutes : 0
        } else {
            habit.isTimed = false
        }
        habit.reminderEnabled = reminderEnabled
        habit.reminderMinutes = reminderTimes
        habit.reminderDays = reminderDays
        if challengeDays != habit.challengeDays {
            habit.challengeDays = challengeDays
            habit.challengeStartDay = Day.today().index
        }
        habit.healthMetric = kind == .quit ? nil : healthMetric
        habit.healthThreshold = healthThreshold
        habit.group = groups.first { $0.id == groupID }
        habit.touch()
    }
}

/// Editable form of a yes/no habit's frequency.
struct ScheduleDraft: Equatable {
    enum Kind: String, CaseIterable, Identifiable {
        case everyDay, everyNDays, perWeek, perMonth, custom
        var id: String { rawValue }

        var title: LocalizedStringKey {
            switch self {
            case .everyDay: "Every day"
            case .everyNDays: "Every few days"
            case .perWeek: "Times per week"
            case .perMonth: "Times per month"
            case .custom: "Custom"
            }
        }
    }

    var kind: Kind = .everyDay
    var times = 3
    var days = 2

    init() {}

    init(_ frequency: Frequency) {
        switch frequency.preset {
        case .everyDay:
            kind = .everyDay
        case .everyNDays(let n):
            kind = .everyNDays
            days = n
        case .timesPerWeek(let n):
            kind = .perWeek
            times = n
        case .timesPerMonth(let n):
            kind = .perMonth
            times = n
        case .custom(let n, let d):
            kind = .custom
            times = n
            days = d
        }
    }

    var frequency: Frequency {
        switch kind {
        case .everyDay: .daily
        case .everyNDays: Frequency(1, days)
        case .perWeek: Frequency(min(times, 7), 7)
        case .perMonth: Frequency(min(times, 30), 30)
        case .custom: Frequency(min(times, days), days)
        }
    }
}

/// The period a measurable habit's target applies to.
enum TargetPeriod: Int, CaseIterable, Identifiable {
    case day = 1, week = 7, month = 30

    var id: Int { rawValue }

    init(_ frequency: Frequency) {
        self = TargetPeriod(rawValue: frequency.denominator) ?? .day
    }

    var frequency: Frequency { Frequency(1, rawValue) }

    var title: LocalizedStringKey {
        switch self {
        case .day: "Every day"
        case .week: "Every week"
        case .month: "Every month"
        }
    }
}

