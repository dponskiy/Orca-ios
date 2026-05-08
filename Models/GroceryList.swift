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
    var listType: String = "grocery"
    var customListName: String = ""
    var memoryIds: [String] = []
    var extraItems: [String] = []
    var createdAt: Date = Date()

    init(name: String, listType: String = "grocery", customListName: String = "", memoryIds: [UUID] = [], extraItems: [String] = []) {
        self.name = name
        self.listType = listType
        self.customListName = customListName
        self.memoryIds = memoryIds.map { $0.uuidString }
        self.extraItems = extraItems
    }

    var memoryUUIDs: [UUID] {
        memoryIds.compactMap { UUID(uuidString: $0) }
    }
}
