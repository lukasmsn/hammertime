//
//  TemplatesView.swift
//  hammertime
//

import SwiftUI
import SwiftData

struct TemplatesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    var onStart: (WorkoutTemplate) -> Void

    var body: some View {
        List {
            Section("Build from history") {
                Button {
                    try? TemplatesService.buildTemplatesFromHistory(context: context)
                } label: {
                    Label("Scan workouts and build templates", systemImage: "wand.and.stars")
                }
            }

            Section("Templates") {
                if templates.isEmpty {
                    Text("No templates yet. Tap the wand to build from history.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(templates) { t in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(t.name).font(.headline)
                                Spacer()
                                Button("Start") { onStart(t) }
                            }
                            Text(t.exercises.sorted { $0.position < $1.position }.map { $0.name }.joined(separator: ", "))
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .navigationTitle("Templates")
    }
}


