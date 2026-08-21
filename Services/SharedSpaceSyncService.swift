//
//  SharedSpaceSyncService.swift
//  Orca
//

import Foundation
import SwiftData
import Supabase

// MARK: - Supabase row structs

private struct SpaceRow: Codable {
    let id: UUID
    let created_by_user_id: UUID
    let invited_user_email: String
    let invited_user_id: UUID?
    let invite_token: String?
    let status: String
    let space_name: String?
    let created_at: Date
    let updated_at: Date
}

private struct RecipeRow: Codable {
    let id: UUID
    let space_id: UUID
    let owner_user_id: UUID
    let source_memory_id: UUID
    let title: String
    let ingredients: [String]
    let instructions: String
    let updated_at: Date
}

private struct GroceryItemRow: Codable {
    let id: UUID
    let space_id: UUID
    let text: String
    let source_recipe_id: UUID?
    let source_recipe_title: String
    let is_checked: Bool
    let checked_by_user_id: UUID?
    let checked_at: Date?
    let added_by_user_id: UUID
    let created_at: Date
}

nonisolated private struct JoinParams: Encodable {
    let token: String
    let member_name: String
}

private struct MemberRow: Codable {
    let id: UUID
    let space_id: UUID
    let user_id: UUID
    let display_name: String
    let role: String
    let joined_at: Date
}

private struct EventRow: Codable {
    let id: UUID
    let space_id: UUID
    let title: String
    let date: Date?
    let end_date: Date?
    let notes: String?
    let url: String?
    let created_by_user_id: UUID
    let created_at: Date
    let updated_at: Date
}

private struct ChecklistRow: Codable {
    let id: UUID
    let event_id: UUID
    let text: String
    let is_completed: Bool
    let completed_by_user_id: UUID?
    let completed_at: Date?
    let created_by_user_id: UUID
    let created_at: Date
}

// MARK: - Service

@MainActor
class SharedSpaceSyncService {
    static let shared = SharedSpaceSyncService()

    private var supabase: SupabaseClient { SupabaseManager.shared.client }
    private var modelContext: ModelContext?
    private var realtimeTasks: [Task<Void, Never>] = []
    private var pendingSyncTask: Task<Void, Never>?

    private init() {}

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Full Sync (called on app open / foreground)

    func syncAll(userId: UUID) async {
        guard let context = modelContext else { return }
        do {
            try await syncSpaces(userId: userId, context: context)
            try await syncMembers(userId: userId, context: context)
            try await syncEvents(userId: userId, context: context)
            try await syncChecklist(userId: userId, context: context)
            try await syncSharedRecipes(userId: userId, context: context)
            try await syncGroceryItems(userId: userId, context: context)
            print("✅ SharedSpace sync complete")
        } catch {
            print("❌ SharedSpace sync failed: \(error)")
        }
    }

    // MARK: - Sync Spaces

