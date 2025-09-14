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
    @State private var currentExerciseIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            progressBar
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .background(BackSwipeDisabledView(disable: true))
        .onAppear { syncCurrentExerciseIndex() }
    }
}

// MARK: - Header
extension InWorkoutView {
    private var header: some View {
        ZStack {
            // Center: title + live timer
            VStack(spacing: 2) {
                Text(workout.name.isEmpty ? "Workout" : workout.name)
                    .font(.title3.weight(.semibold))
                DurationLabel(startedAt: workout.startedAt)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)

            // Leading: Close (X)
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color(UIColor.secondarySystemBackground)))
                }
                Spacer()
            }
            .padding(.horizontal, 12)

            // Trailing: Finish
            HStack {
                Spacer()
                Button(action: finishWorkout) {
                    Text("Finish")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 12)
        }
    }
}

// MARK: - Progress Bar
extension InWorkoutView {
    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(Array(sortedExercises.enumerated()), id: \.0) { idx, ex in
                let isComplete = isExerciseComplete(ex)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isComplete ? Color.brandYellow.opacity(0.4) : .white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
                    )
                    .frame(height: 16)
                    .scaleEffect(idx == currentExerciseIndex ? 1.06 : 1.0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentExerciseIndex)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Actions
extension InWorkoutView {
    private func finishWorkout() {
        let now = Date()
        let elapsed = Int(max(0, now.timeIntervalSince(workout.startedAt)))
        workout.finishedAt = now
        workout.durationSeconds = elapsed
        try? context.save()
        dismiss()
    }
}

// MARK: - Components
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

// MARK: - Helpers
extension InWorkoutView {
    private var sortedExercises: [Exercise] {
        workout.exercises.sorted { $0.position < $1.position }
    }

    private func isExerciseComplete(_ ex: Exercise) -> Bool {
        guard ex.sets.isEmpty == false else { return false }
        for s in ex.sets { if s.isLogged == false { return false } }
        return true
    }

    private func firstActiveExerciseIndex() -> Int {
        for (i, ex) in sortedExercises.enumerated() { if isExerciseComplete(ex) == false { return i } }
        return max(0, sortedExercises.count - 1)
    }

    private func syncCurrentExerciseIndex() {
        currentExerciseIndex = firstActiveExerciseIndex()
    }
}

// MARK: - Utilities
private struct BackSwipeDisabledView: UIViewControllerRepresentable {
    let disable: Bool
    func makeUIViewController(context: Context) -> Controller { Controller(disable: disable) }
    func updateUIViewController(_ uiViewController: Controller, context: Context) { uiViewController.disable = disable }

    final class Controller: UIViewController {
        var disable: Bool { didSet { updateGesture() } }
        init(disable: Bool) { self.disable = disable; super.init(nibName: nil, bundle: nil) }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); updateGesture() }
        override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); navigationController?.interactivePopGestureRecognizer?.isEnabled = true }
        private func updateGesture() { navigationController?.interactivePopGestureRecognizer?.isEnabled = disable ? false : true }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Workout.self, Exercise.self, SetEntry.self, Message.self, configurations: config)
    let w = Workout(startedAt: .now, name: "Pull Day")
    return InWorkoutView(workout: w)
        .modelContainer(container)
}


