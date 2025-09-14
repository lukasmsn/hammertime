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
    @State private var showChat = false

    var body: some View {
        VStack(spacing: 0) {
            header
            progressBar
            navRow
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .background(BackSwipeDisabledView(disable: true))
        .onAppear { syncCurrentExerciseIndex() }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 20, coordinateSpace: .local).onEnded { value in
            if value.translation.width < -40 { goNext() }
            else if value.translation.width > 40 { goPrev() }
        })
        .safeAreaInset(edge: .bottom) { talkToCoachBar }
        .background(
            NavigationLink(isActive: $showChat) { ChatView() } label: { EmptyView() }
        )
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

// MARK: - Nav Row
extension InWorkoutView {
    private var navRow: some View {
        HStack(alignment: .center) {
            // Left target (previous exercise)
            let hasPrev = currentExerciseIndex - 1 >= 0
            Button(action: { goPrev() }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exerciseName(at: currentExerciseIndex - 1))
                            .font(.system(size: 16))
                        Text(exerciseSetsLabel(at: currentExerciseIndex - 1))
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .disabled(!hasPrev)
            .opacity(hasPrev ? 1 : 0.4)

            Spacer(minLength: 0)

            // Middle list icon (inert)
            Button(action: {}) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(8)
            }
            .disabled(true)
            .opacity(0.8)

            Spacer(minLength: 0)

            // Right target (next exercise)
            let hasNext = currentExerciseIndex + 1 < sortedExercises.count
            Button(action: { goNext() }) {
                HStack(spacing: 6) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(exerciseName(at: currentExerciseIndex + 1))
                            .font(.system(size: 16))
                        Text(exerciseSetsLabel(at: currentExerciseIndex + 1))
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .disabled(!hasNext)
            .opacity(hasNext ? 1 : 0.4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Talk to Coach Bar
extension InWorkoutView {
    private var talkToCoachBar: some View {
        Button(action: { showChat = true }) {
            HStack {
                Text("Talk to your coach")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .frame(height: 50)
            .background(
                ZStack {
                    // Base white card
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white)
                    // Subtle brand yellow radial gradient (Figma: #E8FF1C @ 5% → 1%)
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [Color.brandYellow.opacity(0.05), Color.brandYellow.opacity(0.01)],
                                center: .topTrailing,
                                startRadius: 0,
                                endRadius: 220
                            )
                        )
                    // Border
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.01), radius: 71, x: 0, y: 252)
                .shadow(color: .black.opacity(0.01), radius: 44, x: 0, y: 111)
                .shadow(color: .black.opacity(0.02), radius: 37, x: 0, y: 62)
                .shadow(color: .black.opacity(0.03), radius: 28, x: 0, y: 28)
                .shadow(color: .black.opacity(0.04), radius: 15, x: 0, y: 7)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
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

    private func goPrev() {
        guard currentExerciseIndex > 0 else { return }
        currentExerciseIndex -= 1
    }

    private func goNext() {
        guard currentExerciseIndex + 1 < sortedExercises.count else { return }
        currentExerciseIndex += 1
    }

    private func exerciseName(at index: Int) -> String {
        guard index >= 0 && index < sortedExercises.count else { return "" }
        return sortedExercises[index].name
    }

    private func exerciseSetsLabel(at index: Int) -> String {
        guard index >= 0 && index < sortedExercises.count else { return "" }
        let sets = sortedExercises[index].sets.count
        return "\(sets) sets"
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


