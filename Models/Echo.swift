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
    
    init(name: String, emoji: String, isDefault: Bool = true, sortOrder: Int = 0) {
        self.name = name
        self.emoji = emoji
        self.isDefault = isDefault
        self.sortOrder = sortOrder
    }
    
    static func seedDefaults(context: ModelContext) {
        let descriptor = FetchDescriptor<Echo>()
        guard (try? context.fetchCount(descriptor)) == 0 else { return }
        
        let defaults: [(String, String)] = [
            ("Health", "💊"),
            ("Kids", "🎒"),
            ("Birthday", "🎂"),
            ("Gifts", "🎁"),
            ("Travel", "✈️"),
            ("Cooking", "👨‍🍳"),
            ("Dining", "🍜"),
            ("Sports", "🏈"),
            ("Events", "🎉"),
            ("Shopping", "🛒"),
            ("Home", "🏠"),
            ("School", "📚"),
            ("Work", "💼"),
            ("Pets", "🐾"),
            ("Finance", "💰"),
            ("Holidays", "🎄"),
            ("Chores", "🧹"),
            ("Games", "🎮"),
            ("Movies", "🎬"),
            ("Books", "📖"),
            ("Clothes", "👕"),
            ("Notes", "📝"),
        ]
        
        for (index, (name, emoji)) in defaults.enumerated() {
            let echo = Echo(name: name, emoji: emoji, sortOrder: index)
            context.insert(echo)
        }
    }
}
