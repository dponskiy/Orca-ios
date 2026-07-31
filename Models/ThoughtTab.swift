//
//  ThoughtTab.swift
//  Orca
//

import SwiftData
import Foundation

@Model
class ThoughtTab {
    var id: UUID = UUID()
    var name: String
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    init(name: String, sortOrder: Int = 0) {
        self.name = name
        self.sortOrder = sortOrder
    }

    /// Seeds the default "Thoughts" tab if none exist
    static func seedDefaultIfNeeded(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<ThoughtTab>())) ?? []
        guard existing.isEmpty else { return }
        context.insert(ThoughtTab(name: "Thoughts", sortOrder: 0))
    }
}
