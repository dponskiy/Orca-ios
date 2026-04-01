//
//  SportsMemoryService.swift
//  Orca
//
//  Created by David Piliponskiy on 3/24/26.
//

import Foundation
import SwiftData

class SportsMemoryService {
    static let shared = SportsMemoryService()
    private init() {}

    // MARK: - Initial Ping Creation (called when memory is first saved)

    func createGamePings(for text: String, memory: Memory, modelContext: ModelContext, userId: String) async {
        guard let team = ESPNService.shared.detectTeam(in: text) else { return }

        let games = await ESPNService.shared.fetchUpcomingGames(for: team)
        let upcoming = games.filter { $0.status == .scheduled || $0.status == .inProgress }.prefix(5)

        await MainActor.run {
            for game in upcoming {
                let pingDate = game.date
                let gameText = "\(game.awayTeam) @ \(game.homeTeam) · \(game.league)"
                let ping = Ping(memoryId: memory.id, fireDate: pingDate, recurrence: .none)
                ping.fireTime = pingDate
                modelContext.insert(ping)
                NotificationService.shared.schedulePing(ping: ping, memoryText: gameText)
            }

            if let nextGame = upcoming.first {
                let nextGameStr = "\(nextGame.awayTeam) @ \(nextGame.homeTeam)"
                let dateStr = nextGame.date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
                memory.text = "\(text)\nNext: \(nextGameStr) — \(dateStr)"
                memory.updatedAt = Date()
            }
        }
    }

    // MARK: - Refresh Pings on Foreground (called same as checkPriceAlerts)

    func refreshGamePings(memories: [Memory], modelContext: ModelContext) async {
        // Only process sports memories
        let sportsMemories = memories.filter {
            ESPNService.shared.detectTeam(in: $0.text) != nil
        }

        for memory in sportsMemories {
            guard let team = ESPNService.shared.detectTeam(in: memory.text) else { continue }

            let games = await ESPNService.shared.fetchUpcomingGames(for: team)
            let upcoming = games
                .filter { $0.status == .scheduled || $0.status == .inProgress }
                .sorted { $0.date < $1.date }
                .prefix(5)

            await MainActor.run {
                // Fetch existing pings for this memory
                let descriptor = FetchDescriptor<Ping>()
                let allPings = (try? modelContext.fetch(descriptor)) ?? []
                let memoryPings = allPings.filter { $0.memoryId == memory.id }

                // Remove pings for games that are now in the past or final
                let upcomingDates = Set(upcoming.map { $0.date.timeIntervalSince1970 })
                for ping in memoryPings {
                    let isPast = ping.fireDate < Date()
                    let isStale = !upcomingDates.contains(where: {
                        abs($0 - ping.fireDate.timeIntervalSince1970) < 3600 // within 1 hour
                    })
                    if isPast || isStale {
                        NotificationService.shared.cancelPing(pingId: ping.id)
                        modelContext.delete(ping)
                    }
                }

                // Find existing future ping dates to avoid duplicates
                let remainingPings = memoryPings.filter { $0.fireDate > Date() }
                let existingDates = Set(remainingPings.map {
                    Calendar.current.startOfDay(for: $0.fireDate)
                })

                // Add pings for upcoming games not already covered
                for game in upcoming {
                    let gameDay = Calendar.current.startOfDay(for: game.date)
                    guard !existingDates.contains(gameDay) else { continue }
                    guard game.date > Date() else { continue }

                    let gameText = "\(game.awayTeam) @ \(game.homeTeam) · \(game.league)"
                    let ping = Ping(memoryId: memory.id, fireDate: game.date, recurrence: .none)
                    ping.fireTime = game.date
                    modelContext.insert(ping)
                    NotificationService.shared.schedulePing(ping: ping, memoryText: gameText)
                }

                // Update memory text with next game
                if let nextGame = upcoming.first {
                    let nextGameStr = "\(nextGame.awayTeam) @ \(nextGame.homeTeam)"
                    let dateStr = nextGame.date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
                    // Replace previous Next: line if it exists
                    var lines = memory.text.components(separatedBy: "\n")
                        .filter { !$0.hasPrefix("Next:") }
                    lines.append("Next: \(nextGameStr) — \(dateStr)")
                    memory.text = lines.joined(separator: "\n")
                    memory.updatedAt = Date()
                }
            }
        }
    }
}
