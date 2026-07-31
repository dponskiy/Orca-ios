//
//  TCGCard.swift
//  Orca

import SwiftData
import Foundation

@Model
class TCGCard {
    var id: UUID = UUID()
    var pokemonId: String       // e.g. "sv1-1"
    var name: String
    var setId: String           // e.g. "sv1"
    var setName: String
    var number: String
    var imageURL: String
    var largeImageURL: String
    var rarity: String?
    var statusRaw: String = "owned"   // "owned" | "chasing"
    var marketPrice: Double?
    var lowPrice: Double?
    var highPrice: Double?
    var priceVariant: String?         // "normal", "holofoil", "reverseHolofoil" etc.
    var addedAt: Date = Date()
    var psaGrade: Int?                // owned: actual PSA grade 1–10, nil = raw/ungraded
    var psaTargetGrade: Int?          // chasing: minimum PSA grade wanted, nil = raw/any

    var isOwned: Bool {
        get { statusRaw == "owned" }
        set { statusRaw = newValue ? "owned" : "chasing" }
    }

    init(pokemonId: String, name: String, setId: String, setName: String, number: String,
         imageURL: String, largeImageURL: String, rarity: String? = nil) {
        self.pokemonId = pokemonId
        self.name = name
        self.setId = setId
        self.setName = setName
        self.number = number
        self.imageURL = imageURL
        self.largeImageURL = largeImageURL
        self.rarity = rarity
    }
}
