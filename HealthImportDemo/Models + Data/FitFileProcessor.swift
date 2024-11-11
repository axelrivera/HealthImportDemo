//
//  FitFileProcessor.swift
//  HealthImportDemo
//
//  Created by Axel Rivera on 11/10/24.
//

import Foundation
import FitDataProtocol

final class FitFileProcessor {    
    lazy var decoder = FitFileDecoder(crcCheckingStrategy: .throws)
    
    func decode(data: Data) throws -> WorkoutViewModel {
        var session: SessionMessage?
        var activity: ActivityMessage?
        var events: [EventMessage] = []
        var laps: [LapMessage] = []
        var records: [RecordMessage] = []
        
        try decoder.decode(data: data, messages: FitFileDecoder.defaultMessages) { message in
            if let sessionMessage = message as? SessionMessage {
                session = sessionMessage
            }
            
            if let activityMessage = message as? ActivityMessage {
                activity = activityMessage
            }
            
            if let event = message as? EventMessage {
                events.append(event)
            }
            
            if let lap = message as? LapMessage {
                laps.append(lap)
            }
            
            if let message = message as? RecordMessage {
                records.append(message)
            }
        }
        
        guard let session else {
            throw GenericError("missing session")
        }
        
        guard let _ = activity else {
            throw GenericError("missing activity")
        }
        
        return try WorkoutViewModel.viewModel(forSession: session, events: events, laps: laps, records: records)
    }
    
}
