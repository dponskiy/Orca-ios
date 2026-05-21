//
//  RecipeBuilderView.swift
//  Orca
//
//  Created by David Piliponskiy on 4/12/26.
//

import SwiftUI
import SwiftData
import CoreSpotlight

struct RecipeBuilderView: View {
    var onComplete: ((String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Query private var echos: [Echo]

    @State private var recipeTitle: String = ""
    @State private var ingredients: [String] = []
    @State private var instructions: [String] = []
    @State private var newIngredient: String = ""
    @State private var newInstruction: String = ""
    @State private var savedMemory: Memory? = nil
    @FocusState private var titleFocused: Bool
    @FocusState private var ingredientFocused: Bool
    @FocusState private var instructionFocused: Bool
    @FocusState private var focusedIngredientIndex: Int?
    @FocusState private var focusedInstructionIndex: Int?

    var canSave: Bool {
        !recipeTitle.trimmingCharacters(in: .whitespaces).isEmpty && !ingredients.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    // Title section
                    Section {
                        TextField("e.g. Chicken Tikka Masala", text: $recipeTitle)
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(.deepNavy)
                            .focused($titleFocused)
                    } header: {
                        Text("Recipe name")
                            .font(.custom("DMSans-Medium", size: 13))
                            .foregroundColor(.gray)
                            .textCase(nil)
                    }

                    // Ingredients section
                    Section {
                        ForEach(ingredients.indices, id: \.self) { index in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color.oceanTeal)
                                    .frame(width: 6, height: 6)
                                TextField("Ingredient", text: $ingredients[index])
                                    .font(.custom("DMSans-Regular", size: 15))
                                    .foregroundColor(.deepNavy)
                                    .focused($focusedIngredientIndex, equals: index)
                                    .submitLabel(.next)
                                    .onSubmit { ingredientFocused = true }
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete { indexSet in
                            ingredients.remove(atOffsets: indexSet)
                        }

                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 18))
                                .foregroundColor(.oceanTeal.opacity(0.6))
                            TextField("Add ingredient...", text: $newIngredient)
                                .font(.custom("DMSans-Regular", size: 15))
                                .foregroundColor(.deepNavy)
                                .submitLabel(.done)
                                .focused($ingredientFocused)
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
                                Text("\(ingredients.count) added")
                                    .font(.custom("DMMono-Regular", size: 11))
                                    .foregroundColor(.gray)
                            }
                        }
                    } footer: {
                        if ingredients.isEmpty {
                            Text("Add at least one ingredient to save the recipe.")
                                .font(.custom("DMSans-Regular", size: 12))
                                .foregroundColor(.gray)
                        } else {
                            Text("Tap to edit · swipe to delete")
                                .font(.custom("DMSans-Regular", size: 12))
                                .foregroundColor(.gray)
                        }
                    }

                    // Instructions section
                    Section {
                        ForEach(instructions.indices, id: \.self) { index in
                            HStack(alignment: .center, spacing: 10) {
                                Text("\(index + 1).")
                                    .font(.custom("DMMono-Regular", size: 13))
                                    .foregroundColor(.oceanTeal)
                                    .frame(width: 20, alignment: .leading)
                                TextField("Step \(index + 1)", text: $instructions[index])
                                    .font(.custom("DMSans-Regular", size: 15))
                                    .foregroundColor(.deepNavy)
                                    .focused($focusedInstructionIndex, equals: index)
                                    .submitLabel(.next)
                                    .onSubmit { instructionFocused = true }
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete { indexSet in
                            instructions.remove(atOffsets: indexSet)
                        }

                        HStack(alignment: .center, spacing: 10) {
                            Text("\(instructions.count + 1).")
                                .font(.custom("DMMono-Regular", size: 13))
                                .foregroundColor(.gray.opacity(0.4))
                                .frame(width: 20, alignment: .leading)
                            TextField("Add a step...", text: $newInstruction)
                                .font(.custom("DMSans-Regular", size: 15))
                                .foregroundColor(.deepNavy)
                                .submitLabel(.done)
                                .focused($instructionFocused)
                                .onSubmit { addInstruction() }
                            if !newInstruction.isEmpty {
                                Button { addInstruction() } label: {
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
                            Text("Tap to edit · swipe to delete")
                                .font(.custom("DMSans-Regular", size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .listStyle(.insetGrouped)

                // Save button
                VStack(spacing: 0) {
                    Divider()
                    Button { saveRecipe() } label: {
                        Text("Save Recipe")
                            .font(.custom("DMSans-Medium", size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(canSave ? Color.oceanTeal : Color.gray.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!canSave)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.white)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Build a Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
            .onAppear { titleFocused = true }
            .sheet(item: $savedMemory, onDismiss: {
                onComplete?("Recipe saved to Cooking 👨‍🍳")
                dismiss()
            }) { memory in
                MemoryDetailView(memory: memory)
            }
        }
    }

    private func addIngredient() {
        let trimmed = newIngredient.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        ingredients.append(trimmed)
        newIngredient = ""
    }

    private func addInstruction() {
        let trimmed = newInstruction.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        instructions.append(trimmed)
        newInstruction = ""
    }

    private func saveRecipe() {
        let title = recipeTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty, !ingredients.isEmpty else { return }

        let cookingEcho = echos.first {
            $0.name.lowercased().contains("cook") ||
            $0.emoji == "🍳" || $0.emoji == "👨‍🍳"
        } ?? echos.first { $0.name == "Notes" }

        let echoId = cookingEcho?.id ?? UUID()

        var parts: [String] = []
        parts.append("🍽 \(title)")

        if !instructions.isEmpty {
            parts.append("\nInstructions:")
            for (i, step) in instructions.enumerated() {
                parts.append("\(i + 1). \(step)")
            }
        }

        let memory = Memory(
            text: parts.joined(separator: "\n"),
            echoId: echoId,
            captureType: .typed
        )
        memory.hasChecklist = true

        modelContext.insert(memory)
        SpotlightService.shared.indexMemory(
            memory,
            echoName: cookingEcho?.name ?? "Cooking",
            echoEmoji: cookingEcho?.emoji ?? "🍳"
        )

        var createdSubTasks: [SubTask] = []
        for (index, ingredient) in ingredients.enumerated() {
            let subTask = SubTask(memoryId: memory.id, text: ingredient, sortOrder: index)
            modelContext.insert(subTask)
            createdSubTasks.append(subTask)
        }

        if let userId = authService.userId {
            Task {
                await SupabaseSyncService.shared.pushMemory(memory, userId: userId)
                for subTask in createdSubTasks {
                    await SupabaseSyncService.shared.pushSubTask(subTask, userId: userId)
                }
            }
        }

        savedMemory = memory
    }
}
