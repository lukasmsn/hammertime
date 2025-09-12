//
//  Templates.swift
//  hammertime
//

import Foundation
import SwiftData

enum TemplatesService {
    static func buildTemplatesFromHistory(context: ModelContext) throws {
        // Group workouts by name and extract ordered unique exercise names
        let workouts = try context.fetch(FetchDescriptor<Workout>(sortBy: [SortDescriptor(\Workout.startedAt, order: .forward)]))
        var nameToExercises: [String: [String]] = [:]
        for w in workouts {
            let names = w.exercises.sorted { $0.position < $1.position }.map { $0.name }
            if names.isEmpty { continue }
            if var arr = nameToExercises[w.name] {
                for n in names where !arr.contains(n) { arr.append(n) }
                nameToExercises[w.name] = arr
            } else {
                nameToExercises[w.name] = names
            }
        }

        for (name, exercises) in nameToExercises {
            // Skip if template exists
            var descriptor = FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { $0.name == name })
            descriptor.fetchLimit = 1
            if let existing = try? context.fetch(descriptor), existing.isEmpty == false { continue }

            let tmpl = WorkoutTemplate(name: name, isSeed: true)
            context.insert(tmpl)
            for (idx, exName) in exercises.enumerated() {
                let te = TemplateExercise(name: exName, position: idx + 1, template: tmpl)
                tmpl.exercises.append(te)
                context.insert(te)
            }
        }

        try context.save()
    }

    static func instantiate(_ template: WorkoutTemplate, date: Date = .now) -> Workout {
        let w = Workout(startedAt: date, name: template.name)
        for te in template.exercises.sorted(by: { $0.position < $1.position }) {
            let ex = Exercise(name: te.name, position: te.position, workout: w)
            w.exercises.append(ex)
        }
        return w
    }
}


