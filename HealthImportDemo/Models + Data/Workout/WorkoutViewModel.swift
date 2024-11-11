//
//  WorkoutViewModel.swift
//  HealthImportDemo
//
//  Created by Axel Rivera on 11/10/24.
//

import Foundation
import CoreLocation
import FitnessUnits
import FitDataProtocol
import HealthKit
import WeatherKit
import AntMessageProtocol

extension UnitCadence: @retroactive @unchecked Sendable {}

struct WorkoutViewModel: Hashable, Equatable, Identifiable, Sendable {
    static func == (lhs: WorkoutViewModel, rhs: WorkoutViewModel) -> Bool {
        lhs.id == rhs.id
    }
    
    var id: String {
        workoutType.rawValue + "::" + "\(start.timeIntervalSince1970)" + "::" + "\(elapsedTime)lh"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    let workoutType: WorkoutType
    let isIndoor: Bool
    let isVirtualActivity: Bool
    let start: Date
    
    let elapsedTime: Measurement<UnitDuration>
    let timerTime: Measurement<UnitDuration>?
    let movingTime: Measurement<UnitDuration>?
    
    let distance: Measurement<UnitLength>?
    
    let avgHeartRate: Measurement<UnitCadence>?
    let maxHeartRate: Measurement<UnitCadence>?
    let activeCalories: Measurement<UnitEnergy>?
    
    let avgSpeed: Measurement<UnitSpeed>?
    let maxSpeed: Measurement<UnitSpeed>?
    
    let avgCyclingCadence: Measurement<UnitCadence>?
    let maxCyclingCadence: Measurement<UnitCadence>?
    
    let avgCyclingPower: Measurement<UnitPower>?
    let maxCyclingPower: Measurement<UnitPower>?
    
    let elevationAscended: Measurement<UnitLength>?
    let elevationDescended: Measurement<UnitLength>?
    let maxElevation: Measurement<UnitLength>?
    let minElevation: Measurement<UnitLength>?
    
    let avgTemperature: Measurement<UnitTemperature>?
    let maxTemperature: Measurement<UnitTemperature>?
    
    let route: [CLLocation]
    let records: [WorkoutViewModel.Record]
    let events: [WorkoutViewModel.Event]
    let laps: [WorkoutViewModel.Lap]
}

extension WorkoutViewModel {
    
    var end: Date {
        start.addingTimeInterval(elapsedTime.value)
    }
    
    var totalMovingTime: Measurement<UnitDuration>? {
        movingTime ?? timerTime
    }
    
    var pausedTime: Measurement<UnitDuration> {
        let movingTime: Measurement<UnitDuration>
        if let totalMovingTime {
            movingTime = totalMovingTime
        } else {
            movingTime = elapsedTime
        }
        
        let movingTimeConversion = movingTime.converted(to: .seconds)
        let elapsedTimeConversion = elapsedTime.converted(to: .seconds)
        let pausedTime = elapsedTimeConversion.value - movingTimeConversion.value
        
        return Measurement<UnitDuration>(value: pausedTime, unit: .seconds)
    }
    
}

extension WorkoutViewModel {
    
