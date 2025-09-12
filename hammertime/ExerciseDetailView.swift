//
//  ExerciseDetailView.swift
//  hammertime
//

import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    @Environment(\.modelContext) private var context
    @State var exercise: Exercise

    var body: some View {
        List {
            Section(header: Text("Sets")) {
                ForEach(sortedSets) { s in
                    HStack {
                        Text("#\(s.setNumber)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(setLine(s))
                            .font(.body)
                    }
                }
                .onDelete(perform: deleteSets)

                Button(action: addSet) {
                    Label("Add Set", systemImage: "plus")
                }
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sortedSets: [SetEntry] {
        exercise.sets.sorted { $0.setNumber < $1.setNumber }
    }

    private func setLine(_ s: SetEntry) -> String {
        var parts: [String] = []
        if let w = s.weightKg { parts.append("\(Int(w)) kg") }
        if let r = s.reps { parts.append("x\(r)") }
        if let sec = s.seconds, sec > 0 { parts.append("\(sec)s") }
        if let d = s.distanceM, d > 0 { parts.append("\(Int(d)) m") }
        return parts.joined(separator: " ")
    }

    private func addSet() {
        let next = (exercise.sets.map { $0.setNumber }.max() ?? 0) + 1
        let set = SetEntry(setNumber: next, weightKg: 60, reps: 8, exercise: exercise)
        exercise.sets.append(set)
        context.insert(set)
        try? context.save()
    }

    private func deleteSets(_ offsets: IndexSet) {
        let toDelete = offsets.map { sortedSets[$0] }
        toDelete.forEach { context.delete($0) }
        try? context.save()
    }
}

#Preview {
    let container = try! ModelContainer(for: Workout.self, Exercise.self, SetEntry.self, Message.self)
    let w = Workout(startedAt: .now, name: "Preview")
    let e = Exercise(name: "Bench Press", position: 1, workout: w)
    return ExerciseDetailView(exercise: e).modelContainer(container)
}


