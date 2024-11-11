//
//  WorkoutViewModel+Event.swift
//  HealthImportDemo
//
//  Created by Axel Rivera on 11/10/24.
//

import Foundation
import HealthKit
import FitDataProtocol

extension WorkoutViewModel {
    
    enum EventType: String, Hashable, CustomStringConvertible {
        case start = "start"
        case stop = "stop"
        
        init?(fileEventType: FitDataProtocol.EventType) {
            switch fileEventType {
            case .start:
                self = .start
            case .stop, .stopAll:
                self = .stop
            default:
                return nil
            }
        }
        
        var workoutEventType: HKWorkoutEventType {
            switch self {
            case .start:
                return .resume
            case .stop:
                return .pause
            }
        }
        
        var description: String { rawValue }
    }
    
    struct Event: CustomStringConvertible {
        let timestamp: Date
        let eventType: EventType
        
        var workoutEvent: HKWorkoutEvent {
            HKWorkoutEvent(
                type: eventType.workoutEventType,
                dateInterval: .init(start: timestamp, end: timestamp),
                metadata: nil
            )
        }
        
        init?(_ message: EventMessage) {
            guard let timestamp = message.timeStamp?.recordDate, let fileEventType = message.eventType else { return nil }
            guard let eventType = EventType(fileEventType: fileEventType) else { return nil }
            self.timestamp = timestamp
            self.eventType = eventType
        }
        
        var description: String {
            eventType.description + " " + "\(timestamp.timeIntervalSince1970)"
        }
    }
    
    private func filteredEvents() -> [Event] {
        var filteredEvents: [Event] = self.events
                
        if let first = filteredEvents.first, first.eventType == .start {
            filteredEvents = Array(filteredEvents.dropFirst())
        }
        
        if let last = filteredEvents.last, last.eventType == .stop {
            filteredEvents = Array(filteredEvents.dropLast())
        }
        
        return filteredEvents
    }
    
    func workoutEvents() -> [HKWorkoutEvent] {
        filteredEvents().map({ $0.workoutEvent })
    }
    
    static func events(forMessages messages: [EventMessage]) -> [WorkoutViewModel.Event] {
        messages.compactMap({ Event($0) })
    }
    
}
