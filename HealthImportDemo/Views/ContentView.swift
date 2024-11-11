//
//  ContentView.swift
//  HealthImportDemo
//
//  Created by Axel Rivera on 11/9/24.
//

import SwiftUI
import MapKit
import FitnessUnits

struct ContentView: View {
    @Environment(Model.self) var model
    
    @State private var isShowingFileImporter = false
    @State private var isShowingImportConfirmation = false
    @State private var isSavingToHealth = false
    
    @State private var error: GenericError?
    @State private var isShowingError = false
    
    var isReady: Bool {
        model.viewModel != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if let viewModel = model.viewModel {
                    metricsSection(viewModel)
                    recordsSection(viewModel)
                    
                    Section {
                        Map(interactionModes: []) {
                            if !model.coordinates.isEmpty {
                                MapPolyline(coordinates: model.coordinates)
                                    .stroke(.blue, lineWidth: 4)
                            }
                        }
                        .frame(height: 250)
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    } header: {
                        Text("Route")
                    }
                }
            }
            .overlay {
                if !isReady {
                    selectActions()
                }
            }
            .overlay {
                if isSavingToHealth {
                    hudView()
                }
            }
            .navigationTitle("Health Import Demo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isReady {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Reset", role: .destructive, action: reset)
                            .tint(.red)
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        Button("Save", action: { isShowingImportConfirmation.toggle() })
                    }
                }
            }
            .fileImporter(isPresented: $isShowingFileImporter, allowedContentTypes: [.fitDocument], allowsMultipleSelection: false) { result in
                Task {
                    do {
                        try await model.processResult(result)
                    } catch {
                        showError(error)
                    }
                }
            }
            .alert("Save Confirmation", isPresented: $isShowingImportConfirmation) {
                Button("Cancel", action: {})
                Button("Continue", action: save)
            } message: {
                Text("Save workout to Apple Health?")
            }
            .alert(isPresented: $isShowingError, error: error) {
                Button("OK", action: {})
            }
        }
    }
    
    @ViewBuilder
    func metricsSection(_ viewModel: WorkoutViewModel) -> some View {
        Section {
            VStack(alignment: .leading) {
                Text(dateString(viewModel.start))
                Text("\(timeString(viewModel.start)) - \(timeString(viewModel.end))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            row("Total Time", detail: timerString(viewModel.elapsedTime))
            
            if let movingTime = viewModel.totalMovingTime {
                row("Moving Time", detail: timerString(movingTime))
            }
            
            if let distance = viewModel.distance {
                row("Distance", detail: distanceString(distance))
            }
            
            if let elevationAscended = viewModel.elevationAscended {
                row("Elevation Ascended", detail: elevationString(elevationAscended))
            }
            
            if let speed = viewModel.avgSpeed {
                row("Avg Speed", detail: speedString(speed))
            }
            
            if let heartRate = viewModel.avgHeartRate {
                row("Avg HR", detail: heartRateString(heartRate))
            }
            
            if let calories = viewModel.activeCalories {
                row("Active Calories", detail: energyString(calories))
            }

            if let cadence = viewModel.avgCyclingCadence {
                row("Avg Cadence", detail: cadenceString(cadence))
            }
            
            if let power = viewModel.avgCyclingPower {
                row("Avg Power", detail: powerString(power))
            }
        } header: {
            Text("Details")
        }
    }
    
    @ViewBuilder
    func recordsSection(_ viewModel: WorkoutViewModel) -> some View {
        Section {
            row("Total Records", detail: viewModel.records.count.formatted())
            row("Total Laps", detail: viewModel.laps.count.formatted())
            row("Total Events", detail: viewModel.events.count.formatted())
        } header: {
            Text("Samples")
        }
    }
    
    @ViewBuilder
    func selectActions() -> some View {
        VStack {
            Spacer()
            VStack(spacing: 25) {
                Text("Load Sample Files")
                    .font(.title2)
                
                VStack(spacing: 20) {
                    Button("Cycling Sample", action: { loadSample(.cycling) })
                    Button("Cycling Indoor Sample", action: { loadSample(.cyclingZwift) })
                    Button("Cycling Power Sample", action: { loadSample(.cyclingPower) })
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Spacer()
            
            VStack {
                Button(action: { isShowingFileImporter.toggle() }) {
                    Text("Load File from Files App")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Text("This demo will only work with a cycling workout FIT file recorded with a Garmin, Wahoo or other cycling computer.")
                    .multilineTextAlignment(.center)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top)
            }
            
            
            
            
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    func row(_ label: String, detail: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(detail)
        }
    }
    
    @ViewBuilder
    func hudView() -> some View {
        ZStack {
            Rectangle()
                .fill(Material.ultraThin)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            ProgressView()
                .progressViewStyle(.circular)
        }
    }
    
}

extension ContentView {
    
    func save() {
        Task {
            await model.requestAuthorization()
            
            withAnimation {
                isSavingToHealth = true
            }
            
            do {
                try await model.saveToHealth()
                
                withAnimation {
                    isSavingToHealth = false
                    model.reset()
                }
            } catch {
                withAnimation {
                    isSavingToHealth = false
                    showError(error)
                }
            }
        }
    }
    
    func reset() {
        withAnimation {
            model.reset()
        }
    }
    
    func loadSample(_ sample: SampleFile) {
        Task {
            do {
                let data = try sample.data()
                try await model.processData(data)
            } catch {
                showError(error)
            }
        }
    }
    
}

extension ContentView {
    
    func showError(_ error: Error) {
        self.error = (error as? GenericError) ?? GenericError(error.localizedDescription)
        self.isShowingError = true
    }
    
    func dateString(_ date: Date) -> String {
        date.formatted(date: .complete, time: .omitted)
    }
    
    func timeString(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
    
    func timerString(_ duration: Measurement<UnitDuration>) -> String {
        timerDurationString(forDuration: duration)
    }
    
    func distanceString(_ measurement: Measurement<UnitLength>) -> String {
        let conversion = measurement.converted(to: .miles)
        return conversion.formatted(
            .measurement(
                width: .abbreviated,
                usage: .asProvided,
                numberFormatStyle: .number.precision(.fractionLength(0...1))
            )
        )
    }
    
    func elevationString(_ measurement: Measurement<UnitLength>) -> String {
        let conversion = measurement.converted(to: .feet)
        return conversion.formatted(
            .measurement(
                width: .abbreviated,
                usage: .asProvided,
                numberFormatStyle: .number.precision(.fractionLength(0))
            )
        )
    }
    
    func speedString(_ measurement: Measurement<UnitSpeed>) -> String {
        let conversion = measurement.converted(to: .milesPerHour)
        return conversion.formatted(
            .measurement(
                width: .abbreviated,
                usage: .asProvided,
                numberFormatStyle: .number.precision(.fractionLength(0))
            )
        )
    }
    
    func energyString(_ measurement: Measurement<UnitEnergy>) -> String {
        let conversion = measurement.converted(to: .kilocalories)
        return conversion.formatted(
            .measurement(
                width: .abbreviated,
                usage: .asProvided,
                numberFormatStyle: .number.precision(.fractionLength(0))
            )
        )
    }
    
    func heartRateString(_ measurement: Measurement<UnitCadence>) -> String {
        String(format: "%@ %@", Int(measurement.value).formatted(), measurement.unit.symbol.lowercased())
    }
    
    func cadenceString(_ measurement: Measurement<UnitCadence>) -> String {
        String(format: "%@ %@", Int(measurement.value).formatted(), measurement.unit.symbol.lowercased())
    }
    
    func powerString(_ measurement: Measurement<UnitPower>) -> String {
        let conversion = measurement.converted(to: .watts)
        return conversion.formatted(
            .measurement(
                width: .abbreviated,
                usage: .asProvided,
                numberFormatStyle: .number.precision(.fractionLength(0))
            )
        )
    }
    
}

#Preview {
    @Previewable @State var model: Model = .filePreview(nil)
    
    ContentView()
        .environment(model)
}
