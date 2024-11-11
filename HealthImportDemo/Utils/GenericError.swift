//
//  GenericError.swift
//  HealthImportDemo
//
//  Created by Axel Rivera on 11/9/24.
//

import Foundation

struct GenericError: Error {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
}

extension GenericError: LocalizedError {
    
    var errorDescription: String? { message }
    
}
