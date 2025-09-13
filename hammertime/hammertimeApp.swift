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
            RootView()
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
        Message.self,
        WorkoutTemplate.self,
        TemplateExercise.self
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
        return try ModelContainer(for: schema, configurations: configuration)
    } catch {
        #if DEBUG
        print("[SwiftData] Persistent store init failed (\(error)). Falling back to in-memory store for DEBUG.")
        #endif
        let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: memConfig)
        } catch {
            fatalError("Failed to initialize ModelContainer (in-memory fallback also failed): \(error)")
        }
    }
}()

// Root with tabs (Workouts, Chat)
struct RootView: View {
    @Environment(\.modelContext) private var context
    @State private var didSeed = false
    @AppStorage("showSeedData") private var showSeedData = true
    var body: some View {
        TabView {
            NavigationStack { ContentView() }
                .tabItem { Label("Workouts", systemImage: "list.bullet") }
            NavigationStack { ChatView() }
                .tabItem { Label("Chat", systemImage: "message.fill") }
        }
        .task {
            guard !didSeed else { return }
            NotificationManager.requestAuthorization()
            do {
                try SeedData.seedIfNeeded(context: context)
            } catch {
                #if DEBUG
                print("[Seed] Error: \(error)")
                #endif
            }
            didSeed = true
        }
    }
}

enum SeedError: Error { case alreadySeeded }

enum SeedData {
    static func seedIfNeeded(context: ModelContext) throws {
        var descriptor = FetchDescriptor<Workout>()
        descriptor.fetchLimit = 1
        let anyExisting = try? context.fetch(descriptor)
        if let anyExisting, anyExisting.isEmpty == false { throw SeedError.alreadySeeded }
        try seed(context: context)
    }

