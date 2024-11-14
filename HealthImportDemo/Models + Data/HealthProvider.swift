//
//  HealthProvider.swift
//  HealthImportDemo
//
//  Created by Axel Rivera on 11/9/24.
//

import Foundation
import HealthKit
import CoreLocation

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

// MARK: Workouts

extension HealthProvider {
    
    func fetchWorkout(with uuid: UUID) async throws -> HKWorkout {
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForObject(with: uuid)
            let workoutType = HKObjectType.workoutType()
            
            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: 1, sortDescriptors: nil) { query, results, error in
                if let workout = results?.first as? HKWorkout {
                    continuation.resume(returning: workout)
                } else {
                    continuation.resume(throwing: error ?? GenericError("workout not found"))
                }
            }
            
            healthStore.execute(query)
        }
    }
    
}

// MARK: Routes

extension HealthProvider {
    
    func fetchWorkourRoute(for uuid: UUID) async throws -> [CLLocation] {
        let workout = try await fetchWorkout(with: uuid)
        return try await fetchWorkoutRoute(for: workout)
    }
    
    func fetchWorkoutRoute(for workout: HKWorkout) async throws -> [CLLocation] {
        let routeSamples = try await fetchWorkoutRouteSamples(for: workout)
        return try await fetchLocations(from: routeSamples)
    }

    private func fetchWorkoutRouteSamples(for workout: HKWorkout) async throws -> [HKWorkoutRoute] {
        let predicate = HKQuery.predicateForObjects(from: workout)
        let workoutRouteType = HKSeriesType.workoutRoute()

        return try await withCheckedThrowingContinuation { continuation in
            let routeQuery = HKSampleQuery(sampleType: workoutRouteType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { query, results, error in
                if let routeSamples = results as? [HKWorkoutRoute] {
                    continuation.resume(returning: routeSamples)
                } else {
                    continuation.resume(throwing: error ?? GenericError("route error"))
                }
            }

            self.healthStore.execute(routeQuery)
        }
    }

    private func fetchLocations(from routeSamples: [HKWorkoutRoute]) async throws -> [CLLocation] {
        var allLocations: [CLLocation] = []
        
        for route in routeSamples {
            do {
                for try await locations in self.fetchLocations(for: route) {
                    allLocations.append(contentsOf: locations)
                }
            } catch {
                dLog("error fetching route locations: \(error)")
            }
        }

        return allLocations
    }
    
    private func fetchLocations(for route: HKWorkoutRoute) -> AsyncThrowingStream<[CLLocation], Error> {
        AsyncThrowingStream { continuation in
            let routeQuery = HKWorkoutRouteQuery(route: route) { query, newLocations, done, error in
                if let error = error {
                    continuation.finish(throwing: error)
                    return
                }

                if let newLocations = newLocations {
                    continuation.yield(newLocations)
                }

                if done {
                    continuation.finish()
                }
            }

            self.healthStore.execute(routeQuery)
        }
    }
    
}
