//
//  RecipeImportService.swift
//  Orca
//

import SwiftData
import Foundation

// Lightweight payload for peer-to-peer recipe sharing (Option A: base64 JSON in deep link)
struct SharedRecipePayload: Codable {
    let title: String
    let ingredients: [String]
    let instructions: [String]
    let prepTime: String?
    let cookTime: String?
    let servings: String?

    /// Encode to base64 for use in `orca://recipe?data=<base64>`
    func toBase64() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return data.base64EncodedString()
    }

    /// Decode from base64
    static func from(base64 string: String) -> SharedRecipePayload? {
        guard let data = Data(base64Encoded: string) else { return nil }
        return try? JSONDecoder().decode(SharedRecipePayload.self, from: data)
    }
}

@Observable
class RecipeImportService {
    static let shared = RecipeImportService()
    private init() {}

    /// Saves a recipe directly from a SharedRecipePayload (no network fetch). Returns the title.
    func importAndSave(from payload: SharedRecipePayload, modelContext: ModelContext, echos: [Echo]) -> String? {
        let cookingEcho = echos.first {
            $0.name.lowercased().contains("cook") ||
            $0.name.lowercased().contains("recipe") ||
            $0.emoji == "🍳" || $0.emoji == "🍽️"
        } ?? echos.first
        guard let echoId = cookingEcho?.id else { return nil }

        var parts: [String] = ["🍽 \(payload.title)"]
        var meta: [String] = []
        if let prep = payload.prepTime { meta.append("Prep: \(prep)") }
        if let cook = payload.cookTime { meta.append("Cook: \(cook)") }
        if let srv  = payload.servings { meta.append("Serves: \(srv)") }
        if !meta.isEmpty { parts.append(meta.joined(separator: " · ")) }
        if !payload.instructions.isEmpty {
            parts.append("\nInstructions:")
            for (i, step) in payload.instructions.enumerated() {
                parts.append("\(i + 1). \(step)")
            }
        }

        let memory = Memory(text: parts.joined(separator: "\n"), echoId: echoId)
        memory.hasChecklist = !payload.ingredients.isEmpty
        memory.isActionable = false
        modelContext.insert(memory)
        for (index, ingredient) in payload.ingredients.enumerated() {
            modelContext.insert(SubTask(memoryId: memory.id, text: ingredient, sortOrder: index))
        }
        return payload.title
    }

    /// Fetches the recipe at `urlString`, saves it as a Memory + SubTasks, and returns the recipe title.
    /// Returns nil if fetch or save fails.
    func importAndSave(from urlString: String, modelContext: ModelContext, echos: [Echo]) async -> String? {
        guard let recipe = try? await RecipeExtractor.shared.extract(from: urlString) else { return nil }

        let cookingEcho = echos.first {
            $0.name.lowercased().contains("cook") ||
            $0.name.lowercased().contains("recipe") ||
            $0.emoji == "🍳" || $0.emoji == "🍽️"
        } ?? echos.first

        guard let echoId = cookingEcho?.id else { return nil }

        var parts: [String] = ["🍽 \(recipe.title)"]
        var meta: [String] = []
        if let prep = recipe.prepTime { meta.append("Prep: \(prep)") }
        if let cook = recipe.cookTime { meta.append("Cook: \(cook)") }
        if let srv  = recipe.servings { meta.append("Serves: \(srv)") }
        if !meta.isEmpty { parts.append(meta.joined(separator: " · ")) }
        if !recipe.instructions.isEmpty {
            parts.append("\nInstructions:")
            for (i, step) in recipe.instructions.enumerated() {
                parts.append("\(i + 1). \(step)")
            }
        }

        let memory = Memory(text: parts.joined(separator: "\n"), echoId: echoId)
        memory.url = urlString
        memory.hasChecklist = !recipe.ingredients.isEmpty
        modelContext.insert(memory)

        for (index, ingredient) in recipe.ingredients.enumerated() {
            let subTask = SubTask(memoryId: memory.id, text: ingredient, sortOrder: index)
            modelContext.insert(subTask)
        }

        return recipe.title
    }
}
