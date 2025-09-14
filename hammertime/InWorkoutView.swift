//
//  InWorkoutView.swift
//  hammertime
//

import SwiftUI
import SwiftData
import UIKit

struct InWorkoutView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State var workout: Workout
    @State private var currentExerciseIndex: Int = 0
    @State private var isChatOpen = false
    @FocusState private var isComposerFocused: Bool
    @State private var chatInputText: String = ""
    @State private var isSendingChat = false
    @State private var chatErrorText: String?
    @State private var restEndAt: Date? = nil
    @State private var restDurationSeconds: Int = 90
    @State private var restAnchorSetId: UUID? = nil
    @State private var swipeDirection: Int = 0 // -1 prev, +1 next
    @State private var dragOffsetX: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var isChatTab: Bool = true
    @State private var isKeyboardExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            topHeaderSection
            navRowSection
            contentSection
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .background(BackSwipeDisabledView(disable: true))
        .onAppear { syncCurrentExerciseIndex() }
        .onChange(of: isComposerFocused) { _, newVal in
            isKeyboardExpanded = newVal
            if newVal == false { withAnimation(.easeInOut(duration: 0.2)) { isChatOpen = false } }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(DragGesture(minimumDistance: 20, coordinateSpace: .local).onEnded { value in
            if value.translation.height > 40 { endEditing() }
        })
        .safeAreaInset(edge: .bottom) { bottomInsetSection }
        .alert("Error", isPresented: Binding(get: { chatErrorText != nil }, set: { _ in chatErrorText = nil })) {
            Button("OK", role: .cancel) { }
        } message: { Text(chatErrorText ?? "") }
        .toolbar(.hidden, for: .tabBar)
    }

    private var topHeaderSection: some View {
        Group { if !isKeyboardExpanded { header } }
    }

    private var navRowSection: some View {
        Group {
            if !isKeyboardExpanded {
                navRow
                    .id(currentExerciseIndex)
                    .transition(.opacity)
                    .animation(.easeOut(duration: 0.18), value: currentExerciseIndex)
            }
        }
    }

    private var contentSection: some View {
        Group {
            if isChatOpen {
                if isKeyboardExpanded {
                    collapsedChatSection.eraseToAnyView()
                } else {
                    pagerWithBelowContentSection.eraseToAnyView()
                }
            } else {
                pagerSection.eraseToAnyView()
            }
        }
    }

    private var collapsedChatSection: some View {
        VStack(spacing: 8) {
            collapsedCardSection
            Group {
                if isChatTab {
                    WorkoutChatThread(workoutId: workout.id)
                } else {
                    NotesPlaceholder()
                }
            }
            .onTapGesture { }
            .gesture(DragGesture(minimumDistance: 20).onEnded { value in
                if value.translation.height > 40 { endEditing() }
            })
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var collapsedCardSection: some View {
        ExerciseCardRender(
            exercise: exercise(at: currentExerciseIndex),
            isActive: true,
            isNextAnchor: { id in restAnchorSetId == id },
            restEndAt: restEndAt,
            total: restDurationSeconds,
            onDelete: { deleteSet($0) },
            canToggle: { s in canToggle(s, in: exercise(at: currentExerciseIndex)?.sets.sorted { $0.setNumber < $1.setNumber } ?? []) },
            onToggle: { toggleLogged($0) },
            onWeight: { set, lb in updateWeight(set: set, pounds: lb) },
            onReps: { set, reps in updateReps(set: set, reps: reps) },
            onStartRest: { id in startRest(anchorSetId: id) },
            onCompleteRest: { withAnimation(.easeOut(duration: 0.2)) { restEndAt = nil; restAnchorSetId = nil } },
            onAddSet: { },
            visibleSetId: nextSetId(in: exercise(at: currentExerciseIndex)?.sets.sorted { $0.setNumber < $1.setNumber } ?? []),
            showAddSetButton: false
        )
    }

    private var pagerSection: some View {
        GeometryReader { geo in
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(sortedExercises.enumerated()), id: \.0) { idx, _ in
                    cardSection(for: idx)
                        .frame(width: geo.size.width, alignment: .top)
                }
            }
            .offset(x: -CGFloat(currentExerciseIndex) * geo.size.width + dragOffsetX)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 5).onChanged { value in
                isDragging = true
                let tx = value.translation.width
                if (currentExerciseIndex == 0 && tx > 0) || (currentExerciseIndex == sortedExercises.count - 1 && tx < 0) {
                    dragOffsetX = tx / 6
                } else {
                    dragOffsetX = tx
                }
            }.onEnded { value in
                let tx = value.translation.width
                let threshold = geo.size.width * 0.25
                if tx < -threshold && currentExerciseIndex < sortedExercises.count - 1 {
                    swipeDirection = 1
                    withAnimation(.interpolatingSpring(stiffness: 260, damping: 28)) { dragOffsetX = -geo.size.width }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        let gen = UISelectionFeedbackGenerator(); gen.selectionChanged()
                        currentExerciseIndex += 1
                        dragOffsetX = 0
                    }
                } else if tx > threshold && currentExerciseIndex > 0 {
                    swipeDirection = -1
                    withAnimation(.interpolatingSpring(stiffness: 260, damping: 28)) { dragOffsetX = geo.size.width }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        let gen = UISelectionFeedbackGenerator(); gen.selectionChanged()
                        currentExerciseIndex -= 1
                        dragOffsetX = 0
                    }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { dragOffsetX = 0 }
                }
                isDragging = false
            })
        }
    }

    private var pagerWithBelowContentSection: some View {
        VStack(spacing: 8) {
            pagerSection
                .frame(maxHeight: .infinity)
            Group {
                if isChatTab { WorkoutChatThread(workoutId: workout.id) }
                else { NotesPlaceholder() }
            }
            .frame(minHeight: 180)
        }
    }

    private var bottomInsetSection: some View {
        Group { (isChatOpen && isChatTab) ? AnyView(chatComposerWithMode) : AnyView(bottomBarWithNotes) }
    }
}