    private func syncSpaces(userId: UUID, context: ModelContext) async throws {
        // Which spaces am I in? Membership is the source of truth; the legacy
        // columns are still checked so spaces created before this release appear.
        let myMemberships: [MemberRow] = try await supabase
            .from("shared_space_members")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        let memberSpaceIds = myMemberships.map { $0.space_id.uuidString }

        var rows: [SpaceRow] = try await supabase
            .from("shared_spaces")
            .select()
            .or("created_by_user_id.eq.\(userId),invited_user_id.eq.\(userId)")
            .execute()
            .value

        if !memberSpaceIds.isEmpty {
            let viaMembership: [SpaceRow] = try await supabase
                .from("shared_spaces")
                .select()
                .in("id", values: memberSpaceIds)
                .execute()
                .value
            let known = Set(rows.map { $0.id })
            rows += viaMembership.filter { !known.contains($0.id) }
        }

        let existing = try context.fetch(FetchDescriptor<SharedSpace>())
        let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for row in rows {
            if let local = existingById[row.id] {
                local.status = SharedSpace.Status(rawValue: row.status) ?? .pending
                local.invitedUserId = row.invited_user_id?.uuidString
                if let remoteName = row.space_name, !remoteName.isEmpty { local.spaceName = remoteName }
                local.updatedAt = row.updated_at
            } else {
                let space = SharedSpace(
                    createdByUserId: row.created_by_user_id.uuidString,
                    invitedUserEmail: row.invited_user_email
                )
                space.id = row.id
                space.invitedUserId = row.invited_user_id?.uuidString
                space.status = SharedSpace.Status(rawValue: row.status) ?? .pending
                space.createdAt = row.created_at
                space.updatedAt = row.updated_at
                context.insert(space)
            }
        }

        // Check if our email has any pending invites
        if let email = try? await supabase.auth.session.user.email {
            let pending: [SpaceRow] = try await supabase
                .from("shared_spaces")
                .select()
                .eq("invited_user_email", value: email)
                .eq("status", value: "pending")
                .execute()
                .value

            for row in pending {
                // Accept invite — link our userId and bump updated_at so creator's realtime fires
                let now = ISO8601DateFormatter().string(from: Date())
                try await supabase
                    .from("shared_spaces")
                    .update(["invited_user_id": userId.uuidString, "status": "active", "updated_at": now])
                    .eq("id", value: row.id.uuidString)
                    .execute()

                if existingById[row.id] == nil {
                    let space = SharedSpace(
                        createdByUserId: row.created_by_user_id.uuidString,
                        invitedUserEmail: row.invited_user_email
                    )
                    space.id = row.id
                    space.invitedUserId = userId.uuidString
                    space.status = .active
                    space.createdAt = row.created_at
                    space.updatedAt = Date()
                    context.insert(space)
                } else if let local = existingById[row.id] {
                    local.invitedUserId = userId.uuidString
                    local.status = .active
                    local.updatedAt = Date()
                }
            }
        }
    }

    // MARK: - Sync Members

    private func syncMembers(userId: UUID, context: ModelContext) async throws {
        let spaces = try context.fetch(FetchDescriptor<SharedSpace>())
        guard !spaces.isEmpty else { return }
        let spaceIds = spaces.map { $0.id.uuidString }

        // RLS returns only members of spaces I belong to, so this is safe to fetch wide
        let rows: [MemberRow] = try await supabase
            .from("shared_space_members")
            .select()
            .in("space_id", values: spaceIds)
            .execute()
            .value

        let existing = try context.fetch(FetchDescriptor<SharedSpaceMember>())
        var byKey = Dictionary(
            existing.map { (("\($0.spaceId.uuidString)|\($0.userId)"), $0) },
            uniquingKeysWith: { a, _ in a }
        )

        for row in rows {
            let key = "\(row.space_id.uuidString)|\(row.user_id.uuidString)"
            if let local = byKey[key] {
                local.displayName = row.display_name
                local.role = row.role
                byKey.removeValue(forKey: key)
            } else {
                let member = SharedSpaceMember(
                    spaceId: row.space_id,
                    userId: row.user_id.uuidString,
                    displayName: row.display_name,
                    role: row.role
                )
                member.id = row.id
                member.joinedAt = row.joined_at
                context.insert(member)
            }
        }

        // Anything left locally was removed remotely (someone left or was removed)
        let remoteSpaceIds = Set(rows.map { $0.space_id })
        for (_, orphan) in byKey where remoteSpaceIds.contains(orphan.spaceId) {
            context.delete(orphan)
        }

        print("✅ Members synced")
    }

    // MARK: - Membership actions

    func setDisplayName(_ name: String, memberId: UUID) async throws {
        try await supabase
            .from("shared_space_members")
            .update(["display_name": name])
            .eq("id", value: memberId.uuidString)
            .execute()
    }

    func removeMember(_ member: SharedSpaceMember) async throws {
        guard let context = modelContext else { throw SyncError.noContext }
        try await supabase
            .from("shared_space_members")
            .delete()
            .eq("id", value: member.id.uuidString)
            .execute()
        context.delete(member)
    }

    /// New invite link for a space — invalidates the old one.
    func regenerateInviteToken(for space: SharedSpace) async throws -> String {
        let token = UUID().uuidString.lowercased()
        try await supabase
            .from("shared_spaces")
            .update(["invite_token": token])
            .eq("id", value: space.id.uuidString)
            .execute()
        space.inviteToken = token
        return token
    }

