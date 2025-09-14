//
//  SupabaseService.swift
//  hammertime
//
//  Minimal PostgREST client for syncing workouts without auth (MVP).
//

import Foundation
import SwiftData
import UIKit

enum SupabaseError: Error { case missingConfig, http(status: Int, body: String?), decode, encode }

final class SupabaseService {
    static let shared = SupabaseService()
    private init() {}

    private var baseUrl: String? {
        let info = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String
        let env = ProcessInfo.processInfo.environment["SUPABASE_URL"]
        let plist = SecretsLoader.shared.value(for: "SUPABASE_URL")
        let val = (info?.isEmpty == false ? info : nil) ?? (env?.isEmpty == false ? env : nil) ?? (plist?.isEmpty == false ? plist : nil)
        #if DEBUG
        if let info, !info.isEmpty { print("[Supabase] Found URL in Info.plist (len=\(info.count))") }
        if let env, !env.isEmpty { print("[Supabase] Found URL in ENV (len=\(env.count))") }
        if let plist, !plist.isEmpty { print("[Supabase] Found URL in AppSecrets.plist (len=\(plist.count))") }
        #endif
        return val
    }
    private var anonKey: String? {
        let info = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String
        let env = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]
        let plist = SecretsLoader.shared.value(for: "SUPABASE_ANON_KEY")
        let val = (info?.isEmpty == false ? info : nil) ?? (env?.isEmpty == false ? env : nil) ?? (plist?.isEmpty == false ? plist : nil)
        #if DEBUG
        if let info, !info.isEmpty { print("[Supabase] Found anon key in Info.plist (len=\(info.count))") }
        if let env, !env.isEmpty { print("[Supabase] Found anon key in ENV (len=\(env.count))") }
        if let plist, !plist.isEmpty { print("[Supabase] Found anon key in AppSecrets.plist (len=\(plist.count))") }
        #endif
        return val
    }

    // SecretsLoader is defined in its own file for shared use.

    private var clientId: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }

    // MARK: Public API
    func pullAllAndMergeIntoLocal(context: ModelContext) async {
        guard let urlStr = baseUrl, let key = anonKey, !urlStr.isEmpty, !key.isEmpty else {
            #if DEBUG
            print("[Supabase] Missing config: url=\(baseUrl ?? "nil"), anonKeyLen=\(anonKey?.count ?? 0)")
            #endif
            return
        }
        do {
            async let w = fetchWorkouts()
            async let x = fetchExercises()
            async let s = fetchSets()
            let workouts = try await w
            let exercises = try await x
            let sets = try await s
            try await MainActor.run {
                mergeRemote(workouts: workouts, exercises: exercises, sets: sets, into: context)
                try? context.save()
            }
        } catch {
            #if DEBUG
            print("[Supabase] Pull failed: \(error)")
            #endif
        }
    }

    func pushWorkout(_ workout: Workout) async {
        guard let urlStr = baseUrl, let key = anonKey, !urlStr.isEmpty, !key.isEmpty else {
            #if DEBUG
            print("[Supabase] Missing config on push: url=\(baseUrl ?? "nil"), anonKeyLen=\(anonKey?.count ?? 0)")
            #endif
            return
        }
        let snap = SupabaseService.from(workout: workout, clientId: clientId)
        #if DEBUG
        print("[Supabase] Push begin: base=\(urlStr), workout=\(snap.workout.id), ex=\(snap.exercises.count), sets=\(snap.sets.count)")
        #endif
        do {
            try await upsert(workout: snap.workout)
            for ex in snap.exercises {
                try await upsert(exercise: ex)
            }
            for s in snap.sets {
                try await upsert(set: s)
            }
            #if DEBUG
            print("[Supabase] Push complete for workout \(snap.workout.id)")
            #endif
        } catch {
            #if DEBUG
            print("[Supabase] Push failed: \(error)")
            #endif
        }
    }

    // MARK: DTOs
    struct WorkoutDTO: Codable, Hashable {
        let id: UUID
        let client_id: String
        let started_at: Date
        let finished_at: Date?
        let name: String
        let duration_seconds: Int?
        let notes: String?
        let body_weight_kg: Double?
        let sleep_hours: Double?
        let is_seed: Bool
        static func from(workout: Workout, clientId: String) -> WorkoutDTO {
            WorkoutDTO(
                id: workout.id,
                client_id: clientId,
                started_at: workout.startedAt,
                finished_at: workout.finishedAt,
                name: workout.name,
                duration_seconds: workout.durationSeconds,
                notes: workout.notes,
                body_weight_kg: workout.bodyWeightKg,
                sleep_hours: workout.sleepHours,
                is_seed: workout.isSeed
            )
        }
    }

    struct ExerciseDTO: Codable, Hashable {
        let id: UUID
        let client_id: String
        let workout_id: UUID
        let name: String
        let position: Int
        let notes: String?
        static func from(ex: Exercise, clientId: String, workoutId: UUID) -> ExerciseDTO {
            ExerciseDTO(id: ex.id, client_id: clientId, workout_id: workoutId, name: ex.name, position: ex.position, notes: ex.notes)
        }
    }

    struct SetDTO: Codable, Hashable {
        let id: UUID
        let client_id: String
        let exercise_id: UUID
        let set_number: Int
        let weight_kg: Double?
        let reps: Int?
        let distance_m: Double?
        let seconds: Int?
        let rpe: Double?
        let notes: String?
        let is_logged: Bool
        static func from(set s: SetEntry, clientId: String, exerciseId: UUID) -> SetDTO {
            SetDTO(
                id: s.id,
                client_id: clientId,
                exercise_id: exerciseId,
                set_number: s.setNumber,
                weight_kg: s.weightKg,
                reps: s.reps,
                distance_m: s.distanceM,
                seconds: s.seconds,
                rpe: s.rpe,
                notes: s.notes,
                is_logged: s.isLogged
            )
        }
    }

    struct Snapshot {
        let workout: WorkoutDTO
        let exercises: [ExerciseDTO]
        let sets: [SetDTO]
    }

    static func from(workout: Workout, clientId: String) -> Snapshot {
        let w = WorkoutDTO.from(workout: workout, clientId: clientId)
        var xs: [ExerciseDTO] = []
        var ss: [SetDTO] = []
        for ex in workout.exercises.sorted(by: { $0.position < $1.position }) {
            xs.append(ExerciseDTO.from(ex: ex, clientId: clientId, workoutId: workout.id))
            for s in ex.sets.sorted(by: { $0.setNumber < $1.setNumber }) {
                ss.append(SetDTO.from(set: s, clientId: clientId, exerciseId: ex.id))
            }
        }
        return Snapshot(workout: w, exercises: xs, sets: ss)
    }

    // MARK: Networking
    private func headers() throws -> [String: String] {
        guard let key = anonKey else { throw SupabaseError.missingConfig }
        return [
            "apikey": key,
            "Authorization": "Bearer \(key)",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "Prefer": "resolution=merge-duplicates, return=representation"
        ]
    }

    private func upsert<T: Encodable>(endpoint: String, body: [T]) async throws {
        guard let base = baseUrl, let url = URL(string: base + "/rest/v1/" + endpoint) else { throw SupabaseError.missingConfig }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.allHTTPHeaderFields = try headers()
        req.httpBody = try JSONEncoder.iso8601.encode(body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw SupabaseError.http(status: -1, body: nil) }
        if http.statusCode >= 200 && http.statusCode < 300 {
            #if DEBUG
            if let body = String(data: data, encoding: .utf8) { print("[Supabase] Upsert \(endpoint) OK: \(http.statusCode) body=\(body)") }
            #endif
            return
        }
        #if DEBUG
        print("[Supabase] Upsert \(endpoint) HTTP \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "<no body>")")
        #endif
        throw SupabaseError.http(status: http.statusCode, body: String(data: data, encoding: .utf8))
    }

    private func fetch<T: Decodable>(endpoint: String, query: String) async throws -> [T] {
        guard let base = baseUrl, let url = URL(string: base + "/rest/v1/" + endpoint + query) else { throw SupabaseError.missingConfig }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.allHTTPHeaderFields = try headers()
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw SupabaseError.http(status: -1, body: nil) }
        guard http.statusCode == 200 else { throw SupabaseError.http(status: http.statusCode, body: String(data: data, encoding: .utf8)) }
        return try JSONDecoder.iso8601.decode([T].self, from: data)
    }

    private func upsert(workout: WorkoutDTO) async throws {
        try await upsert(endpoint: "workouts", body: [workout])
    }
    private func upsert(exercise: ExerciseDTO) async throws {
        try await upsert(endpoint: "workout_exercises", body: [exercise])
    }
    private func upsert(set: SetDTO) async throws {
        try await upsert(endpoint: "workout_sets", body: [set])
    }

    private func fetchWorkouts() async throws -> [WorkoutDTO] {
        let q = "?select=*&client_id=eq.\(clientId)&order=started_at.asc"
        return try await fetch(endpoint: "workouts", query: q)
    }
    private func fetchExercises() async throws -> [ExerciseDTO] {
        let q = "?select=*&client_id=eq.\(clientId)&order=position.asc"
        return try await fetch(endpoint: "workout_exercises", query: q)
    }
    private func fetchSets() async throws -> [SetDTO] {
        let q = "?select=*&client_id=eq.\(clientId)&order=set_number.asc"
        return try await fetch(endpoint: "workout_sets", query: q)
    }

    // MARK: Merge
    private func mergeRemote(workouts: [WorkoutDTO], exercises: [ExerciseDTO], sets: [SetDTO], into context: ModelContext) {
        // Workouts
        for rw in workouts {
            var fd = FetchDescriptor<Workout>(predicate: #Predicate { $0.id == rw.id })
            fd.fetchLimit = 1
            let existing = (try? context.fetch(fd))?.first
            let w = existing ?? Workout(id: rw.id, startedAt: rw.started_at, name: rw.name)
            w.startedAt = rw.started_at
            w.finishedAt = rw.finished_at
            w.name = rw.name
            w.durationSeconds = rw.duration_seconds
            w.notes = rw.notes
            w.bodyWeightKg = rw.body_weight_kg
            w.sleepHours = rw.sleep_hours
            w.isSeed = rw.is_seed
            if existing == nil { context.insert(w) }
        }
        // Build workout map
        var workoutById: [UUID: Workout] = [:]
        for rw in workouts {
            var fd = FetchDescriptor<Workout>(predicate: #Predicate { $0.id == rw.id })
            fd.fetchLimit = 1
            if let w = (try? context.fetch(fd))?.first { workoutById[rw.id] = w }
        }
        // Exercises
        for rx in exercises {
            var fd = FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == rx.id })
            fd.fetchLimit = 1
            let existing = (try? context.fetch(fd))?.first
            let parent = workoutById[rx.workout_id]
            let e = existing ?? Exercise(id: rx.id, name: rx.name, position: rx.position, notes: rx.notes, workout: parent)
            e.name = rx.name
            e.position = rx.position
            e.notes = rx.notes
            e.workout = parent
            if existing == nil {
                if let parent { parent.exercises.append(e) }
                context.insert(e)
            }
        }
        // Build exercise map
        var exerciseById: [UUID: Exercise] = [:]
        for rx in exercises {
            var fd = FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == rx.id })
            fd.fetchLimit = 1
            if let e = (try? context.fetch(fd))?.first { exerciseById[rx.id] = e }
        }
        // Sets
        for rs in sets {
            var fd = FetchDescriptor<SetEntry>(predicate: #Predicate { $0.id == rs.id })
            fd.fetchLimit = 1
            let existing = (try? context.fetch(fd))?.first
            let parent = exerciseById[rs.exercise_id]
            let s = existing ?? SetEntry(id: rs.id, setNumber: rs.set_number, weightKg: rs.weight_kg, reps: rs.reps, distanceM: rs.distance_m, seconds: rs.seconds, rpe: rs.rpe, notes: rs.notes, exercise: parent, isLogged: rs.is_logged)
            s.setNumber = rs.set_number
            s.weightKg = rs.weight_kg
            s.reps = rs.reps
            s.distanceM = rs.distance_m
            s.seconds = rs.seconds
            s.rpe = rs.rpe
            s.notes = rs.notes
            s.exercise = parent
            s.isLogged = rs.is_logged
            if existing == nil {
                if let parent { parent.sets.append(s) }
                context.insert(s)
            }
        }
    }
}

// MARK: - JSON Encoder/Decoder helpers
private extension JSONEncoder {
    static var iso8601: JSONEncoder {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return enc
    }
}
private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }
}