// MARK: - Header
extension InWorkoutView {
    private func cardSection(for index: Int) -> some View { cardContent(for: index, isActive: index == currentExerciseIndex) }
    private func cardContent(for index: Int, isActive: Bool) -> some View {
        let ex = index >= 0 && index < sortedExercises.count ? sortedExercises[index] : nil
        return ExerciseCardRender(exercise: ex,
                                  isActive: isActive,
                                  isNextAnchor: { id in restAnchorSetId == id },
                                  restEndAt: restEndAt,
                                  total: restDurationSeconds,
                                  onDelete: { deleteSet($0) },
                                  canToggle: { canToggle($0, in: ex?.sets.sorted { $0.setNumber < $1.setNumber } ?? []) },
                                  onToggle: { toggleLogged($0) },
                                  onWeight: { set, lb in updateWeight(set: set, pounds: lb) },
                                  onReps: { set, reps in updateReps(set: set, reps: reps) },
                                  onStartRest: { id in startRest(anchorSetId: id) },
                                  onCompleteRest: { restEndAt = nil; restAnchorSetId = nil },
                                  onAddSet: { if isActive { addSetToCurrentExercise() } },
                                  visibleSetId: nil,
                                  showAddSetButton: true)
        .onTapGesture { if isChatOpen { closeChat() } }
    }
    private var cardTransition: AnyTransition {
        // Move out based on swipe direction and bring new one from opposite edge
        if swipeDirection > 0 {
            return .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                               removal: .move(edge: .leading).combined(with: .opacity))
        } else if swipeDirection < 0 {
            return .asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                               removal: .move(edge: .trailing).combined(with: .opacity))
        } else {
            return .opacity
        }
    }
    private var currentExerciseSection: some View { exerciseCard }
    private func nextSetId(in sets: [SetEntry]) -> UUID? {
        // Always highlight first unchecked set
        if let firstUnchecked = sets.first(where: { !$0.isLogged }) { return firstUnchecked.id }
        return sets.last?.id
    }

    private func canToggle(_ s: SetEntry, in sets: [SetEntry]) -> Bool {
        // Allow unchecking any logged set; only the first unchecked set is tappable to check
        if s.isLogged { return true }
        return s.id == nextSetId(in: sets)
    }

    private func deleteSet(_ s: SetEntry) {
        withAnimation(.easeOut(duration: 0.08)) {
            context.delete(s)
            try? context.save()
        }
    }

    private func toggleLogged(_ s: SetEntry) {
        s.isLogged.toggle()
        try? context.save()
    }

    private func updateWeight(set s: SetEntry, pounds: Int?) {
        if let pounds { s.weightKg = lbToKg(Double(pounds)) } else { s.weightKg = nil }
        try? context.save()
    }

    private func updateReps(set s: SetEntry, reps: Int?) {
        s.reps = reps
        try? context.save()
    }
    private func startRest(anchorSetId: UUID) {
        restDurationSeconds = 90
        restAnchorSetId = anchorSetId
        restEndAt = Date().addingTimeInterval(TimeInterval(restDurationSeconds))
    }
    private func openChat() {
        withAnimation(.easeInOut(duration: 0.22)) { isChatOpen = true }
        isChatTab = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isComposerFocused = true }
    }
    private func closeChat() {
        endEditing()
        withAnimation(.easeInOut(duration: 0.22)) { isChatOpen = false }
    }
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
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(Color.black.opacity(0.02)))
                }
                Spacer()
            }
            .padding(.horizontal, 12)

            // Trailing: Finish
            HStack {
                Spacer()
                Button(action: {}) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(Color.black.opacity(0.02)))
                }
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
        HStack(alignment: .center, spacing: 0) {
            // Left target (previous exercise)
            let hasPrev = currentExerciseIndex - 1 >= 0
            Button(action: { goPrev() }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exerciseName(at: currentExerciseIndex - 1))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .disabled(!hasPrev)
            .opacity(hasPrev ? 1 : 0.4)
            .buttonStyle(.plain)
            .tint(Color.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Middle list icon (inert)
            // Button(action: {}) {
            //     Image(systemName: "list.bullet")
            //         .font(.system(size: 18, weight: .medium))
            //         .foregroundStyle(.secondary)
            //         .padding(8)
            // }
            // .disabled(true)
            // .opacity(0.8)
            // .buttonStyle(.plain)
            // .tint(Color.secondary)
            // .frame(width: 44)

            // Right target (next exercise)
            let hasNext = currentExerciseIndex + 1 < sortedExercises.count
            Button(action: { goNext() }) {
                HStack(spacing: 6) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(exerciseName(at: currentExerciseIndex + 1))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .disabled(!hasNext)
            .opacity(hasNext ? 1 : 0.4)
            .buttonStyle(.plain)
            .tint(Color.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Talk to Coach Bar
extension InWorkoutView {
    private var bottomBarWithNotes: some View {
        HStack(spacing: 12) {
            // Talk to your coach
            if isAllSetsCompleted {
                Button(action: { openChat() }) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color(UIColor.systemGray))
                        .frame(width: 48, height: 48)
                        .background(
                            Circle().fill(Color.white)
                        )
                        .overlay(Circle().stroke(Color.black.opacity(0.05), lineWidth: 1))
                }
                .buttonStyle(.plain)
            } else {
                Button(action: { openChat() }) {
                    HStack {
                        Text("Talk to your coach")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 50)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white)
                            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(RadialGradient(colors: [Color.brandYellow.opacity(0.05), Color.brandYellow.opacity(0.01)], center: .topTrailing, startRadius: 0, endRadius: 220))
                            RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.01), radius: 71, x: 0, y: 252)
                        .shadow(color: .black.opacity(0.01), radius: 44, x: 0, y: 111)
                        .shadow(color: .black.opacity(0.02), radius: 37, x: 0, y: 62)
                        .shadow(color: .black.opacity(0.03), radius: 28, x: 0, y: 28)
                        .shadow(color: .black.opacity(0.04), radius: 15, x: 0, y: 7)
                    )
                }
                .buttonStyle(.plain)
            }

            // Notes button on the right
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isChatOpen = true; isChatTab = false; endEditing() } }) {
                Image(systemName: "note.text")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color.white))
                    .overlay(Circle().stroke(Color.black.opacity(0.05), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
            }
            .buttonStyle(.plain)

            // Finish primary (only when all sets completed)
            if isAllSetsCompleted {
                Button(action: finishWorkout) {
                    Text("Finish")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(.brandYellowPrimary)
                                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 1))
                                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

// MARK: - Chat Composer (inline)
extension InWorkoutView {
    private var chatComposerWithMode: some View {
        HStack(alignment: .center, spacing: 8) {
            // Background styled like the Talk to your coach bar
            HStack(spacing: 12) {
                TextField("Talk to your coach", text: $chatInputText, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.system(size: 18))
                    .disabled(isSendingChat)
                    .focused($isComposerFocused)
                    .onSubmit { sendChat() }
                    .padding(.vertical, 12)
            }
            .padding(.horizontal, 20)
            .frame(height: 48)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white)
                    RoundedRectangle(cornerRadius: 24, style: .continuous).fill(RadialGradient(colors: [Color.brandYellow.opacity(0.05), Color.brandYellow.opacity(0.01)], center: .topTrailing, startRadius: 0, endRadius: 220))
                    RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.01), radius: 71, x: 0, y: 252)
                .shadow(color: .black.opacity(0.01), radius: 44, x: 0, y: 111)
                .shadow(color: .black.opacity(0.02), radius: 37, x: 0, y: 62)
                .shadow(color: .black.opacity(0.03), radius: 28, x: 0, y: 28)
                .shadow(color: .black.opacity(0.04), radius: 15, x: 0, y: 7)
            )
            // Detached floating send button
            Button(action: sendChat) {
                ZStack {
                    Circle()
                        .fill(Color.brandYellow)
                        .overlay(Circle().stroke(Color.black.opacity(0.05), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
                    if isSendingChat { ProgressView().progressViewStyle(.circular) }
                    else { Image(systemName: "arrow.up").font(.system(size: 18, weight: .bold)).foregroundStyle(.black) }
                }
                .frame(width: 48, height: 48)
            }
            .disabled(chatInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSendingChat)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private func sendChat() {
        let trimmed = chatInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSendingChat else { return }
        isSendingChat = true
        chatInputText = ""

        let userMsg = Message(role: "user", content: trimmed, createdAt: .now, workout: workout)
        context.insert(userMsg)
        try? context.save()

        Task {
            do {
                let metrics = try ChatContextBuilder.buildMetricsContext(modelContext: context)
                let current = exercise(at: currentExerciseIndex)
                let nextId = nextSetId(in: current?.sets.sorted { $0.setNumber < $1.setNumber } ?? [])
                let state = ChatContextBuilder.buildCurrentStateContext(workout: workout, currentExercise: current, restEndAt: restEndAt, restTotalSeconds: restDurationSeconds, nextSetId: nextId)
                var contextLines = metrics
                contextLines.append("CURRENT_STATE_JSON:\n" + state)

                // Fetch last messages for this workout only
                let wid: UUID? = workout.id
                var fd = FetchDescriptor<Message>(
                    predicate: #Predicate<Message> { $0.workout?.id == wid },
                    sortBy: [SortDescriptor(\Message.createdAt, order: .forward)]
                )
                fd.fetchLimit = 20
                let historyMsgs = try context.fetch(fd)
                let historyPairs: [(role: String, content: String)] = historyMsgs.map { ($0.role, $0.content) } + [("user", trimmed)]

                let reply = try await OpenAIService.shared.replyWithHistory(contextLines: contextLines, history: historyPairs)
                let assistant = Message(role: "assistant", content: reply, workout: workout)
                context.insert(assistant)
                try? context.save()
            } catch {
                chatErrorText = userFriendly(error)
            }
            isSendingChat = false
        }
    }
}

// MARK: - Error Mapping
extension InWorkoutView {
    private func userFriendly(_ error: Error) -> String {
        if let err = error as? OpenAIError {
            switch err {
            case .missingApiKey:
                return "Missing OpenAI API key. Set OPENAI_API_KEY in Secrets.xcconfig and ensure the target's Base Configuration points to it."
            case .http(let status, let body):
                return "OpenAI HTTP error \(status). \(body ?? "")"
            case .decoding:
                return "OpenAI response could not be parsed. Try again."
            case .network(let underlying):
                return "Network error: \(underlying.localizedDescription)"
            }
        }
        return error.localizedDescription
    }
}

// MARK: - Exercise Card UI
extension InWorkoutView {
    private var exerciseCard: some View {
        let ex = exercise(at: currentExerciseIndex)
        return VStack(alignment: .leading, spacing: 8) {
            Text(ex?.name ?? "")
                .font(.system(size: 22, weight: .medium))

            // header row: lbs / reps
            HStack {
                Text("")
                    .frame(width: 24, alignment: .leading)
                Spacer()
                Text("lbs").foregroundStyle(.secondary)
                    .frame(width: 80)
                Text("reps").foregroundStyle(.secondary)
                    .frame(width: 80)
                Spacer().frame(width: 36)
            }
            .font(.system(size: 16, weight: .medium))

            VStack(spacing: 8) {
                let sets = ex?.sets.sorted { $0.setNumber < $1.setNumber } ?? []
                ForEach(sets) { s in
                    ExerciseSetRowView(
                        set: s,
                        isNext: s.id == nextSetId(in: sets),
                        onDelete: { deleteSet(s) },
                        onToggleLogged: { if canToggle(s, in: sets) { toggleLogged(s) } },
                        onChangeWeightLb: { newLb in updateWeight(set: s, pounds: newLb) },
                        onChangeReps: { newReps in updateReps(set: s, reps: newReps) },
                        onNextSetLogged: { startRest(anchorSetId: s.id) }
                    )
                    // Inline rest row directly after the just-completed set
                    if let end = restEndAt, end > Date(), restAnchorSetId == s.id {
                        RestBar(endAt: end, total: restDurationSeconds) {
                            let gen = UINotificationFeedbackGenerator(); gen.notificationOccurred(.success)
                            withAnimation(.easeOut(duration: 0.2)) { restEndAt = nil; restAnchorSetId = nil }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            // No explicit transition; rely on withAnimation in add/delete to keep button and rows in sync

            Button(action: { withAnimation(.easeOut(duration: 0.08)) { addSetToCurrentExercise() } }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Set")
                }
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.black.opacity(0.02))
                )
                .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            // Follows parent animation driven by withAnimation in add/delete
        }
        .padding(0)
        .background(
            ZStack {
                // base
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white)
                // subtle brand yellow radial per Figma
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [Color.brandYellow.opacity(0.05), Color.brandYellow.opacity(0.01)],
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: 320
                        )
                    )
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.0), radius: 49, x: 0, y: 173)
            .shadow(color: .black.opacity(0.01), radius: 44, x: 0, y: 111)
            .shadow(color: .black.opacity(0.02), radius: 37, x: 0, y: 62)
            .shadow(color: .black.opacity(0.03), radius: 28, x: 0, y: 28)
            .shadow(color: .black.opacity(0.04), radius: 15, x: 0, y: 7)
        )
        
        .allowsHitTesting(true)
        .zIndex(1)
        .animation(.easeOut(duration: 0.08), value: exercise(at: currentExerciseIndex)?.sets.count ?? 0)
    }
}

