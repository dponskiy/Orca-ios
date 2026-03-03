//
//  SubTask.swift
//  Orca
//
//  Created by David Piliponskiy on 3/3/26.
//

import SwiftData
import Foundation

@Model
class SubTask {
    var id: UUID = UUID()
    var memoryId: UUID
    var text: String
    var isCompleted: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    
    init(memoryId: UUID, text: String, sortOrder: Int = 0) {
        self.memoryId = memoryId
        self.text = text
        self.sortOrder = sortOrder
    }
}
