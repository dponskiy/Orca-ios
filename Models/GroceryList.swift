//
//  GroceryList.swift
//  Orca
//
//  Created by David Piliponskiy on 3/21/26.
//

import SwiftData
import Foundation

@Model
class GroceryList {
    var id: UUID = UUID()
    var name: String
    var memoryIds: [String] = []
    var createdAt: Date = Date()

    init(name: String, memoryIds: [UUID]) {
        self.name = name
        self.memoryIds = memoryIds.map { $0.uuidString }
    }

    var memoryUUIDs: [UUID] {
        memoryIds.compactMap { UUID(uuidString: $0) }
    }
}
