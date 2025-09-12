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
    @State private var showCreate = false
    @State private var showTemplates = false
    @State private var nameInput: String = ""
    @State private var dateInput: Date = .now
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
                            showCreate = true
                        } label: {
                            Label("Add Workout", systemImage: "plus")
                                .font(.headline)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(
                                    Capsule().fill(
                                        LinearGradient(colors: [.orange.opacity(0.95), .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                )
                                .foregroundStyle(.white)
                                .shadow(color: .orange.opacity(0.3), radius: 12, x: 0, y: 8)
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(workouts.filter { showSeedData || !$0.isSeed }) { w in
                            NavigationLink(value: w) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(w.name).font(.headline)
                                    Text(w.startedAt.formatted(date: .abbreviated, time: .shortened))
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
                WorkoutDetailView(workout: workout)
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
            Button(action: { showCreate = true }) {
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
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                Form {
                    Section("Details") {
                        TextField("Workout name", text: $nameInput)
                        DatePicker("Date", selection: $dateInput, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                .navigationTitle("New Workout")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { cancelCreate() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") { createWorkout() }
                            .disabled(nameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
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

    private func createWorkout() {
        let trimmed = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let workout = Workout(startedAt: dateInput, name: trimmed)
        context.insert(workout)
        try? context.save()
        nameInput = ""
        dateInput = .now
        showCreate = false
        DispatchQueue.main.async {
            path.append(workout)
        }
    }

    private func cancelCreate() {
        nameInput = ""
        dateInput = .now
        showCreate = false
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
