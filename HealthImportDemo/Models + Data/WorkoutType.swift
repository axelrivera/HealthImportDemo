//
//  WorkoutType.swift
//  HealthImportDemo
//
//  Created by Axel Rivera on 11/10/24.
//

import Foundation
import HealthKit
import AntMessageProtocol

enum WorkoutType: String, CaseIterable {
    case cycling
    
    init?(sport: Sport) {
        let workoutType: WorkoutType?
        switch sport {
        case .cycling: workoutType = .cycling
        default: workoutType = nil
        }
        guard let workoutType else {
            return nil
        }
        self = workoutType
    }
    
    var activityType: HKWorkoutActivityType {
        switch self {
        case .cycling: .cycling
        }
    }
    
    var stringValue: String {
        switch self {
        case .cycling: "Cycling"
        }
        
    }
}
