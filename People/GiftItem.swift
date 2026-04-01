//
//  GiftItem.swift
//  Orca
//
//  Created by David Piliponskiy on 3/29/26.
//

import SwiftData
import Foundation

enum GiftStatus: String, Codable {
    case idea, purchased
}

@Model
class GiftItem {
    var id: UUID = UUID()
    var personId: UUID
    var name: String
    var price: Double?
    var statusRaw: String = GiftStatus.idea.rawValue
    var occasion: String = "Birthday"
    var year: Int = Calendar.current.component(.year, from: Date())
    var linkedMemoryId: UUID?
    var url: String?
    var createdAt: Date = Date()

    var status: GiftStatus {
        get { GiftStatus(rawValue: statusRaw) ?? .idea }
        set { statusRaw = newValue.rawValue }
    }

    var isPurchased: Bool { status == .purchased }

    init(personId: UUID, name: String, occasion: String = "Birthday") {
        self.personId = personId
        self.name = name
        self.occasion = occasion
        self.year = Calendar.current.component(.year, from: Date())
    }
}
