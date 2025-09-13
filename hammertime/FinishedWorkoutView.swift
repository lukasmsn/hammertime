//
//  FinishedWorkoutView.swift
//  hammertime
//

import SwiftUI
import SwiftData

struct FinishedWorkoutView: View {
    @Environment(\.modelContext) private var context
    @State var workout: Workout

    var body: some View {
        List {
            Section("Summary") {
                HStack {
                    Label("When", systemImage: "calendar")
                    Spacer()
                    Text(workout.finishedAt?.formatted(date: .abbreviated, time: .shortened) ?? "–")
                        .foregroundStyle(.secondary)
                }
                if let dur = workout.durationSeconds {
                    HStack {
                        Label("Duration", systemImage: "clock")
                        Spacer()
                        Text(formatDuration(dur)).foregroundStyle(.secondary)
                    }
                }
                if let notes = workout.notes, !notes.isEmpty {
                    Text(notes).font(.body)
                }
            }

            Section("Exercises") {
                ForEach(workout.exercises.sorted { $0.position < $1.position }) { ex in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(ex.name).font(.headline)
                        ForEach(ex.sets.sorted { $0.setNumber < $1.setNumber }) { s in
                            Text(setLine(s)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(workout.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("Edit") { WorkoutDetailView(workout: workout) }
            }
        }
    }

    private func setLine(_ s: SetEntry) -> String {
        var parts: [String] = []
        if let w = s.weightKg { parts.append("\(Int(round(w * 2.20462))) lb") }
        if let r = s.reps { parts.append("x\(r)") }
        return parts.joined(separator: " ")
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}