    func renameSpace(_ space: SharedSpace, to name: String) async throws {
        try await supabase
            .from("shared_spaces")
            .update(["space_name": name])
            .eq("id", value: space.id.uuidString)
            .execute()
        space.spaceName = name
    }

    // MARK: - Shared Recipes
    //
    // Your recipes publish into every household you belong to. Ownership never
    // moves: this is a copy for the others to read, and it disappears when you
    // delete the recipe or leave the space.

    /// A Memory qualifies as a recipe if it has an ingredient checklist.
    private func recipeIngredients(for memory: Memory, context: ModelContext) -> [String] {
        guard memory.hasChecklist else { return [] }
        let subTasks = (try? context.fetch(FetchDescriptor<SubTask>())) ?? []
        return subTasks
            .filter { $0.memoryId == memory.id }
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { $0.text }
    }

    private func syncSharedRecipes(userId: UUID, context: ModelContext) async throws {
        let members = try context.fetch(FetchDescriptor<SharedSpaceMember>())
        let mySpaceIds = members.filter { $0.userId == userId.uuidString }.map { $0.spaceId }
        guard !mySpaceIds.isEmpty else { return }

        // Publish mine — only cooking memories that actually carry ingredients
        let echos = try context.fetch(FetchDescriptor<Echo>())
        let cookingEchoIds = Set(echos.filter {
            let n = $0.name.lowercased()
            return n.contains("cook") || n.contains("recipe")
        }.map { $0.id })

        let memories = try context.fetch(FetchDescriptor<Memory>())
        let myRecipes = memories.filter { cookingEchoIds.contains($0.echoId) && $0.hasChecklist }

        var rows: [[String: AnyJSON]] = []
        for space in mySpaceIds {
            for memory in myRecipes {
                let ingredients = recipeIngredients(for: memory, context: context)
                guard !ingredients.isEmpty else { continue }
                let title = memory.text.components(separatedBy: "\n").first ?? memory.text
                rows.append([
                    "space_id": .string(space.uuidString),
                    "owner_user_id": .string(userId.uuidString),
                    "source_memory_id": .string(memory.id.uuidString),
                    "title": .string(title),
                    "ingredients": .array(ingredients.map { .string($0) }),
                    "instructions": .string(memory.text),
                    "updated_at": .string(ISO8601DateFormatter().string(from: memory.updatedAt))
                ])
            }
        }
        if !rows.isEmpty {
            try await supabase
                .from("shared_recipes")
                .upsert(rows, onConflict: "space_id,source_memory_id")
                .execute()
        }

        // Pull everyone's (RLS limits this to households I'm in)
        let remote: [RecipeRow] = try await supabase
            .from("shared_recipes")
            .select()
            .in("space_id", values: mySpaceIds.map { $0.uuidString })
            .execute()
            .value

        let existing = try context.fetch(FetchDescriptor<SharedRecipe>())
        var byId = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        for row in remote {
            if let local = byId[row.id] {
                local.title = row.title
                local.ingredients = row.ingredients
                local.instructions = row.instructions
                local.updatedAt = row.updated_at
                byId.removeValue(forKey: row.id)
            } else {
                let recipe = SharedRecipe(
                    spaceId: row.space_id,
                    ownerUserId: row.owner_user_id.uuidString,
                    sourceMemoryId: row.source_memory_id,
                    title: row.title,
                    ingredients: row.ingredients,
                    instructions: row.instructions
                )
                recipe.id = row.id
                recipe.updatedAt = row.updated_at
                context.insert(recipe)
            }
        }
        // Unpublished remotely — someone deleted a recipe or left
        for (_, stale) in byId { context.delete(stale) }

        print("✅ Shared recipes synced")
    }

    /// Removes a recipe from every household when its owner deletes it locally.
    func unpublishRecipe(memoryId: UUID, userId: UUID) async {
        do {
            try await supabase
                .from("shared_recipes")
                .delete()
                .eq("source_memory_id", value: memoryId.uuidString)
                .eq("owner_user_id", value: userId.uuidString)
                .execute()
        } catch {
            print("❌ Failed to unpublish recipe: \(error)")
        }
    }

