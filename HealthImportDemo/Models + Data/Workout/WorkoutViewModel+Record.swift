//
//  RawWorkout+Record.swift
//  HealthImportDemo
//
//  Created by Axel Rivera on 11/10/24.
//

import Foundation
import CoreLocation
import FitnessUnits
import FitDataProtocol

extension WorkoutViewModel {
    struct Record: Identifiable, Hashable, Equatable {
        let timestamp: Date
        let distance: Measurement<UnitLength>?
        let speed: Measurement<UnitSpeed>?
        let heartRate: Measurement<UnitCadence>?
        let calories: Measurement<UnitEnergy>?
        let cadence: Measurement<UnitCadence>?
        let power: Measurement<UnitPower>?
        let altitude: Measurement<UnitLength>?
        
        var id: String {
            "\(timestamp.timeIntervalSince1970)"
        }
    }
    
    static func records(forMessages messages: [RecordMessage]) -> [Record] {
        messages.compactMap { message in
            guard let timestamp = message.timeStamp?.recordDate else { return nil }
            return .init(
                timestamp: timestamp,
                distance: message.distance,
                speed: message.speed,
                heartRate: message.heartRate,
                calories: message.calories,
                cadence: absoluteCadence(message.cadence, fraction: message.fractionalCadence),
                power: message.power,
                altitude: message.altitude
            )
        }
    }
    
    static func locations(forMessages messages: [RecordMessage]) -> [CLLocation] {
        messages.compactMap { (record) -> CLLocation? in
            guard let position = record.position, let coordinate = position.location?.coordinate else { return nil }
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

extension Position {
    
    var location: CLLocation? {
        guard let latitude, let longitude else {
            return nil
        }
        
        let newLatitude = latitude.converted(to: .degrees).value
        let newLongitude = longitude.converted(to: .degrees).value
        
        return CLLocation(latitude: newLatitude, longitude: newLongitude)
    }
    
}
