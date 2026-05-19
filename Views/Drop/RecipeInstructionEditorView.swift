//
//  RecipeInstructionEditorView.swift
//  Orca
//

import SwiftUI
import SwiftData

struct RecipeInstructionEditorView: View {
    @Bindable var memory: Memory
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allSubTasks: [SubTask]

    @State private var instructions: [String] = []
    @State private var newInstruction: String = ""
    @State private var newIngredient: String = ""
    @FocusState private var focusedIngredient: SubTask.ID?
    @FocusState private var focusedInstructionIndex: Int?
    @FocusState private var newIngredientFocused: Bool
    @FocusState private var newInstructionFocused: Bool

    private var ingredients: [SubTask] {
        allSubTasks.filter { $0.memoryId == memory.id }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    // MARK: Ingredients
                    Section {
                        ForEach(ingredients) { subTask in
                            let bindable = Bindable(subTask)
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color.oceanTeal)
                                    .frame(width: 6, height: 6)
                                TextField("Ingredient", text: bindable.text)
                                    .font(.custom("DMSans-Regular", size: 15))
                                    .foregroundColor(.deepNavy)
                                    .focused($focusedIngredient, equals: subTask.id)
                                    .submitLabel(.next)
                                    .onSubmit { newIngredientFocused = true }
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete { indexSet in
                            for i in indexSet {
                                modelContext.delete(ingredients[i])
                            }
                        }
                        .onMove { from, to in
                            var reordered = ingredients
                            reordered.move(fromOffsets: from, toOffset: to)
                            for (index, subTask) in reordered.enumerated() {
                                subTask.sortOrder = index
                            }
                        }

                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 18))
                                .foregroundColor(.oceanTeal.opacity(0.6))
                            TextField("Add ingredient...", text: $newIngredient)
                                .font(.custom("DMSans-Regular", size: 15))
                                .foregroundColor(.deepNavy)
                                .focused($newIngredientFocused)
                                .submitLabel(.done)
                                .onSubmit { addIngredient() }
                            if !newIngredient.isEmpty {
                                Button { addIngredient() } label: {
                                    Text("Add")
                                        .font(.custom("DMSans-Medium", size: 13))
                                        .foregroundColor(.oceanTeal)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    } header: {
                        HStack {
                            Text("Ingredients")
                                .font(.custom("DMSans-Medium", size: 13))
                                .foregroundColor(.gray)
                                .textCase(nil)
                            Spacer()
                            if !ingredients.isEmpty {
                                Text("\(ingredients.count) items")
                                    .font(.custom("DMMono-Regular", size: 11))
                                    .foregroundColor(.gray)
                            }
                        }
                    } footer: {
                        if !ingredients.isEmpty {
                            Text("Tap to edit · swipe to delete · drag to reorder")
                                .font(.custom("DMSans-Regular", size: 12))
                                .foregroundColor(.gray)
                        }
                    }

                    // MARK: Instructions
                    Section {
                        ForEach(instructions.indices, id: \.self) { index in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1).")
                                    .font(.custom("DMMono-Regular", size: 13))
                                    .foregroundColor(.oceanTeal)
                                    .frame(width: 20, alignment: .leading)
                                    .padding(.top, 10)
                                TextField("Step \(index + 1)", text: $instructions[index], axis: .vertical)
                                    .font(.custom("DMSans-Regular", size: 15))
                                    .foregroundColor(.deepNavy)
                                    .focused($focusedInstructionIndex, equals: index)
                                    .submitLabel(.next)
                                    .onSubmit { newInstructionFocused = true }
                                    .lineLimit(1...5)
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
                                .focused($newInstructionFocused)
                                .submitLabel(.done)
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
                            Text("Instructions")
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
                            Text("Tap to edit · swipe to delete · drag to reorder")
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
                        Text("Save Recipe")
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
            .navigationTitle("Edit Recipe")
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

    private func addIngredient() {
        let trimmed = newIngredient.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let nextOrder = (ingredients.map { $0.sortOrder }.max() ?? -1) + 1
        let subTask = SubTask(memoryId: memory.id, text: trimmed, sortOrder: nextOrder)
        modelContext.insert(subTask)
        newIngredient = ""
    }

    private func addStep() {
        let trimmed = newInstruction.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        instructions.append(trimmed)
        newInstruction = ""
    }

    private func saveInstructions() {
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
