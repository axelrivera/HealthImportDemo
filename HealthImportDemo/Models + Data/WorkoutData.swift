//
//  WorkoutData.swift
//  HealthImportDemo
//
//  Created by Axel Rivera on 11/13/24.
//

import Foundation
import FitDataProtocol
import CoreLocation
import HealthKit

struct WorkoutData {
    let session: SessionMessage
    let events: [EventMessage]
    let records: [RecordMessage]
    
    var sport: String {
        session.sport?.stringValue ?? "Unknown"
    }
    
    var distance: Measurement<UnitLength>? {
        session.totalDistance
    }
    
    var duration: Measurement<UnitDuration>? {
        session.totalElapsedTime
    }
    
    var startDate: Date? {
        session.startTime?.recordDate
    }
    
    var totalRecords: Int {
        records.count
    }
    
}

extension WorkoutData {
    
    var workoutViewModel: WorkoutViewModel {
        let activityType: HKWorkoutActivityType = session.sport == .cycling ? .cycling : .cycling
        
        let startDate = session.startTime?.recordDate ?? Date.now
        let elapsedTime = session.totalElapsedTime?.converted(to: .seconds) ?? .init(value: 0, unit: .seconds)
        let endDate = startDate.addingTimeInterval(elapsedTime.value)
        
        
        let movingTime = session.totalMovingTime?.converted(to: .seconds)
        let timerTime = session.totalTimerTime?.converted(to: .seconds)
        let duration = movingTime ?? timerTime ?? elapsedTime
        
        let distance = session.totalDistance?.converted(to: .meters)
        let speed = session.averageSpeed?.converted(to: .metersPerSecond)
        let elevation = session.totalAscent?.converted(to: .meters)
        let energy = session.totalCalories?.converted(to: .kilocalories)
        let heartRate = session.averageHeartRate
        let cadence = session.averageCadence
        let power = session.averagePower
        
        return .init(
            id: UUID(),
            activityType: activityType,
            isIndoor: isIndoor,
            startDate: startDate,
            endDate: endDate,
            duration: duration,
            distance: distance,
            avgSpeed: speed,
            elevation: elevation,
            totalEnergy: energy,
            avgHeartRate: heartRate,
            avgCadence: cadence,
            avgPower: power
        )
    }
    
    var coordinates: [CLLocationCoordinate2D] {
        records.compactMap { (record) -> CLLocationCoordinate2D? in
            guard let position = record.position else { return nil }
            guard let latitude = position.latitude, let longitude = position.longitude else {
                return nil
            }
            
            let newLatitude = latitude.converted(to: .degrees).value
            let newLongitude = longitude.converted(to: .degrees).value
            let coordinate = CLLocationCoordinate2D(latitude: newLatitude, longitude: newLongitude)
            
            guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
            return coordinate
        }
    }
    
    private var isIndoor: Bool {
        guard let subSport = session.subSport else { return false }
        return [.indoorCycling, .spin, .virtualActivity].contains(subSport)
    }
    
}
