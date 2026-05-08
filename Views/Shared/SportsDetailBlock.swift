//
//  SportsDetailBlock.swift
//  Orca
//
//  Created by David Piliponskiy on 3/28/26.
//

import SwiftUI

struct SportsDetailBlock: View {
    let memory: Memory

    @State private var upcomingGames: [ESPNGame] = []
    @State private var recentGames: [ESPNGame] = []
    @State private var standings: [ESPNStandingEntry] = []
    @State private var isLoading = false
    @State private var teamRecord: String = ""

    private var team: ESPNTeam? { ESPNService.shared.detectTeam(in: memory.text) }
    private var teamName: String { team?.name ?? "" }
    private var league: String { team?.league.uppercased() ?? "" }

    var body: some View {
        Group {
            if team == nil {
                EmptyView()
            } else if isLoading {
                loadingCard
            } else if upcomingGames.isEmpty && recentGames.isEmpty && standings.isEmpty && teamRecord.isEmpty {
                EmptyView()
            } else {
                VStack(spacing: 10) {
                    teamHeaderCard
                    if !recentGames.isEmpty { recentResultsCard }
                    if upcomingGames.count > 1 { upcomingCard }
                    if !standings.isEmpty { standingsCard }
                }
            }
        }
        .onAppear { loadData() }
    }

    // MARK: - Loading

