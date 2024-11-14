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
        guard let startDate = session.startTime?.recordDate, let elapsedTime = session.totalElapsedTime else {
            throw WorkoutImporterError.invalidData
        }
        
        guard let activityType = activityType() else {
            throw WorkoutImporterError.activityNotSupported
        }
        
        let elapsedTimeInSeconds = elapsedTime.converted(to: .seconds).value
        let endDate = startDate.addingTimeInterval(elapsedTimeInSeconds)
        
        let subSport = session.subSport
        let isIndoor = isIndoor(subSport: subSport)
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = isIndoor  ? .indoor : .outdoor
        
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        try await builder.beginCollection(at: startDate)
        
        let metadata = try self.metadata(from: session)
        try await builder.addMetadata(metadata)
        
        let events = generateWorkoutEvents()
        if !events.isEmpty {
            try await builder.addWorkoutEvents(events)
        }
        
        let samples = generateWorkoutSamples()
        if !samples.isEmpty {
            try await builder.addSamples(samples)
        }
        
        try await builder.endCollection(at: endDate)
        
        guard let workout = try await builder.finishWorkout() else {
            throw WorkoutImporterError.saveFailed
        }
        
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
        
        if let first = workoutEvents.first, first.type == .resume {
            workoutEvents = Array(workoutEvents.dropFirst())
        }
        
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
    
    func createDiscreteQuantity<T: Unit>(
        record: RecordMessage,
        keyPath: KeyPath<RecordMessage, Measurement<T>?>,
        quantityUnit: HKUnit,
        quantityType: HKQuantityType
    ) -> HKDiscreteQuantitySample? {
        guard let date = record.timeStamp?.recordDate else { return nil }
        guard let measurement = record[keyPath: keyPath] else { return nil }
        
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
