//
//  FitFileProcessor.swift
//  HealthImportDemo
//
//  Created by Axel Rivera on 11/10/24.
//

import Foundation
import FitDataProtocol

enum FitFileProcessorError: Error {
    case missingSession
}

final class FitFileProcessor {    
    lazy var decoder = FitFileDecoder(crcCheckingStrategy: .throws)
    
    func decode(data: Data) throws -> WorkoutData {
        var session: SessionMessage?
        var events: [EventMessage] = []
        var records: [RecordMessage] = []

        try decoder.decode(data: data, messages: FitFileDecoder.defaultMessages) { message in
            if let sessionMessage = message as? SessionMessage {
                session = sessionMessage
            }
            
            if let event = message as? EventMessage {
                events.append(event)
            }
            
            if let message = message as? RecordMessage {
                records.append(message)
            }
        }
        
        guard let session else {
            throw FitFileProcessorError.missingSession
        }
        
        return WorkoutData(session: session, events: events, records: records)
    }
    
}
