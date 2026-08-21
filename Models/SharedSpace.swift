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

// Membership replaces the old two people-slots on SharedSpace, so a household can
// hold any number of people. The legacy createdByUserId / invitedUserId fields stay
// populated for app versions that predate this.
@Model
class SharedSpaceMember {
    /// Max people in one household. Kept here so UI copy can't drift from the
    /// value the join function actually enforces (mirrored in Supabase's
    /// join_space_by_token — change both together).
    static let cap = 10

    var id: UUID = UUID()
    var spaceId: UUID
    var userId: String                  // Supabase auth user ID
    var displayName: String = ""        // what this person is called *in this space*
    var role: String = "member"         // "owner" | "member"
    var joinedAt: Date = Date()

    var isOwner: Bool { role == "owner" }

    init(spaceId: UUID, userId: String, displayName: String = "", role: String = "member") {
        self.spaceId = spaceId
        self.userId = userId
        self.displayName = displayName
        self.role = role
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

// MARK: - Shared grocery
//
// Recipes have exactly one owner and live in that person's own collection; these
// rows are a published copy so the rest of the household can see and cook from
// them. Leaving a space takes your recipes with you.

@Model
class SharedRecipe {
    var id: UUID = UUID()
    var spaceId: UUID
    var ownerUserId: String
    var sourceMemoryId: UUID      // the owner's Memory this was published from
    var title: String = ""
    var ingredients: [String] = []
    var instructions: String = ""
    var updatedAt: Date = Date()

    init(spaceId: UUID, ownerUserId: String, sourceMemoryId: UUID,
         title: String, ingredients: [String], instructions: String) {
        self.spaceId = spaceId
        self.ownerUserId = ownerUserId
        self.sourceMemoryId = sourceMemoryId
        self.title = title
        self.ingredients = ingredients
        self.instructions = instructions
    }
}

// One row per thing to buy. Recipe-sourced items keep a copy of the ingredient
// text rather than a live link, so editing a recipe never changes a list someone
// is already shopping. Which recipes are "selected" is simply which ones have
// items here.
@Model
class SharedGroceryItem {
    var id: UUID = UUID()
    var spaceId: UUID
    var text: String
    var sourceRecipeId: UUID?
    var sourceRecipeTitle: String = ""
    var isChecked: Bool = false
    var checkedByUserId: String?
    var checkedAt: Date?
    var addedByUserId: String
    var createdAt: Date = Date()

    var isExtra: Bool { sourceRecipeId == nil }

    init(spaceId: UUID, text: String, addedByUserId: String,
         sourceRecipeId: UUID? = nil, sourceRecipeTitle: String = "") {
        self.spaceId = spaceId
        self.text = text
        self.addedByUserId = addedByUserId
        self.sourceRecipeId = sourceRecipeId
        self.sourceRecipeTitle = sourceRecipeTitle
    }
}