// MARK: - Helpers for sets
extension InWorkoutView {
    private func exercise(at index: Int) -> Exercise? {
        guard index >= 0 && index < sortedExercises.count else { return nil }
        return sortedExercises[index]
    }
}

private struct ExerciseSetRowView: View {
    let set: SetEntry
    let isNext: Bool
    let onDelete: () -> Void
    let onToggleLogged: () -> Void
    let onChangeWeightLb: (Int?) -> Void
    let onChangeReps: (Int?) -> Void
    let onNextSetLogged: () -> Void

    @State private var weightText: String = ""
    @State private var repsText: String = ""

    var body: some View {
        HStack(spacing: 12) {
            Text("\(set.setNumber)")
                .foregroundStyle(Color(UIColor.systemGray3))
                .frame(width: 24, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                numericPill(text: $weightText, placeholder: "-", width: 80) { newVal in onChangeWeightLb(newVal) }
                numericPill(text: $repsText, placeholder: "-", width: 80) { newVal in onChangeReps(newVal) }
            }
            .frame(width: 172, alignment: .trailing)

            // Log button
            logButton
            .frame(width: 48, height: 48, alignment: .center)
        }
        .contentShape(Rectangle())
        .modifier(SwipeToDeleteModifier(onDelete: onDelete))
        .onAppear { syncTextFromModel() }
        .onChange(of: set.weightKg) { _, _ in syncTextFromModel() }
        .onChange(of: set.reps) { _, _ in syncTextFromModel() }
    }

