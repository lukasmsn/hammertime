//
//  ExerciseLibrary.swift
//  hammertime
//

import Foundation

enum ExerciseLibrary {
    static let push = [
        "Bench Press",
        "Incline Bench Press",
        "Overhead Press",
        "Dumbbell Bench Press",
        "Dips"
    ]
    static let pull = [
        "Barbell Row",
        "Pull-ups",
        "Lat Pulldown",
        "Seated Row"
    ]
    static let legs = [
        "Back Squat",
        "Front Squat",
        "Romanian Deadlift",
        "Deadlift",
        "Leg Press"
    ]
    static let cardio = [
        "Run (Easy)",
        "Run (Tempo)",
        "Bike (Zone 2)",
        "Elliptical Machine"
    ]

    // Additional exercises used in hardcoded templates (TemplatesService.upsertHardcodedPPLTemplates)
    static let templates = [
        // Push A
        "Elliptical Machine",
        "Bench Press (Barbell)",
        "Overhead Press (Dumbbell)",
        "Triceps Dip (Assisted)",
        "Chest Fly (Dumbbell)",
        "Triceps Extension",
        "Lateral Raise (Dumbbell)",
        // Push B
        "Incline Bench Press (Barbell)",
        "Bench Press - Close Grip (Barbell)",
        "Triceps Pushdown (Cable - Straight Bar)",
        // Pull A
        "Deadlift (Barbell)",
        "Chin Up (Assisted)",
        "Shrug (Dumbbell)",
        "Seated Row (Cable)",
        "Bicep Curl (Dumbbell)",
        "Reverse Fly (Machine)",
        "Hanging Leg Raise",
        // Pull B
        "Snatch Grip Deadlift",
        "Bent Over Row (Barbell)",
        "Pull Up (Assisted)",
        "Reverse Fly (Dumbbell)",
        "Zottman Curl",
        // Legs A
        "Cycling (Indoor)",
        "Squat (Barbell)",
        "Good Morning (Barbell)",
        "Leg Press",
        "Back Extension",
        "Seated Leg Curl (Machine)",
        "Standing Calf Raise (Machine)",
        // Legs B
        "Front Squat (Barbell)",
        "Romanian Deadlift (Barbell)",
        "Lunge (Dumbbell)",
        "Leg Extension (Machine)"
    ]

    static var all: [String] { Array(Set(push + pull + legs + cardio + templates)).sorted() }
}