    // MARK: - Shared Grocery Items

    private func syncGroceryItems(userId: UUID, context: ModelContext) async throws {
        let members = try context.fetch(FetchDescriptor<SharedSpaceMember>())
        let mySpaceIds = members.filter { $0.userId == userId.uuidString }.map { $0.spaceId }
        guard !mySpaceIds.isEmpty else { return }

        let remote: [GroceryItemRow] = try await supabase
            .from("shared_grocery_items")
            .select()
            .in("space_id", values: mySpaceIds.map { $0.uuidString })
            .execute()
            .value

        let existing = try context.fetch(FetchDescriptor<SharedGroceryItem>())
        var byId = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        for row in remote {
            if let local = byId[row.id] {
                local.text = row.text
                local.isChecked = row.is_checked
                local.checkedByUserId = row.checked_by_user_id?.uuidString
                local.checkedAt = row.checked_at
                byId.removeValue(forKey: row.id)
            } else {
                let item = SharedGroceryItem(
                    spaceId: row.space_id,
                    text: row.text,
                    addedByUserId: row.added_by_user_id.uuidString,
                    sourceRecipeId: row.source_recipe_id,
                    sourceRecipeTitle: row.source_recipe_title
                )
                item.id = row.id
                item.isChecked = row.is_checked
                item.checkedByUserId = row.checked_by_user_id?.uuidString
                item.checkedAt = row.checked_at
                item.createdAt = row.created_at
                context.insert(item)
            }
        }
        for (_, removed) in byId { context.delete(removed) }

        print("✅ Shared grocery synced")
    }

    // MARK: - Shared grocery actions

    func addGroceryItems(_ texts: [String], spaceId: UUID, userId: UUID,
                         recipeId: UUID? = nil, recipeTitle: String = "") async throws {
        guard let context = modelContext, !texts.isEmpty else { return }
        var rows: [[String: AnyJSON]] = []
        for text in texts {
            let item = SharedGroceryItem(spaceId: spaceId, text: text,
                                         addedByUserId: userId.uuidString,
                                         sourceRecipeId: recipeId, sourceRecipeTitle: recipeTitle)
            context.insert(item)
            rows.append([
                "id": .string(item.id.uuidString),
                "space_id": .string(spaceId.uuidString),
                "text": .string(text),
                "source_recipe_id": recipeId.map { .string($0.uuidString) } ?? .null,
                "source_recipe_title": .string(recipeTitle),
                "added_by_user_id": .string(userId.uuidString)
            ])
        }
        try await supabase.from("shared_grocery_items").insert(rows).execute()
    }

    func toggleGroceryItem(_ item: SharedGroceryItem, userId: UUID) async throws {
        let nowChecked = !item.isChecked
        item.isChecked = nowChecked
        item.checkedByUserId = nowChecked ? userId.uuidString : nil
        item.checkedAt = nowChecked ? Date() : nil

        var payload: [String: AnyJSON] = ["is_checked": .bool(nowChecked)]
        payload["checked_by_user_id"] = nowChecked ? .string(userId.uuidString) : .null
        payload["checked_at"] = nowChecked ? .string(ISO8601DateFormatter().string(from: Date())) : .null

        try await supabase
            .from("shared_grocery_items")
            .update(payload)
            .eq("id", value: item.id.uuidString)
            .execute()
    }

    func removeGroceryItems(_ items: [SharedGroceryItem]) async throws {
        guard let context = modelContext, !items.isEmpty else { return }
        let ids = items.map { $0.id.uuidString }
        for item in items { context.delete(item) }
        try await supabase
            .from("shared_grocery_items")
            .delete()
            .in("id", values: ids)
            .execute()
    }

    // MARK: - Sync Events

