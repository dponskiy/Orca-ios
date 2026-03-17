//
//  RecipeCaptureView.swift
//  Orca
//
//  Created by David Piliponskiy on 3/15/26.
//

import SwiftUI
import SwiftData

struct RecipeCaptureView: View {
    @Binding var isPresented: Bool
    var onComplete: ((String) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Query private var echos: [Echo]

    @State private var urlText: String = ""
    @State private var isFetching = false
    @State private var errorMessage: String? = nil
    @FocusState private var urlFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.oceanTeal.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Image(systemName: "fork.knife")
                        .font(.system(size: 30))
                        .foregroundColor(.oceanTeal)
                }
                .padding(.top, 20)

                VStack(spacing: 8) {
                    Text("Save a Recipe")
                        .font(.custom("DMSans-Medium", size: 22))
                        .foregroundColor(.deepNavy)
                    Text("Paste a recipe URL and Orca will fetch the ingredients and instructions automatically.")
                        .font(.custom("DMSans-Regular", size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                // URL input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recipe URL")
                        .font(.custom("DMSans-Medium", size: 14))
                        .foregroundColor(.gray)

                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        TextField("https://...", text: $urlText)
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(.deepNavy)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .focused($urlFocused)
                        if !urlText.isEmpty {
                            Button {
                                urlText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.pearl)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.oceanTeal.opacity(0.3), lineWidth: 1))
                }
                .padding(.horizontal, 20)

                if let error = errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 13))
                            .foregroundColor(.coral)
                        Text(error)
                            .font(.custom("DMSans-Regular", size: 13))
                            .foregroundColor(.coral)
                    }
                    .padding(.horizontal, 20)
                }

                // Fetch button
                Button {
                    fetchRecipe()
                } label: {
                    HStack(spacing: 8) {
                        if isFetching {
                            ProgressView().scaleEffect(0.8).tint(.white)
                            Text("Fetching recipe...")
                                .font(.custom("DMSans-Medium", size: 16))
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 16))
                            Text("Fetch Recipe")
                                .font(.custom("DMSans-Medium", size: 16))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(urlText.isEmpty ? Color.gray.opacity(0.3) : Color.oceanTeal)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(urlText.isEmpty || isFetching)
                .padding(.horizontal, 20)

                Spacer()
            }
            .background(Color.white)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(.gray)
                }
            }
            .onAppear { urlFocused = true }
        }
    }

    private func fetchRecipe() {
        guard !urlText.isEmpty else { return }
        errorMessage = nil
        isFetching = true
        urlFocused = false

        Task {
            do {
                let recipe = try await RecipeExtractor.shared.extract(from: urlText)
                await MainActor.run {
                    saveRecipe(recipe)
                }
            } catch {
                await MainActor.run {
                    isFetching = false
                    errorMessage = "Couldn't fetch recipe. Check the URL and try again."
                }
            }
        }
    }

    private func saveRecipe(_ recipe: RecipeResult) {
        let cookingEcho = echos.first {
            $0.name.lowercased().contains("cook") ||
            $0.emoji == "🍳" || $0.emoji == "👨‍🍳"
        } ?? echos.first { $0.name == "Notes" }

        let echoId = cookingEcho?.id ?? UUID()

        var parts: [String] = []
        parts.append("🍽 \(recipe.title)")
        var meta: [String] = []
        if let prep = recipe.prepTime { meta.append("Prep: \(prep)") }
        if let cook = recipe.cookTime { meta.append("Cook: \(cook)") }
        if let srv = recipe.servings { meta.append("Serves: \(srv)") }
        if !meta.isEmpty { parts.append(meta.joined(separator: " · ")) }
        if !recipe.instructions.isEmpty {
            parts.append("\nInstructions:")
            for (i, step) in recipe.instructions.enumerated() {
                parts.append("\(i + 1). \(step)")
            }
        }

        let memory = Memory(text: parts.joined(separator: "\n"), echoId: echoId, captureType: .typed)
        memory.url = urlText
        memory.hasChecklist = !recipe.ingredients.isEmpty

        modelContext.insert(memory)

        for (index, ingredient) in recipe.ingredients.enumerated() {
            let subTask = SubTask(memoryId: memory.id, text: ingredient, sortOrder: index)
            modelContext.insert(subTask)
        }

        if let userId = authService.userId {
            Task {
                await SupabaseSyncService.shared.pushMemory(memory, userId: userId)
            }
        }

        isFetching = false
        isPresented = false
        onComplete?("Recipe saved to \(cookingEcho?.name ?? "Cooking") 👨‍🍳")
    }
}