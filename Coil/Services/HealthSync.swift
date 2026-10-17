import Foundation
import SwiftData
#if HEALTHKIT
import HealthKit
#endif

/// Fills habits linked to Apple Health from the user's Health data.
///
/// Measurable habits get the day's value; yes/no habits are checked off once the value
/// reaches the habit's threshold. Entries written by hand are never overwritten.
enum HealthSync {
    /// Health needs the HealthKit capability; the build turns it on with `COIL_HEALTH=true xcodegen`.
    static var isSupported: Bool {
        #if HEALTHKIT
        return HKHealthStore.isHealthDataAvailable()
        #else
        return false
        #endif
    }

    /// How many days back each sync looks.
    static let daysBack = 30

    /// Decides what a day's entry should be for a Health value (exposed for tests).
    /// Returns `.keep` when a manual entry is present or nothing should change.
    enum Decision: Equatable {
        case keep
        case set(EntryRecord)
        case clear
    }

    static func decision(value: Double, habitKind: HabitKind, threshold: Double, existingSource: EntrySource?, hasRecord: Bool) -> Decision {
        if hasRecord && existingSource == .manual { return .keep }
        switch habitKind {
        case .measurable:
            if value > 0 {
                return .set(EntryRecord(state: .yes, amount: (value * 10).rounded() / 10))
            }
        case .yesNo:
            if value >= max(threshold, 0.0001) {
                return .set(EntryRecord(state: .yes, amount: (value * 10).rounded() / 10))
            }
        case .quit:
            return .keep
        }
        return hasRecord && existingSource == .health ? .clear : .keep
    }

    /// Applies a day's Health value to a habit.
    @MainActor
    static func apply(value: Double, to habit: Habit, on day: Day, in context: ModelContext) {
        let entry = habit.entry(on: day, in: context)
        let source = entry.map { EntrySource(rawValue: $0.source) ?? .manual }
        switch decision(value: value, habitKind: habit.kind, threshold: habit.healthThreshold,
                        existingSource: source, hasRecord: entry?.storedRecord != nil) {
        case .keep:
            break
        case .set(let record):
            if entry?.storedRecord != record {
                habit.setRecord(record, on: day, in: context, source: .health)
            }
        case .clear:
            habit.setRecord(nil, on: day, in: context)
        }
    }

    #if HEALTHKIT
    private static let store = HKHealthStore()

    /// Asks for read access to the metrics used by the given habits.
    static func requestAuthorization(for metrics: Set<HealthMetric>) async -> Bool {
        guard isSupported, !metrics.isEmpty else { return false }
        let types = Set(metrics.compactMap(\.objectType))
        do {
            try await store.requestAuthorization(toShare: [], read: types)
            return true
        } catch {
            return false
        }
    }

    /// Pulls the last `daysBack` days for every linked habit.
    @MainActor
    static func syncAll(in context: ModelContext, today: Day = .today()) async {
        guard isSupported else { return }
        let habits = ((try? context.fetch(FetchDescriptor<Habit>())) ?? []).filter { $0.healthMetric != nil && !$0.isArchived }
        guard !habits.isEmpty else { return }
        _ = await requestAuthorization(for: Set(habits.compactMap(\.healthMetric)))
        let start = today.advanced(by: -(daysBack - 1))
        var cache: [HealthMetric: [Day: Double]] = [:]
        for habit in habits {
            guard let metric = habit.healthMetric else { continue }
            if cache[metric] == nil {
                cache[metric] = await dailyValues(metric, from: start, to: today)
            }
            let values = cache[metric] ?? [:]
            var day = max(start, habit.createdDay)
            while day <= today {
                apply(value: values[day] ?? 0, to: habit, on: day, in: context)
                day = day.advanced(by: 1)
            }
        }
        try? context.save()
    }

    /// Daily totals for a metric, keyed by day.
    static func dailyValues(_ metric: HealthMetric, from start: Day, to end: Day) async -> [Day: Double] {
        let startDate = start.date()
        let endDate = end.advanced(by: 1).date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)

        if let quantity = metric.quantityType, let unit = metric.hkUnit {
            let descriptor = HKStatisticsCollectionQueryDescriptor(
                predicate: HKSamplePredicate.quantitySample(type: quantity, predicate: predicate),
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: DateComponents(day: 1)
            )
            guard let collection = try? await descriptor.result(for: store) else { return [:] }
            var result: [Day: Double] = [:]
            collection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                if let sum = statistics.sumQuantity() {
                    result[Day(statistics.startDate)] = sum.doubleValue(for: unit) * metric.scale
                }
            }
            return result
        }

        if metric == .workouts {
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.workout(predicate)],
                sortDescriptors: []
            )
            let workouts = (try? await descriptor.result(for: store)) ?? []
            return workouts.reduce(into: [:]) { result, workout in
                result[Day(workout.endDate), default: 0] += 1
            }
        }

        if let category = metric.categoryType {
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.categorySample(type: category, predicate: predicate)],
                sortDescriptors: []
            )
            let samples = (try? await descriptor.result(for: store)) ?? []
            var result: [Day: Double] = [:]
            for sample in samples {
                switch metric {
                case .standHours:
                    if sample.value == HKCategoryValueAppleStandHour.stood.rawValue {
                        result[Day(sample.startDate), default: 0] += 1
                    }
                case .sleepHours:
                    // Count time asleep towards the morning it ends on.
                    let asleep: Set<Int> = [
                        HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                        HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                        HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                        HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    ]
                    if asleep.contains(sample.value) {
                        result[Day(sample.endDate), default: 0] += sample.endDate.timeIntervalSince(sample.startDate) / 3600
                    }
                default:
                    // Mindful sessions: total minutes.
                    result[Day(sample.startDate), default: 0] += sample.endDate.timeIntervalSince(sample.startDate) / 60
                }
            }
            return result
        }
        return [:]
    }
    #else
    @MainActor
    static func syncAll(in context: ModelContext, today: Day = .today()) async {}
    static func requestAuthorization(for metrics: Set<HealthMetric>) async -> Bool { false }
    #endif
}

#if HEALTHKIT
private extension HealthMetric {
    var quantityType: HKQuantityType? {
        switch self {
        case .steps: HKQuantityType(.stepCount)
        case .distance: HKQuantityType(.distanceWalkingRunning)
        case .activeEnergy: HKQuantityType(.activeEnergyBurned)
        case .exerciseMinutes: HKQuantityType(.appleExerciseTime)
        case .flightsClimbed: HKQuantityType(.flightsClimbed)
        case .water: HKQuantityType(.dietaryWater)
        default: nil
        }
    }

    var categoryType: HKCategoryType? {
        switch self {
        case .standHours: HKCategoryType(.appleStandHour)
        case .mindfulMinutes: HKCategoryType(.mindfulSession)
        case .sleepHours: HKCategoryType(.sleepAnalysis)
        default: nil
        }
    }

    var objectType: HKObjectType? {
        if self == .workouts { return HKObjectType.workoutType() }
        return quantityType ?? categoryType
    }

    var hkUnit: HKUnit? {
        switch self {
        case .steps, .flightsClimbed: .count()
        case .distance: .meterUnit(with: .kilo)
        case .activeEnergy: .kilocalorie()
        case .exerciseMinutes: .minute()
        case .water: .liter()
        default: nil
        }
    }

    /// Extra conversion after `hkUnit` (none needed today).
    var scale: Double { 1 }
}
#endif
