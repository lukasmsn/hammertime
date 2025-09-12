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

    static var all: [String] { Array(Set(push + pull + legs + cardio)).sorted() }
}


