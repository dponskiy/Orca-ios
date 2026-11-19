//
//  CookTimeParsingTests.swift
//  OrcaTests
//
//  The times a recipe step should offer as timers, and the numbers it must leave alone.
//
//  Add a line to `cases` whenever a step reads wrong: the step, and the timers a cook
//  would expect from it, as (what was written, minutes). An empty expectation means no
//  timers at all — which is the point of half this file, because a recipe is mostly
//  numbers that aren't times.
//

import Testing
@testable import Orca

struct CookTimeParsingTests {

    /// One step and the timers it should produce. A struct rather than a tuple so each
    /// case shows up as its own named test.
    struct Step: Sendable, CustomStringConvertible {
        let text: String
        let timers: [(String, Int)]
        var description: String { text }
        init(_ text: String, _ timers: [(String, Int)]) {
            self.text = text; self.timers = timers
        }
    }

    static let cases: [Step] = [

        // --- The ordinary ones ---
        Step("Simmer for 20 minutes", [("20 minutes", 20)]),
        Step("Bake for 45 min", [("45 min", 45)]),
        Step("Rest 10 mins before slicing", [("10 mins", 10)]),
        Step("Blanch for 90 seconds", [("90 seconds", 1)]),      // 90s rounds down in minutes
        Step("Roast for 1 hour", [("1 hour", 60)]),
        Step("Chill for 2 hrs", [("2 hrs", 120)]),

        // --- A range starts at the lower end: check early rather than burn it ---
        Step("Bake 35-40 minutes until golden", [("35-40 minutes", 35)]),
        Step("Saute 2 to 3 min", [("2 to 3 min", 2)]),
        Step("Simmer 10–15 minutes", [("10–15 minutes", 10)]),

        // --- One timer, not two ---
        Step("Braise for 1 hour 20 minutes", [("1 hour 20 minutes", 80)]),
        Step("Cook 2 hrs and 5 min", [("2 hrs and 5 min", 125)]),

        // --- Several timers in one step, in the order written ---
        Step("Simmer 20 minutes, then bake 35-40 minutes",
             [("20 minutes", 20), ("35-40 minutes", 35)]),
        Step("Rest 5 min, roast 1 hour, rest another 10 minutes",
             [("5 min", 5), ("1 hour", 60), ("10 minutes", 10)]),

        // --- Written out, and halves ---
        Step("Let it rise for half an hour", [("half an hour", 30)]),
        Step("Leave for an hour", [("an hour", 60)]),
        Step("Bake 1½ hours", [("1½ hours", 90)]),
        Step("Simmer 1 1/2 hours", [("1 1/2 hours", 90)]),

        // --- Hyphenated as an adjective still reads as a time ---
        Step("Give it a 30-minute rest", [("30-minute", 30)]),

        // --- Numbers that are not times, and must offer nothing ---
        Step("Preheat the oven to 350", []),
        Step("Preheat to 350°F (180°C)", []),
        Step("Bake at 425 degrees", []),
        Step("Pour into a 9x13 pan", []),
        Step("Add 2 cups of flour and 3 eggs", []),
        Step("Season with 1 tsp salt", []),
        Step("Serves 4 to 6", []),
        Step("Cut into 8 wedges", []),
        Step("Use a 12 inch skillet", []),

        // --- A temperature and a time in the same step: take only the time ---
        Step("Bake at 350 for 25 minutes", [("25 minutes", 25)]),
        Step("Roast at 400°F for 1 hour 10 minutes", [("1 hour 10 minutes", 70)]),
        Step("Heat a 10 inch pan, then cook 4-5 minutes per side", [("4-5 minutes", 4)]),

        // --- Nothing to time at all ---
        Step("Stir until the sauce thickens", []),
        Step("Season to taste", []),
    ]

    @Test("Step offers the right timers", arguments: cases)
    func parses(_ step: Step) {
        let got = CookTimeParser.times(in: step.text).map { ($0.text, $0.minutes) }
        let want = step.timers

        #expect(got.count == want.count,
                "expected \(want.count) timer(s) \(want), got \(got.count) \(got) for \"\(step.text)\"")

        for (actual, expected) in zip(got, want) {
            #expect(actual.0 == expected.0,
                    "expected the chip to read \"\(expected.0)\", got \"\(actual.0)\" for \"\(step.text)\"")
            #expect(actual.1 == expected.1,
                    "expected \(expected.1) min from \"\(expected.0)\", got \(actual.1) for \"\(step.text)\"")
        }
    }
}