    private func syncTextFromModel() {
        let lb = set.weightKg.map { Int(round($0 * 2.20462)) }
        weightText = lb.map { String($0) } ?? ""
        repsText = set.reps.map { String($0) } ?? ""
    }

    private func numericPill(text: Binding<String>, placeholder: String, width: CGFloat, onChange: @escaping (Int?) -> Void) -> some View {
        ZStack {
            Capsule().fill(Color.black.opacity(0.02))
            NumericField(text: text, placeholder: placeholder, onChange: onChange)
                .frame(width: width, height: 48)
        }
        .frame(width: width, height: 48)
    }
}

// MARK: - UIKit Numeric Field
private struct NumericField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onChange: (Int?) -> Void

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.keyboardType = .numberPad
        tf.textAlignment = .center
        tf.font = .systemFont(ofSize: 20, weight: .medium)
        tf.placeholder = placeholder
        tf.delegate = context.coordinator
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.selectAllOnTap))
        tap.cancelsTouchesInView = false
        tf.addGestureRecognizer(tap)
        tf.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text { uiView.text = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text, onChange: onChange) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        let onChange: (Int?) -> Void
        init(text: Binding<String>, onChange: @escaping (Int?) -> Void) {
            _text = text
            self.onChange = onChange
        }
        func textFieldDidBeginEditing(_ textField: UITextField) {
            textField.selectAll(nil)
        }
        @objc func selectAllOnTap(_ sender: UITapGestureRecognizer) {
            if let tf = sender.view as? UITextField { tf.selectAll(nil) }
        }
        @objc func editingChanged(_ sender: UITextField) {
            let filtered = (sender.text ?? "").filter { $0.isNumber }
            if filtered != sender.text { sender.text = filtered }
            text = filtered
            onChange(Int(filtered))
        }
    }
}

