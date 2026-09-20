//
//  GroceryAisleTests.swift
//  OrcaTests
//
//  Which aisle a grocery item lands in. Add a line whenever something turns up in the
//  wrong section — the item as it appears on the list, and where you'd walk to find it.
//

import Testing
@testable import Orca

struct GroceryAisleTests {

    struct Item: Sendable, CustomStringConvertible {
        let name: String
        let aisle: String
        var description: String { name }
        init(_ name: String, _ aisle: String) { self.name = name; self.aisle = aisle }
    }

    static let produce = "🥬 Produce", meat = "🥩 Meat", seafood = "🐟 Seafood"
    static let dairy = "🥛 Dairy & Eggs", deli = "🧀 Deli & Prepared", bakery = "🍞 Bakery & Bread"
    static let frozen = "❄️ Frozen", canned = "🥫 Canned & Jarred", grains = "🌾 Pasta, Rice & Grains"
    static let breakfast = "🥣 Breakfast", snacks = "🍿 Snacks", drinks = "🥤 Beverages"
    static let alcohol = "🍷 Beer, Wine & Spirits", condiments = "🫙 Condiments & Sauces"
    static let oils = "🫒 Oils & Vinegars", baking = "🧂 Baking & Spices"
    static let bodyCare = "🧴 Body Care", household = "🏠 Household", pet = "🐾 Pet"

    static let cases: [Item] = [

        // --- Reported ---
        Item("fresca", drinks),
        Item("ground spicy italian sausage", meat),

        // --- A short word hiding inside a longer one ---
        Item("champagne", alcohol),          // "ham"
        Item("graham crackers", snacks),     // "ham"
        Item("shampoo", bodyCare),           // "ham"
        Item("popcorn", snacks),             // "corn"
        Item("lemonade", drinks),            // "lemon"
        Item("horseradish", condiments),     // "radish"
        Item("rolled oats", grains),         // "roll"
        Item("herbal tea", drinks),          // "herb"

        // --- Named after something else ---
        Item("dr pepper", drinks),
        Item("ginger ale", drinks),
        Item("root beer", drinks),
        Item("orange juice", drinks),
        Item("coconut water", drinks),
        Item("baking soda", baking),
        Item("peanut butter", breakfast),
        Item("ground ginger", baking),

        // --- The last word is the thing you're buying ---
        Item("potato chips", snacks),
        Item("tortilla chips", snacks),
        Item("banana bread", bakery),
        Item("cinnamon rolls", bakery),
        Item("hamburger buns", bakery),
        Item("strawberry jam", breakfast),
        Item("honey mustard", condiments),
        Item("basil pesto", condiments),
        Item("fish sauce", condiments),
        Item("smoked salmon", deli),
        Item("chocolate chips", baking),
        Item("plastic wrap", household),
        Item("steak sauce", condiments),
        Item("dried cranberries", snacks),

        // --- Already right, and must stay right ---
        Item("chicken breast", meat),
        Item("ground beef", meat),
        Item("salmon", seafood),
        Item("sage", produce),
        Item("cilantro", produce),
        Item("cherry tomatoes", produce),
        Item("garlic", produce),
        Item("garlic cloves", produce),
        Item("butternut squash", produce),
        Item("eggs", dairy),
        Item("cream cheese", dairy),
        Item("buttermilk", dairy),
        Item("pepper jack", dairy),
        Item("almond milk", dairy),
        Item("sourdough bread", bakery),
        Item("frozen broccoli", frozen),
        Item("canned tomatoes", canned),
        Item("chicken broth", canned),
        Item("spaghetti", grains),
        Item("black pepper", baking),
        Item("all purpose flour", baking),
        Item("olive oil", oils),
        Item("rice vinegar", oils),
        Item("coffee", drinks),
        Item("paper towels", household),
        Item("dog food", pet),
        Item("pea", produce),
    ]

    @Test("Item lands in the right aisle", arguments: cases)
    func aisle(_ c: Item) {
        let got = GroceryAisles.category(for: c.name)
        #expect(got == c.aisle, "expected \(c.aisle), got \(got)")
    }
}
