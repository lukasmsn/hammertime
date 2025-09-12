//
//  Models.swift
//  hammertime
//
//  SwiftData model definitions for local storage
//

import Foundation
import SwiftData

@Model
final class Workout {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var name: String
    var durationSeconds: Int?
    var notes: String?
    @Relationship(deleteRule: .cascade) var exercises: [Exercise]

    init(id: UUID = UUID(), startedAt: Date, name: String, durationSeconds: Int? = nil, notes: String? = nil, exercises: [Exercise] = []) {
        self.id = id
        self.startedAt = startedAt
        self.name = name
        self.durationSeconds = durationSeconds
        self.notes = notes
        self.exercises = exercises
    }
}

@Model
final class Exercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var position: Int
    var notes: String?
    var workout: Workout?
    @Relationship(deleteRule: .cascade) var sets: [SetEntry]

    init(id: UUID = UUID(), name: String, position: Int, notes: String? = nil, workout: Workout? = nil, sets: [SetEntry] = []) {
        self.id = id
        self.name = name
        self.position = position
        self.notes = notes
        self.workout = workout
        self.sets = sets
    }
}

@Model
final class SetEntry {
    @Attribute(.unique) var id: UUID
    var setNumber: Int
    var weightKg: Double?
    var reps: Int?
    var distanceM: Double?
    var seconds: Int?
    var rpe: Double?
    var notes: String?
    var exercise: Exercise?

    init(id: UUID = UUID(), setNumber: Int, weightKg: Double? = nil, reps: Int? = nil, distanceM: Double? = nil, seconds: Int? = nil, rpe: Double? = nil, notes: String? = nil, exercise: Exercise? = nil) {
        self.id = id
        self.setNumber = setNumber
        self.weightKg = weightKg
        self.reps = reps
        self.distanceM = distanceM
        self.seconds = seconds
        self.rpe = rpe
        self.notes = notes
        self.exercise = exercise
    }
}

@Model
final class Message {
    @Attribute(.unique) var id: UUID
    var role: String
    var content: String
    var createdAt: Date

    init(id: UUID = UUID(), role: String, content: String, createdAt: Date = .now) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}


