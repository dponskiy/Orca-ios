//
//  SupabaseSyncService.swift
//  Orca
//
//  Created by David Piliponskiy on 3/4/26.
//

import Foundation
import SwiftData
import Supabase

@MainActor
class SupabaseSyncService {
    static let shared = SupabaseSyncService()

    var isSyncing = false
    var lastSyncDate: Date?
    var syncError: String?

    private var supabase: SupabaseClient { SupabaseManager.shared.client }
    private var syncTask: Task<Void, Never>?
    private var modelContext: ModelContext?

    private init() {}

    // MARK: - Pending Delete Tracking

    private let pendingDeleteKey = "pendingMemoryDeletes"

    private var pendingDeleteIds: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: pendingDeleteKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: pendingDeleteKey) }
    }

    private func markPendingDelete(id: UUID) {
        var ids = pendingDeleteIds
        ids.insert(id.uuidString.lowercased())
        pendingDeleteIds = ids
    }

    private func clearPendingDelete(id: UUID) {
        var ids = pendingDeleteIds
        ids.remove(id.uuidString.lowercased())
        pendingDeleteIds = ids
    }

    // MARK: - Setup

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Full Sync

    func syncAll(userId: UUID) async {
        guard !isSyncing else { return }
        guard let context = modelContext else { return }

        isSyncing = true
        syncError = nil

        do {
            try deduplicateLocal(context: context)
            try await upsertUser(userId: userId)
            try await syncEchos(userId: userId, context: context)
            try await syncMemories(userId: userId, context: context)
            try await syncSubTasks(userId: userId, context: context)
            try await syncPings(userId: userId, context: context)
            try await syncPersons(userId: userId, context: context)
            try await syncGiftItems(userId: userId, context: context)
            try await syncWatchlistItems(userId: userId, context: context)
            try await syncTCGCards(userId: userId, context: context)
            try await syncSmiskiItems(userId: userId, context: context)
            try await syncLegoSets(userId: userId, context: context)
            try await syncGameItems(userId: userId, context: context)
            lastSyncDate = Date()
        } catch {
            syncError = error.localizedDescription
            print("❌ Sync failed: \(error)")
        }

        isSyncing = false
    }

    // MARK: - Deduplicate Local

    private func deduplicateLocal(context: ModelContext) throws {
        let echos = try context.fetch(FetchDescriptor<Echo>())
        var seenEchoNames = Set<String>()
        for echo in echos {
            if seenEchoNames.contains(echo.name) {
                context.delete(echo)
            } else {
                seenEchoNames.insert(echo.name)
            }
        }

        let memories = try context.fetch(FetchDescriptor<Memory>())
        var seenMemoryIds = Set<UUID>()
        for memory in memories {
            if seenMemoryIds.contains(memory.id) {
                context.delete(memory)
            } else {
                seenMemoryIds.insert(memory.id)
            }
        }
        let allPersons = try context.fetch(FetchDescriptor<Person>())
        var seenPersonNames = [String: Person]()
        for person in allPersons.sorted(by: { $0.updatedAt > $1.updatedAt }) {
            let key = person.name.lowercased()
            if seenPersonNames[key] != nil {
                context.delete(person)
            } else {
                seenPersonNames[key] = person
            }
        }
        let pings = try context.fetch(FetchDescriptor<Ping>())
        var seenPingIds = Set<UUID>()
        for ping in pings {
            if seenPingIds.contains(ping.id) {
                context.delete(ping)
            } else {
                seenPingIds.insert(ping.id)
            }
        }
        let allGiftItems = try context.fetch(FetchDescriptor<GiftItem>())
        var seenGiftKeys = Set<String>()
        for item in allGiftItems.sorted(by: { $0.createdAt > $1.createdAt }) {
            let key = "\(item.personId.uuidString)-\(item.name.lowercased())-\(item.occasion)"
            if seenGiftKeys.contains(key) {
                context.delete(item)
            } else {
                seenGiftKeys.insert(key)
            }
        }
        // Deduplicate watchlist items by id
        let allWatchlistItems = try context.fetch(FetchDescriptor<WatchlistItem>())
        var seenWatchlistIds = Set<UUID>()
        for item in allWatchlistItems {
            if seenWatchlistIds.contains(item.id) { context.delete(item) }
            else { seenWatchlistIds.insert(item.id) }
        }
        let allTCGCards = try context.fetch(FetchDescriptor<TCGCard>())
        var seenTCGIds = Set<UUID>()
        for card in allTCGCards {
            if seenTCGIds.contains(card.id) { context.delete(card) }
            else { seenTCGIds.insert(card.id) }
        }
        let allSmiskiItems = try context.fetch(FetchDescriptor<SmiskiItem>())
        var seenSmiskiIds = Set<UUID>()
        for item in allSmiskiItems {
            if seenSmiskiIds.contains(item.id) { context.delete(item) }
            else { seenSmiskiIds.insert(item.id) }
        }
        let allLegoSets = try context.fetch(FetchDescriptor<LegoSet>())
        var seenLegoIds = Set<UUID>()
        for set in allLegoSets {
            if seenLegoIds.contains(set.id) { context.delete(set) }
            else { seenLegoIds.insert(set.id) }
        }
        let allGameItems = try context.fetch(FetchDescriptor<GameItem>())
        var seenGameIds = Set<UUID>()
        for game in allGameItems {
            if seenGameIds.contains(game.id) { context.delete(game) }
            else { seenGameIds.insert(game.id) }
        }
        try context.save()
        print("✅ Local deduplication complete")
    }

    // MARK: - Patch Missing Default Echos

    private func patchMissingDefaultEchos(context: ModelContext, userId: UUID) async throws {
        let existingEchos = try context.fetch(FetchDescriptor<Echo>())
        let existingNames = Set(existingEchos.map { $0.name.lowercased() })

        let required: [(name: String, emoji: String, sortOrder: Int)] = [
            ("Workout", "💪", 21),
        ]

        var newEchos: [Echo] = []
        for item in required where !existingNames.contains(item.name.lowercased()) {
            let echo = Echo(name: item.name, emoji: item.emoji, sortOrder: item.sortOrder)
            context.insert(echo)
            newEchos.append(echo)
            print("✅ Patched missing echo: \(item.name)")
        }

        if !newEchos.isEmpty {
            try context.save()
            let rows = newEchos.map { EchoRow(from: $0, userId: userId) }
            try await supabase.from("echos").upsert(rows, onConflict: "id").execute()
        }
    }

    // MARK: - Upsert User

    private func upsertUser(userId: UUID) async throws {
        struct UserRow: Codable {
            let id: String
        }
        let row = UserRow(id: userId.uuidString)
        try await supabase
            .from("users")
            .upsert(row, onConflict: "id")
            .execute()
        print("✅ User upserted: \(userId)")
    }

    // MARK: - Sync Echos

    private func syncEchos(userId: UUID, context: ModelContext) async throws {
        let remoteEchos: [EchoRow] = try await supabase
            .from("echos")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        let localEchos = try context.fetch(FetchDescriptor<Echo>())
        let didSeed = UserDefaults.standard.bool(forKey: "orcaDidSeedDefaults")

        if remoteEchos.isEmpty && (!didSeed || localEchos.isEmpty) {
            if localEchos.isEmpty {
                Echo.seedDefaults(context: context)
            }
            UserDefaults.standard.set(true, forKey: "orcaDidSeedDefaults")
            try context.save()

            let seededEchos = try context.fetch(FetchDescriptor<Echo>())
            let echoRows = seededEchos.map { EchoRow(from: $0, userId: userId) }
            if !echoRows.isEmpty {
                try await supabase.from("echos").upsert(echoRows, onConflict: "id").execute()
            }
            print("✅ Echos seeded and pushed for new user")
            return
        }

        if !didSeed && !remoteEchos.isEmpty {
            UserDefaults.standard.set(true, forKey: "orcaDidSeedDefaults")
        }

        for remote in remoteEchos {
            guard let remoteId = UUID(uuidString: remote.id) else { continue }
            // Thoughts is a local-only system echo — never import it from Supabase
            guard remote.name != "Thoughts" else { continue }

            if let existing = localEchos.first(where: { $0.id == remoteId }) {
                existing.name = remote.name
                existing.emoji = remote.emoji
                existing.sortOrder = remote.sort_order
                existing.learnedKeywords = remote.learned_keywords ?? []
                continue
            }

            if let nameMatch = localEchos.first(where: { $0.name == remote.name }) {
                let allMemories = try context.fetch(FetchDescriptor<Memory>())
                for memory in allMemories where memory.echoId == nameMatch.id {
                    memory.echoId = remoteId
                }
                nameMatch.id = remoteId
                nameMatch.emoji = remote.emoji
                nameMatch.sortOrder = remote.sort_order
                nameMatch.learnedKeywords = remote.learned_keywords ?? []
                continue
            }

            let echo = Echo(name: remote.name, emoji: remote.emoji,
                            isDefault: remote.is_default, sortOrder: remote.sort_order)
            echo.id = remoteId
            echo.learnedKeywords = remote.learned_keywords ?? []
            context.insert(echo)
        }

        try context.save()

        let mergedEchos = try context.fetch(FetchDescriptor<Echo>())
        let remoteIds = Set(remoteEchos.map { $0.id })
        // Exclude system echoes (e.g. Thoughts) from being pushed to Supabase
        let newLocalEchos = mergedEchos.filter { !remoteIds.contains($0.id.uuidString) && !$0.isSystemEcho }

        if !newLocalEchos.isEmpty {
            let echoRows = newLocalEchos.map { EchoRow(from: $0, userId: userId) }
            try await supabase.from("echos").upsert(echoRows, onConflict: "id").execute()
        }

        try await patchMissingDefaultEchos(context: context, userId: userId)

        print("✅ Echos synced")
    }

    // MARK: - Sync Memories

    private func syncMemories(userId: UUID, context: ModelContext) async throws {
        let localMemories = try context.fetch(FetchDescriptor<Memory>())

        let memoryRows = localMemories.reduce(into: [MemoryRow]()) { result, memory in
            guard !result.contains(where: { $0.id == memory.id.uuidString }) else { return }
            result.append(MemoryRow(
                id: memory.id.uuidString,
                user_id: userId.uuidString,
                text: memory.text,
                echo_id: memory.echoId.uuidString,
                tags: memory.tags,
                detected_date: memory.detectedDate.map { ISO8601DateFormatter().string(from: $0) },
                end_date: memory.endDate.map { ISO8601DateFormatter().string(from: $0) },
                capture_type: memory.captureType.rawValue,
                sonar_confidence: memory.sonarConfidence,
                echo_confidence: memory.echoConfidence,
                date_confidence: memory.dateConfidence,
                is_actionable: memory.isActionable,
                is_completed: memory.isCompleted,
                completed_at: memory.completedAt.map { ISO8601DateFormatter().string(from: $0) },
                recurring_completed_dates: memory.recurringCompletedDates,
                was_edited: memory.wasEdited,
                created_at: ISO8601DateFormatter().string(from: memory.createdAt),
                updated_at: ISO8601DateFormatter().string(from: memory.updatedAt),
                location_name: memory.locationName,
                location_address: memory.locationAddress,
                latitude: memory.latitude,
                longitude: memory.longitude,
                url: memory.url
            ))
        }

        if !memoryRows.isEmpty {
            try await supabase
                .from("memories")
                .upsert(memoryRows, onConflict: "id")
                .execute()
        }

        let localIds = Set(localMemories.map { $0.id.uuidString.lowercased() })

        let remoteMemories: [MemoryRow] = try await supabase
            .from("memories")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        // Retry any deletes that didn't complete (e.g. app closed mid-flight)
        let pending = pendingDeleteIds
        for idStr in pending {
            do {
                try await supabase.from("memories").delete().eq("id", value: idStr).execute()
                if let uid = UUID(uuidString: idStr) { clearPendingDelete(id: uid) }
            } catch {
                print("⚠️ Retry delete failed for \(idStr): \(error)")
            }
        }

        for remote in remoteMemories {
            // Never re-insert a memory the user deleted locally
            guard !pendingDeleteIds.contains(remote.id.lowercased()) else { continue }
            guard !localIds.contains(remote.id.lowercased()) else { continue }
            guard let remoteId = UUID(uuidString: remote.id),
                  let echoId = UUID(uuidString: remote.echo_id) else { continue }
            let existing = localMemories.first { $0.id == remoteId }
            guard existing == nil else { continue }

            let memory = Memory(text: remote.text, echoId: echoId)
            memory.id = remoteId
            memory.tags = remote.tags
            memory.sonarConfidence = remote.sonar_confidence
            memory.echoConfidence = remote.echo_confidence
            memory.dateConfidence = remote.date_confidence
            memory.isActionable = remote.is_actionable
            memory.isCompleted = remote.is_completed
            memory.recurringCompletedDates = remote.recurring_completed_dates ?? []
            memory.wasEdited = remote.was_edited
            memory.locationName = remote.location_name
            memory.locationAddress = remote.location_address
            memory.latitude = remote.latitude
            memory.longitude = remote.longitude
            memory.url = remote.url

            if let dateStr = remote.detected_date {
                memory.detectedDate = ISO8601DateFormatter().date(from: dateStr)
            }
            if let endDateStr = remote.end_date {
                memory.endDate = ISO8601DateFormatter().date(from: endDateStr)
            }
            if let completedStr = remote.completed_at {
                memory.completedAt = ISO8601DateFormatter().date(from: completedStr)
            }
            if let createdStr = remote.created_at {
                memory.createdAt = ISO8601DateFormatter().date(from: createdStr) ?? Date()
            }
            if let updatedStr = remote.updated_at {
                memory.updatedAt = ISO8601DateFormatter().date(from: updatedStr) ?? Date()
            }
            if let captureStr = remote.capture_type,
               let captureType = Memory.CaptureType(rawValue: captureStr) {
                memory.captureType = captureType
            }

            context.insert(memory)
        }

        print("✅ Memories synced")
    }

    // MARK: - Sync SubTasks

    private func syncSubTasks(userId: UUID, context: ModelContext) async throws {
        let localSubTasks = try context.fetch(FetchDescriptor<SubTask>())

        // Only push SubTasks whose parent Memory exists locally (= was already pushed to Supabase
        // by syncMemories). This prevents foreign key violations when a memory hasn't synced yet
        // or a SubTask outlived a deleted memory.
        let localMemories = try context.fetch(FetchDescriptor<Memory>())
        let validMemoryIds = Set(localMemories.map { $0.id.uuidString.lowercased() })

        let rows = localSubTasks.reduce(into: [SubTaskRow]()) { result, st in
            guard !result.contains(where: { $0.id == st.id.uuidString }) else { return }
            guard validMemoryIds.contains(st.memoryId.uuidString.lowercased()) else { return }
            result.append(SubTaskRow(
                id: st.id.uuidString,
                user_id: userId.uuidString,
                memory_id: st.memoryId.uuidString,
                text: st.text,
                is_completed: st.isCompleted,
                sort_order: st.sortOrder,
                created_at: ISO8601DateFormatter().string(from: st.createdAt)
            ))
        }

        if !rows.isEmpty {
            try await supabase.from("sub_tasks").upsert(rows, onConflict: "id").execute()
        }

        // Lowercase both sides — Supabase returns UUIDs lowercase, Swift uuidString is uppercase
        let localIds = Set(localSubTasks.map { $0.id.uuidString.lowercased() })

        let remoteSubTasks: [SubTaskRow] = try await supabase
            .from("sub_tasks")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        for remote in remoteSubTasks {
            guard !localIds.contains(remote.id.lowercased()),
                  let remoteId = UUID(uuidString: remote.id),
                  let memoryId = UUID(uuidString: remote.memory_id) else { continue }

            let st = SubTask(memoryId: memoryId, text: remote.text, sortOrder: remote.sort_order)
            st.id = remoteId
            st.isCompleted = remote.is_completed
            if let c = remote.created_at { st.createdAt = ISO8601DateFormatter().date(from: c) ?? Date() }
            context.insert(st)
        }

        try context.save()

        // Reconcile hasChecklist — after a reinstall memories sync before subtasks,
        // so hasChecklist can be false even though subtasks exist in Supabase.
        // After subtasks are in, flip the flag for any memory that has them.
        let allSubTasks = try context.fetch(FetchDescriptor<SubTask>())
        let memoryIdsWithSubTasks = Set(allSubTasks.map { $0.memoryId })
        let allMemories = try context.fetch(FetchDescriptor<Memory>())
        var checklistFixed = false
        for memory in allMemories {
            if memoryIdsWithSubTasks.contains(memory.id) && !memory.hasChecklist {
                memory.hasChecklist = true
                checklistFixed = true
            }
        }
        if checklistFixed { try context.save() }

        print("✅ SubTasks synced")
    }

    // MARK: - Sync Pings

    private func syncPings(userId: UUID, context: ModelContext) async throws {
        let localPings = try context.fetch(FetchDescriptor<Ping>())

        struct MemoryIdRow: Codable {
            let id: String
        }

        let remoteMemoryRows: [MemoryIdRow] = try await supabase
            .from("memories")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        let safeMemoryIds = Set(remoteMemoryRows.map { $0.id })

        let pingRows = localPings.reduce(into: [PingRow]()) { result, ping in
            guard !result.contains(where: { $0.id == ping.id.uuidString }) else { return }
            guard safeMemoryIds.contains(ping.memoryId.uuidString) else { return }
            result.append(PingRow(
                id: ping.id.uuidString,
                user_id: userId.uuidString,
                memory_id: ping.memoryId.uuidString,
                fire_date: ISO8601DateFormatter().string(from: ping.fireDate),
                fire_time: ISO8601DateFormatter().string(from: ping.fireTime),
                recurrence: ping.recurrence.rawValue,
                is_active: ping.isActive,
                last_fired: ping.lastFired.map { ISO8601DateFormatter().string(from: $0) },
                created_at: ISO8601DateFormatter().string(from: ping.createdAt)
            ))
        }

        if !pingRows.isEmpty {
            try await supabase
                .from("pings")
                .upsert(pingRows, onConflict: "id")
                .execute()
        }

        let localIds = Set(localPings.map { $0.id.uuidString.lowercased() })

        // Only re-create pings whose parent memory still exists locally
        let localMemories = try context.fetch(FetchDescriptor<Memory>())
        let localMemoryIds = Set(localMemories.map { $0.id.uuidString.lowercased() })

        let remotePings: [PingRow] = try await supabase
            .from("pings")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        for remote in remotePings {
            guard !localIds.contains(remote.id.lowercased()) else { continue }
            // Skip orphaned pings whose memory was deleted — prevents phantom pings on sync
            guard localMemoryIds.contains(remote.memory_id.lowercased()) else { continue }
            guard let remoteId = UUID(uuidString: remote.id),
                  let memoryId = UUID(uuidString: remote.memory_id),
                  let fireDate = ISO8601DateFormatter().date(from: remote.fire_date) else { continue }
            let existing = localPings.first { $0.id == remoteId }
            guard existing == nil else { continue }

            let recurrence = Ping.Recurrence(rawValue: remote.recurrence) ?? .none
            let ping = Ping(memoryId: memoryId, fireDate: fireDate, recurrence: recurrence)
            ping.id = remoteId
            ping.isActive = remote.is_active

            if let fireTimeStr = remote.fire_time,
               let fireTime = ISO8601DateFormatter().date(from: fireTimeStr) {
                ping.fireTime = fireTime
            }
            if let lastFiredStr = remote.last_fired,
               let lastFired = ISO8601DateFormatter().date(from: lastFiredStr) {
                ping.lastFired = lastFired
            }

            context.insert(ping)
        }

        print("✅ Pings synced")
    }

    // MARK: - Sync Persons

    private func syncPersons(userId: UUID, context: ModelContext) async throws {
        let localPersons = try context.fetch(FetchDescriptor<Person>())

        let personRows = localPersons.reduce(into: [PersonRow]()) { result, p in
            guard !result.contains(where: { $0.id == p.id.uuidString }) else { return }
            result.append(PersonRow(
                id: p.id.uuidString,
                user_id: userId.uuidString,
                name: p.name,
                relationship: p.relationship,
                birthday: p.birthday.map { ISO8601DateFormatter().string(from: $0) },
                notes: p.notes,
                linked_memory_ids: p.linkedMemoryIds.map { $0.uuidString },
                occasion_budgets: p.occasionBudgets.isEmpty ? nil : p.occasionBudgets,
                custom_occasions: p.customOccasions.isEmpty ? nil : p.customOccasions,
                created_at: ISO8601DateFormatter().string(from: p.createdAt),
                updated_at: ISO8601DateFormatter().string(from: p.updatedAt)
            ))
        }

        if !personRows.isEmpty {
            try await supabase.from("persons").upsert(personRows, onConflict: "id").execute()
        }

        let remotePersons: [PersonRow] = try await supabase
            .from("persons").select().eq("user_id", value: userId.uuidString).execute().value

        let localIds = Set(localPersons.map { $0.id.uuidString.lowercased() })
        let localNames = Set(localPersons.map { $0.name.lowercased() })

        for remote in remotePersons {
            guard !localIds.contains(remote.id.lowercased()),
                  let remoteId = UUID(uuidString: remote.id) else { continue }
            guard !localNames.contains(remote.name.lowercased()) else { continue }
            let p = Person(name: remote.name, relationship: remote.relationship)
            p.id = remoteId
            p.notes = remote.notes
            p.occasionBudgets = remote.occasion_budgets ?? [:]
            p.customOccasions = remote.custom_occasions ?? []
            p.linkedMemoryIds = (remote.linked_memory_ids ?? []).compactMap { UUID(uuidString: $0) }
            if let bdStr = remote.birthday { p.birthday = ISO8601DateFormatter().date(from: bdStr) }
            if let createdStr = remote.created_at { p.createdAt = ISO8601DateFormatter().date(from: createdStr) ?? Date() }
            context.insert(p)
        }
        print("✅ Persons synced")
    }

    // MARK: - Sync Gift Items

    private func syncGiftItems(userId: UUID, context: ModelContext) async throws {
        let localItems = try context.fetch(FetchDescriptor<GiftItem>())

        let rows = localItems.reduce(into: [GiftItemRow]()) { result, item in
            guard !result.contains(where: { $0.id == item.id.uuidString }) else { return }
            guard item.personId != GiftItem.wishlistPersonId else { return }
            result.append(GiftItemRow(
                id: item.id.uuidString,
                user_id: userId.uuidString,
                person_id: item.personId.uuidString,
                name: item.name,
                price: item.price,
                status: item.statusRaw,
                occasion: item.occasion,
                year: item.year,
                linked_memory_id: item.linkedMemoryId?.uuidString,
                url: item.url,
                created_at: ISO8601DateFormatter().string(from: item.createdAt)
            ))
        }

        if !rows.isEmpty {
            try await supabase.from("gift_items").upsert(rows, onConflict: "id").execute()
        }

        let remoteItems: [GiftItemRow] = try await supabase
            .from("gift_items").select().eq("user_id", value: userId.uuidString).execute().value

        let localIds = Set(localItems.map { $0.id.uuidString.lowercased() })
        for remote in remoteItems {
            guard !localIds.contains(remote.id.lowercased()),
                  let remoteId = UUID(uuidString: remote.id),
                  let personId = UUID(uuidString: remote.person_id) else { continue }

            let alreadyExists = localItems.contains {
                $0.personId == personId &&
                $0.name.lowercased() == remote.name.lowercased() &&
                $0.occasion == remote.occasion
            }
            guard !alreadyExists else { continue }

            let item = GiftItem(personId: personId, name: remote.name, occasion: remote.occasion)
            item.id = remoteId
            item.price = remote.price
            item.statusRaw = remote.status
            item.year = remote.year
            item.linkedMemoryId = remote.linked_memory_id.flatMap { UUID(uuidString: $0) }
            item.url = remote.url
            if let createdStr = remote.created_at { item.createdAt = ISO8601DateFormatter().date(from: createdStr) ?? Date() }
            context.insert(item)
        }
        print("✅ Gift items synced")
    }

    // MARK: - Sync Watchlist Items

    private func syncWatchlistItems(userId: UUID, context: ModelContext) async throws {
        let localItems = try context.fetch(FetchDescriptor<WatchlistItem>())
        print("🔍 Watchlist sync — local items count: \(localItems.count)")

        let rows = localItems.reduce(into: [WatchlistItemRow]()) { result, item in
            guard !result.contains(where: { $0.id == item.id.uuidString }) else { return }
            result.append(WatchlistItemRow(
                id: item.id.uuidString,
                user_id: userId.uuidString,
                title: item.title,
                item_type: item.itemType,
                streaming_service: item.streamingService,
                status: item.status,
                rating: item.rating,
                comment: item.comment,
                created_at: ISO8601DateFormatter().string(from: item.createdAt),
                completed_at: item.completedAt.map { ISO8601DateFormatter().string(from: $0) },
                updated_at: ISO8601DateFormatter().string(from: item.updatedAt),
                season: item.season
            ))
        }

        if !rows.isEmpty {
            try await supabase.from("watchlist_items").upsert(rows, onConflict: "id").execute()
        }

        let localIds = Set(localItems.map { $0.id.uuidString.lowercased() })

        let remoteItems: [WatchlistItemRow] = try await supabase
            .from("watchlist_items")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        let localTitles = Set(localItems.map { $0.title.lowercased() })

        for remote in remoteItems {
            guard !localIds.contains(remote.id.lowercased()),
                  let remoteId = UUID(uuidString: remote.id) else { continue }
            // Skip if we already have an item with this title locally
            guard !localTitles.contains(remote.title.lowercased()) else { continue }

            let item = WatchlistItem(
                title: remote.title,
                itemType: remote.item_type,
                streamingService: remote.streaming_service
            )
            item.id = remoteId
            item.status = remote.status
            item.rating = remote.rating
            item.comment = remote.comment
            if let c = remote.created_at { item.createdAt = ISO8601DateFormatter().date(from: c) ?? Date() }
            if let u = remote.updated_at { item.updatedAt = ISO8601DateFormatter().date(from: u) ?? Date() }
            if let ca = remote.completed_at { item.completedAt = ISO8601DateFormatter().date(from: ca) }
            item.season = remote.season
            context.insert(item)
        }

        print("✅ Watchlist items synced")
    }

    // MARK: - Push Single Memory

    func pushMemory(_ memory: Memory, userId: UUID) async {
        let row = MemoryRow(
            id: memory.id.uuidString,
            user_id: userId.uuidString,
            text: memory.text,
            echo_id: memory.echoId.uuidString,
            tags: memory.tags,
            detected_date: memory.detectedDate.map { ISO8601DateFormatter().string(from: $0) },
            end_date: memory.endDate.map { ISO8601DateFormatter().string(from: $0) },
            capture_type: memory.captureType.rawValue,
            sonar_confidence: memory.sonarConfidence,
            echo_confidence: memory.echoConfidence,
            date_confidence: memory.dateConfidence,
            is_actionable: memory.isActionable,
            is_completed: memory.isCompleted,
            completed_at: memory.completedAt.map { ISO8601DateFormatter().string(from: $0) },
            recurring_completed_dates: memory.recurringCompletedDates,
            was_edited: memory.wasEdited,
            created_at: ISO8601DateFormatter().string(from: memory.createdAt),
            updated_at: ISO8601DateFormatter().string(from: memory.updatedAt),
            location_name: memory.locationName,
            location_address: memory.locationAddress,
            latitude: memory.latitude,
            longitude: memory.longitude,
            url: memory.url
        )

        do {
            try await supabase
                .from("memories")
                .upsert(row, onConflict: "id")
                .execute()
            print("✅ Memory pushed: \(memory.id)")
        } catch {
            print("❌ Failed to push memory: \(error)")
        }
    }

    // MARK: - Push Single Ping

    func pushPing(_ ping: Ping, userId: UUID) async {
        let row = PingRow(
            id: ping.id.uuidString,
            user_id: userId.uuidString,
            memory_id: ping.memoryId.uuidString,
            fire_date: ISO8601DateFormatter().string(from: ping.fireDate),
            fire_time: ISO8601DateFormatter().string(from: ping.fireTime),
            recurrence: ping.recurrence.rawValue,
            is_active: ping.isActive,
            last_fired: ping.lastFired.map { ISO8601DateFormatter().string(from: $0) },
            created_at: ISO8601DateFormatter().string(from: ping.createdAt)
        )

        do {
            try await supabase
                .from("pings")
                .upsert(row, onConflict: "id")
                .execute()
            print("✅ Ping pushed: \(ping.id)")
        } catch {
            print("❌ Failed to push ping: \(error)")
        }
    }

    // MARK: - Push Single Echo

    func pushEcho(_ echo: Echo, userId: UUID) async {
        guard !echo.isSystemEcho else { return }  // Thoughts is local-only, never push
        let row = EchoRow(from: echo, userId: userId)
        do {
            try await supabase
                .from("echos")
                .upsert(row, onConflict: "id")
                .execute()
            print("✅ Echo pushed: \(echo.id)")
        } catch {
            print("❌ Failed to push echo: \(error)")
        }
    }

    // MARK: - Push Single SubTask

    func pushSubTask(_ subTask: SubTask, userId: UUID) async {
        let row = SubTaskRow(
            id: subTask.id.uuidString,
            user_id: userId.uuidString,
            memory_id: subTask.memoryId.uuidString,
            text: subTask.text,
            is_completed: subTask.isCompleted,
            sort_order: subTask.sortOrder,
            created_at: ISO8601DateFormatter().string(from: subTask.createdAt)
        )
        do {
            try await supabase.from("sub_tasks").upsert(row, onConflict: "id").execute()
            print("✅ SubTask pushed: \(subTask.id)")
        } catch {
            print("❌ Failed to push subTask: \(error)")
        }
    }

    // MARK: - Delete SubTask

    func deleteSubTask(id: UUID) async {
        do {
            try await supabase.from("sub_tasks").delete().eq("id", value: id.uuidString).execute()
            print("✅ SubTask deleted from Supabase: \(id)")
        } catch {
            print("❌ Failed to delete subTask: \(error)")
        }
    }

    // MARK: - Delete Ping

    func deletePing(id: UUID) async {
        do {
            try await supabase.from("pings").delete().eq("id", value: id.uuidString).execute()
            print("✅ Ping deleted from Supabase: \(id)")
        } catch {
            print("❌ Failed to delete ping: \(error)")
        }
    }

    // MARK: - Delete Memory

    /// Preferred call site: registers the pending-delete synchronously (so UserDefaults
    /// is written before any Task runs), then fires the network delete in the background.
    /// Safe to call from a button action on the main thread.
    func scheduleDelete(id: UUID) {
        markPendingDelete(id: id)
        Task { await deleteMemory(id: id) }
    }

    func deleteMemory(id: UUID) async {
        markPendingDelete(id: id) // no-op if scheduleDelete already registered it
        do {
            try await supabase
                .from("memories")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()
            clearPendingDelete(id: id)
            print("✅ Memory deleted from Supabase: \(id)")
        } catch {
            print("❌ Failed to delete memory (will retry on next sync): \(error)")
        }
    }

    // MARK: - Delete Person

    func deletePerson(id: UUID) async {
        do {
            try await supabase
                .from("persons")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()
            print("✅ Person deleted from Supabase: \(id)")
        } catch {
            print("❌ Failed to delete person: \(error)")
        }
    }

    // MARK: - Delete Gift Item

    func deleteGiftItem(id: UUID) async {
        do {
            try await supabase
                .from("gift_items")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()
            print("✅ Gift item deleted from Supabase: \(id)")
        } catch {
            print("❌ Failed to delete gift item: \(error)")
        }
    }

    // MARK: - Delete Echo

    func deleteEcho(id: UUID) async {
        do {
            try await supabase
                .from("echos")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()
            print("✅ Echo deleted from Supabase: \(id)")
        } catch {
            print("❌ Failed to delete echo: \(error)")
        }
    }

    // MARK: - Push Single Watchlist Item

    func pushWatchlistItem(_ item: WatchlistItem, userId: UUID) async {
        let row = WatchlistItemRow(
            id: item.id.uuidString,
            user_id: userId.uuidString,
            title: item.title,
            item_type: item.itemType,
            streaming_service: item.streamingService,
            status: item.status,
            rating: item.rating,
            comment: item.comment,
            created_at: ISO8601DateFormatter().string(from: item.createdAt),
            completed_at: item.completedAt.map { ISO8601DateFormatter().string(from: $0) },
            updated_at: ISO8601DateFormatter().string(from: item.updatedAt),
            season: item.season
        )
        do {
            try await supabase.from("watchlist_items").upsert(row, onConflict: "id").execute()
        } catch {
            print("❌ Failed to push watchlist item: \(error)")
        }
    }

    // MARK: - Delete Watchlist Item

    func deleteWatchlistItem(id: UUID) async {
        do {
            try await supabase
                .from("watchlist_items")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()
            print("✅ Watchlist item deleted from Supabase: \(id)")
        } catch {
            print("❌ Failed to delete watchlist item: \(error)")
        }
    }

    // MARK: - Sync TCG Cards

    private func syncTCGCards(userId: UUID, context: ModelContext) async throws {
        let localCards = try context.fetch(FetchDescriptor<TCGCard>())
        let rows = localCards.reduce(into: [TCGCardRow]()) { result, card in
            guard !result.contains(where: { $0.id == card.id.uuidString }) else { return }
            result.append(TCGCardRow(
                id: card.id.uuidString,
                user_id: userId.uuidString,
                pokemon_id: card.pokemonId,
                name: card.name,
                set_id: card.setId,
                set_name: card.setName,
                number: card.number,
                image_url: card.imageURL,
                large_image_url: card.largeImageURL,
                rarity: card.rarity,
                status: card.statusRaw,
                market_price: card.marketPrice,
                low_price: card.lowPrice,
                high_price: card.highPrice,
                price_variant: card.priceVariant,
                added_at: ISO8601DateFormatter().string(from: card.addedAt),
                psa_grade: card.psaGrade,
                psa_target_grade: card.psaTargetGrade
            ))
        }
        if !rows.isEmpty {
            try await supabase.from("tcg_cards").upsert(rows, onConflict: "id").execute()
        }
        let localIds = Set(localCards.map { $0.id.uuidString.lowercased() })
        let remoteCards: [TCGCardRow] = try await supabase
            .from("tcg_cards").select().eq("user_id", value: userId.uuidString).execute().value
        for remote in remoteCards {
            guard !localIds.contains(remote.id.lowercased()), let remoteId = UUID(uuidString: remote.id) else { continue }
            let card = TCGCard(pokemonId: remote.pokemon_id, name: remote.name, setId: remote.set_id,
                               setName: remote.set_name, number: remote.number,
                               imageURL: remote.image_url, largeImageURL: remote.large_image_url,
                               rarity: remote.rarity)
            card.id = remoteId
            card.statusRaw = remote.status
            card.marketPrice = remote.market_price
            card.lowPrice = remote.low_price
            card.highPrice = remote.high_price
            card.priceVariant = remote.price_variant
            card.psaGrade = remote.psa_grade
            card.psaTargetGrade = remote.psa_target_grade
            if let a = remote.added_at { card.addedAt = ISO8601DateFormatter().date(from: a) ?? Date() }
            context.insert(card)
        }
        print("✅ TCG cards synced")
    }

    // MARK: - Sync Smiski Items

    private func syncSmiskiItems(userId: UUID, context: ModelContext) async throws {
        let localItems = try context.fetch(FetchDescriptor<SmiskiItem>())
        let rows = localItems.reduce(into: [SmiskiItemRow]()) { result, item in
            guard !result.contains(where: { $0.id == item.id.uuidString }) else { return }
            result.append(SmiskiItemRow(
                id: item.id.uuidString,
                user_id: userId.uuidString,
                figure_id: item.figureId,
                series_id: item.seriesId,
                series_name: item.seriesName,
                figure_name: item.figureName,
                is_secret: item.isSecret,
                status: item.statusRaw,
                added_at: ISO8601DateFormatter().string(from: item.addedAt)
            ))
        }
        if !rows.isEmpty {
            try await supabase.from("smiski_items").upsert(rows, onConflict: "id").execute()
        }
        let localIds = Set(localItems.map { $0.id.uuidString.lowercased() })
        let remoteItems: [SmiskiItemRow] = try await supabase
            .from("smiski_items").select().eq("user_id", value: userId.uuidString).execute().value
        for remote in remoteItems {
            guard !localIds.contains(remote.id.lowercased()), let remoteId = UUID(uuidString: remote.id) else { continue }
            let item = SmiskiItem(figureId: remote.figure_id, seriesId: remote.series_id,
                                  seriesName: remote.series_name, figureName: remote.figure_name,
                                  isSecret: remote.is_secret)
            item.id = remoteId
            item.statusRaw = remote.status
            if let a = remote.added_at { item.addedAt = ISO8601DateFormatter().date(from: a) ?? Date() }
            context.insert(item)
        }
        print("✅ Smiski items synced")
    }

    // MARK: - Sync Lego Sets

    private func syncLegoSets(userId: UUID, context: ModelContext) async throws {
        let localSets = try context.fetch(FetchDescriptor<LegoSet>())
        let rows = localSets.reduce(into: [LegoSetRow]()) { result, set in
            guard !result.contains(where: { $0.id == set.id.uuidString }) else { return }
            result.append(LegoSetRow(
                id: set.id.uuidString,
                user_id: userId.uuidString,
                set_num: set.setNum,
                name: set.name,
                year: set.year,
                theme_id: set.themeId,
                theme_name: set.themeName,
                num_parts: set.numParts,
                image_url: set.imageURL,
                status: set.statusRaw,
                added_at: ISO8601DateFormatter().string(from: set.addedAt)
            ))
        }
        if !rows.isEmpty {
            try await supabase.from("lego_sets").upsert(rows, onConflict: "id").execute()
        }
        let localIds = Set(localSets.map { $0.id.uuidString.lowercased() })
        let remoteSets: [LegoSetRow] = try await supabase
            .from("lego_sets").select().eq("user_id", value: userId.uuidString).execute().value
        for remote in remoteSets {
            guard !localIds.contains(remote.id.lowercased()), let remoteId = UUID(uuidString: remote.id) else { continue }
            let set = LegoSet(setNum: remote.set_num, name: remote.name, year: remote.year ?? 0,
                              themeId: remote.theme_id ?? 0, themeName: remote.theme_name,
                              numParts: remote.num_parts ?? 0, imageURL: remote.image_url ?? "")
            set.id = remoteId
            set.statusRaw = remote.status
            if let a = remote.added_at { set.addedAt = ISO8601DateFormatter().date(from: a) ?? Date() }
            context.insert(set)
        }
        print("✅ Lego sets synced")
    }

    // MARK: - Sync Game Items

    private func syncGameItems(userId: UUID, context: ModelContext) async throws {
        let localGames = try context.fetch(FetchDescriptor<GameItem>())
        let rows = localGames.reduce(into: [GameItemRow]()) { result, game in
            guard !result.contains(where: { $0.id == game.id.uuidString }) else { return }
            result.append(GameItemRow(
                id: game.id.uuidString,
                user_id: userId.uuidString,
                igdb_id: game.igdbId,
                name: game.name,
                cover_url: game.coverURL,
                genre_names: game.genreNames,
                platform_names: game.platformNames,
                rating: game.rating,
                release_year: game.releaseYear,
                summary: game.summary,
                is_owned: game.isOwned,
                primary_platform: game.primaryPlatform,
                added_at: ISO8601DateFormatter().string(from: game.addedAt)
            ))
        }
        if !rows.isEmpty {
            try await supabase.from("game_items").upsert(rows, onConflict: "id").execute()
        }
        let localIds = Set(localGames.map { $0.id.uuidString.lowercased() })
        let remoteGames: [GameItemRow] = try await supabase
            .from("game_items").select().eq("user_id", value: userId.uuidString).execute().value
        for remote in remoteGames {
            guard !localIds.contains(remote.id.lowercased()), let remoteId = UUID(uuidString: remote.id) else { continue }
            let game = GameItem(igdbId: remote.igdb_id, name: remote.name,
                                coverURL: remote.cover_url ?? "",
                                genreNames: remote.genre_names, platformNames: remote.platform_names,
                                rating: remote.rating, releaseYear: remote.release_year,
                                summary: remote.summary, isOwned: remote.is_owned,
                                primaryPlatform: remote.primary_platform ?? "")
            game.id = remoteId
            if let a = remote.added_at { game.addedAt = ISO8601DateFormatter().date(from: a) ?? Date() }
            context.insert(game)
        }
        print("✅ Game items synced")
    }

    // MARK: - Push Single Game Item

    func pushGameItem(_ game: GameItem, userId: UUID) async {
        let row = GameItemRow(
            id: game.id.uuidString, user_id: userId.uuidString, igdb_id: game.igdbId,
            name: game.name, cover_url: game.coverURL, genre_names: game.genreNames,
            platform_names: game.platformNames, rating: game.rating,
            release_year: game.releaseYear, summary: game.summary,
            is_owned: game.isOwned, primary_platform: game.primaryPlatform,
            added_at: ISO8601DateFormatter().string(from: game.addedAt)
        )
        do { try await supabase.from("game_items").upsert(row, onConflict: "id").execute() }
        catch { print("❌ Failed to push game item: \(error)") }
    }

    func deleteGameItem(id: UUID) async {
        do { try await supabase.from("game_items").delete().eq("id", value: id.uuidString).execute() }
        catch { print("❌ Failed to delete game item: \(error)") }
    }

    // MARK: - Push Single TCG Card

    func pushTCGCard(_ card: TCGCard, userId: UUID) async {
        let row = TCGCardRow(
            id: card.id.uuidString, user_id: userId.uuidString, pokemon_id: card.pokemonId,
            name: card.name, set_id: card.setId, set_name: card.setName, number: card.number,
            image_url: card.imageURL, large_image_url: card.largeImageURL, rarity: card.rarity,
            status: card.statusRaw, market_price: card.marketPrice, low_price: card.lowPrice,
            high_price: card.highPrice, price_variant: card.priceVariant,
            added_at: ISO8601DateFormatter().string(from: card.addedAt),
            psa_grade: card.psaGrade, psa_target_grade: card.psaTargetGrade
        )
        do { try await supabase.from("tcg_cards").upsert(row, onConflict: "id").execute() }
        catch { print("❌ Failed to push TCG card: \(error)") }
    }

    func deleteTCGCard(id: UUID) async {
        do { try await supabase.from("tcg_cards").delete().eq("id", value: id.uuidString).execute() }
        catch { print("❌ Failed to delete TCG card: \(error)") }
    }

    // MARK: - Push Single Smiski Item

    func pushSmiskiItem(_ item: SmiskiItem, userId: UUID) async {
        let row = SmiskiItemRow(
            id: item.id.uuidString, user_id: userId.uuidString, figure_id: item.figureId,
            series_id: item.seriesId, series_name: item.seriesName, figure_name: item.figureName,
            is_secret: item.isSecret, status: item.statusRaw,
            added_at: ISO8601DateFormatter().string(from: item.addedAt)
        )
        do { try await supabase.from("smiski_items").upsert(row, onConflict: "id").execute() }
        catch { print("❌ Failed to push Smiski item: \(error)") }
    }

    func deleteSmiskiItem(id: UUID) async {
        do { try await supabase.from("smiski_items").delete().eq("id", value: id.uuidString).execute() }
        catch { print("❌ Failed to delete Smiski item: \(error)") }
    }

    // MARK: - Push Single Lego Set

    func pushLegoSet(_ set: LegoSet, userId: UUID) async {
        let row = LegoSetRow(
            id: set.id.uuidString, user_id: userId.uuidString, set_num: set.setNum,
            name: set.name, year: set.year, theme_id: set.themeId, theme_name: set.themeName,
            num_parts: set.numParts, image_url: set.imageURL, status: set.statusRaw,
            added_at: ISO8601DateFormatter().string(from: set.addedAt)
        )
        do { try await supabase.from("lego_sets").upsert(row, onConflict: "id").execute() }
        catch { print("❌ Failed to push Lego set: \(error)") }
    }

    func deleteLegoSet(id: UUID) async {
        do { try await supabase.from("lego_sets").delete().eq("id", value: id.uuidString).execute() }
        catch { print("❌ Failed to delete Lego set: \(error)") }
    }

    // MARK: - Auto Sync

    func startAutoSync(userId: UUID) {
        syncTask?.cancel()
        syncTask = nil
        syncTask = Task { @MainActor in
            await syncAll(userId: userId)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)
                if !Task.isCancelled {
                    await syncAll(userId: userId)
                }
            }
        }
    }

    func stopAutoSync() {
        syncTask?.cancel()
        syncTask = nil
    }
}

