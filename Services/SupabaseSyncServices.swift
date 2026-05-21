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
            if seenWatchlistIds.contains(item.id) {
                context.delete(item)
            } else {
                seenWatchlistIds.insert(item.id)
            }
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
        let newLocalEchos = mergedEchos.filter { !remoteIds.contains($0.id.uuidString) }

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

        for remote in remoteMemories {
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

        let rows = localSubTasks.reduce(into: [SubTaskRow]()) { result, st in
            guard !result.contains(where: { $0.id == st.id.uuidString }) else { return }
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

        let remotePings: [PingRow] = try await supabase
            .from("pings")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        for remote in remotePings {
            guard !localIds.contains(remote.id.lowercased()) else { continue }
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
                updated_at: ISO8601DateFormatter().string(from: item.updatedAt)
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

    func deleteMemory(id: UUID) async {
        do {
            try await supabase
                .from("memories")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()
            print("✅ Memory deleted from Supabase: \(id)")
        } catch {
            print("❌ Failed to delete memory: \(error)")
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
