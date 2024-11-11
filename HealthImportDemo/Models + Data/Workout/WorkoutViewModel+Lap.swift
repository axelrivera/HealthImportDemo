//
//  WorkoutViewModel+Lap.swift
//  HealthImportDemo
//
//  Created by Axel Rivera on 11/10/24.
//

import Foundation
import HealthKit
import FitnessUnits
import FitDataProtocol

extension WorkoutViewModel {
    
    struct Lap: Identifiable, Hashable, Equatable {
        static func == (lhs: Lap, rhs: Lap) -> Bool {
            lhs.id == rhs.id
        }
        
        var id: String {
            "\(number)" + "::" + "\(start.timeIntervalSince1970)" + "::" + "\(end.timeIntervalSince1970)"
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        let number: Int
        let start: Date
        let end: Date
        let elapsedTime: Measurement<UnitDuration>
        let movingTime: Measurement<UnitDuration>?
        
        let avgHeartRate: Measurement<UnitCadence>?
        let maxHeartRate: Measurement<UnitCadence>?
        
        let distance: Measurement<UnitLength>?
        
        let avgSpeed: Measurement<UnitSpeed>?
        let maxSpeed: Measurement<UnitSpeed>?
        
        let avgCadence: Measurement<UnitCadence>?
        let maxCadence: Measurement<UnitCadence>?
        
        let elevationAscended: Measurement<UnitLength>?
        let elevationDescended: Measurement<UnitLength>?
        
        init(number: Int,
             start: Date,
             end: Date,
             elapsedTime: Measurement<UnitDuration>,
             movingTime: Measurement<UnitDuration>?,
             avgHeartRate: Measurement<UnitCadence>?,
             maxHeartRate: Measurement<UnitCadence>?,
             distance: Measurement<UnitLength>?,
             avgSpeed: Measurement<UnitSpeed>?,
             maxSpeed: Measurement<UnitSpeed>?,
             avgCadence: Measurement<UnitCadence>?,
             maxCadence: Measurement<UnitCadence>?,
             elevationAscended: Measurement<UnitLength>?,
             elevationDescended: Measurement<UnitLength>?)
        {
            self.number = number
            self.start = start
            self.end = end
            self.elapsedTime = elapsedTime
            self.movingTime = movingTime
            self.avgHeartRate = avgHeartRate
            self.maxHeartRate = maxHeartRate
            self.distance = distance
            self.avgSpeed = avgSpeed
            self.maxSpeed = maxSpeed
            self.avgCadence = avgCadence
            self.maxCadence = maxCadence
            self.elevationAscended = elevationAscended
            self.elevationDescended = elevationDescended
        }
        
        var interval: DateInterval {
            .init(start: start, end: end)
        }
        
        static func lapForMessage(message: LapMessage, lapNumber: Int) -> Lap? {
            guard let start = message.startTime?.recordDate, let end = message.timeStamp?.recordDate else { return nil }
            
            let elapsedTime = message.totalElapsedTime ?? .init(value: 0, unit: .seconds)
            let movingTime = message.totalMovingTime ?? message.totalTimerTime
            let avgHeartRate = message.averageHeartRate
            let maxHeartRate = message.maximumHeartRate
            let distance = message.totalDistance
            let avgSpeed = message.averageSpeed
            let maxSpeed = message.maximumSpeed
            let avgCadence = absoluteCadence(message.averageCadence, fraction: message.averageFractionalCadence)
            let maxCadence = absoluteCadence(message.maximumCadence, fraction: message.maximumFractionalCadence)
            let elevationAscended = message.totalAscent
            let elevationDescended = message.totalDescent
            
            return .init(
                number: lapNumber,
                start: start,
                end: end,
                elapsedTime: elapsedTime,
                movingTime: movingTime,
                avgHeartRate: avgHeartRate,
                maxHeartRate: maxHeartRate,
                distance: distance,
                avgSpeed: avgSpeed,
                maxSpeed: maxSpeed,
                avgCadence: avgCadence,
                maxCadence: maxCadence,
                elevationAscended: elevationAscended,
                elevationDescended: elevationDescended
            )
        }
    }

    static func laps(forMessages messages: [LapMessage]) -> [Lap] {
        messages.enumerated().compactMap { (index, message) -> Lap? in
            Lap.lapForMessage(message: message, lapNumber: index + 1)
        }
    }
    
    func workoutLaps() -> [HKWorkoutEvent] {
        laps.map({ HKWorkoutEvent(type: .segment, dateInterval: $0.interval, metadata: nil) })
    }
    
}