// MARK: - Rest Bar
private struct RestBar: View {
    let endAt: Date
    let total: Int
    let onComplete: () -> Void
    @State private var nowTick: Date = .now
    @State private var progress: CGFloat = 1
    var body: some View {
        let remaining = max(0, Int(endAt.timeIntervalSince(nowTick)))
        ZStack(alignment: .center) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track (gray)
                    RoundedRectangle(cornerRadius: 99, style: .continuous)
                        .fill(Color.black.opacity(0.02))
                        .frame(height: 24)
                        // .overlay(
                        //     RoundedRectangle(cornerRadius: 99, style: .continuous)
                        //         .stroke(Color.black.opacity(0.05), lineWidth: 1)
                        // )
                    // Fill (yellow) shrinks from full width to zero smoothly
                    RoundedRectangle(cornerRadius: 99, style: .continuous)
                        .fill(Color.brandYellow)
                        .frame(width: geo.size.width * progress, height: 24)
                }
            }
            // Time label centered over the bar
            Text(timeString(remaining))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
        }
        .frame(height: 24)
        .onAppear { startSmoothAnimation() }
        .onChange(of: endAt) { _, _ in startSmoothAnimation() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now in
            nowTick = now
            if endAt <= now { onComplete() }
        }
    }
    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
    private func startSmoothAnimation() {
        let remaining = max(0, endAt.timeIntervalSince(.now))
        let initial = CGFloat(min(1, max(0, remaining / Double(max(1, total)))))
        progress = initial
        withAnimation(.linear(duration: remaining)) { progress = 0 }
    }
}

