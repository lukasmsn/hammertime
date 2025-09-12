//
//  ContentView.swift
//  hammertime
//
//  Created by Lukas Maschmann on 9/11/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]

    var body: some View {
        NavigationStack {
            List {
                ForEach(workouts) { w in
                    NavigationLink(value: w) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(w.name).font(.headline)
                            Text(w.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Workouts")
            .navigationDestination(for: Workout.self) { workout in
                WorkoutDetailView(workout: workout)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button(action: addSample) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle().fill(
                            LinearGradient(colors: [.orange.opacity(0.95), .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    )
                    .shadow(color: .orange.opacity(0.35), radius: 16, x: 0, y: 10)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 24)
        }
    }

    private func addSample() {
        let workout = Workout(startedAt: .now, name: "Sample Workout")
        let exercise = Exercise(name: "Bench Press", position: 1, workout: workout)
        let set1 = SetEntry(setNumber: 1, weightKg: 60, reps: 8, exercise: exercise)
        exercise.sets = [set1]
        workout.exercises = [exercise]
        context.insert(workout)
        try? context.save()
    }
}

#Preview {
    ContentView()
}
