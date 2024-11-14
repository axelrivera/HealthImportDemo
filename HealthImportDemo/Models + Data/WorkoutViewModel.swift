//
//  WorkoutViewModel.swift
//  HealthImportDemo
//
//  Created by Axel Rivera on 11/13/24.
//

import Foundation
import FitnessUnits
import HealthKit

struct WorkoutViewModel: Identifiable, Hashable, Equatable {
    var id: UUID
    let activityType: HKWorkoutActivityType
    let isIndoor: Bool
    let startDate: Date
    let endDate: Date
    let duration: Measurement<UnitDuration>
    
    let distance: Measurement<UnitLength>?
    let avgSpeed: Measurement<UnitSpeed>?
    let elevation: Measurement<UnitLength>?
    let totalEnergy: Measurement<UnitEnergy>?
    let avgHeartRate: Measurement<UnitCadence>?
    let avgCadence: Measurement<UnitCadence>?
    let avgPower: Measurement<UnitPower>?
    
    var totalDuration: Measurement<UnitDuration> {
        let seconds = endDate.timeIntervalSince1970 - startDate.timeIntervalSince1970
        return .init(value: seconds, unit: .seconds)
    }
}

extension WorkoutViewModel {
    
    static func viewModel(for workout: HKWorkout) -> Self {
        let duration = Measurement<UnitDuration>(value: workout.duration, unit: .seconds)
        return .init(
            id: workout.uuid,
            activityType: workout.workoutActivityType,
            isIndoor: workout.isIndoor,
            startDate: workout.startDate,
            endDate: workout.endDate,
            duration: duration,
            distance: workout.cyclingDistance,
            avgSpeed: workout.avgSpeed,
            elevation: workout.elevation,
            totalEnergy: workout.totalEnergy,
            avgHeartRate: workout.avgHeartRate,
            avgCadence: workout.avgCyclingCadence,
            avgPower: workout.avgCyclingPower
        )
    }
    
}

extension HKWorkout {
    
    var isIndoor: Bool {
        metadata?[HKMetadataKeyIndoorWorkout] as? Bool ?? false
    }
    
    var cyclingDistance: Measurement<UnitLength>? {
        if let quantity = statistics(for: .distanceCycling())?.sumQuantity() {
            let value = quantity.doubleValue(for: .meter())
            return .init(value: value, unit: .meters)
        } else {
            return nil
        }
    }
    
    var avgSpeed: Measurement<UnitSpeed>? {
        if let quantity = metadata?[HKMetadataKeyAverageSpeed] as? HKQuantity {
            let value = quantity.doubleValue(for: .metersPerSecond())
            return .init(value: value, unit: .metersPerSecond)
        } else {
            return nil
        }
    }
    
    var elevation: Measurement<UnitLength>? {
        if let quantity = metadata?[HKMetadataKeyElevationAscended] as? HKQuantity {
            let value = quantity.doubleValue(for: .meter())
            return .init(value: value, unit: .meters)
        } else {
            return nil
        }
    }
    
    var totalEnergy: Measurement<UnitEnergy>? {
        if let quantity = statistics(for: .activeEnergyBurned())?.sumQuantity() {
            let value = quantity.doubleValue(for: .kilocalorie())
            return .init(value: value, unit: .kilocalories)
        } else {
            return nil
        }
    }
    
    var avgHeartRate: Measurement<UnitCadence>? {
        if let quantity = statistics(for: .heartRate())?.averageQuantity() {
            let value = quantity.doubleValue(for: .bpm())
            return .init(value: value, unit: .beatsPerMinute)
        } else {
            return nil
        }
    }
    
    var avgCyclingCadence: Measurement<UnitCadence>? {
        if let quantity = statistics(for: .cyclingCadence())?.averageQuantity() {
            let value = quantity.doubleValue(for: .rpm())
            return .init(value: value, unit: .revolutionsPerMinute)
        } else {
            return nil
        }
    }
    
    var avgCyclingPower: Measurement<UnitPower>? {
        if let quantity = statistics(for: .cyclingPower())?.averageQuantity() {
            let value = quantity.doubleValue(for: .watt())
            return .init(value: value, unit: .watts)
        } else {
            return nil
        }
    }
    
}
                     

