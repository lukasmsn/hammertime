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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Exercise name", text: Binding(get: { ex.name }, set: { ex.name = $0 }))
                                .font(.headline)
                            Spacer()
                            Button(action: { addSet(to: ex) }) {
                                Label("Add Set", systemImage: "plus")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.borderless)
                        }

                        if !ex.sets.isEmpty {
                            ForEach(ex.sets.sorted { $0.setNumber < $1.setNumber }) { s in
                                HStack(spacing: 12) {
                                    Text("#\(s.setNumber)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    HStack(spacing: 6) {
                                        TextField(
                                            "0",
                                            value: Binding<Double>(
                                                get: { s.weightKg ?? 0 },
                                                set: { s.weightKg = $0 }
                                            ),
                                            format: .number
                                        )
                                        .keyboardType(.decimalPad)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(Color.gray.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .frame(width: 80)

                                        Text("kg")
                                            .foregroundStyle(.secondary)
                                    }

                                    Text("x")
                                        .foregroundStyle(.secondary)

                                    TextField(
                                        "0",
                                        value: Binding<Int>(
                                            get: { s.reps ?? 0 },
                                            set: { s.reps = $0 }
                                        ),
                                        format: .number
                                    )
                                    .keyboardType(.numberPad)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(Color.gray.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .frame(width: 60)

                                    Spacer()

                                    Button {
                                        s.isLogged.toggle()
                                        try? context.save()
                                    } label: {
                                        Image(systemName: s.isLogged ? "checkmark.seal.fill" : "checkmark.circle.fill")
                                            .foregroundStyle(s.isLogged ? .green : .blue)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) { deleteSet(s) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
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

    private func setLine(_ s: SetEntry) -> String {
        var parts: [String] = []
        if let w = s.weightKg { parts.append("\(Int(w)) kg") }
        if let r = s.reps { parts.append("x\(r)") }
        if let sec = s.seconds, sec > 0 { parts.append("\(sec)s") }
        if let d = s.distanceM, d > 0 { parts.append("\(Int(d)) m") }
        return parts.joined(separator: " ")
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

    private func addSet(to ex: Exercise) {
        let next = (ex.sets.map { $0.setNumber }.max() ?? 0) + 1
        let s = SetEntry(setNumber: next, weightKg: 60, reps: 8, exercise: ex)
        ex.sets.append(s)
        context.insert(s)
        try? context.save()
    }

    private func deleteSet(_ s: SetEntry) {
        context.delete(s)
        try? context.save()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Workout.self, Exercise.self, SetEntry.self, Message.self, configurations: config)
    let w = Workout(startedAt: .now, name: "Preview Workout")
    WorkoutDetailView(workout: w)
        .modelContainer(container)
}


