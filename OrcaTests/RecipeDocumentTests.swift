//
//  RecipeDocumentTests.swift
//  OrcaTests
//
//  Reading a recipe's steps out of its memory text, and writing them back without
//  disturbing the title and notes sitting above them.
//
//  Writing is the part worth pinning down: adding a step edits text that also holds
//  everything else about the recipe, so these cases are mostly about what survives.
//

import Testing
@testable import Orca

struct RecipeDocumentTests {

    static let sauce = """
    🍽 Sunday Sauce
    45 min · 6 servings

    Instructions:
    1. Brown the sausage
    2. Simmer 20 minutes
    3. Season to taste
    """

    static let noSteps = """
    🍽 Grandma's Soup
    Serves 4
    """

    // MARK: - Reading

    @Test("Title comes back without the emoji it's saved with")
    func readsTitle() {
        #expect(RecipeDocument.title(in: Self.sauce) == "Sunday Sauce")
        #expect(RecipeDocument.title(in: Self.noSteps) == "Grandma's Soup")
    }

    @Test("Steps come back in order, with the saved numbering removed")
    func readsSteps() {
        #expect(RecipeDocument.steps(in: Self.sauce) ==
                ["Brown the sausage", "Simmer 20 minutes", "Season to taste"])
    }

    @Test("A recipe with no instructions block has no steps, not a crash")
    func readsNoSteps() {
        #expect(RecipeDocument.steps(in: Self.noSteps).isEmpty)
        #expect(RecipeDocument.steps(in: "").isEmpty)
    }

    @Test("A step that mentions the marker mid-line doesn't start the block early")
    func markerMustBeItsOwnLine() {
        let text = """
        🍽 Pancakes
        See Instructions: on the packet
        """
        #expect(RecipeDocument.steps(in: text).isEmpty)
    }

    // MARK: - Writing

    @Test("Adding a step keeps the title and notes above it")
    func writeKeepsPreamble() {
        let updated = RecipeDocument.settingSteps(
            RecipeDocument.steps(in: Self.sauce) + ["Serve over rigatoni"], in: Self.sauce)

        #expect(updated.hasPrefix("🍽 Sunday Sauce\n45 min · 6 servings"))
        #expect(RecipeDocument.steps(in: updated) ==
                ["Brown the sausage", "Simmer 20 minutes", "Season to taste", "Serve over rigatoni"])
    }

    @Test("Steps can be added to a recipe that never had any")
    func writeToRecipeWithNoBlock() {
        let updated = RecipeDocument.settingSteps(["Soften the onions", "Add stock"], in: Self.noSteps)

        #expect(updated.hasPrefix("🍽 Grandma's Soup\nServes 4"))
        #expect(RecipeDocument.steps(in: updated) == ["Soften the onions", "Add stock"])
        #expect(updated.contains("1. Soften the onions"))
        #expect(updated.contains("2. Add stock"))
    }

    @Test("Removing every step leaves the recipe, not an empty instructions heading")
    func writeEmptyRemovesBlock() {
        let updated = RecipeDocument.settingSteps([], in: Self.sauce)
        #expect(!updated.contains(RecipeDocument.marker))
        #expect(RecipeDocument.title(in: updated) == "Sunday Sauce")
    }

    @Test("Blank steps are dropped rather than written as empty lines")
    func writeIgnoresBlanks() {
        let updated = RecipeDocument.settingSteps(["Chop the garlic", "   ", ""], in: Self.noSteps)
        #expect(RecipeDocument.steps(in: updated) == ["Chop the garlic"])
    }

    @Test("Reading then writing unchanged leaves the steps as they were")
    func roundTrips() {
        let once = RecipeDocument.settingSteps(RecipeDocument.steps(in: Self.sauce), in: Self.sauce)
        let twice = RecipeDocument.settingSteps(RecipeDocument.steps(in: once), in: once)

        #expect(RecipeDocument.steps(in: once) == RecipeDocument.steps(in: Self.sauce))
        #expect(twice == once, "writing the same steps twice should settle, not keep changing the text")
    }

    @Test("Steps saved with ) instead of . are read the same way")
    func toleratesOtherNumbering() {
        let text = """
        🍽 Toast
        Instructions:
        1) Toast the bread
        2) Butter it
        """
        #expect(RecipeDocument.steps(in: text) == ["Toast the bread", "Butter it"])
    }
}
