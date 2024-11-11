//
//  HealthStore.swift
//  HealthImportDemo
//
//  Created by Axel Rivera on 11/9/24.
//

import Foundation
import HealthKit

final class HealthStore: Sendable {
    static let shared = HealthStore()
    let defaultStore = HKHealthStore()
}
