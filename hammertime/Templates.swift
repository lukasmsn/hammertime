//
//  Templates.swift
//  hammertime
//

import Foundation
import SwiftData

enum TemplatesService {
    static func buildTemplatesFromHistory(context: ModelContext) throws {
        // One template per workout title, taking the MOST RECENT instance's exercise order
        let all = try context.fetch(FetchDescriptor<Workout>(sortBy: [SortDescriptor(\Workout.startedAt, order: .reverse)]))
        var mostRecentByName: [String: Workout] = [:]
        for w in all {
            if mostRecentByName[w.name] == nil { mostRecentByName[w.name] = w }
        }

        for (name, w) in mostRecentByName {
            // Skip if template exists
            var tdesc = FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { $0.name == name })
            tdesc.fetchLimit = 1
            if let existing = try? context.fetch(tdesc), existing.isEmpty == false { continue }

            let exercises = w.exercises
                .sorted { $0.position < $1.position }
                .map { $0.name }
                .filter { $0.caseInsensitiveCompare("Rest Timer") != .orderedSame }
            if exercises.isEmpty { continue }

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

    static func upsertTemplates(context: ModelContext, names: [String], includeCardio: Bool = true) throws {
        let all = try context.fetch(FetchDescriptor<Workout>(sortBy: [SortDescriptor(\Workout.startedAt, order: .reverse)]))
        let excludeNames: Set<String> = ["Rest Timer"]
        func isCardio(_ name: String) -> Bool {
            let n = name.lowercased()
            return n.contains("elliptical") || n.contains("bike") || n.contains("cycling") || (n.contains("row") && !n.contains("seated row")) || n.contains("run")
        }

        for title in names {
            guard let w = all.first(where: { $0.name.caseInsensitiveCompare(title) == .orderedSame }) else { continue }
            var exNames = w.exercises.sorted { $0.position < $1.position }.map { $0.name }.filter { !excludeNames.contains($0) }
            if !includeCardio { exNames = exNames.filter { !isCardio($0) } }
            if exNames.isEmpty { continue }

            var tdesc = FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { $0.name == title })
            tdesc.fetchLimit = 1
            let existing = try context.fetch(tdesc).first
            let tmpl = existing ?? WorkoutTemplate(name: title)
            if existing == nil { context.insert(tmpl) }

            // remove old exercises
            for te in tmpl.exercises { context.delete(te) }
            tmpl.exercises.removeAll(keepingCapacity: false)

            for (idx, exName) in exNames.enumerated() {
                let te = TemplateExercise(name: exName, position: idx + 1, template: tmpl)
                tmpl.exercises.append(te)
                context.insert(te)
            }
        }

        try context.save()
    }

    static func upsertHardcodedPPLTemplates(context: ModelContext, includeCardio: Bool = true) throws {
        // Hard-coded exercise lists per template title
        var templates: [String: [String]] = [
            "Push A": [
                "Elliptical Machine",
                "Bench Press (Barbell)",
                "Overhead Press (Dumbbell)",
                "Triceps Dip (Assisted)",
                "Chest Fly (Dumbbell)",
                "Triceps Extension",
                "Lateral Raise (Dumbbell)"
            ],
            "Push B": [
                "Elliptical Machine",
                "Incline Bench Press (Barbell)",
                "Overhead Press (Dumbbell)",
                "Bench Press - Close Grip (Barbell)",
                "Triceps Pushdown (Cable - Straight Bar)",
                "Chest Fly (Dumbbell)",
                "Lateral Raise (Dumbbell)"
            ],
            "Pull A": [
                "Elliptical Machine",
                "Deadlift (Barbell)",
                "Chin Up (Assisted)",
                "Shrug (Dumbbell)",
                "Seated Row (Cable)",
                "Bicep Curl (Dumbbell)",
                "Reverse Fly (Machine)",
                "Hanging Leg Raise"
            ],
            "Pull B": [
                "Elliptical Machine",
                "Snatch Grip Deadlift",
                "Bent Over Row (Barbell)",
                "Seated Row (Cable)",
                "Pull Up (Assisted)",
                "Reverse Fly (Dumbbell)",
                "Zottman Curl",
                "Hanging Leg Raise"
            ],
            "Legs A": [
                "Cycling (Indoor)",
                "Squat (Barbell)",
                "Good Morning (Barbell)",
                "Leg Press",
                "Back Extension",
                "Seated Leg Curl (Machine)",
                "Standing Calf Raise (Machine)"
            ],
            "Legs B": [
                "Elliptical Machine",
                "Front Squat (Barbell)",
                "Romanian Deadlift (Barbell)",
                "Back Extension",
                "Lunge (Dumbbell)",
                "Leg Extension (Machine)",
                "Hanging Leg Raise"
            ]
        ]

        if includeCardio == false {
            for (k, v) in templates {
                if let first = v.first, first.lowercased().contains("elliptical") || first.lowercased().contains("cycling") || first.lowercased().contains("run") {
                    templates[k] = Array(v.dropFirst())
                }
            }
        }

        for (title, exercises) in templates {
            var tdesc = FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { $0.name == title })
            tdesc.fetchLimit = 1
            let existing = try context.fetch(tdesc).first
            let tmpl = existing ?? WorkoutTemplate(name: title, isSeed: true)
            if existing == nil { context.insert(tmpl) }

            // remove old exercises
            for te in tmpl.exercises { context.delete(te) }
            tmpl.exercises.removeAll(keepingCapacity: false)

            for (idx, exName) in exercises.enumerated() {
                let te = TemplateExercise(name: exName, position: idx + 1, template: tmpl)
                tmpl.exercises.append(te)
                context.insert(te)
            }
        }

        try context.save()
    }
}


