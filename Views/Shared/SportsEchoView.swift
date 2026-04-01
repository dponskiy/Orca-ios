//
//  SportsEchoView.swift
//  Orca
//
//  Created by David Piliponskiy on 3/24/26.
//

import SwiftUI

struct SportsEchoView: View {
    let memories: [Memory]
    @State private var recentGames: [String: [ESPNGame]] = [:]  // teamId -> games
    @State private var upcomingGames: [String: ESPNGame] = [:]   // teamId -> next game
    @State private var teams: [ESPNTeam] = []
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7).tint(.oceanTeal)
                    Text("Loading scores...")
                        .font(.custom("DMSans-Regular", size: 13))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            } else if !teams.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    // Subtitle
                    Text("\(teams.count) \(teams.count == 1 ? "team" : "teams") · updated just now")
                        .font(.custom("DMSans-Regular", size: 13))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)

                    // Live & Recent card
                    let allRecent = teams.flatMap { team in
                        (recentGames[team.id] ?? []).map { (team: team, game: $0) }
                    }.sorted { $0.game.date > $1.game.date }

                    if !allRecent.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("LIVE & RECENT")
                                .font(.custom("DMSans-Medium", size: 11))
                                .foregroundColor(.gray)
                                .tracking(0.5)
                                .padding(.horizontal, 16)
                                .padding(.top, 14)
                                .padding(.bottom, 10)

                            ForEach(Array(allRecent.prefix(5).enumerated()), id: \.element.game.id) { index, item in
                                if index > 0 { Divider().padding(.horizontal, 16) }
                                recentRow(team: item.team, game: item.game)
                            }
                            Spacer().frame(height: 8)
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
                        .padding(.horizontal, 20)
                    }

                    // Up Next card
                    let allUpcoming = teams.compactMap { team -> (team: ESPNTeam, game: ESPNGame)? in
                        guard let game = upcomingGames[team.id] else { return nil }
                        return (team: team, game: game)
                    }.sorted { $0.game.date < $1.game.date }

                    if !allUpcoming.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("UP NEXT")
                                .font(.custom("DMSans-Medium", size: 11))
                                .foregroundColor(.gray)
                                .tracking(0.5)
                                .padding(.horizontal, 16)
                                .padding(.top, 14)
                                .padding(.bottom, 10)

                            ForEach(Array(allUpcoming.enumerated()), id: \.element.game.id) { index, item in
                                if index > 0 { Divider().padding(.horizontal, 16) }
                                upcomingRow(team: item.team, game: item.game)
                            }
                            Spacer().frame(height: 8)
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
                        .padding(.horizontal, 20)
                    }

                    Text("Tap a memory to see full schedule & standings")
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                }
                .padding(.bottom, 8)
            }
        }
        .onAppear { loadData() }
    }

    // MARK: - Recent Row

    private func recentRow(team: ESPNTeam, game: ESPNGame) -> some View {
        let teamName = team.name.lowercased()
        let userIsHome = game.homeTeam.lowercased().contains(teamName)
        let opponent = userIsHome ? game.awayTeam : game.homeTeam
        let atOrVs = userIsHome ? "vs." : "@"
        let userScore = userIsHome ? (game.homeScore ?? "-") : (game.awayScore ?? "-")
        let oppScore = userIsHome ? (game.awayScore ?? "-") : (game.homeScore ?? "-")
        let isLive = game.status == .inProgress

        let result: String = {
            let us = Int(userScore) ?? 0
            let os = Int(oppScore) ?? 0
            if us == os { return "D" }
            if let hw = game.homeWon {
                return (userIsHome ? hw : !hw) ? "W" : "L"
            }
            return us > os ? "W" : "L"
        }()

        return HStack(spacing: 12) {
            teamDot(team: team)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("\(atOrVs) \(opponent)")
                        .font(.custom("DMSans-Regular", size: 14))
                        .foregroundColor(.deepNavy)
                    if isLive {
                        Text("LIVE")
                            .font(.custom("DMSans-Medium", size: 10))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.coral)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                Text(game.date.formatted(.dateTime.month(.abbreviated).day()) + " · " + (isLive ? "Live" : "Final"))
                    .font(.custom("DMMono-Regular", size: 12))
                    .foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(userScore)–\(oppScore)")
                    .font(.custom("DMSans-Medium", size: 15))
                    .foregroundColor(.deepNavy)
                Text(isLive ? (result == "W" ? "Winning" : result == "D" ? "Drawing" : "Losing") : result)
                    .font(.custom("DMSans-Medium", size: 11))
                    .foregroundColor(result == "W" ? Color(red: 0.18, green: 0.49, blue: 0.2) : result == "D" ? .gray : .coral)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Upcoming Row

    private func upcomingRow(team: ESPNTeam, game: ESPNGame) -> some View {
        let teamName = team.name.lowercased()
        let userIsHome = game.homeTeam.lowercased().contains(teamName)
        let opponent = userIsHome ? game.awayTeam : game.homeTeam
        let atOrVs = userIsHome ? "vs." : "@"
        let daysUntil = Calendar.current.dateComponents([.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: game.date)).day ?? 0

        return HStack(spacing: 12) {
            teamDot(team: team)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(atOrVs) \(opponent)")
                    .font(.custom("DMSans-Regular", size: 14))
                    .foregroundColor(.deepNavy)
                HStack(spacing: 4) {
                    Text(game.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                        .font(.custom("DMMono-Regular", size: 12))
                        .foregroundColor(.gray)
                    if let broadcast = game.broadcast {
                        Text("· \(broadcast)")
                            .font(.custom("DMMono-Regular", size: 12))
                            .foregroundColor(.gray)
                    }
                }
            }

            Spacer()

            Text(daysUntil == 0 ? "Today" : "\(daysUntil)d")
                .font(.custom("DMSans-Medium", size: 11))
                .foregroundColor(daysUntil == 0 ? .white : .oceanTeal)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(daysUntil == 0 ? Color.coral : Color.oceanTeal.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Team Dot

    private func teamDot(team: ESPNTeam) -> some View {
        Circle()
            .fill(leagueColor(team.league.uppercased()))
            .frame(width: 24, height: 24)
            .overlay(
                Text(String(team.name.prefix(1)).uppercased())
                    .font(.custom("DMSans-Medium", size: 10))
                    .foregroundColor(.white)
            )
    }

    // MARK: - Load

    private func loadData() {
        let detectedTeams = detectTeamsFromMemories()
        guard !detectedTeams.isEmpty else { return }
        teams = detectedTeams
        isLoading = true

        Task {
            await withTaskGroup(of: Void.self) { group in
                for team in detectedTeams {
                    group.addTask {
                        let games = await ESPNService.shared.fetchUpcomingGames(for: team)
                        let recent = Array(games.filter { $0.status == .final_ || $0.status == .inProgress }
                            .sorted { $0.date > $1.date }.prefix(3))
                        let next = games.filter { $0.status == .scheduled || $0.status == .inProgress }
                            .sorted { $0.date < $1.date }.first
                        await MainActor.run {
                            self.recentGames[team.id] = recent
                            if let next = next { self.upcomingGames[team.id] = next }
                        }
                    }
                }
            }
            await MainActor.run { self.isLoading = false }
        }
    }

    private func detectTeamsFromMemories() -> [ESPNTeam] {
        var seen = Set<String>()
        var teams: [ESPNTeam] = []
        for memory in memories {
            if let team = ESPNService.shared.detectTeam(in: memory.text) {
                let key = "\(team.sport)-\(team.id)"
                if !seen.contains(key) {
                    seen.insert(key)
                    teams.append(team)
                }
            }
        }
        return teams
    }

    private func leagueColor(_ league: String) -> Color {
        switch league {
        case "NFL": return Color(red: 0.01, green: 0.22, blue: 0.43)
        case "NBA": return Color(red: 0.2, green: 0.47, blue: 0.75)
        case "MLB": return Color(red: 0.7, green: 0.1, blue: 0.15)
        case "NHL": return Color(red: 0.0, green: 0.28, blue: 0.6)
        case "ENG.1": return Color(red: 0.38, green: 0.0, blue: 0.47)
        case "ENG.2": return Color(red: 0.2, green: 0.4, blue: 0.2)
        case "ESP.1": return Color(red: 0.85, green: 0.15, blue: 0.15)
        case "GER.1": return Color(red: 0.8, green: 0.0, blue: 0.0)
        case "ITA.1": return Color(red: 0.0, green: 0.35, blue: 0.7)
        case "FRA.1": return Color(red: 0.0, green: 0.2, blue: 0.6)
        default: return Color.oceanTeal
        }
    }
}
