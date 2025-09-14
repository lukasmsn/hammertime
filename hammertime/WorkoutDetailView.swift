//
//  WorkoutDetailView.swift
//  hammertime
//

import SwiftUI
import SwiftData
import UIKit
import AudioToolbox

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State var workout: Workout
    @State private var exercisePicking: Exercise?
    @State private var showingNotes = false
    @State private var restEndAt: Date?
    @State private var restStartAt: Date?
    @State private var saveWorkItem: DispatchWorkItem?

    var body: some View {
        List {
            Section(header: Text("Session")) {
                HStack {
                    Label("Duration", systemImage: "clock")
                    Spacer()
                    DurationLabel(startedAt: workout.startedAt)
                        .foregroundStyle(.secondary)
                }
                Button {
                    showingNotes = true
                } label: {
                    HStack {
                        Label("Notes", systemImage: "note.text")
                        Spacer()
                        Text(workout.notes?.isEmpty == false ? "Edit" : "Add")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            Section(header: Text("Exercises")) {
                ForEach(sortedExercises) { ex in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button {
                                exercisePicking = ex
                            } label: {
                                HStack(spacing: 6) {
                                    Text(ex.name).font(.headline)
                                    Image(systemName: "chevron.down").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
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

                                    if let prev = previousFor(exerciseName: ex.name, setNumber: s.setNumber) {
                                        Text("Prev: \(prev)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .frame(minWidth: 64, alignment: .leading)
                                    }

                                    HStack(spacing: 6) {
                                        TextField(
                                            "0",
                                            value: Binding<Double>(
                                                get: { kgToLb(s.weightKg) },
                                                set: { newLb in s.weightKg = lbToKg(newLb); scheduleAutosave() }
                                            ),
                                            format: .number
                                        )
                                        .keyboardType(.decimalPad)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(Color.gray.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .frame(width: 90)

                                        Text("lb")
                                            .foregroundStyle(.secondary)
                                    }

                                    Text("x")
                                        .foregroundStyle(.secondary)

                                    TextField(
                                        "0",
                                        value: Binding<Int>(
                                            get: { s.reps ?? 0 },
                                            set: { s.reps = $0; scheduleAutosave() }
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
                                        if s.isLogged { startRestTimer(seconds: 90) }
                                    } label: {
                                        Image(systemName: s.isLogged ? "checkmark.seal.fill" : "circle")
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

            if let start = restStartAt, let end = restEndAt, end > Date() {
                Section(footer: RestCountdownBar(startAt: start, endAt: end) { triggerRestEndFeedback(); restStartAt = nil; restEndAt = nil }) { EmptyView() }
            }
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(get: { exercisePicking != nil }, set: { if $0 == false { exercisePicking = nil } })) {
            if let ex = exercisePicking {
                ExercisePickerSheet(currentName: ex.name, onSelect: { name in
                    ex.name = name
                    try? context.save()
                })
            }
        }
        .sheet(isPresented: $showingNotes) {
            NotesEditorSheet(text: workout.notes ?? "") { newText in
                workout.notes = newText
                try? context.save()
            }
            .presentationDetents([.medium])
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if workout.finishedAt == nil {
                    Button("Finish") { finishWorkout() }
                }
            }
        }
    }

    private var sortedExercises: [Exercise] {
        workout.exercises.sorted { $0.position < $1.position }
    }

    private var exerciseOptions: [String] { ExerciseLibrary.all }

    private func setsLine(for ex: Exercise) -> String {
        let sorted = ex.sets.sorted { $0.setNumber < $1.setNumber }
        return sorted.map { s in
            let w = s.weightKg.map { String(format: "%.0f", kgToLb($0)) } ?? "-"
            let r = s.reps.map { String($0) } ?? "-"
            return "\(w)x\(r)"
        }.joined(separator: ", ")
    }

    private func setLine(_ s: SetEntry) -> String {
        var parts: [String] = []
        if let w = s.weightKg { parts.append("\(Int(round(kgToLb(w)))) lb") }
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

// Duration label isolated from the list tick updates
private struct DurationLabel: View {
    let startedAt: Date
    @State private var nowTick: Date = .now
    var body: some View {
        Text(durationString)
            .monospacedDigit()
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now in nowTick = now }
    }
    private var durationString: String {
        let seconds = Int(max(0, nowTick.timeIntervalSince(startedAt)))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

// Rest countdown bar with no controls; fires completion when reaches 0
private struct RestCountdownBar: View {
    let startAt: Date
    let endAt: Date
    var onFinish: () -> Void
    @State private var now: Date = .now
    @State private var didFire = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Rest", systemImage: "hourglass")
                Spacer()
                Text(remainingString).monospacedDigit()
            }
            GeometryReader { geo in
                let total = max(0, endAt.timeIntervalSince(startAt))
                let remain = max(0, endAt.timeIntervalSince(now))
                let pct = total > 0 ? remain / total : 0
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.brandYellowPrimary)
                        .frame(width: geo.size.width * pct)
                }
                .frame(height: 8)
            }
            .frame(height: 8)
        }
        .padding(.vertical, 8)
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { t in
            now = t
            if !didFire && now >= endAt {
                didFire = true
                onFinish()
            }
        }
    }
    private var remainingString: String {
        let remain = max(0, Int(endAt.timeIntervalSince(now)))
        let m = remain / 60
        let s = remain % 60
        return String(format: "%d:%02d", m, s)
    }
}

// Minimal notes editor sheet
private struct NotesEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var text: String
    var onSave: (String) -> Void
    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .padding()
                .navigationTitle("Notes")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(text); dismiss() } }
                }
        }
    }
}

// Searchable exercise picker with free text
private struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    let currentName: String
    var onSelect: (String) -> Void
    private var allNames: [String] { ExerciseLibrary.all }
    private var filtered: [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return allNames }
        return allNames.filter { $0.localizedCaseInsensitiveContains(q) }
    }
    var body: some View {
        NavigationStack {
            List {
                if !query.isEmpty {
                    Section {
                        Button("Use “\(query)”") { onSelect(query); dismiss() }
                    }
                }
                Section("All") {
                    ForEach(filtered, id: \.self) { name in
                        HStack {
                            Text(name)
                            Spacer()
                            if name == currentName { Image(systemName: "checkmark").foregroundStyle(.secondary) }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(name); dismiss() }
                    }
                }
            }
            .searchable(text: $query)
            .navigationTitle("Choose Exercise")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}
// MARK: - Timers & Helpers
extension WorkoutDetailView {
    private func kgToLb(_ kg: Double?) -> Double {
        guard let kg else { return 0 }
        return (kg * 2.20462)
    }

    private func lbToKg(_ lb: Double?) -> Double? {
        guard let lb else { return nil }
        return (lb / 2.20462)
    }
    private func startRestTimer(seconds: Int) {
        NotificationManager.scheduleRestDone(after: seconds)
        let start = Date()
        restStartAt = start
        restEndAt = start.addingTimeInterval(TimeInterval(seconds))
    }

    private func previousFor(exerciseName: String, setNumber: Int) -> String? {
        var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\Workout.startedAt, order: .reverse)])
        descriptor.fetchLimit = 10
        guard let workouts = try? context.fetch(descriptor) else { return nil }
        for w in workouts where w.id != workout.id {
            if let ex = w.exercises.first(where: { $0.name == exerciseName }) {
                if let set = ex.sets.first(where: { $0.setNumber == setNumber }) {
                    let wStr = set.weightKg.map { String(Int($0)) } ?? "-"
                    let rStr = set.reps.map { String($0) } ?? "-"
                    return "\(wStr)x\(rStr)"
                }
            }
        }
        return nil
    }

    private func finishWorkout() {
        let now = Date()
        let elapsed = Int(max(0, now.timeIntervalSince(workout.startedAt)))
        workout.finishedAt = now
        workout.durationSeconds = elapsed
        try? context.save()
        dismiss()
    }

    private func scheduleAutosave() {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { try? context.save() }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func triggerRestEndFeedback() {
        // Short, subtle haptic + brief chime
        let impact = UIImpactFeedbackGenerator(style: .rigid)
        impact.prepare()
        impact.impactOccurred(intensity: 1.0)
        AudioServicesPlaySystemSound(1103) // Tock (very short)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Workout.self, Exercise.self, SetEntry.self, Message.self, configurations: config)
    let w = Workout(startedAt: .now, name: "Preview Workout")
    WorkoutDetailView(workout: w)
        .modelContainer(container)
}



