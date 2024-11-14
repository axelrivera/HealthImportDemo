//
//  HealthKit+Additions.swift
//  HealthImportDemo
//
//  Created by Axel Rivera on 11/13/24.
//

import Foundation
import HealthKit

extension HKQuantityType {
            
    static func distanceCycling() -> HKQuantityType {
        .init(.distanceCycling)
    }
        
    static func cyclingCadence() -> HKQuantityType {
        HKQuantityType(.cyclingCadence)
    }
    
    static func heartRate() -> HKQuantityType {
        HKQuantityType(.heartRate)
    }
    
    static func activeEnergyBurned() -> HKQuantityType {
        HKQuantityType(.activeEnergyBurned)
    }
    
    static func cyclingPower() -> HKQuantityType {
        HKQuantityType(.cyclingPower)
    }
    
}

extension HKUnit {
    
    static func bpm() -> HKUnit {
        HKUnit.count().unitDivided(by: HKUnit.minute())
    }
    
    static func rpm() -> HKUnit {
        HKUnit.count().unitDivided(by: .minute())
    }
    
    static func metersPerSecond() -> HKUnit {
        HKUnit.meter().unitDivided(by: .second())
    }
    
}
