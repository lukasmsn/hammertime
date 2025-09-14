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
    @State private var path = NavigationPath()
    @State private var showTemplates = false
    @State private var showingDeleteAlert = false
    @State private var workoutPendingDelete: Workout?
    @AppStorage("showSeedData") private var showSeedData = true

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if workouts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 44, weight: .regular))
                            .foregroundStyle(.secondary)
                        Text("No workouts yet")
                            .font(.title3.weight(.semibold))
                        Text("Start by adding your first workout.")
                            .foregroundStyle(.secondary)
                        Button {
                            startBlankWorkout()
                        } label: {
                            Label("Add Workout", systemImage: "plus")
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(workouts.filter { showSeedData || !$0.isSeed }) { w in
                            NavigationLink(value: w) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(titleFor(w)).font(.headline)
                                    Text(statusLine(for: w))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    workoutPendingDelete = w
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workouts")
            .navigationDestination(for: Workout.self) { workout in
                if workout.finishedAt != nil {
                    FinishedWorkoutView(workout: workout)
                } else {
                    InWorkoutView(workout: workout)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Templates") { showTemplates = true }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(showSeedData ? "Hide Seed" : "Show Seed") { showSeedData.toggle() }
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button(action: { startBlankWorkout() }) {
                Label(systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.trailing, 20)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showTemplates) {
            NavigationStack { TemplatesView(onStart: { template in startFromTemplate(template) }) }
                .presentationDetents([.medium, .large])
        }
        .alert("Delete workout?", isPresented: $showingDeleteAlert, presenting: workoutPendingDelete) { workout in
            Button("Delete", role: .destructive) { deleteWorkout(workout) }
            Button("Cancel", role: .cancel) { }
        } message: { _ in
            Text("This will remove all exercises and sets.")
        }
    }

    private func statusLine(for w: Workout) -> String {
        if let finished = w.finishedAt, let dur = w.durationSeconds {
            return "Finished • " + finished.formatted(date: .abbreviated, time: .shortened) + " • " + formatDuration(dur)
        } else {
            return "In Progress • " + w.startedAt.formatted(date: .abbreviated, time: .shortened)
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    private func startBlankWorkout() {
        let workout = Workout(startedAt: .now, name: "")
        context.insert(workout)
        try? context.save()
        DispatchQueue.main.async { path.append(workout) }
    }

    private func titleFor(_ w: Workout) -> String {
        if let first = w.exercises.sorted(by: { $0.position < $1.position }).first?.name, !first.isEmpty {
            return first
        }
        return w.name.isEmpty ? "Workout" : w.name
    }

    private func startFromTemplate(_ template: WorkoutTemplate) {
        let workout = TemplatesService.instantiate(template)
        context.insert(workout)
        try? context.save()
        showTemplates = false
        DispatchQueue.main.async { path.append(workout) }
    }

    private func deleteWorkout(_ workout: Workout) {
        context.delete(workout)
        try? context.save()
        workoutPendingDelete = nil
    }
}

#Preview {
    ContentView()
}