    private var loadingCard: some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.7).tint(.oceanTeal)
            Text("Loading...").font(.custom("DMSans-Regular", size: 14)).foregroundColor(.gray)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - Team Header

    private var teamHeaderCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Circle().fill(leagueColor(league)).frame(width: 28, height: 28)
                    .overlay(Text(String(teamName.prefix(1)).uppercased())
                        .font(.custom("DMSans-Medium", size: 12)).foregroundColor(.white))
                Text(teamName.capitalized)
                    .font(.custom("DMSans-Medium", size: 17)).foregroundColor(.deepNavy)
                Spacer()
                Text(league).font(.custom("DMMono-Regular", size: 11)).foregroundColor(.gray)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.mist).clipShape(Capsule())
            }
            .padding(16)

            if !teamRecord.isEmpty {
                Text(teamRecord).font(.custom("DMSans-Regular", size: 13)).foregroundColor(.gray)
                    .padding(.horizontal, 16).padding(.bottom, 10)
            }

            if let next = upcomingGames.first {
                Divider().padding(.horizontal, 16)
                nextGameRow(game: next)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    @ViewBuilder
    private func nextGameRow(game: ESPNGame) -> some View {
        let userIsHome = game.homeTeam.lowercased().contains(teamName.lowercased())
        let opponent = userIsHome ? game.awayTeam : game.homeTeam
        let atOrVs = userIsHome ? "vs." : "@"
        let daysUntil = Calendar.current.dateComponents([.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: game.date)).day ?? 0

        VStack(alignment: .leading, spacing: 4) {
            Text("NEXT GAME").font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).tracking(0.5)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(atOrVs) \(opponent)").font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy)
                    HStack(spacing: 6) {
                        Text(game.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                            .font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                        if let b = game.broadcast { Text("· \(b)").font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray) }
                    }
                }
                Spacer()
                Text(daysUntil == 0 ? "Today" : "\(daysUntil)d")
                    .font(.custom("DMSans-Medium", size: 12))
                    .foregroundColor(daysUntil == 0 ? .white : .oceanTeal)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(daysUntil == 0 ? Color.coral : Color.oceanTeal.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
    }

    // MARK: - Recent Results

    private var recentResultsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("RECENT RESULTS").font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).tracking(0.5)
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)
            ForEach(Array(recentGames.enumerated()), id: \.element.id) { index, game in
                if index > 0 { Divider().padding(.horizontal, 16) }
                recentRow(game: game)
            }
            Spacer().frame(height: 6)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    @ViewBuilder
    private func recentRow(game: ESPNGame) -> some View {
        let userIsHome = game.homeTeam.lowercased().contains(teamName.lowercased())
        let opponent = userIsHome ? game.awayTeam : game.homeTeam
        let atOrVs = userIsHome ? "vs." : "@"
        let userScore = userIsHome ? (game.homeScore ?? "-") : (game.awayScore ?? "-")
        let oppScore = userIsHome ? (game.awayScore ?? "-") : (game.homeScore ?? "-")
        let result = gameResult(game: game, userIsHome: userIsHome)

        HStack(spacing: 12) {
            Text(result)
                .font(.custom("DMSans-Medium", size: 12)).foregroundColor(resultColor(result))
                .frame(width: 22, height: 22)
                .background(resultColor(result).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 1) {
                Text("\(atOrVs) \(opponent)").font(.custom("DMSans-Regular", size: 14)).foregroundColor(.deepNavy)
                Text(game.date.formatted(.dateTime.month(.abbreviated).day())).font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
            }
            Spacer()
            Text("\(userScore)–\(oppScore)").font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    // MARK: - Upcoming

    private var upcomingCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("UPCOMING").font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).tracking(0.5)
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)
            ForEach(Array(upcomingGames.dropFirst().enumerated()), id: \.element.id) { index, game in
                if index > 0 { Divider().padding(.horizontal, 16) }
                let userIsHome = game.homeTeam.lowercased().contains(teamName.lowercased())
                let opponent = userIsHome ? game.awayTeam : game.homeTeam
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(userIsHome ? "vs." : "@") \(opponent)").font(.custom("DMSans-Regular", size: 14)).foregroundColor(.deepNavy)
                        Text(game.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                            .font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                    }
                    Spacer()
                    if let b = game.broadcast { Text(b).font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray) }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
            Spacer().frame(height: 6)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - Standings

    private var standingsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("STANDINGS · \(standings.count) TEAMS")
                .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).tracking(0.5)
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            standingsHeader
            Divider()

            ForEach(standings.prefix(15), id: \.teamName) { entry in
                standingsRow(entry: entry)
                if entry.teamName != standings.prefix(15).last?.teamName { Divider() }
            }
            Spacer().frame(height: 6)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    @ViewBuilder
    private var standingsHeader: some View {
        let isSoccer = standings.first?.isSoccer == true
        let isHockey = standings.first?.isHockey == true
        HStack {
            Text("Team").frame(maxWidth: .infinity, alignment: .leading)
            Text("W").frame(width: 28, alignment: .trailing)
            if isSoccer { Text("D").frame(width: 28, alignment: .trailing) }
            Text("L").frame(width: 28, alignment: .trailing)
            if isHockey { Text("OTL").frame(width: 36, alignment: .trailing) }
            Text(isSoccer ? "PTS" : isHockey ? "PTS" : "PCT").frame(width: isSoccer || isHockey ? 36 : 42, alignment: .trailing)
            if !isSoccer && !isHockey { Text("GB").frame(width: 32, alignment: .trailing) }
        }
        .font(.custom("DMMono-Regular", size: 11)).foregroundColor(.gray)
        .padding(.horizontal, 16).padding(.bottom, 6)
    }

    @ViewBuilder
    private func standingsRow(entry: ESPNStandingEntry) -> some View {
        HStack {
            Text(entry.teamName)
                .font(.custom(entry.isUserTeam ? "DMSans-Medium" : "DMSans-Regular", size: 13))
                .foregroundColor(entry.isUserTeam ? .deepNavy : .gray)
                .frame(maxWidth: .infinity, alignment: .leading).lineLimit(1)
            Text("\(entry.wins)").font(.custom("DMMono-Regular", size: 13)).foregroundColor(entry.isUserTeam ? .deepNavy : .gray).frame(width: 28, alignment: .trailing)
            if entry.isSoccer { Text("\(entry.draws)").font(.custom("DMMono-Regular", size: 13)).foregroundColor(.gray).frame(width: 28, alignment: .trailing) }
            Text("\(entry.losses)").font(.custom("DMMono-Regular", size: 13)).foregroundColor(entry.isUserTeam ? .deepNavy : .gray).frame(width: 28, alignment: .trailing)
            if entry.isHockey { Text("\(entry.otLosses)").font(.custom("DMMono-Regular", size: 13)).foregroundColor(.gray).frame(width: 36, alignment: .trailing) }
            if entry.isSoccer || entry.isHockey {
                Text("\(entry.points)").font(.custom("DMSans-Medium", size: 13)).foregroundColor(entry.isUserTeam ? .deepNavy : .gray).frame(width: 36, alignment: .trailing)
            } else {
                Text(entry.winPct).font(.custom("DMMono-Regular", size: 13)).foregroundColor(.gray).frame(width: 42, alignment: .trailing)
                Text(entry.gamesBehind).font(.custom("DMMono-Regular", size: 13)).foregroundColor(.gray).frame(width: 32, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 9)
        .background(entry.isUserTeam ? leagueColor(league).opacity(0.05) : Color.clear)
    }

    // MARK: - Helpers

    private func gameResult(game: ESPNGame, userIsHome: Bool) -> String {
        guard let hs = game.homeScore, let as_ = game.awayScore,
              let h = Int(hs), let a = Int(as_) else {
            if let hw = game.homeWon { return (userIsHome ? hw : !hw) ? "W" : "L" }
            return "?"
        }
        if h == a { return "D" }
        return ((userIsHome && h > a) || (!userIsHome && a > h)) ? "W" : "L"
    }

    private func resultColor(_ result: String) -> Color {
        switch result {
        case "W": return Color(red: 0.18, green: 0.49, blue: 0.2)
        case "D": return .gray
        default: return .coral
        }
    }

    private func leagueColor(_ league: String) -> Color {
        switch league {
        case "NFL": return Color(red: 0.01, green: 0.22, blue: 0.43)
        case "NBA": return Color(red: 0.2, green: 0.47, blue: 0.75)
        case "MLB": return Color(red: 0.7, green: 0.1, blue: 0.15)
        case "NHL": return Color(red: 0.0, green: 0.28, blue: 0.6)
        case "ENG.1": return Color(red: 0.38, green: 0.0, blue: 0.47)
        case "ESP.1": return Color(red: 0.85, green: 0.15, blue: 0.15)
        case "GER.1": return Color(red: 0.8, green: 0.0, blue: 0.0)
        case "ITA.1": return Color(red: 0.0, green: 0.35, blue: 0.7)
        case "FRA.1": return Color(red: 0.0, green: 0.2, blue: 0.6)
        default: return Color.oceanTeal
        }
    }

    private func loadData() {
        guard let team = team else {
            print("⚾️ No team detected in: \(memory.text)")
            return
        }
        print("⚾️ Team detected: \(team.name) | id: \(team.id) | league: \(team.league)")
        isLoading = true
        Task {
            async let gamesTask = ESPNService.shared.fetchUpcomingGames(for: team)
            async let standingsTask = ESPNService.shared.fetchStandings(for: team)
            async let recordTask = ESPNService.shared.fetchTeamRecord(for: team)
            let (allGames, fetchedStandings, record) = await (gamesTask, standingsTask, recordTask)
            await MainActor.run {
                print("⚾️ Games total: \(allGames.count) | Standings: \(fetchedStandings.count) | Record: '\(record)'")
                print("⚾️ Upcoming: \(allGames.filter { $0.status == .scheduled || $0.status == .inProgress }.count) | Recent: \(allGames.filter { $0.status == .final_ }.count)")
                upcomingGames = Array(allGames.filter { $0.status == .scheduled || $0.status == .inProgress }
                    .sorted { $0.date < $1.date }.prefix(5))
                recentGames = Array(allGames.filter { $0.status == .final_ }
                    .sorted { $0.date > $1.date }.prefix(3))
                standings = fetchedStandings
                teamRecord = record
                isLoading = false
            }
        }
    }
}
