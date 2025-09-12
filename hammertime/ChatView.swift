//
//  ChatView.swift
//  hammertime
//

import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Message.createdAt, order: .forward) private var messages: [Message]
    @State private var inputText: String = ""
    @State private var isSending = false
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                List {
                    ForEach(messages) { m in
                        HStack(alignment: .top) {
                            if m.role == "assistant" {
                                Text(m.content)
                                    .padding(12)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                Spacer(minLength: 0)
                            } else {
                                Spacer(minLength: 0)
                                Text(m.content)
                                    .foregroundStyle(.white)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(LinearGradient(colors: [.orange.opacity(0.95), .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    )
                            }
                        }
                        .listRowSeparator(.hidden)
                        .id(m.id)
                    }
                }
                .listStyle(.plain)
                .onChange(of: messages.last?.id) { _, newValue in
                    if let id = newValue {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()
            HStack(spacing: 8) {
                TextField("Message", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .disabled(isSending)
                    .onSubmit { send() }
                Button(action: send) {
                    if isSending {
                        ProgressView().progressViewStyle(.circular)
                    } else {
                        Image(systemName: "paperplane.fill").font(.system(size: 18, weight: .semibold))
                    }
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .navigationTitle("Chat")
        .alert("Error", isPresented: Binding(get: { errorText != nil }, set: { _ in errorText = nil })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorText ?? "")
        }
    }

    private func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }
        isSending = true
        inputText = ""

        let userMsg = Message(role: "user", content: trimmed)
        context.insert(userMsg)
        try? context.save()

        Task {
            do {
                let contextLines = try fetchWorkoutContextLines(limit: 5)
                let historyPairs: [(role: String, content: String)] = Array(messages.suffix(19)).map { ($0.role, $0.content) } + [("user", trimmed)]
                let reply = try await OpenAIService.shared.replyWithHistory(contextLines: contextLines, history: historyPairs)
                let assistant = Message(role: "assistant", content: reply)
                context.insert(assistant)
                try? context.save()
            } catch {
                errorText = userFriendly(error)
            }
            isSending = false
        }
    }

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

    private func fetchWorkoutContextLines(limit: Int) throws -> [String] {
        var descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\Workout.startedAt, order: .reverse)])
        descriptor.fetchLimit = limit
        let recent = try context.fetch(descriptor)
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        df.locale = .current
        return recent.map { w in
            let dateStr = df.string(from: w.startedAt)
            let exercises = w.exercises.sorted { $0.position < $1.position }.map { ex in
                let sets = ex.sets.sorted { $0.setNumber < $1.setNumber }.map { s in
                    let w = s.weightKg.map { String(format: "%.0f", $0) } ?? "-"
                    let r = s.reps.map { String($0) } ?? "-"
                    return "\(w)x\(r)"
                }.joined(separator: ", ")
                return "\(ex.name): \(sets)"
            }.joined(separator: "; ")
            return "\(dateStr) \(w.name): \(exercises)"
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Workout.self, Exercise.self, SetEntry.self, Message.self, configurations: config)
    return NavigationStack { ChatView() }.modelContainer(container)
}