    private func syncEvents(userId: UUID, context: ModelContext) async throws {
        // Get all space IDs this user belongs to
        let spaces = try context.fetch(FetchDescriptor<SharedSpace>())
        guard !spaces.isEmpty else { return }
        let spaceIds = spaces.map { $0.id.uuidString }

        let rows: [EventRow] = try await supabase
            .from("shared_events")
            .select()
            .in("space_id", values: spaceIds)
            .execute()
            .value

        let existing = try context.fetch(FetchDescriptor<SharedEvent>())
        let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        let remoteIds = Set(rows.map { $0.id })

        for row in rows {
            if let local = existingById[row.id] {
                local.title = row.title
                local.date = row.date
                local.endDate = row.end_date
                local.notes = row.notes
                local.url = row.url
                local.updatedAt = row.updated_at
            } else {
                let event = SharedEvent(
                    spaceId: row.space_id,
                    title: row.title,
                    createdByUserId: row.created_by_user_id.uuidString,
                    date: row.date,
                    endDate: row.end_date
                )
                event.id = row.id
                event.notes = row.notes
                event.url = row.url
                event.createdAt = row.created_at
                event.updatedAt = row.updated_at
                context.insert(event)
            }
        }

        // Delete locally if removed remotely
        for local in existing where !remoteIds.contains(local.id) {
            context.delete(local)
        }
    }

    // MARK: - Sync Checklist

    private func syncChecklist(userId: UUID, context: ModelContext) async throws {
        let events = try context.fetch(FetchDescriptor<SharedEvent>())
        guard !events.isEmpty else { return }
        let eventIds = events.map { $0.id.uuidString }

        let rows: [ChecklistRow] = try await supabase
            .from("shared_checklist_items")
            .select()
            .in("event_id", values: eventIds)
            .execute()
            .value

        let existing = try context.fetch(FetchDescriptor<SharedChecklistItem>())
        let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let remoteIds = Set(rows.map { $0.id })

        for row in rows {
            if let local = existingById[row.id] {
                local.text = row.text
                local.isCompleted = row.is_completed
                local.completedByUserId = row.completed_by_user_id?.uuidString
                local.completedAt = row.completed_at
            } else {
                let item = SharedChecklistItem(
                    eventId: row.event_id,
                    text: row.text,
                    createdByUserId: row.created_by_user_id.uuidString
                )
                item.id = row.id
                item.isCompleted = row.is_completed
                item.completedByUserId = row.completed_by_user_id?.uuidString
                item.completedAt = row.completed_at
                item.createdAt = row.created_at
                context.insert(item)
            }
        }

        for local in existing where !remoteIds.contains(local.id) {
            context.delete(local)
        }
    }

    // MARK: - Realtime Subscriptions

    func startRealtime(userId: UUID) {
        stopRealtime()

        // Listen for shared_events changes
        let eventsTask = Task {
            let channel = supabase.channel("shared-events-\(userId)")
            let changes = channel.postgresChange(AnyAction.self, table: "shared_events")
            await channel.subscribe()
            for await _ in changes {
                requestSync(userId: userId)
            }
        }

        // Listen for checklist changes
        let checklistTask = Task {
            let channel = supabase.channel("shared-checklist-\(userId)")
            let changes = channel.postgresChange(AnyAction.self, table: "shared_checklist_items")
            await channel.subscribe()
            for await _ in changes {
                requestSync(userId: userId)
            }
        }

        // Shared grocery — the list has to move for everyone the moment someone
        // ticks something off, otherwise two people buy the same milk
        let groceryTask = Task {
            let channel = supabase.channel("shared-grocery-\(userId)")
            let changes = channel.postgresChange(AnyAction.self, table: "shared_grocery_items")
            await channel.subscribe()
            for await _ in changes {
                requestSync(userId: userId)
            }
        }

        // Listen for space status changes (invite accepted)
        let spacesTask = Task {
            let channel = supabase.channel("shared-spaces-\(userId)")
            let changes = channel.postgresChange(AnyAction.self, table: "shared_spaces")
            await channel.subscribe()
            for await _ in changes {
                requestSync(userId: userId)
            }
        }

        realtimeTasks = [eventsTask, checklistTask, groceryTask, spacesTask]
        print("🔴 SharedSpace realtime subscriptions active")
    }

