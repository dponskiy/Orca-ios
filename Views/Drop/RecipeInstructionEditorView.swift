//
//  RecipeInstructionEditorView.swift
//  Orca
//

import SwiftUI
import SwiftData

struct RecipeInstructionEditorView: View {
    @Bindable var memory: Memory
    @Environment(\.dismiss) private var dismiss

    @State private var instructions: [String] = []
    @State private var newInstruction: String = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    Section {
                        ForEach(Array(instructions.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1).")
                                    .font(.custom("DMMono-Regular", size: 13))
                                    .foregroundColor(.oceanTeal)
                                    .frame(width: 20, alignment: .leading)
                                    .padding(.top, 2)
                                Text(step)
                                    .font(.custom("DMSans-Regular", size: 15))
                                    .foregroundColor(.deepNavy)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete { indexSet in
                            instructions.remove(atOffsets: indexSet)
                        }
                        .onMove { from, to in
                            instructions.move(fromOffsets: from, toOffset: to)
                        }

                        HStack(alignment: .top, spacing: 10) {
                            Text("\(instructions.count + 1).")
                                .font(.custom("DMMono-Regular", size: 13))
                                .foregroundColor(.gray.opacity(0.4))
                                .frame(width: 20, alignment: .leading)
                                .padding(.top, 10)
                            TextField("Add a step...", text: $newInstruction, axis: .vertical)
                                .font(.custom("DMSans-Regular", size: 15))
                                .foregroundColor(.deepNavy)
                                .submitLabel(.done)
                                .focused($inputFocused)
                                .onSubmit { addStep() }
                                .lineLimit(1...4)
                            if !newInstruction.isEmpty {
                                Button { addStep() } label: {
                                    Text("Add")
                                        .font(.custom("DMSans-Medium", size: 13))
                                        .foregroundColor(.oceanTeal)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 8)
                            }
                        }
                        .padding(.vertical, 2)
                    } header: {
                        HStack {
                            Text("Steps")
                                .font(.custom("DMSans-Medium", size: 13))
                                .foregroundColor(.gray)
                                .textCase(nil)
                            Spacer()
                            if !instructions.isEmpty {
                                Text("\(instructions.count) steps")
                                    .font(.custom("DMMono-Regular", size: 11))
                                    .foregroundColor(.gray)
                            }
                        }
                    } footer: {
                        if !instructions.isEmpty {
                            Text("Swipe left to delete · drag to reorder")
                                .font(.custom("DMSans-Regular", size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .environment(\.editMode, .constant(.active))

                VStack(spacing: 0) {
                    Divider()
                    Button { saveInstructions() } label: {
                        Text("Save Instructions")
                            .font(.custom("DMSans-Medium", size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.oceanTeal)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.white)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Edit Instructions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
            .onAppear { loadInstructions() }
        }
    }

    private func loadInstructions() {
        let lines = memory.text.components(separatedBy: "\n")
        var capturing = false
        var steps: [String] = []
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces) == "Instructions:" {
                capturing = true
                continue
            }
            if capturing {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { continue }
                let stripped = trimmed.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
                if !stripped.isEmpty { steps.append(stripped) }
            }
        }
        instructions = steps
    }

    private func addStep() {
        let trimmed = newInstruction.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        instructions.append(trimmed)
        newInstruction = ""
    }

    private func saveInstructions() {
        // Preserve everything before \nInstructions: block
        let base: String
        if let range = memory.text.range(of: "\nInstructions:") {
            base = String(memory.text[memory.text.startIndex..<range.lowerBound])
        } else {
            base = memory.text
        }

        var parts = [base]
        if !instructions.isEmpty {
            parts.append("\nInstructions:")
            for (i, step) in instructions.enumerated() {
                parts.append("\(i + 1). \(step)")
            }
        }
        memory.text = parts.joined(separator: "\n")
        dismiss()
    }
}
