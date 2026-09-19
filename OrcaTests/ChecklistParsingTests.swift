//
//  ChecklistParsingTests.swift
//  OrcaTests
//
//  How people actually write lists, and which items Sonar should pull out of them.
//
//  Add a line to `cases` whenever a list comes out wrong: the phrase, and the items a
//  person would expect to see. An empty expectation means no checklist at all — one
//  task on its own is a note, and some text just isn't a list.
//
//  Failures print the phrase, what was expected and what came out.
//

import Testing
@testable import Orca

struct ChecklistParsingTests {

    /// One phrasing and the checklist it should produce. A struct rather than a tuple
    /// so each case shows up as its own named test.
    struct Phrasing: Sendable, CustomStringConvertible {
        let phrase: String
        let items: [String]
        var description: String { phrase }
        init(_ phrase: String, _ items: [String]) {
            self.phrase = phrase; self.items = items
        }
    }

    static let cases: [Phrasing] = [

        // --- Every item you separate should survive, whatever verb it starts with ---
        Phrasing("tomorrow I need to vacuum basement, go grocery shopping, cook dinner, and clean upstairs sink",
                 ["Vacuum basement", "Go grocery shopping", "Cook dinner", "Clean upstairs sink"]),
        Phrasing("I need to walk the dog, feed the cat, water the plants",
                 ["Walk the dog", "Feed the cat", "Water the plants"]),
        Phrasing("this weekend I have to renew my passport, visit grandma, and mow the lawn",
                 ["Renew my passport", "Visit grandma", "Mow the lawn"]),
        Phrasing("I need to get milk, eggs, bread, and butter",
                 ["Get milk", "Eggs", "Bread", "Butter"]),
        Phrasing("I need to:\nvacuum\ncook dinner\nclean the sink",
                 ["Vacuum", "Cook dinner", "Clean the sink"]),

        // --- "and" inside one item belongs to that item ---
        Phrasing("I need to pick up milk and eggs, call mom", ["Pick up milk and eggs", "Call mom"]),
        Phrasing("I need to make mac and cheese, buy bread", ["Make mac and cheese", "Buy bread"]),
        Phrasing("remind me to email John and Sarah about the trip, book the hotel",
                 ["Email John and Sarah about the trip", "Book the hotel"]),

        // --- ...but "and" in front of a new task still splits ---
        Phrasing("I need to cook dinner and clean the kitchen", ["Cook dinner", "Clean the kitchen"]),
        Phrasing("I need to vacuum and mop the floors", ["Vacuum", "Mop the floors"]),
        Phrasing("I need to call mom and I have to pay rent", ["Call mom", "Pay rent"]),

        // --- Connecting words and end punctuation aren't part of the task ---
        Phrasing("I need to vacuum, then mop, then take out the trash", ["Vacuum", "Mop", "Take out the trash"]),
        Phrasing("I need to buy milk, call mom.", ["Buy milk", "Call mom"]),
        Phrasing("I need to tomorrow morning call the vet, pick up milk", ["Call the vet", "Pick up milk"]),

        // --- Asides aren't tasks (the second uses the curly apostrophe iOS types) ---
        Phrasing("I need to call mom, she's been sick, and pick up her prescription",
                 ["Call mom", "Pick up her prescription"]),
        Phrasing("I need to go to the gym, it\u{2019}s leg day", []),

        // --- Colon lists ---
        Phrasing("To do: laundry, dishes, vacuum", ["Laundry", "Dishes", "Vacuum"]),
        Phrasing("Things I need to buy: milk, eggs, bread", ["Buy milk", "Eggs", "Bread"]),
        Phrasing("BBQ list: mustard, ketchup, buns", ["Mustard", "Ketchup", "Buns"]),

        // --- A trigger word hiding inside another word isn't a trigger ---
        Phrasing("shoulder press, bench, squats", []),

        // --- Spoken lists with no punctuation keep working ---
        Phrasing("I need to pick up milk grab eggs call mom", ["Pick up milk", "Grab eggs", "Call mom"]),
        Phrasing("tomorrow at 4pm I need to call the vet and pick up dog food", ["Call the vet", "Pick up dog food"]),
        Phrasing("Don\u{2019}t forget to text Jake, call the plumber and pay rent",
                 ["Text Jake", "Call the plumber", "Pay rent"]),

        // --- One task is a note, not a checklist ---
        Phrasing("I need to call the dentist tomorrow", []),
        Phrasing("tomorrow I need to vacuum the basement", []),

        // --- Not a list at all ---
        Phrasing("I need to remember that the meeting moved to 3", []),
    ]

    @Test("List parses correctly", arguments: cases)
    func list(_ c: Phrasing) {
        let got = SonarEngine().detectChecklistItems(text: c.phrase)
        #expect(got == c.items, "expected \(c.items), got \(got)")
    }
}