    static func seed(context: ModelContext) throws {
        let baseTz = TimeZone(secondsFromGMT: 0) ?? .gmt
        let cal = Calendar(identifier: .iso8601)
        func date(_ y: Int,_ m: Int,_ d: Int,_ h: Int = 18,_ min: Int = 0) -> Date {
            var comps = DateComponents()
            comps.calendar = cal
            comps.timeZone = baseTz
            comps.year = y
            comps.month = m
            comps.day = d
            comps.hour = h
            comps.minute = min
            return comps.date ?? .now
        }

        struct BWEntry { let date: Date; let kg: Double; let sleep: Double }

        let entries: [(Date,String,Int?,String?,Double?,Double?,[(String,Int,[(Int,Double?,Int?,Double?,Double?,Int?,String?,Bool)])])] = [
            // 2025-01-06 Lower A (Baseline)
            (date(2025,1,6), "Lower A (Baseline)", 3600, "Sleep 7h. Beginner baseline.", 79.5, 7.0, [
                ("Back Squat", 1, [ (1,60,8,6.5,nil,nil,nil,true), (2,60,8,7,nil,nil,nil,true), (3,60,8,7,nil,nil,nil,true) ]),
                ("Romanian Deadlift", 2, [ (1,70,8,6,nil,nil,nil,true), (2,70,8,6.5,nil,nil,nil,true) ]),
                ("Run (Easy)", 3, [ (1,nil,nil,5,2500.0,900,nil,true) ])
            ]),
            // 2025-01-09 Upper A (Baseline)
            (date(2025,1,9), "Upper A (Baseline)", 3300, "Good energy.", 79.4, 7.5, [
                ("Bench Press", 1, [ (1,40,8,6,nil,nil,nil,true), (2,40,8,6.5,nil,nil,nil,true), (3,40,8,7,nil,nil,nil,true) ]),
                ("Barbell Row", 2, [ (1,50,8,6.5,nil,nil,nil,true), (2,50,8,7,nil,nil,nil,true) ]),
                ("Overhead Press", 3, [ (1,25,8,6,nil,nil,nil,true), (2,25,8,6.5,nil,nil,nil,true) ])
            ]),
            // 2025-02-03 Lower A (LP W4)
            (date(2025,2,3), "Lower A (LP W4)", 3600, "Linear progression steady.", 78.8, 7.2, [
                ("Back Squat", 1, [ (1,80,8,7,nil,nil,nil,true), (2,80,8,7.5,nil,nil,nil,true), (3,80,8,8,nil,nil,nil,true) ]),
                ("Deadlift", 2, [ (1,100,5,7,nil,nil,nil,true), (2,100,5,7.5,nil,nil,nil,true) ]),
                ("Bike (Zone 2)", 3, [ (1,nil,nil,5,nil,1200,nil,true) ])
            ]),
            // 2025-02-06 Upper A (LP W4)
            (date(2025,2,6), "Upper A (LP W4)", 3300, "Slight triceps fatigue.", 78.7, 7.0, [
                ("Bench Press", 1, [ (1,55,8,7,nil,nil,nil,true), (2,55,8,7.5,nil,nil,nil,true), (3,55,8,8,nil,nil,nil,true) ]),
                ("Overhead Press", 2, [ (1,35,8,7,nil,nil,nil,true), (2,35,8,7.5,nil,nil,nil,true) ]),
                ("Pull-ups", 3, [ (1,nil,6,7,nil,nil,nil,true), (2,nil,5,7.5,nil,nil,nil,true), (3,nil,5,8,nil,nil,nil,true) ])
            ]),
            // 2025-03-03 Lower A (LP W8)
            (date(2025,3,3), "Lower A (LP W8)", 3720, "Squat moving well.", 78.5, 7.4, [
                ("Back Squat", 1, [ (1,95,8,7,nil,nil,nil,true), (2,95,8,7.5,nil,nil,nil,true), (3,95,8,8,nil,nil,nil,true) ]),
                ("Deadlift", 2, [ (1,125,5,7.5,nil,nil,nil,true), (2,125,5,8,nil,nil,nil,true) ])
            ]),
            // 2025-03-06 Upper A (LP W8)
            (date(2025,3,6), "Upper A (LP W8)", 3450, "Bench steady, OHP improving.", 78.6, 7.3, [
                ("Bench Press", 1, [ (1,67.5,6,7.5,nil,nil,nil,true), (2,67.5,6,8,nil,nil,nil,true), (3,67.5,6,8.5,nil,nil,nil,true) ]),
                ("Overhead Press", 2, [ (1,42.5,6,7.5,nil,nil,nil,true), (2,42.5,6,8,nil,nil,nil,true) ])
            ]),
            // 2025-03-17 Deload (W9)
            (date(2025,3,17), "Deload (W9)", 3000, "Deload week: -30% load, keep movement quality.", 78.7, 7.9, [
                ("Back Squat", 1, [ (1,67.5,5,5.5,nil,nil,nil,true), (2,67.5,5,5.5,nil,nil,nil,true) ]),
                ("Bench Press", 2, [ (1,47.5,5,5.5,nil,nil,nil,true), (2,47.5,5,5.5,nil,nil,nil,true) ]),
                ("Run (Easy)", 3, [ (1,nil,nil,5,3000.0,1080,nil,true) ])
            ]),
            // 2025-04-07 Lower A (Block 2 W3)
            (date(2025,4,7), "Lower A (Block 2 W3)", 3720, "Transition to 5s, heavier loads.", 78.2, 7.2, [
                ("Back Squat", 1, [ (1,110,5,7,nil,nil,nil,true), (2,110,5,7.5,nil,nil,nil,true), (3,110,5,8,nil,nil,nil,true) ]),
                ("Deadlift", 2, [ (1,150,3,7.5,nil,nil,nil,true), (2,150,3,8,nil,nil,nil,true) ])
            ]),
            // 2025-04-10 Upper A (Block 2 W3)
            (date(2025,4,10), "Upper A (Block 2 W3)", 3480, "Bench 5s, OHP 6s.", 78.1, 7.1, [
                ("Bench Press", 1, [ (1,75,5,7.5,nil,nil,nil,true), (2,75,5,8,nil,nil,nil,true), (3,75,5,8.5,nil,nil,nil,true) ]),
                ("Overhead Press", 2, [ (1,47.5,6,7.5,nil,nil,nil,true), (2,47.5,6,8,nil,nil,nil,true) ])
            ]),
            // 2025-05-05 Lower A (Block 2 W7)
            (date(2025,5,5), "Lower A (Block 2 W7)", 3780, "Small back tweak on deadlift, reduced volume.", 78.3, 7.0, [
                ("Back Squat", 1, [ (1,120,5,7.5,nil,nil,nil,true), (2,120,5,8,nil,nil,nil,true), (3,120,5,8.5,nil,nil,nil,true) ]),
                ("Deadlift", 2, [ (1,160,2,8.5,nil,nil,"Stopped early due to tightness",true) ])
            ]),
            // 2025-05-08 Upper A (Recovery)
            (date(2025,5,8), "Upper A (Recovery)", 3300, "Back tightness – kept arch modest on bench.", 78.4, 7.6, [
                ("Bench Press", 1, [ (1,80,5,7.5,nil,nil,nil,true), (2,80,5,8,nil,nil,nil,true) ]),
                ("Overhead Press", 2, [ (1,50,5,7.5,nil,nil,nil,true), (2,50,5,8,nil,nil,nil,true) ]),
                ("Bike (Zone 2)", 3, [ (1,nil,nil,5,nil,1200,nil,true) ])
            ]),
            // 2025-06-09 Lower A (Peak W3)
            (date(2025,6,9), "Lower A (Peak W3)", 3960, "Peak singles practice.", 78.0, 7.3, [
                ("Back Squat", 1, [ (1,135,3,8.5,nil,nil,nil,true) ]),
                ("Deadlift", 2, [ (1,175,1,8.5,nil,nil,nil,true) ])
            ]),
            // 2025-06-12 Upper A (Peak W3)
            (date(2025,6,12), "Upper A (Peak W3)", 3600, "Taper volume, keep intensity.", 77.9, 7.5, [
                ("Bench Press", 1, [ (1,92.5,1,8.5,nil,nil,nil,true) ]),
                ("Overhead Press", 2, [ (1,60,3,8.5,nil,nil,nil,true) ])
            ]),
            // 2025-06-28 Test Day
            (date(2025,6,28,10,0), "Test Day", 4500, "PRs across the board.", 77.8, 7.8, [
                ("Back Squat", 1, [ (1,150,1,9,nil,nil,nil,true) ]),
                ("Bench Press", 2, [ (1,95,1,9,nil,nil,nil,true) ]),
                ("Deadlift", 3, [ (1,180,1,9,nil,nil,nil,true) ])
            ])
        ]

        for entry in entries {
            let started = entry.0
            let duration = entry.2
            let finished = duration.map { started.addingTimeInterval(TimeInterval($0)) }
            let w = Workout(startedAt: started, name: entry.1, finishedAt: finished, durationSeconds: duration, notes: entry.3, bodyWeightKg: entry.4, sleepHours: entry.5, isSeed: true)
            context.insert(w)
            var posAcc = 0
            for exTuple in entry.6 {
                posAcc += 1
                let ex = Exercise(name: exTuple.0, position: exTuple.1, workout: w)
                w.exercises.append(ex)
                context.insert(ex)
                for setT in exTuple.2 {
                    let s = SetEntry(setNumber: setT.0, weightKg: setT.1, reps: setT.2, distanceM: setT.4, seconds: setT.5, rpe: setT.3, notes: setT.6, exercise: ex, isLogged: setT.7)
                    ex.sets.append(s)
                    context.insert(s)
                }
            }
        }

        try context.save()
        // Hard-code six core templates
        try? TemplatesService.upsertHardcodedPPLTemplates(context: context, includeCardio: true)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Workout.self, Exercise.self, SetEntry.self, Message.self, configurations: config)
    return RootView().modelContainer(container)
}
