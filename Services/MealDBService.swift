// MealDBService.swift — TheMealDB API (free, no key required)

import Foundation

final class MealDBService {
    static let shared = MealDBService()
    private let base = "https://www.themealdb.com/api/json/v1/1"

    // MARK: - Models

    struct MealSummary: Decodable, Identifiable {
        let idMeal: String
        let strMeal: String
        let strMealThumb: String
        var id: String { idMeal }
    }

    private struct ListResponse: Decodable {
        let meals: [MealSummary]?
    }

    // MARK: - Fetch

    func fetchMeals(category: String) async throws -> [MealSummary] {
        try await fetch(query: "c", value: category)
    }

    func fetchMeals(area: String) async throws -> [MealSummary] {
        try await fetch(query: "a", value: area)
    }

    private func fetch(query: String, value: String) async throws -> [MealSummary] {
        let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
        let url = URL(string: "\(base)/filter.php?\(query)=\(encoded)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(ListResponse.self, from: data)
        // Shuffle so each open shows different recipes; cap at 8
        return Array((response.meals ?? []).shuffled().prefix(8))
    }

    // MARK: - Full Recipe

    func fetchRecipe(id: String) async throws -> RecipeResult {
        let url = URL(string: "\(base)/lookup.php?i=\(id)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let meals = json["meals"] as? [[String: Any]],
            let meal = meals.first
        else { throw URLError(.badServerResponse) }

        var ingredients: [String] = []
        for i in 1...20 {
            let ing  = (meal["strIngredient\(i)"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            let meas = (meal["strMeasure\(i)"]    as? String ?? "").trimmingCharacters(in: .whitespaces)
            guard !ing.isEmpty else { continue }
            ingredients.append(meas.isEmpty ? ing : "\(meas) \(ing)")
        }

        let title        = meal["strMeal"]        as? String ?? "Recipe"
        let imageURL     = meal["strMealThumb"]   as? String
        let instructions = meal["strInstructions"] as? String ?? ""

        return RecipeResult(
            title: title,
            ingredients: ingredients,
            instructions: instructions.components(separatedBy: "\r\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
            imageURL: imageURL,
            prepTime: nil,
            cookTime: nil,
            servings: nil
        )
    }
}
