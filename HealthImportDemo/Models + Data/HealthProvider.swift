//
//  HealthProvider.swift
//  HealthImportDemo
//
//  Created by Axel Rivera on 11/9/24.
//

import Foundation
import HealthKit

final class HealthProvider: Sendable {
    let healthStore: HKHealthStore
    
    init(healthStore: HealthStore = .shared) {
        self.healthStore = healthStore.defaultStore
    }
}

// MARK: Authorization

extension HealthProvider {
    
    static let writeSampleTypes: Set<HKSampleType> = [
        HKSeriesType.workoutType(),
        HKSeriesType.workoutRoute(),
        HKQuantityType.distanceCycling(),
        HKQuantityType.activeEnergyBurned(),
        HKQuantityType.heartRate(),
        HKQuantityType.cyclingCadence(),
        HKQuantityType.cyclingPower()
    ]
    
    func requestHealthAuthorization(read: Set<HKObjectType>?, write: Set<HKSampleType>?, completionHandler: @escaping @Sendable (Result<Bool, Error>) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completionHandler(.failure(GenericError("data not available")))
            return
        }
        
        dLog("request health authorization")
        healthStore.requestAuthorization(
            toShare: write,
            read: read
        ) { (success, error) in
            guard success else {
                let resultError = error ?? GenericError("data error")
                dLog("authorization error: \(resultError.localizedDescription)")
                completionHandler(.failure(resultError))
                return
            }
            
            dLog("health authorization succeeded")
            completionHandler(.success(true))
        }
    }
    
    func requestHealthAuthorization(completionHandler: @escaping @Sendable (Result<Bool, Error>) -> Void) {
        requestHealthAuthorization(read: [], write: Self.writeSampleTypes, completionHandler: completionHandler)
    }
    
    func requestHealthAuthorization() async throws {
        try await withCheckedThrowingContinuation { continuation in
            requestHealthAuthorization { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
}

extension HKQuantityType {
    
    // MARK: Distance
        
    static func distanceCycling() -> HKQuantityType {
        .init(.distanceCycling)
    }
    
    // MARK: Other Types
    
    static func cyclingCadence() -> HKQuantityType {
        HKQuantityType(.cyclingCadence)
    }
    
    static func heartRate() -> HKQuantityType {
        HKQuantityType(.heartRate)
    }
    
    static func activeEnergyBurned() -> HKQuantityType {
        HKQuantityType(.activeEnergyBurned)
    }
    
    static func cyclingPower() -> HKQuantityType {
        HKQuantityType(.cyclingPower)
    }
    
}

extension HKQuantity {
    
    func defaultDistanceValue() -> Double {
        doubleValue(for: .meter())
    }
    
    func defaultEnergyValue() -> Double {
        doubleValue(for: .kilocalorie())
    }
    
}

extension HKQuantity {
    
    static func quantity(for value: Double?, unit: HKUnit) -> HKQuantity? {
        guard let value = value else { return nil }
        return HKQuantity(unit: unit, doubleValue: value)
    }
    
}

extension HKUnit {
    
    static func bpm() -> HKUnit {
        HKUnit.count().unitDivided(by: HKUnit.minute())
    }
    
    static func rpm() -> HKUnit {
        HKUnit.count().unitDivided(by: .minute())
    }
    
    static func celcius() -> HKUnit {
        HKUnit.degreeCelsius()
    }
    
    static func metersPerSecond() -> HKUnit {
        HKUnit.meter().unitDivided(by: .second())
    }
    
}