    /// Collapses a burst of realtime events into a single sync.
    ///
    /// Each change previously triggered a full syncAll on every member's device —
    /// fine for two people, but a household ticking items off in a store produced
    /// one full sync per tap, on every phone. A short delay lets a flurry settle,
    /// and the trailing sync picks up all of it at once.
    private func requestSync(userId: UUID) {
        pendingSyncTask?.cancel()
        pendingSyncTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled, let self else { return }
            await self.syncAll(userId: userId)
        }
    }

    func stopRealtime() {
        pendingSyncTask?.cancel()
        pendingSyncTask = nil
        realtimeTasks.forEach { $0.cancel() }
        realtimeTasks = []
    }

    // MARK: - CRUD: Spaces

    func createSpace(name: String, userId: UUID, ownerName: String = "") async throws -> SharedSpace {
        guard let context = modelContext else { throw SyncError.noContext }

        // Generate a unique invite token client-side
        let inviteToken = UUID().uuidString.lowercased()

        let payload: [String: String] = [
            "created_by_user_id": userId.uuidString,
            "invited_user_email": "",
            "invite_token": inviteToken,
            "status": "pending",
            "space_name": name
        ]
        let row: SpaceRow = try await supabase
            .from("shared_spaces")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        let space = SharedSpace(createdByUserId: userId.uuidString, invitedUserEmail: "")
        space.id = row.id
        space.spaceName = name
        space.inviteToken = row.invite_token ?? inviteToken
        space.status = .pending
        context.insert(space)

        // The creator is a member too — otherwise they'd be the one nameless
        // person in their own household.
        try await supabase
            .from("shared_space_members")
            .insert([
                "space_id": row.id.uuidString,
                "user_id": userId.uuidString,
                "display_name": ownerName,
                "role": "owner"
            ])
            .execute()
        let owner = SharedSpaceMember(spaceId: row.id, userId: userId.uuidString,
                                      displayName: ownerName, role: "owner")
        context.insert(owner)

        return space
    }

    // MARK: - Delete Space

    func deleteSpace(_ space: SharedSpace) async throws {
        guard let context = modelContext else { return }

        // Delete from Supabase (cascade should handle events + checklist, but clean up locally too)
        try await supabase
            .from("shared_spaces")
            .delete()
            .eq("id", value: space.id.uuidString)
            .execute()

        // Remove local events + checklist items for this space
        let events = (try? context.fetch(FetchDescriptor<SharedEvent>())) ?? []
        let spaceEvents = events.filter { $0.spaceId == space.id }
        let eventIds = Set(spaceEvents.map { $0.id })
        let items = (try? context.fetch(FetchDescriptor<SharedChecklistItem>())) ?? []
        for item in items where eventIds.contains(item.eventId) { context.delete(item) }
        for event in spaceEvents { context.delete(event) }
        context.delete(space)
    }

    // MARK: - Accept Invite by Token

    func acceptInvite(token: String, userId: UUID) async throws {
        try await acceptInvite(token: token, userId: userId, displayName: "")
    }

    /// Joins via a reusable invite link. The server enforces the member cap and
    /// keeps the legacy columns populated, so the client never needs read access
    /// to spaces it isn't in yet.
    func acceptInvite(token: String, userId: UUID, displayName: String) async throws {
        guard let context = modelContext else { throw SyncError.noContext }


        do {
            _ = try await supabase
                .rpc("join_space_by_token", params: JoinParams(token: token, member_name: displayName))
                .execute()
        } catch {
            // Surfaces invalid_token / space_full from the function
            throw error
        }

        // Membership now exists, so a normal sync pulls the space and everyone in it
        await syncAll(userId: userId)
        _ = context
    }


    func createEvent(spaceId: UUID, title: String, date: Date?, endDate: Date? = nil, userId: UUID) async throws -> SharedEvent {
        guard let context = modelContext else { throw SyncError.noContext }

        let iso = ISO8601DateFormatter()
        var payload: [String: AnyEncodable] = [
            "space_id": AnyEncodable(spaceId.uuidString),
            "title": AnyEncodable(title),
            "created_by_user_id": AnyEncodable(userId.uuidString)
        ]
        if let date = date { payload["date"] = AnyEncodable(iso.string(from: date)) }
        if let endDate = endDate { payload["end_date"] = AnyEncodable(iso.string(from: endDate)) }

        let row: EventRow = try await supabase
            .from("shared_events")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        let event = SharedEvent(spaceId: spaceId, title: title, createdByUserId: userId.uuidString, date: date, endDate: endDate)
        event.id = row.id
        event.createdAt = row.created_at
        event.updatedAt = row.updated_at
        context.insert(event)
        return event
    }

    func updateEvent(_ event: SharedEvent) async throws {
        let iso = ISO8601DateFormatter()
        var payload: [String: AnyEncodable] = [
            "title": AnyEncodable(event.title),
            "updated_at": AnyEncodable(iso.string(from: Date()))
        ]
        if let notes = event.notes { payload["notes"] = AnyEncodable(notes) }
        if let url = event.url { payload["url"] = AnyEncodable(url) }
        if let date = event.date { payload["date"] = AnyEncodable(iso.string(from: date)) }
        if let endDate = event.endDate { payload["end_date"] = AnyEncodable(iso.string(from: endDate)) } else { payload["end_date"] = AnyEncodable(Optional<String>.none) }

        try await supabase
            .from("shared_events")
            .update(payload)
            .eq("id", value: event.id.uuidString)
            .execute()

        event.updatedAt = Date()
    }

    func deleteEvent(_ event: SharedEvent) async throws {
        guard let context = modelContext else { return }
        try await supabase
            .from("shared_events")
            .delete()
            .eq("id", value: event.id.uuidString)
            .execute()
        context.delete(event)
    }

    // MARK: - CRUD: Checklist

    func addChecklistItem(eventId: UUID, text: String, userId: UUID) async throws -> SharedChecklistItem {
        guard let context = modelContext else { throw SyncError.noContext }

        let payload: [String: String] = [
            "event_id": eventId.uuidString,
            "text": text,
            "created_by_user_id": userId.uuidString
        ]
        let row: ChecklistRow = try await supabase
            .from("shared_checklist_items")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        let item = SharedChecklistItem(eventId: eventId, text: text, createdByUserId: userId.uuidString)
        item.id = row.id
        item.createdAt = row.created_at
        context.insert(item)
        return item
    }

    func toggleChecklistItem(_ item: SharedChecklistItem, userId: UUID) async throws {
        let nowCompleted = !item.isCompleted
        let payload: [String: AnyEncodable] = [
            "is_completed": AnyEncodable(nowCompleted),
            "completed_by_user_id": AnyEncodable(nowCompleted ? userId.uuidString : nil),
            "completed_at": AnyEncodable(nowCompleted ? ISO8601DateFormatter().string(from: Date()) : nil)
        ]
        try await supabase
            .from("shared_checklist_items")
            .update(payload)
            .eq("id", value: item.id.uuidString)
            .execute()

        item.isCompleted = nowCompleted
        item.completedByUserId = nowCompleted ? userId.uuidString : nil
        item.completedAt = nowCompleted ? Date() : nil
    }

    func updateChecklistItem(_ item: SharedChecklistItem, text: String) async throws {
        let payload: [String: AnyEncodable] = ["text": AnyEncodable(text)]
        try await supabase
            .from("shared_checklist_items")
            .update(payload)
            .eq("id", value: item.id.uuidString)
            .execute()
        item.text = text
    }

    func deleteChecklistItem(_ item: SharedChecklistItem) async throws {
        guard let context = modelContext else { return }
        try await supabase
            .from("shared_checklist_items")
            .delete()
            .eq("id", value: item.id.uuidString)
            .execute()
        context.delete(item)
    }

    // MARK: - Errors

    enum SyncError: Error {
        case noContext
        case inviteNotFound   // Token doesn't exist or already accepted
        case selfInvite       // User trying to accept their own invite
    }
}

// MARK: - AnyEncodable helper

struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init<T: Encodable>(_ value: T) { _encode = { try value.encode(to: $0) } }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}