// MARK: - Readonly Card for Peek
private struct ExerciseCardRender: View {
    let exercise: Exercise?
    let isActive: Bool
    let isNextAnchor: (UUID) -> Bool
    let restEndAt: Date?
    let total: Int
    let onDelete: (SetEntry) -> Void
    let canToggle: (SetEntry) -> Bool
    let onToggle: (SetEntry) -> Void
    let onWeight: (SetEntry, Int?) -> Void
    let onReps: (SetEntry, Int?) -> Void
    let onStartRest: (UUID) -> Void
    let onCompleteRest: () -> Void
    let onAddSet: () -> Void
    let visibleSetId: UUID?
    let showAddSetButton: Bool

    var body: some View {
        // Compute filtered set list outside of the ViewBuilder to avoid buildExpression errors
        let setsAll: [SetEntry] = (exercise?.sets.sorted { $0.setNumber < $1.setNumber } ?? [])
        let sets: [SetEntry] = {
            if let visibleSetId, let only = setsAll.first(where: { $0.id == visibleSetId }) { return [only] }
            return setsAll
        }()

        return VStack(alignment: .leading, spacing: 8) {
            Text(exercise?.name ?? "")
                .font(.system(size: 22, weight: .medium))
            if visibleSetId == nil { // show lbs/reps header only in full mode
                HStack {
                    Text("").frame(width: 24)
                    Spacer()
                    Text("lbs").foregroundStyle(.secondary).frame(width: 80)
                    Text("reps").foregroundStyle(.secondary).frame(width: 80)
                    Spacer().frame(width: 36)
                }
                .font(.system(size: 16, weight: .medium))
            }

            VStack(spacing: 8) {
                ForEach(sets) { s in
                    ExerciseSetRowView(
                        set: s,
                        isNext: s.id == setsAll.first(where: { !$0.isLogged })?.id,
                        onDelete: { onDelete(s) },
                        onToggleLogged: { if canToggle(s) { onToggle(s) } },
                        onChangeWeightLb: { onWeight(s, $0) },
                        onChangeReps: { onReps(s, $0) },
                        onNextSetLogged: { onStartRest(s.id) }
                    )
                    if let end = restEndAt, end > Date(), isNextAnchor(s.id) {
                        RestBar(endAt: end, total: total) { onCompleteRest() }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }

            // Always render +Set to keep heights consistent across pages
            if showAddSetButton {
                Button(action: { onAddSet() }) {
                    HStack(spacing: 6) { Image(systemName: "plus"); Text("Set") }
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.black.opacity(0.02)))
                        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
                }
                .allowsHitTesting(isActive)
            }
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white)
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(RadialGradient(colors: [Color.brandYellow.opacity(0.05), Color.brandYellow.opacity(0.01)], center: .topTrailing, startRadius: 0, endRadius: 320))
                RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 1)
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.0), radius: 49, x: 0, y: 173)
            .shadow(color: .black.opacity(0.01), radius: 44, x: 0, y: 111)
            .shadow(color: .black.opacity(0.02), radius: 37, x: 0, y: 62)
            .shadow(color: .black.opacity(0.03), radius: 28, x: 0, y: 28)
            .shadow(color: .black.opacity(0.04), radius: 15, x: 0, y: 7)
        )
        .padding(.horizontal, 12)
        .padding(.top, 16)
        .padding(.bottom, 16)
    }
}

