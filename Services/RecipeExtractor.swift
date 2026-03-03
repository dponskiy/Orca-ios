//
//  RecipeExtractor.swift
//  Orca
//
//  Created by David Piliponskiy on 3/3/26.
//

import Foundation

// MARK: - Recipe Result

struct RecipeResult {
    let title: String
    let ingredients: [String]
    let instructions: [String]
    let imageURL: String?
    let prepTime: String?
    let cookTime: String?
    let servings: String?
}

// MARK: - Extractor

actor RecipeExtractor {
    
    static let shared = RecipeExtractor()
    
    enum RecipeError: LocalizedError {
        case invalidURL
        case networkError(Error)
        case noRecipeFound
        case parseError
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:            return "Invalid URL"
            case .networkError(let e):   return "Network error: \(e.localizedDescription)"
            case .noRecipeFound:         return "No recipe found on this page"
            case .parseError:            return "Couldn't parse recipe data"
            }
        }
    }
    
    // MARK: - Public Entry Point
    
    func extract(from urlString: String) async throws -> RecipeResult {
        guard let url = URL(string: urlString) else {
            throw RecipeError.invalidURL
        }
        
        let html: String
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let string = String(data: data, encoding: .utf8)
                           ?? String(data: data, encoding: .isoLatin1) else {
                throw RecipeError.parseError
            }
            html = string
        } catch let error as RecipeError {
            throw error
        } catch {
            throw RecipeError.networkError(error)
        }
        
        return try parseRecipe(from: html)
    }
    
    // MARK: - Parsing
    
    private func parseRecipe(from html: String) throws -> RecipeResult {
        let scriptPattern = #"<script[^>]*type=["']application/ld\+json["'][^>]*>([\s\S]*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: scriptPattern, options: .caseInsensitive) else {
            throw RecipeError.parseError
        }
        
        let nsHTML = html as NSString
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        
        for match in matches {
            let range = match.range(at: 1)
            guard range.location != NSNotFound else { continue }
            let jsonString = nsHTML.substring(with: range)
            
            guard let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) else { continue }
            
            // Single object
            if let dict = json as? [String: Any],
               let result = try? extractFromDict(dict) {
                return result
            }
            
            // Array of objects
            if let array = json as? [[String: Any]] {
                for dict in array {
                    if let result = try? extractFromDict(dict) {
                        return result
                    }
                }
            }
            
            // @graph wrapper (common on WordPress sites)
            if let dict = json as? [String: Any],
               let graph = dict["@graph"] as? [[String: Any]] {
                for node in graph {
                    if let result = try? extractFromDict(node) {
                        return result
                    }
                }
            }
        }
        
        throw RecipeError.noRecipeFound
    }
    
    private func extractFromDict(_ dict: [String: Any]) throws -> RecipeResult {
        // Check @type — can be a String or [String]
        let typeMatches: Bool
        if let singleType = dict["@type"] as? String {
            typeMatches = singleType.lowercased() == "recipe"
        } else if let typeArray = dict["@type"] as? [String] {
            typeMatches = typeArray.map { $0.lowercased() }.contains("recipe")
        } else {
            typeMatches = false
        }
        
        guard typeMatches else {
            throw RecipeError.noRecipeFound
        }
        
        let title = dict["name"] as? String ?? "Recipe"
        
        // Ingredients
        let ingredients: [String]
        if let raw = dict["recipeIngredient"] as? [String] {
            ingredients = raw
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        } else {
            ingredients = []
        }
        
        // Instructions
        let instructions: [String]
        if let raw = dict["recipeInstructions"] as? [Any] {
            instructions = parseInstructions(raw)
        } else if let raw = dict["recipeInstructions"] as? String {
            instructions = [raw]
        } else {
            instructions = []
        }
        
        guard !ingredients.isEmpty || !instructions.isEmpty else {
            throw RecipeError.noRecipeFound
        }
        
        // Image
        let imageURL: String?
        if let img = dict["image"] as? String {
            imageURL = img
        } else if let imgDict = dict["image"] as? [String: Any] {
            imageURL = imgDict["url"] as? String
        } else if let imgArray = dict["image"] as? [String] {
            imageURL = imgArray.first
        } else {
            imageURL = nil
        }
        
        let prepTime = humanReadableDuration(dict["prepTime"] as? String)
        let cookTime = humanReadableDuration(dict["cookTime"] as? String)
        let servings = (dict["recipeYield"] as? String)
                    ?? (dict["recipeYield"] as? [String])?.first
        
        return RecipeResult(
            title: title,
            ingredients: ingredients,
            instructions: instructions,
            imageURL: imageURL,
            prepTime: prepTime,
            cookTime: cookTime,
            servings: servings
        )
    }
    
    // MARK: - Instruction Parsing
    
    private func parseInstructions(_ raw: [Any]) -> [String] {
        var steps: [String] = []
        for item in raw {
            if let str = item as? String {
                let cleaned = str.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty { steps.append(cleaned) }
            } else if let dict = item as? [String: Any] {
                if let text = dict["text"] as? String {
                    let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty { steps.append(cleaned) }
                } else if let subItems = dict["itemListElement"] as? [Any] {
                    steps.append(contentsOf: parseInstructions(subItems))
                }
            }
        }
        return steps
    }
    
    // MARK: - ISO 8601 Duration → Human Readable
    
    private func humanReadableDuration(_ iso: String?) -> String? {
        guard let iso = iso else { return nil }
        let pattern = #"PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: iso, range: NSRange(iso.startIndex..., in: iso)) else {
            return nil
        }
        let ns = iso as NSString
        var result = ""
        if match.range(at: 1).location != NSNotFound {
            result += "\(ns.substring(with: match.range(at: 1)))h "
        }
        if match.range(at: 2).location != NSNotFound {
            result += "\(ns.substring(with: match.range(at: 2)))m"
        }
        let trimmed = result.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Memory Population Helper

extension RecipeExtractor {
    
    /// Formats a RecipeResult into a clean memory text string.
    static func memoryText(from recipe: RecipeResult) -> String {
        var parts: [String] = []
        parts.append("🍽 \(recipe.title)")
        
        var meta: [String] = []
        if let prep = recipe.prepTime  { meta.append("Prep: \(prep)") }
        if let cook = recipe.cookTime  { meta.append("Cook: \(cook)") }
        if let srv  = recipe.servings  { meta.append("Serves: \(srv)") }
        if !meta.isEmpty { parts.append(meta.joined(separator: " · ")) }
        
        if !recipe.instructions.isEmpty {
            parts.append("\nInstructions:")
            for (i, step) in recipe.instructions.enumerated() {
                parts.append("\(i + 1). \(step)")
            }
        }
        
        return parts.joined(separator: "\n")
    }
}