    static func viewModel(forSession session: SessionMessage, events: [EventMessage], laps: [LapMessage], records: [RecordMessage]) throws -> WorkoutViewModel {
        guard let sport = session.sport, let workoutType = WorkoutType(sport: sport) else {
            throw GenericError("sport not supported")
        }
        
        guard let start = session.startTime?.recordDate, let elapsedTime = session.totalElapsedTime else {
            throw GenericError("missing data")
        }
        
        let timerTime = session.totalTimerTime
        let movingTime = session.totalMovingTime
        let avgHeartRate = session.averageHeartRate
        let maxHeartRate = session.maximumHeartRate
        let activeCalories = session.totalCalories
        let distance = session.totalDistance
        let avgSpeed = session.averageSpeed
        let maxSpeed = session.maximumSpeed
        let avgCyclingCadence = Self.absoluteCadence(session.averageCadence, fraction: session.averageFractionalCadence)
        let maxCyclingCadence = Self.absoluteCadence(session.maximumCadence, fraction: session.maximumFractionalCadence)
        let avgCyclingPower = session.averagePower
        let maxCyclingPower = session.maximumPower
        let elevationAscended = session.totalAscent
        let elevationDescended = session.totalDescent
        let avgTemperature = session.averageTemperature
        let maxElevation = session.maximumAltitude
        let minElevation = session.minimumAltitude
        let maxTemperature = session.maximumTemperature
        
        let workoutRecords = self.records(forMessages: records)
        let workoutEvents = self.events(forMessages: events)
        let workoutLaps = self.laps(forMessages: laps)
        let workoutRoute = self.locations(forMessages: records)
        
        let isIndoor: Bool
        let isVirtualActivity: Bool
        if let subSport = session.subSport {
            isIndoor = subSport.isIndoor
            isVirtualActivity = subSport == .virtualActivity
        } else {
            isIndoor = workoutRoute.isEmpty
            isVirtualActivity = false
        }
                
        return .init(
            workoutType: workoutType,
            isIndoor: isIndoor,
            isVirtualActivity: isVirtualActivity,
            start: start,
            elapsedTime: elapsedTime,
            timerTime: timerTime,
            movingTime: movingTime,
            distance: distance,
            avgHeartRate: avgHeartRate,
            maxHeartRate: maxHeartRate,
            activeCalories: activeCalories,
            avgSpeed: avgSpeed,
            maxSpeed: maxSpeed,
            avgCyclingCadence: avgCyclingCadence,
            maxCyclingCadence: maxCyclingCadence,
            avgCyclingPower: avgCyclingPower,
            maxCyclingPower: maxCyclingPower,
            elevationAscended: elevationAscended,
            elevationDescended: elevationDescended,
            maxElevation: maxElevation,
            minElevation: minElevation,
            avgTemperature: avgTemperature,
            maxTemperature: maxTemperature,
            route: workoutRoute,
            records: workoutRecords,
            events: workoutEvents,
            laps: workoutLaps
        )
    }
    
    static func absoluteCadence(_ value: Measurement<UnitCadence>?, fraction: Measurement<UnitCadence>?) -> Measurement<UnitCadence>? {
        guard let value else { return nil }
        let fraction = fraction?.value ?? 0
        return Measurement<UnitCadence>(value: value.value + fraction, unit: .revolutionsPerMinute)
    }
    
}

extension WorkoutViewModel {
    
    var weatherLocation: CLLocation? {
        if let location = route.first, !isIndoor && !isVirtualActivity {
            return location
        } else {
            return nil
        }
    }
    
}

extension WeatherCondition {
    
    var healthWeatherCondition: HKWeatherCondition {
        switch self {
        case .blizzard: .snow
        case .blowingDust: .dust
        case .blowingSnow: .snow
        case .breezy: .windy
        case .clear: .clear
        case .cloudy: .cloudy
        case .drizzle: .drizzle
        case .flurries: .snow
        case .foggy: .foggy
        case .freezingDrizzle: .freezingDrizzle
        case .freezingRain: .freezingRain
        case .frigid: .none // IGNORE
        case .hail: .hail
        case .haze: .haze
        case .heavyRain: .thunderstorms
        case .heavySnow: .snow
        case .hot: .none // IGNORE
        case .hurricane: .hurricane
        case .isolatedThunderstorms: .thunderstorms
        case .mostlyClear: .clear
        case .mostlyCloudy: .mostlyCloudy
        case .partlyCloudy: .partlyCloudy
        case .rain: .showers
        case .scatteredThunderstorms: .scatteredShowers
        case .sleet: .sleet
        case .smoky: .smoky
        case .snow: .snow
        case .strongStorms: .thunderstorms
        case .sunFlurries: .snow
        case .sunShowers: .showers
        case .thunderstorms: .thunderstorms
        case .tropicalStorm: .tropicalStorm
        case .windy: .windy
        case .wintryMix: .mixedRainAndSnow
        @unknown default: .none
        }
    }
    
}

extension SubSport {
    
    static func indoorActivities() -> [SubSport] {
        [
            .indoorCycling,
            .spin,
            .virtualActivity
        ]
    }
    
    var isIndoor: Bool {
        let indoorActivities = Self.indoorActivities()
        return indoorActivities.contains(self)
    }
    
}