// MARK: - Notes Placeholder
private struct NotesPlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Previous workouts & notes will appear here")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 12)
        .background(Color.clear)
    }
}


// MARK: - Log Button Builder
private extension ExerciseSetRowView {
    @ViewBuilder
    var logButton: some View {
        if set.isLogged {
            Circle()
                .fill(Color.black.opacity(0.02))
                .overlay(Image(systemName: "checkmark").font(.system(size: 18, weight: .semibold)).foregroundStyle(.black))
                .onTapGesture {
                    onToggleLogged()
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        } else if isNext {
            Circle()
                .fill(Color.brandYellow)
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
                .overlay(Circle().stroke(Color.black.opacity(0.05), lineWidth: 1))
                .overlay(Image(systemName: "checkmark").font(.system(size: 18, weight: .semibold)).foregroundStyle(.black))
                .onTapGesture {
                    let gen = UINotificationFeedbackGenerator(); gen.notificationOccurred(.success)
                    onToggleLogged()
                    onNextSetLogged()
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        } else {
            Circle()
                .fill(Color.black.opacity(0.02))
        }
    }
}

// MARK: - Swipe to delete red feedback
private struct SwipeToDeleteModifier: ViewModifier {
    @State private var offsetX: CGFloat = 0
    @State private var showRed: Bool = false
    let onDelete: () -> Void
    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                Spacer()
                Image(systemName: "trash")
                    .foregroundStyle(Color.red)
                    .font(.system(size: 18, weight: .semibold))
                    .padding(12)
                    .background(Color.clear)
                    // Start fully outside (to the right), pull in as you swipe left
                    .offset(x: 44 - min(44, -offsetX))
                    .opacity(min(1, max(0, (-offsetX) / 12)))
            }
            content
                .background(Color.clear)
                .offset(x: offsetX)
        }
        // Do not clip the row; allow shadows from siblings (e.g., +Set) to overflow
        .gesture(DragGesture(minimumDistance: 25).onChanged { value in
            offsetX = min(0, value.translation.width)
            showRed = value.translation.width < -10
        }.onEnded { value in
            if value.translation.width < -60 {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                withAnimation(.easeInOut(duration: 0.12)) { offsetX = -80; showRed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { onDelete() }
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { offsetX = 0; showRed = false }
            }
        })
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

    private var isAllSetsCompleted: Bool {
        for ex in sortedExercises { if isExerciseComplete(ex) == false { return false } }
        return !sortedExercises.isEmpty
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

    private func addSetToCurrentExercise() {
        guard let ex = exercise(at: currentExerciseIndex) else { return }
        let nextNum = (ex.sets.map { $0.setNumber }.max() ?? 0) + 1
        let last = ex.sets.max(by: { $0.setNumber < $1.setNumber })
        let weightKg: Double? = last?.weightKg ?? lbToKg(30)
        let reps: Int? = last?.reps ?? 8
        let s = SetEntry(setNumber: nextNum, weightKg: weightKg, reps: reps, exercise: ex)
        withAnimation(.easeOut(duration: 0.08)) {
            ex.sets.append(s)
        }
        context.insert(s)
        try? context.save()
    }

    private func lbToKg(_ lb: Double?) -> Double? {
        guard let lb else { return nil }
        return lb / 2.20462
    }

    private func endEditing() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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


