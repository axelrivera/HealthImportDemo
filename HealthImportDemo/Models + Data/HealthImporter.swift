//
//  HealthImporter.swift
//  HealthImportDemo
//
//  Created by Axel Rivera on 11/9/24.
//

import Foundation
import HealthKit

final class HealthImporter {
    let healthStore: HKHealthStore
    
    init(healthStore: HealthStore = .shared) {
        self.healthStore = healthStore.defaultStore
    }
}

extension HealthImporter {
    
    func saveWorkout(_ viewModel: WorkoutViewModel) async throws {
        let route = viewModel.route
        let isVirtualActivity = viewModel.isVirtualActivity
        let isIndoor = viewModel.isIndoor
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = viewModel.workoutType.activityType
        configuration.locationType = viewModel.isIndoor ? .indoor : .outdoor
        
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        
        try await builder.beginCollection(at: viewModel.start)
        
        let samples = viewModel.hkSamples()
        if !samples.isEmpty {
            try await builder.addSamples(samples)
        }
        
        let metadata = viewModel.metadata()
        try await builder.addMetadata(metadata)
        
        let events = viewModel.workoutEvents()
        if !events.isEmpty {
            try await builder.addWorkoutEvents(events)
        }
        
        let laps = viewModel.workoutLaps()
        if laps.count > 1 {
            try await builder.addWorkoutEvents(laps)
        }
        
        try await builder.endCollection(at: viewModel.end)
        
        guard let workout = try await builder.finishWorkout() else {
            throw GenericError("failed to save workout")
        }
        
        let shouldIgnoreRoute: Bool
        if isVirtualActivity || isIndoor {
            shouldIgnoreRoute = true
        } else {
            shouldIgnoreRoute = route.isEmpty
        }
        
        // IGNORING ROUTE FOR VIRTUAL, INDOOR OR EMPTY ROUTE VALUES
        if shouldIgnoreRoute { return }
        
        let routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: .local())
        try await routeBuilder.insertRouteData(route)
        try await routeBuilder.finishRoute(with: workout, metadata: nil)
    }
    
}
