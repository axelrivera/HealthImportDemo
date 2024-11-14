//
//  Model.swift
//  HealthImportDemo
//
//  Created by Axel Rivera on 11/10/24.
//

import SwiftUI
import HealthKit
import CoreLocation
import FitDataProtocol
import AntMessageProtocol

struct SampleFile: RawRepresentable {
    var rawValue: String
    
    init?(rawValue: String) {
        self.rawValue = rawValue
    }
    
    init(_ fileName: String) {
        self.rawValue = fileName
    }
    
    func data() throws -> Data {
        let url = Bundle.main.url(forResource: rawValue, withExtension: "fit")!
        return try Data(contentsOf: url)
    }
    
    static let cycling: Self = .init("cycling")
    static let cyclingPower: Self = .init("cycling_power")
    static let cyclingZwift: Self = .init("cycling_zwift")
}

@MainActor @Observable
class Model {
    private let fileProcessor = FitFileProcessor()
    private let healthProvider = HealthProvider()
    
    var workoutData: WorkoutData?
    var fileSport: String?
    var fileSubSport: String?
    var fileDate: Date?
    var fileTotalRecords: Int?
    
    var viewModel: WorkoutViewModel?
    var coordinates: [CLLocationCoordinate2D] = []
    
    init(workoutData: WorkoutData? = nil, loadViewModel: Bool = true) {
#if DEBUG
        if loadViewModel, let workoutData {
            self.viewModel = workoutData.workoutViewModel
            self.coordinates = workoutData.coordinates
        } else {
            self.workoutData = workoutData
        }
#endif
    }
}

extension Model {
    
    func requestAuthorization() async {
        do {
            try await healthProvider.requestHealthAuthorization()
        } catch {
            dLog("error requesting authorization: \(error.localizedDescription)")
        }
    }
    
    func processResult(_ result: Result<[URL], Error>) async throws(GenericError) {
        do {
            if let url = try result.get().first {
                try await processURL(url)
            } else {
                throw GenericError("missing url")
            }
        } catch let error as GenericError {
            throw error
        } catch {
            throw GenericError(error.localizedDescription)
        }
    }
    
    func processURL(_ url: URL) async throws {
        let document = FitFileDocument(fileURL: url)
        await document.open()
                
        guard let data = document.data else {
            throw GenericError("missing data in fit file")
        }
                
        try await processData(data)
    }
    
    func processData(_ data: Data) async throws {
        let workoutData = try fileProcessor.decode(data: data)
        self.workoutData = workoutData
    }
    
    func saveToHealth() async throws {
        guard let workoutData else {
            throw GenericError("workout cannot be empty")
        }
        
        let importer = WorkoutImporter()
        let workoutID = try await importer.process(data: workoutData)
        
        let workout = try await healthProvider.fetchWorkout(with: workoutID)
        let locations = try await healthProvider.fetchWorkourRoute(for: workoutID)
        
        let viewModel = WorkoutViewModel.viewModel(for: workout)
        let coordinates = locations.map(\.coordinate)
        
        resetFile()
        self.viewModel = viewModel
        self.coordinates = coordinates
    }
    
    func resetFile() {
        self.workoutData = nil
        self.fileSport = nil
        self.fileDate = nil
        self.fileTotalRecords = nil
    }
    
    func resetWorkout() {
        self.viewModel = nil
        self.coordinates = []
    }
    
}

extension Model {
    
    static var preview: Model {
        filePreview(.cycling)
    }
    
    static func filePreview(_ file: SampleFile? = .cycling, loadViewModel: Bool = true) -> Model {
        if let file {
            let processor = FitFileProcessor()
            let data = try! file.data()
            let workoutData = try! processor.decode(data: data)
            return Model(workoutData: workoutData, loadViewModel: loadViewModel)
        } else {
            return Model()
        }
    }
    
}
