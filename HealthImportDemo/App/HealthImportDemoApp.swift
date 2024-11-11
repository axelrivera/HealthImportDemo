//
//  HealthImportDemoApp.swift
//  HealthImportDemo
//
//  Created by Axel Rivera on 11/9/24.
//

import SwiftUI

@main
struct HealthImportDemoApp: App {
    let healthStore = HealthStore()
    @State var model = Model()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
    }
}
