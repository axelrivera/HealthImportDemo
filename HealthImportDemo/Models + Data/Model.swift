//
//  Model.swift
//  HealthImportDemo
//
//  Created by Axel Rivera on 11/10/24.
//

import SwiftUI
import CoreLocation

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
    
    var viewModel: WorkoutViewModel?
    var coordinates: [CLLocationCoordinate2D] = []
    
    init(viewModel: WorkoutViewModel? = nil) {
#if DEBUG
        self.viewModel = viewModel
        self.coordinates = viewModel?.route.map(\.coordinate) ?? []
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
        let viewModel = try fileProcessor.decode(data: data)
        updateValues(forViewModel: viewModel)
    }
    
    func updateValues(forViewModel viewModel: WorkoutViewModel) {
        self.viewModel = viewModel
        self.coordinates = viewModel.route.map(\.coordinate)
    }
    
    func saveToHealth() async throws {
        guard let viewModel else {
            throw GenericError("workout cannot be empty")
        }
        
        let importer = HealthImporter()
        try await importer.saveWorkout(viewModel)
    }
    
    func reset() {
        self.viewModel = nil
        self.coordinates = []
    }
    
}

extension Model {
    
    static var preview: Model {
        filePreview(.cycling)
    }
    
    static func filePreview(_ file: SampleFile? = .cycling) -> Model {
        if let file {
            let processor = FitFileProcessor()
            let data = try! file.data()
            let result = try! processor.decode(data: data)
            return Model(viewModel: result)
        } else {
            return Model(viewModel: nil)
        }
    }
    
}
