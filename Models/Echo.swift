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
    var isDefault: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    init(name: String, emoji: String, isDefault: Bool = false) {
        self.name = name
        self.emoji = emoji
        self.isDefault = isDefault
    }

    static let defaults: [(String, String)] = [
            ("Health", "💊"), ("Kids", "🎒"),
            ("Gifts", "🎁"), ("Travel", "✈️"),
            ("Cooking", "👨‍🍳"), ("Dining", "🍜"),
            ("Sports", "🏈"), ("Shopping", "🛒"),
            ("Home", "🏠"), ("Work", "💼"),
            ("Pets", "🐾"), ("Finance", "💰"),
            ("Chores", "🧹"), ("Games", "🎮"),
    ]
}
