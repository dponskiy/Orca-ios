//
//  SharedSpace.swift
//  Orca
//

import SwiftData
import Foundation

@Model
class SharedSpace {
    var id: UUID = UUID()
    var createdByUserId: String          // Supabase auth user ID of creator
    var invitedUserEmail: String         // Email used to invite the other person
    var invitedUserId: String?           // Filled in once they accept
    var inviteToken: String?             // Token for deep-link invite URL
    var spaceName: String = ""           // User-defined label (local only)
    var status: Status = Status.pending  // pending → active
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    enum Status: String, Codable {
        case pending  // invite sent, not yet accepted
        case active   // both parties joined
    }

    init(createdByUserId: String, invitedUserEmail: String) {
        self.createdByUserId = createdByUserId
        self.invitedUserEmail = invitedUserEmail
    }
}

@Model
class SharedEvent {
    var id: UUID = UUID()
    var spaceId: UUID                    // Links to SharedSpace.id
    var title: String
    var date: Date?                      // nil = undated card (note/misc)
    var endDate: Date?                   // Optional end date for multi-day events
    var notes: String?
    var url: String?
    var createdByUserId: String
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(spaceId: UUID, title: String, createdByUserId: String, date: Date? = nil, endDate: Date? = nil) {
        self.spaceId = spaceId
        self.title = title
        self.createdByUserId = createdByUserId
        self.date = date
        self.endDate = endDate
    }
}

@Model
class SharedChecklistItem {
    var id: UUID = UUID()
    var eventId: UUID                    // Links to SharedEvent.id
    var text: String
    var isCompleted: Bool = false
    var completedByUserId: String?       // Who checked it off
    var completedAt: Date?
    var createdByUserId: String
    var createdAt: Date = Date()

    init(eventId: UUID, text: String, createdByUserId: String) {
        self.eventId = eventId
        self.text = text
        self.createdByUserId = createdByUserId
    }
}
