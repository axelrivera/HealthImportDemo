//
//  WorkoutImporter.swift
//  HealthImportDemo
//
//  Created by Axel Rivera on 11/13/24.
//

import Foundation
import HealthKit
import CoreLocation
import FitDataProtocol
import AntMessageProtocol

enum WorkoutImporterError: Error {
    case invalidData
    case missingSession
    case activityNotSupported
    case saveFailed
}

final class WorkoutImporter {
    private let healthStore: HKHealthStore
    
    private var session: SessionMessage = SessionMessage()
    private var events: [EventMessage] = []
    private var records: [RecordMessage] = []
    
    init(healthStore: HealthStore = .shared) {
        self.healthStore = healthStore.defaultStore
    }
}

extension WorkoutImporter {
    
    func process(data: WorkoutData) async throws -> UUID {
        self.session = data.session
        self.events = data.events
        self.records = data.records
        return try await saveToHealth()
    }
    
}

private extension WorkoutImporter {
    
    func saveToHealth() async throws -> UUID {
        // all workouts must have a start time and duration
        guard let startDate = session.startTime?.recordDate, let elapsedTime = session.totalElapsedTime else {
            throw WorkoutImporterError.invalidData
        }
        
        // Map the Sport property in the FIT file to HKWorkoutActivityType
        // Or throw an error if an activity type is not supported
        guard let activityType = activityType() else {
            throw WorkoutImporterError.activityNotSupported
        }
        
        // A workout is indoor if the subSport is spinning, indoor cycling or virtual activity (i.e. Zwift)
        let subSport = session.subSport
        let isIndoor = isIndoor(subSport: subSport)
        
        // 1. Create Configuration
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = isIndoor  ? .indoor : .outdoor
        
        // 2. Create Builder
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        
        // 3. Begin Collecting Data
        try await builder.beginCollection(at: startDate)
        
        // 4. Add Metadata
        let metadata = try self.metadata(from: session)
        try await builder.addMetadata(metadata)
        
        // 5. Add Events
        // The app will crash if you try to add empty values to the builder
        let events = generateWorkoutEvents()
        if !events.isEmpty {
            try await builder.addWorkoutEvents(events)
        }
        
        // 6. Add Samples
        let samples = generateWorkoutSamples()
        if !samples.isEmpty {
            try await builder.addSamples(samples)
        }
        
        // 7. End Collecting Data
        // FIT files don't include an end data so we need to calculate it from the elapsed time
        let elapsedTimeInSeconds = elapsedTime.converted(to: .seconds).value
        let endDate = startDate.addingTimeInterval(elapsedTimeInSeconds)
        try await builder.endCollection(at: endDate)
        
        // 8. Finish the Workout
        guard let workout = try await builder.finishWorkout() else {
            throw WorkoutImporterError.saveFailed
        }
        
        // 9. Generate and save a route if needed
        let locations = generateLocations()
        
        // Route processing is ignored if the activity is virtual or indoor
        // It is also ignored if there are no locations available in the FIT file
        let shouldProcessRoute = !((subSport == .virtualActivity || isIndoor) || locations.isEmpty)
        if shouldProcessRoute {
            let routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: .local())
            try await routeBuilder.insertRouteData(locations)
            try await routeBuilder.finishRoute(with: workout, metadata: nil)
        }
        
        return workout.uuid
    }
    
    func activityType() -> HKWorkoutActivityType? {
        // I"m only supporting cycling to keep things simple, but you should map supported activities here.
        // You may need to include additional metadata or samples
        
        switch session.sport {
        case .cycling:
            return .cycling
        default:
            return nil
        }
    }
    
    func isIndoor(subSport: SubSport?) -> Bool {
        guard let subSport else { return false }
        return [.indoorCycling, .spin, .virtualActivity].contains(subSport)
    }
    
    func metadata(from session: SessionMessage) throws -> [String: Any] {
        var dictionary: [String: Any] = [:]
        dictionary[HKMetadataKeyIndoorWorkout] = isIndoor(subSport: session.subSport)
        
        if let avgSpeed = session.averageSpeed {
            let conversion = avgSpeed.converted(to: .metersPerSecond)
            let quantity = HKQuantity(unit: HKUnit.meter().unitDivided(by: .second()), doubleValue: conversion.value)
            dictionary[HKMetadataKeyAverageSpeed] = quantity
        }
        
        if let totalAscent = session.totalAscent {
            let conversion = totalAscent.converted(to: .meters)
            let quantity = HKQuantity(unit: HKUnit.meter(), doubleValue: conversion.value)
            dictionary[HKMetadataKeyElevationAscended] = quantity
        }
        
        return dictionary
    }
    
    func generateWorkoutEvents() -> [HKWorkoutEvent] {
        var workoutEvents: [HKWorkoutEvent] = []
        
        // We only care about start and stop events in the FIT file to map them to their corresponding
        // resume or pause events in HealthKit
        for event in events {
            guard let timestamp = event.timeStamp?.recordDate else { continue }
            
            let dateInterval = DateInterval(start: timestamp, end: timestamp)
            switch event.eventType {
            case .start:
                workoutEvents.append(.init(type: .resume, dateInterval: dateInterval, metadata: nil))
            case .stop, .stopAll:
                workoutEvents.append(.init(type: .pause, dateInterval: dateInterval, metadata: nil))
            default:
                break
            }
        }
        
        // cleaning the first and last events to make sure they are valid
        // the app will crash if the events are not in order following sequences
        // of pause, resume, pause, resume, etc...
        
        // the first event cannot be resume
        if let first = workoutEvents.first, first.type == .resume {
            workoutEvents = Array(workoutEvents.dropFirst())
        }
        
        // the last event cannot be a pause
        if let last = workoutEvents.last, last.type == .pause {
            workoutEvents = Array(workoutEvents.dropLast())
        }
        
        return workoutEvents
    }
    
}

