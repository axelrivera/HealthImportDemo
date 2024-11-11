//
//  Calendar+Additions.swift
//  HealthImportDemo
//
//  Created by Axel Rivera on 11/10/24.
//

import Foundation

extension Calendar {
    
    func startOfHour(for date: Date) -> Date {
        var components = dateComponents([.month, .day, .year, .hour, .minute], from: date)
        components.minute = 0
        return self.date(from: components)!
    }
    
}