// MARK: - Row Models

struct EchoRow: Codable {
    let id: String
    let user_id: String
    let name: String
    let emoji: String
    let is_default: Bool
    let sort_order: Int
    let created_at: String
    let learned_keywords: [String]?

    init(from echo: Echo, userId: UUID) {
        self.id = echo.id.uuidString
        self.user_id = userId.uuidString
        self.name = echo.name
        self.emoji = echo.emoji
        self.is_default = echo.isDefault
        self.sort_order = echo.sortOrder
        self.created_at = ISO8601DateFormatter().string(from: echo.createdAt)
        self.learned_keywords = echo.learnedKeywords
    }
}

struct MemoryRow: Codable {
    let id: String
    let user_id: String
    let text: String
    let echo_id: String
    let tags: [String]
    let detected_date: String?
    let end_date: String?
    let capture_type: String?
    let sonar_confidence: Double
    let echo_confidence: Double
    let date_confidence: Double?
    let is_actionable: Bool
    let is_completed: Bool
    let completed_at: String?
    // Local-day keys ("2026-08-07") for recurring-task completions. Opaque strings —
    // written in the completing device's local day, never timezone-converted.
    let recurring_completed_dates: [String]?
    let was_edited: Bool
    let created_at: String?
    let updated_at: String?
    let location_name: String?
    let location_address: String?
    let latitude: Double?
    let longitude: Double?
    let url: String?
}