private extension WorkoutImporter {
    
    func generateWorkoutSamples() -> [HKSample] {
        var distance: [HKSample] = []
        var energy: [HKSample] = []
        var heartRate: [HKSample] = []
        var cadence: [HKSample] = []
        var power: [HKSample] = []
        
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
        
        return distance + energy + heartRate + cadence + power
    }
    
    // MARK: Cummulative Samples
    
    func distanceSample(start: RecordMessage, end: RecordMessage) -> HKCumulativeQuantitySample? {
        createCumulativeQuantitySample(
            start: start,
            end: end,
            keyPath: \.distance,
            conversionUnit: .meters,
            quantityUnit: .meter(),
            quantityType: .distanceCycling()
        )
    }
    
    func energySample(start: RecordMessage, end: RecordMessage) -> HKCumulativeQuantitySample? {
        createCumulativeQuantitySample(
            start: start,
            end: end,
            keyPath: \.calories,
            conversionUnit: .kilocalories,
            quantityUnit: .kilocalorie(),
            quantityType: .activeEnergyBurned()
        )
    }
    
    // Convenience method to reuse the logic for cumulative samples
    
    func createCumulativeQuantitySample<T: Dimension>(
        start: RecordMessage,
        end: RecordMessage,
        keyPath: KeyPath<RecordMessage, Measurement<T>?>,
        conversionUnit: T,
        quantityUnit: HKUnit,
        quantityType: HKQuantityType
    ) -> HKCumulativeQuantitySample? {
        guard let startMeasurement = start[keyPath: keyPath],
              let endMeasurement = end[keyPath: keyPath] else { return nil }
        guard let startDate = start.timeStamp?.recordDate,
              let endDate = end.timeStamp?.recordDate else { return nil }

        let startValue = startMeasurement.converted(to: conversionUnit).value
        let endValue = endMeasurement.converted(to: conversionUnit).value
        
        // FIT files include the total cummulative value in each record
        // but samples in HealthKit expects fractional values as they increase
        let value = endValue - startValue
        guard value > 0 else { return nil }

        let quantity = HKQuantity(unit: quantityUnit, doubleValue: value)
        return HKCumulativeQuantitySample(type: quantityType, quantity: quantity, start: startDate, end: endDate)
    }
    
    // MARK: Discrete Samples
    
    func heartRateSample(record: RecordMessage) -> HKDiscreteQuantitySample? {
        createDiscreteQuantity(
            record: record,
            keyPath: \.heartRate,
            quantityUnit: HKUnit.count().unitDivided(by: HKUnit.minute()),
            quantityType: .heartRate()
        )
    }
        
    func cadenceSample(record: RecordMessage) -> HKDiscreteQuantitySample? {
        createDiscreteQuantity(
            record: record,
            keyPath: \.cadence,
            quantityUnit: HKUnit.count().unitDivided(by: HKUnit.minute()),
            quantityType: .cyclingCadence()
        )
    }
    
    func powerSample(record: RecordMessage) -> HKDiscreteQuantitySample? {
        createDiscreteQuantity(
            record: record,
            keyPath: \.power,
            quantityUnit: HKUnit.watt(),
            quantityType: .cyclingPower()
        )
    }
    
    // Convenience method to reuse the logic for discrete samples
    // Note that it handles cadence as an edge case since it requires
    // 2 properties to calculate the full cadence
    
    func createDiscreteQuantity<T: Unit>(
        record: RecordMessage,
        keyPath: KeyPath<RecordMessage, Measurement<T>?>,
        quantityUnit: HKUnit,
        quantityType: HKQuantityType
    ) -> HKDiscreteQuantitySample? {
        guard let date = record.timeStamp?.recordDate else { return nil }
        guard let measurement = record[keyPath: keyPath] else { return nil }
        
        // NOTE ABOUNT CADENCE:
        // cadence samples use two properties in FIT files due to number constraints
        // the total cadence is the sum of the cadence and fractional cadence properties in the FIT file
        let value: Double
        if keyPath == \.cadence {
            let fractionalCadence = record.fractionalCadence ?? .init(value: 0, unit: .revolutionsPerMinute)
            value = measurement.value + fractionalCadence.value
        } else {
            value = measurement.value
        }
        
        guard value > 0 else { return nil }
        let quantity = HKQuantity(unit: quantityUnit, doubleValue: value)
        return .init(type: quantityType, quantity: quantity, start: date, end: date)
    }
    
    // MARK: Locations
    
    func generateLocations() -> [CLLocation] {
        // NOTE: Including location metadata is important!
        // The metadata is used when showing the elevation chart in Workout Details in the Fitness app.
        
        records.compactMap { (record) -> CLLocation? in
            guard let position = record.position else { return nil }
            guard let latitude = position.latitude, let longitude = position.longitude else {
                return nil
            }
            
            let newLatitude = latitude.converted(to: .degrees).value
            let newLongitude = longitude.converted(to: .degrees).value
            let coordinate = CLLocationCoordinate2D(latitude: newLatitude, longitude: newLongitude)
            
            guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
            
            guard let timestamp = record.timeStamp?.recordDate else { return nil }
            
            let accuracy = record.gpsAccuracy?.converted(to: .meters).value ?? 0
            let altitude = record.altitude?.converted(to: .meters).value ?? 0
            let speed = record.speed?.converted(to: .metersPerSecond).value ?? 0
            
            return CLLocation(
                coordinate: coordinate,
                altitude: altitude,
                horizontalAccuracy: accuracy,
                verticalAccuracy: accuracy,
                course: -1,
                speed: speed,
                timestamp: timestamp
            )
        }
    }
        
}
