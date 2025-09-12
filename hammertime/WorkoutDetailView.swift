//
//  WorkoutDetailView.swift
//  hammertime
//

import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var context
    @State var workout: Workout

    var body: some View {
        List {
            Section(header: Text("Exercises")) {
                ForEach(sortedExercises) { ex in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(ex.name).font(.headline)
                        if !ex.sets.isEmpty {
                            Text(setsLine(for: ex))
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                    }
                }
                .onDelete(perform: deleteExercise)

                Button(action: addExercise) {
                    Label("Add Exercise", systemImage: "plus")
                }
            }
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sortedExercises: [Exercise] {
        workout.exercises.sorted { $0.position < $1.position }
    }

    private func setsLine(for ex: Exercise) -> String {
        let sorted = ex.sets.sorted { $0.setNumber < $1.setNumber }
        return sorted.map { s in
            let w = s.weightKg.map { String(format: "%.0f", $0) } ?? "-"
            let r = s.reps.map { String($0) } ?? "-"
            return "\(w)x\(r)"
        }.joined(separator: ", ")
    }

    private func addExercise() {
        let nextPos = (workout.exercises.map { $0.position }.max() ?? 0) + 1
        let ex = Exercise(name: "New Exercise", position: nextPos, workout: workout)
        workout.exercises.append(ex)
        context.insert(ex)
        try? context.save()
    }

    private func deleteExercise(_ offsets: IndexSet) {
        let toDelete = offsets.map { sortedExercises[$0] }
        toDelete.forEach { context.delete($0) }
        try? context.save()
    }
}

#Preview {
    let container = try! ModelContainer(for: Workout.self, Exercise.self, SetEntry.self, Message.self)
    let w = Workout(startedAt: .now, name: "Preview Workout")
    WorkoutDetailView(workout: w)
        .modelContainer(container)
}


