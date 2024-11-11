//
//  WorkoutViewModel+Health.swift
//  HealthImportDemo
//
//  Created by Axel Rivera on 11/10/24.
//

import Foundation
import HealthKit

extension WorkoutViewModel {
    
    func metadata() -> [String: Any] {
        let avgSpeedValue = self.avgSpeed?.converted(to: .metersPerSecond).value
        let avgSpeed = HKQuantity.quantity(for: avgSpeedValue, unit: .metersPerSecond())
        
        let maxSpeedValue = self.maxSpeed?.converted(to: .metersPerSecond).value
        let maxSpeed = HKQuantity.quantity(for: maxSpeedValue, unit: .metersPerSecond())
                
        var dictionary: [String: Any] = [:]
        dictionary[HKMetadataKeyIndoorWorkout] = isIndoor
        dictionary[HKMetadataKeyAverageSpeed] = avgSpeed
        dictionary[HKMetadataKeyMaximumSpeed] = maxSpeed
        
        if let elevationAscended {
            let conversion = elevationAscended.converted(to: .meters)
            dictionary[HKMetadataKeyElevationAscended] = HKQuantity.quantity(for: conversion.value, unit: .meter())
        }
        
        return dictionary.compactMapValues({ $0 })
    }
    
}

extension WorkoutViewModel {
    
    enum SampleType: Hashable {
        case cyclingDistance
        case heartRate
        case activeEnergy
        case cyclingCadence
        case cyclingPower
    }
    
    struct SampleValue {
        let sampleType: SampleType
        let value: Double
        let start: Date
        let end: Date
    }
}

extension WorkoutViewModel.SampleValue {
    
    func workoutSample() -> HKSample {
        switch sampleType {
        case .cyclingDistance:
            return HKCumulativeQuantitySample(type: .distanceCycling(), quantity: .init(unit: .meter(), doubleValue: value), start: start, end: end)
        case .heartRate:
            return HKDiscreteQuantitySample(type: .heartRate(), quantity: .init(unit: .bpm(), doubleValue: value), start: start, end: end)
        case .activeEnergy:
            return HKCumulativeQuantitySample(type: .activeEnergyBurned(), quantity: .init(unit: .kilocalorie(), doubleValue: value), start: start, end: end)
        case .cyclingCadence:
            return HKDiscreteQuantitySample(type: .cyclingCadence(), quantity: .init(unit: .rpm(), doubleValue: value), start: start, end: end)
        case .cyclingPower:
            return HKDiscreteQuantitySample(type: .cyclingPower(), quantity: .init(unit: .watt(), doubleValue: value), start: start, end: end)
        }
    }
    
}

extension WorkoutViewModel {
    
    func samples() -> [SampleValue] {
        var distance: [SampleValue] = []
        var energy: [SampleValue] = []
        var heartRate: [SampleValue] = []
        var cadence: [SampleValue] = []
        var power: [SampleValue] = []
                
        for (record, nextRecord) in zip(records, records.dropFirst()) {
            if let value = distanceSample(start: record, end: nextRecord) {
                distance.append(value)
            }
            
            if let value = energySample(start: record, end: nextRecord) {
                energy.append(value)
            }
            
            if let value = heartRateSample(record: record) {
                heartRate.append(value)
            }
            
            if let value = cadenceSample(record: record) {
                cadence.append(value)
            }
            
            if let value = powerSample(record: record) {
                power.append(value)
            }
        }
        
        if energy.isEmpty, let activeCalories {
            let convertion = activeCalories.converted(to: .kilocalories)
            energy.append(SampleValue(sampleType: .activeEnergy, value: convertion.value, start: start, end: end))
        }
        
        return distance + energy + heartRate + cadence + power
    }
    
    func hkSamples() -> [HKSample] {
        let samples = self.samples()
        return samples.map({ $0.workoutSample() })
    }
    
    private func distanceSample(start: WorkoutViewModel.Record, end: WorkoutViewModel.Record) -> SampleValue? {
        guard let startRecord = start.distance, let endRecord = end.distance else { return nil }
        
        let startDate = start.timestamp
        let endDate = end.timestamp
        
        let startValue = startRecord.converted(to: .meters).value
        let endValue = endRecord.converted(to: .meters).value
        
        let value = endValue - startValue
        guard value > 0 else { return nil }
        
        return SampleValue(sampleType: .cyclingDistance, value: value, start: startDate, end: endDate)
    }
    
    private func energySample(start: WorkoutViewModel.Record, end: WorkoutViewModel.Record) -> SampleValue? {
        let startDate = start.timestamp
        let endDate = end.timestamp
        guard let startSample = start.calories, let endSample = end.calories else { return nil }
        
        let startValue = startSample.converted(to: .kilocalories).value
        let endValue = endSample.converted(to: .kilocalories).value
        
        let value = endValue - startValue
        guard value > 0 else { return nil }
        
        return .init(sampleType: .activeEnergy, value: value, start: startDate, end: endDate)
    }
    
    private func heartRateSample(record: WorkoutViewModel.Record) -> SampleValue? {
        guard let value = record.heartRate?.value, value > 0 else {
            return nil
        }
        let date = record.timestamp
        return .init(sampleType: .heartRate, value: value, start: date, end: date)
    }
    
    private func cadenceSample(record: WorkoutViewModel.Record) -> SampleValue? {
        guard let cadence = record.cadence, cadence.value > 0 else { return nil }
        let date = record.timestamp
        return .init(sampleType: .cyclingCadence, value: cadence.value, start: date, end: date)
    }
    
    private func powerSample(record: WorkoutViewModel.Record) -> SampleValue? {
        guard let power = record.power, power.value > 0 else { return nil }
        let date = record.timestamp
        return .init(sampleType: .cyclingPower, value: power.value, start: date, end: date)
    }
    
}
