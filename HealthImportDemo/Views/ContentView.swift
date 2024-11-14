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
        model.viewModel != nil || model.workoutData != nil
    }
    
    var body: some View {
        NavigationStack {
            List {
                if let viewModel = model.viewModel {
                    if !model.coordinates.isEmpty {
                        Section {
                            Map(interactionModes: []) {
                                MapPolyline(coordinates: model.coordinates)
                                    .stroke(.blue, lineWidth: 4)
                            }
                            .frame(height: 250)
                            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                        }
                    }
                    
                    metricsSection(viewModel)
                } else if let workoutData = model.workoutData {
                    fileSection(workoutData)
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
            .listStyle(.plain)
            .navigationTitle("Health Import Demo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let _ = model.viewModel {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Reset", role: .destructive, action: reset)
                            .tint(.red)
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
    func fileSection(_ workoutData: WorkoutData) -> some View {
        Section {
            row("Sport", detail: workoutData.sport)
            
            if let startDate = workoutData.startDate {
                row("Date", detail: dateString(startDate))
                row("Time", detail: timeString(startDate))
            }
            
            if let duration = workoutData.duration {
                row("Duration", detail: timerString(duration))
            }
            
            if let distance = workoutData.distance {
                row("Distance", detail: distanceString(distance))
            }
            
            row("Total Records", detail: workoutData.totalRecords.formatted())
        } header: {
            Text("File Details")
        } footer: {
            Button(action: save) {
                Text("Save to Apple Health")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.vertical, 10)
            .listRowSeparator(.hidden, edges: .bottom)
        }
    }
    
    @ViewBuilder
    func metricsSection(_ viewModel: WorkoutViewModel) -> some View {
        Section {
            VStack(alignment: .leading) {
                Text(dateString(viewModel.startDate))
                Text("\(timeString(viewModel.startDate)) - \(timeString(viewModel.endDate))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            row("Total Time", detail: timerString(viewModel.totalDuration))
            
            if viewModel.duration.value > 0 {
                row("Moving Time", detail: timerString(viewModel.duration))
            }
            
            if let distance = viewModel.distance {
                row("Distance", detail: distanceString(distance))
            }
            
            if let elevationAscended = viewModel.elevation {
                row("Elevation Ascended", detail: elevationString(elevationAscended))
            }
            
            if let speed = viewModel.avgSpeed {
                row("Avg Speed", detail: speedString(speed))
            }
            
            if let heartRate = viewModel.avgHeartRate {
                row("Avg HR", detail: heartRateString(heartRate))
            }
            
            if let calories = viewModel.totalEnergy {
                row("Active Calories", detail: energyString(calories))
            }

            if let cadence = viewModel.avgCadence {
                row("Avg Cadence", detail: cadenceString(cadence))
            }
            
            if let power = viewModel.avgPower {
                row("Avg Power", detail: powerString(power))
            }
        } header: {
            Text("Details")
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
            model.resetWorkout()
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
    @Previewable @State var model: Model = .filePreview(.cycling, loadViewModel: false)
    
    ContentView()
        .environment(model)
}
