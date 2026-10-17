import Foundation
import SwiftUI

/// Apple Health data a habit can be filled from.
nonisolated enum HealthMetric: String, CaseIterable, Identifiable, Sendable {
    case steps
    case distance
    case activeEnergy
    case exerciseMinutes
    case standHours
    case flightsClimbed
    case mindfulMinutes
    case sleepHours
    case water
    case workouts

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .steps: "Steps"
        case .distance: "Walking + Running Distance"
        case .activeEnergy: "Active Energy"
        case .exerciseMinutes: "Exercise Minutes"
        case .standHours: "Stand Hours"
        case .flightsClimbed: "Flights Climbed"
        case .mindfulMinutes: "Mindful Minutes"
        case .sleepHours: "Sleep"
        case .water: "Water"
        case .workouts: "Workouts"
        }
    }

    /// The unit shown on a measurable habit linked to this metric.
    var unit: LocalizedStringResource {
        switch self {
        case .steps: "steps"
        case .distance: "km"
        case .activeEnergy: "kcal"
        case .exerciseMinutes, .mindfulMinutes: "min"
        case .standHours, .sleepHours: "h"
        case .flightsClimbed: "floors"
        case .water: "L"
        case .workouts: "workouts"
        }
    }

    var systemImage: String {
        switch self {
        case .steps: "figure.walk"
        case .distance: "map"
        case .activeEnergy: "flame"
        case .exerciseMinutes: "figure.run"
        case .standHours: "figure.stand"
        case .flightsClimbed: "figure.stairs"
        case .mindfulMinutes: "brain.head.profile"
        case .sleepHours: "bed.double"
        case .water: "drop"
        case .workouts: "dumbbell"
        }
    }

    /// A sensible daily goal to suggest.
    var suggestedTarget: Double {
        switch self {
        case .steps: 8000
        case .distance: 5
        case .activeEnergy: 400
        case .exerciseMinutes: 30
        case .standHours: 10
        case .flightsClimbed: 10
        case .mindfulMinutes: 10
        case .sleepHours: 7.5
        case .water: 2
        case .workouts: 1
        }
    }
}
