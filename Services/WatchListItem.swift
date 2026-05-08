//
//  WatchlistItem.swift
//  Orca
//
//  Created by David Piliponskiy on 4/30/26.
//

import SwiftData
import Foundation

@Model
class WatchlistItem {
    var id: UUID = UUID()
    var title: String
    var itemType: String
    var streamingService: String?
    var status: String = "queued"
    var rating: Int?
    var comment: String?
    var createdAt: Date = Date()
    var completedAt: Date?
    var linkedMemoryId: UUID?

    init(title: String, itemType: String, streamingService: String? = nil, linkedMemoryId: UUID? = nil) {
        self.title = title
        self.itemType = itemType
        self.streamingService = streamingService
        self.linkedMemoryId = linkedMemoryId
    }
}
