//
//  Echo.swift
//  Orca
//
//  Created by David Piliponskiy on 2/24/26.
//

import SwiftData
import Foundation

@Model
class Echo {
    var id: UUID = UUID()
    var name: String
    var emoji: String
    var isDefault: Bool = true
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var learnedKeywords: [String] = []

    /// Fixed UUID for the Thoughts system echo — identical across all builds and devices
    /// so Supabase sync never creates a conflicting duplicate.
    static let thoughtsEchoId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    /// True for echoes that are internal to a feature and should not appear in user-facing echo lists
    var isSystemEcho: Bool { name == "Thoughts" }

    init(name: String, emoji: String, isDefault: Bool = true, sortOrder: Int = 0) {
        self.name = name
        self.emoji = emoji
        self.isDefault = isDefault
        self.sortOrder = sortOrder
    }

    static func seedDefaults(context: ModelContext) {
        let defaults: [(String, String)] = [
            ("Health", "💊"), ("Kids", "🎒"), ("Birthday", "🎂"),
            ("Gifts", "🎁"), ("Travel", "✈️"), ("Cooking", "👨‍🍳"),
            ("Dining", "🍜"), ("Sports", "🏈"), ("Events", "🎉"),
            ("Shopping", "🛒"), ("Home", "🏠"), ("School", "📚"),
            ("Work", "💼"), ("Pets", "🐾"), ("Finance", "💰"),
            ("Holidays", "🎄"), ("To-Do", "📋"), ("Games", "🎮"),
            ("Movies", "🎬"), ("Books", "📖"), ("Clothes", "👕"),
            ("Workout", "💪"), ("Notes", "📝"),
        ]
        for (index, (name, emoji)) in defaults.enumerated() {
            let echo = Echo(name: name, emoji: emoji, sortOrder: index)
            context.insert(echo)
        }
    }

    /// Seeds the Thoughts echo with a fixed UUID so both dev and production builds
    /// always agree on the same ID — preventing Supabase sync conflicts.
    static func seedThoughtsEchoIfNeeded(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Echo>())) ?? []

        if let existing = existing.first(where: { $0.name == "Thoughts" }) {
            // Migrate any old random UUID to the fixed one
            if existing.id != thoughtsEchoId {
                let oldId = existing.id
                existing.id = thoughtsEchoId
                // Update all memories that pointed to the old UUID
                let memories = (try? context.fetch(FetchDescriptor<Memory>())) ?? []
                for m in memories where m.echoId == oldId {
                    m.echoId = thoughtsEchoId
                }
                try? context.save()
            }
            // Make sure the default tab also exists
            ThoughtTab.seedDefaultIfNeeded(context: context)
            return
        }

        // First time — create with the fixed UUID
        let echo = Echo(name: "Thoughts", emoji: "💭", isDefault: true, sortOrder: 999)
        echo.id = thoughtsEchoId
        context.insert(echo)
        ThoughtTab.seedDefaultIfNeeded(context: context)
        try? context.save()
    }
}
