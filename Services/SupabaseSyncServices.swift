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
            try await syncEchos(userId: userId, context: context)
            try await syncMemories(userId: userId, context: context)
            try await syncPings(userId: userId, context: context)
            lastSyncDate = Date()
        } catch {
            syncError = error.localizedDescription
            print("❌ Sync failed: \(error)")
        }
        
        isSyncing = false
    }
    
    // MARK: - Sync Echos
    
    private func syncEchos(userId: UUID, context: ModelContext) async throws {
        let localEchos = try context.fetch(FetchDescriptor<Echo>())
        
        let echoRows = localEchos.map { echo in
            EchoRow(
                id: echo.id.uuidString,
                user_id: userId.uuidString,
                name: echo.name,
                emoji: echo.emoji,
                is_default: echo.isDefault,
                sort_order: echo.sortOrder,
                created_at: ISO8601DateFormatter().string(from: echo.createdAt)
            )
        }
        
        if !echoRows.isEmpty {
            try await supabase
                .from("echos")
                .upsert(echoRows, onConflict: "id")
                .execute()
        }
        
        let localIds = Set(localEchos.map { $0.id.uuidString })
        
        let remoteEchos: [EchoRow] = try await supabase
            .from("echos")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        for remote in remoteEchos {
            guard !localIds.contains(remote.id) else { continue }
            guard let remoteId = UUID(uuidString: remote.id) else { continue }
            
            let echo = Echo(
                name: remote.name,
                emoji: remote.emoji,
                isDefault: remote.is_default,
                sortOrder: remote.sort_order
            )
            echo.id = remoteId
            context.insert(echo)
        }
        
        print("✅ Echos synced")
    }
    
    // MARK: - Sync Memories
    
    private func syncMemories(userId: UUID, context: ModelContext) async throws {
        let localMemories = try context.fetch(FetchDescriptor<Memory>())
        
        let memoryRows = localMemories.map { memory in
            MemoryRow(
                id: memory.id.uuidString,
                user_id: userId.uuidString,
                text: memory.text,
                echo_id: memory.echoId.uuidString,
                tags: memory.tags,
                detected_date: memory.detectedDate.map { ISO8601DateFormatter().string(from: $0) },
                capture_type: memory.captureType.rawValue,
                sonar_confidence: memory.sonarConfidence,
                echo_confidence: memory.echoConfidence,
                date_confidence: memory.dateConfidence,
                is_actionable: memory.isActionable,
                is_completed: memory.isCompleted,
                completed_at: memory.completedAt.map { ISO8601DateFormatter().string(from: $0) },
                was_edited: memory.wasEdited,
                created_at: ISO8601DateFormatter().string(from: memory.createdAt),
                updated_at: ISO8601DateFormatter().string(from: memory.updatedAt)
            )
        }
        
        if !memoryRows.isEmpty {
            try await supabase
                .from("memories")
                .upsert(memoryRows, onConflict: "id")
                .execute()
        }
        
        let localIds = Set(localMemories.map { $0.id.uuidString })
        
        let remoteMemories: [MemoryRow] = try await supabase
            .from("memories")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        for remote in remoteMemories {
            guard !localIds.contains(remote.id) else { continue }
            guard let remoteId = UUID(uuidString: remote.id),
                  let echoId = UUID(uuidString: remote.echo_id) else { continue }
            
            let memory = Memory(text: remote.text, echoId: echoId)
            memory.id = remoteId
            memory.tags = remote.tags
            memory.sonarConfidence = remote.sonar_confidence
            memory.echoConfidence = remote.echo_confidence
            memory.dateConfidence = remote.date_confidence
            memory.isActionable = remote.is_actionable
            memory.isCompleted = remote.is_completed
            memory.wasEdited = remote.was_edited
            
            if let dateStr = remote.detected_date {
                memory.detectedDate = ISO8601DateFormatter().date(from: dateStr)
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
    
    // MARK: - Sync Pings
    
    private func syncPings(userId: UUID, context: ModelContext) async throws {
        let localPings = try context.fetch(FetchDescriptor<Ping>())
        
        let pingRows = localPings.map { ping in
            PingRow(
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
        }
        
        if !pingRows.isEmpty {
            try await supabase
                .from("pings")
                .upsert(pingRows, onConflict: "id")
                .execute()
        }
        
        let localIds = Set(localPings.map { $0.id.uuidString })
        
        let remotePings: [PingRow] = try await supabase
            .from("pings")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        for remote in remotePings {
            guard !localIds.contains(remote.id) else { continue }
            guard let remoteId = UUID(uuidString: remote.id),
                  let memoryId = UUID(uuidString: remote.memory_id),
                  let fireDate = ISO8601DateFormatter().date(from: remote.fire_date) else { continue }
            
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
    
    // MARK: - Push Single Memory
    
    func pushMemory(_ memory: Memory, userId: UUID) async {
        let row = MemoryRow(
            id: memory.id.uuidString,
            user_id: userId.uuidString,
            text: memory.text,
            echo_id: memory.echoId.uuidString,
            tags: memory.tags,
            detected_date: memory.detectedDate.map { ISO8601DateFormatter().string(from: $0) },
            capture_type: memory.captureType.rawValue,
            sonar_confidence: memory.sonarConfidence,
            echo_confidence: memory.echoConfidence,
            date_confidence: memory.dateConfidence,
            is_actionable: memory.isActionable,
            is_completed: memory.isCompleted,
            completed_at: memory.completedAt.map { ISO8601DateFormatter().string(from: $0) },
            was_edited: memory.wasEdited,
            created_at: ISO8601DateFormatter().string(from: memory.createdAt),
            updated_at: ISO8601DateFormatter().string(from: memory.updatedAt)
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
    
    // MARK: - Auto Sync
    
    func startAutoSync(userId: UUID) {
        syncTask?.cancel()
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
}

struct MemoryRow: Codable {
    let id: String
    let user_id: String
    let text: String
    let echo_id: String
    let tags: [String]
    let detected_date: String?
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
