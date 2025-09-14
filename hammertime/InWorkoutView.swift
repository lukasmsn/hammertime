//
//  InWorkoutView.swift
//  hammertime
//

import SwiftUI
import SwiftData

struct InWorkoutView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State var workout: Workout

    var body: some View {
        VStack(spacing: 12) {
            Text("In Workout")
                .font(.title3.weight(.semibold))
            Text(workout.name.isEmpty ? "Workout" : workout.name)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Workout.self, Exercise.self, SetEntry.self, Message.self, configurations: config)
    let w = Workout(startedAt: .now, name: "Pull Day")
    return InWorkoutView(workout: w)
        .modelContainer(container)
}