struct PingRow: Codable {
    let id: String
    let user_id: String
    let memory_id: String
    let fire_date: String
    let fire_time: String?
    let recurrence: String
    let is_active: Bool
    let last_fired: String?
    let created_at: String
}

struct PersonRow: Codable {
    let id: String
    let user_id: String
    let name: String
    let relationship: String?
    let birthday: String?
    let notes: String?
    let linked_memory_ids: [String]?
    let occasion_budgets: [String: Double]?
    let custom_occasions: [String]?
    let created_at: String?
    let updated_at: String?
}

struct GiftItemRow: Codable {
    let id: String
    let user_id: String
    let person_id: String
    let name: String
    let price: Double?
    let status: String
    let occasion: String
    let year: Int
    let linked_memory_id: String?
    let url: String?
    let created_at: String?
}

struct WatchlistItemRow: Codable {
    let id: String
    let user_id: String
    let title: String
    let item_type: String
    let streaming_service: String?
    let status: String
    let rating: Int?
    let comment: String?
    let created_at: String?
    let completed_at: String?
    let updated_at: String?
    let season: Int?
}

struct SubTaskRow: Codable {
    let id: String
    let user_id: String
    let memory_id: String
    let text: String
    let is_completed: Bool
    let sort_order: Int
    let created_at: String?
}

