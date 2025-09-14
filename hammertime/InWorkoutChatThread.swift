//
//  InWorkoutChatThread.swift
//  hammertime
//

import SwiftUI
import SwiftData

struct WorkoutChatThread: View {
    @Environment(\.modelContext) private var context
    let workoutId: UUID

    @Query private var messages: [Message]

    init(workoutId: UUID) {
        self.workoutId = workoutId
        let wid: UUID? = workoutId
        let predicate = #Predicate<Message> { $0.workout?.id == wid }
        _messages = Query(filter: predicate, sort: [SortDescriptor(\Message.createdAt, order: .forward)])
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(messages) { m in
                    HStack(alignment: .top) {
                        if m.role == "assistant" {
                            Text(m.content)
                                .foregroundStyle(.secondary)
                                .font(.system(size: 18))
                            Spacer(minLength: 0)
                        } else {
                            Spacer(minLength: 0)
                            Text(m.content)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.brandYellow)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.05), lineWidth: 1))
                                )
                                .font(.system(size: 18))
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .id(m.id)
                }
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .onChange(of: messages.last?.id) { _, newValue in
                if let id = newValue {
                    withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
        }
    }
}


