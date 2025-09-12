//
//  hammertimeApp.swift
//  hammertime
//
//  Created by Lukas Maschmann on 9/11/25.
//

import SwiftUI
import SwiftData

@main
struct hammertimeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

// Shared SwiftData container for the app
var sharedModelContainer: ModelContainer = {
    let schema = Schema([
        Workout.self,
        Exercise.self,
        SetEntry.self,
        Message.self
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    do {
        return try ModelContainer(for: schema, configurations: configuration)
    } catch {
        fatalError("Failed to initialize ModelContainer: \(error)")
    }
}()