struct TCGCardRow: Codable {
    let id: String
    let user_id: String
    let pokemon_id: String
    let name: String
    let set_id: String
    let set_name: String
    let number: String
    let image_url: String
    let large_image_url: String
    let rarity: String?
    let status: String
    let market_price: Double?
    let low_price: Double?
    let high_price: Double?
    let price_variant: String?
    let added_at: String?
    let psa_grade: Int?
    let psa_target_grade: Int?
}

struct SmiskiItemRow: Codable {
    let id: String
    let user_id: String
    let figure_id: String
    let series_id: String
    let series_name: String
    let figure_name: String
    let is_secret: Bool
    let status: String
    let added_at: String?
}

struct LegoSetRow: Codable {
    let id: String
    let user_id: String
    let set_num: String
    let name: String
    let year: Int?
    let theme_id: Int?
    let theme_name: String
    let num_parts: Int?
    let image_url: String?
    let status: String
    let added_at: String?
}

struct GameItemRow: Codable {
    let id: String
    let user_id: String
    let igdb_id: Int
    let name: String
    let cover_url: String?
    let genre_names: [String]
    let platform_names: [String]
    let rating: Double?
    let release_year: Int?
    let summary: String?
    let is_owned: Bool
    let primary_platform: String?
    let added_at: String?
}
