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
    let created_at: Date
    let updated_at: Date
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

    private init() {}

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Full Sync (called on app open / foreground)

    func syncAll(userId: UUID) async {
        guard let context = modelContext else { return }
        do {
            try await syncSpaces(userId: userId, context: context)
            try await syncEvents(userId: userId, context: context)
            try await syncChecklist(userId: userId, context: context)
            print("✅ SharedSpace sync complete")
        } catch {
            print("❌ SharedSpace sync failed: \(error)")
        }
    }

    // MARK: - Sync Spaces

    private func syncSpaces(userId: UUID, context: ModelContext) async throws {
        let rows: [SpaceRow] = try await supabase
            .from("shared_spaces")
            .select()
            .or("created_by_user_id.eq.\(userId),invited_user_id.eq.\(userId)")
            .execute()
            .value

        let existing = try context.fetch(FetchDescriptor<SharedSpace>())
        let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for row in rows {
            if let local = existingById[row.id] {
                local.status = SharedSpace.Status(rawValue: row.status) ?? .pending
                local.invitedUserId = row.invited_user_id?.uuidString
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
                // Accept invite — link our userId
                try await supabase
                    .from("shared_spaces")
                    .update(["invited_user_id": userId.uuidString, "status": "active"])
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
                }
            }
        }
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
                await syncAll(userId: userId)
            }
        }

        // Listen for checklist changes
        let checklistTask = Task {
            let channel = supabase.channel("shared-checklist-\(userId)")
            let changes = channel.postgresChange(AnyAction.self, table: "shared_checklist_items")
            await channel.subscribe()
            for await _ in changes {
                await syncAll(userId: userId)
            }
        }

        // Listen for space status changes (invite accepted)
        let spacesTask = Task {
            let channel = supabase.channel("shared-spaces-\(userId)")
            let changes = channel.postgresChange(AnyAction.self, table: "shared_spaces")
            await channel.subscribe()
            for await _ in changes {
                await syncAll(userId: userId)
            }
        }

        realtimeTasks = [eventsTask, checklistTask, spacesTask]
        print("🔴 SharedSpace realtime subscriptions active")
    }

    func stopRealtime() {
        realtimeTasks.forEach { $0.cancel() }
        realtimeTasks = []
    }

    // MARK: - CRUD: Spaces

    func createSpace(name: String, userId: UUID) async throws -> SharedSpace {
        guard let context = modelContext else { throw SyncError.noContext }

        // Generate a unique invite token client-side
        let inviteToken = UUID().uuidString.lowercased()

        let payload: [String: String] = [
            "created_by_user_id": userId.uuidString,
            "invited_user_email": "",
            "invite_token": inviteToken,
            "status": "pending"
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
        guard let context = modelContext else { throw SyncError.noContext }

        // Look up the space by token
        let rows: [SpaceRow] = try await supabase
            .from("shared_spaces")
            .select()
            .eq("invite_token", value: token)
            .eq("status", value: "pending")
            .execute()
            .value

        guard let row = rows.first else {
            throw SyncError.inviteNotFound
        }

        // Guard: can't accept your own invite
        guard row.created_by_user_id.uuidString.lowercased() != userId.uuidString.lowercased() else {
            throw SyncError.selfInvite
        }

        // Atomically claim the invite (only succeeds if still pending + unclaimed)
        try await supabase
            .from("shared_spaces")
            .update(["invited_user_id": userId.uuidString, "status": "active"])
            .eq("invite_token", value: token)
            .eq("status", value: "pending")
            .is("invited_user_id", value: nil)
            .execute()

        // Upsert locally
        let existing = try context.fetch(FetchDescriptor<SharedSpace>())
        if existing.first(where: { $0.id == row.id }) == nil {
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
        }

        // Sync everything now that we're active
        await syncAll(userId: userId)
    }

    // MARK: - CRUD: Events

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
