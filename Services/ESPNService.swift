//
//  ESPNService.swift
//  Orca
//
//  Created by David Piliponskiy on 3/24/26.
//

import Foundation

struct ESPNGame: Identifiable {
    let id: String
    let homeTeam: String
    let awayTeam: String
    let homeScore: String?
    let awayScore: String?
    let homeWon: Bool?
    let date: Date
    let status: GameStatus
    let venue: String?
    let broadcast: String?
    let league: String

    enum GameStatus: Sendable {
            case scheduled, inProgress, final_, postponed
            var label: String {
                switch self {
                case .scheduled: return "Scheduled"
                case .inProgress: return "Live"
                case .final_: return "Final"
                case .postponed: return "Postponed"
            }
        }
    }
}

struct ESPNTeam {
    let id: String
    let name: String
    let abbreviation: String
    let sport: String
    let league: String
}

struct ESPNStandingEntry {
    let teamName: String
    let wins: Int
    let losses: Int
    let draws: Int
    let otLosses: Int
    let points: Int
    let winPct: String
    let gamesBehind: String
    let isSoccer: Bool
    let isHockey: Bool
    let isUserTeam: Bool
}

class ESPNService {
    static let shared = ESPNService()

    private let teamLookup: [String: (id: String, sport: String, league: String)] = [
        // NFL
        "cowboys": ("6", "football", "nfl"),
        "dallas cowboys": ("6", "football", "nfl"),
        "eagles": ("21", "football", "nfl"),
        "philadelphia eagles": ("21", "football", "nfl"),
        "patriots": ("17", "football", "nfl"),
        "new england patriots": ("17", "football", "nfl"),
        "chiefs": ("12", "football", "nfl"),
        "kansas city chiefs": ("12", "football", "nfl"),
        "49ers": ("25", "football", "nfl"),
        "san francisco 49ers": ("25", "football", "nfl"),
        "ravens": ("33", "football", "nfl"),
        "baltimore ravens": ("33", "football", "nfl"),
        "bills": ("2", "football", "nfl"),
        "buffalo bills": ("2", "football", "nfl"),
        "bengals": ("4", "football", "nfl"),
        "cincinnati bengals": ("4", "football", "nfl"),
        "browns": ("5", "football", "nfl"),
        "cleveland browns": ("5", "football", "nfl"),
        "steelers": ("23", "football", "nfl"),
        "pittsburgh steelers": ("23", "football", "nfl"),
        "texans": ("34", "football", "nfl"),
        "houston texans": ("34", "football", "nfl"),
        "colts": ("11", "football", "nfl"),
        "indianapolis colts": ("11", "football", "nfl"),
        "jaguars": ("30", "football", "nfl"),
        "jacksonville jaguars": ("30", "football", "nfl"),
        "titans": ("10", "football", "nfl"),
        "tennessee titans": ("10", "football", "nfl"),
        "broncos": ("7", "football", "nfl"),
        "denver broncos": ("7", "football", "nfl"),
        "raiders": ("13", "football", "nfl"),
        "las vegas raiders": ("13", "football", "nfl"),
        "chargers": ("24", "football", "nfl"),
        "los angeles chargers": ("24", "football", "nfl"),
        "rams": ("14", "football", "nfl"),
        "los angeles rams": ("14", "football", "nfl"),
        "seahawks": ("26", "football", "nfl"),
        "seattle seahawks": ("26", "football", "nfl"),
        "cardinals": ("22", "football", "nfl"),
        "arizona cardinals": ("22", "football", "nfl"),
        "giants": ("19", "football", "nfl"),
        "new york giants": ("19", "football", "nfl"),
        "jets": ("20", "football", "nfl"),
        "new york jets": ("20", "football", "nfl"),
        "commanders": ("28", "football", "nfl"),
        "washington commanders": ("28", "football", "nfl"),
        "bears": ("3", "football", "nfl"),
        "chicago bears": ("3", "football", "nfl"),
        "lions": ("8", "football", "nfl"),
        "detroit lions": ("8", "football", "nfl"),
        "packers": ("9", "football", "nfl"),
        "green bay packers": ("9", "football", "nfl"),
        "vikings": ("16", "football", "nfl"),
        "minnesota vikings": ("16", "football", "nfl"),
        "falcons": ("1", "football", "nfl"),
        "atlanta falcons": ("1", "football", "nfl"),
        "panthers": ("29", "football", "nfl"),
        "carolina panthers": ("29", "football", "nfl"),
        "saints": ("18", "football", "nfl"),
        "new orleans saints": ("18", "football", "nfl"),
        "buccaneers": ("27", "football", "nfl"),
        "tampa bay buccaneers": ("27", "football", "nfl"),
        "dolphins": ("15", "football", "nfl"),
        "miami dolphins": ("15", "football", "nfl"),

        // NBA
        "lakers": ("13", "basketball", "nba"),
        "los angeles lakers": ("13", "basketball", "nba"),
        "celtics": ("2", "basketball", "nba"),
        "boston celtics": ("2", "basketball", "nba"),
        "warriors": ("9", "basketball", "nba"),
        "golden state warriors": ("9", "basketball", "nba"),
        "bulls": ("4", "basketball", "nba"),
        "chicago bulls": ("4", "basketball", "nba"),
        "heat": ("14", "basketball", "nba"),
        "miami heat": ("14", "basketball", "nba"),
        "knicks": ("18", "basketball", "nba"),
        "new york knicks": ("18", "basketball", "nba"),
        "nets": ("17", "basketball", "nba"),
        "brooklyn nets": ("17", "basketball", "nba"),
        "bucks": ("15", "basketball", "nba"),
        "milwaukee bucks": ("15", "basketball", "nba"),
        "suns": ("21", "basketball", "nba"),
        "phoenix suns": ("21", "basketball", "nba"),
        "nuggets": ("7", "basketball", "nba"),
        "denver nuggets": ("7", "basketball", "nba"),
        "clippers": ("12", "basketball", "nba"),
        "la clippers": ("12", "basketball", "nba"),
        "76ers": ("20", "basketball", "nba"),
        "philadelphia 76ers": ("20", "basketball", "nba"),
        "sixers": ("20", "basketball", "nba"),
        "mavericks": ("6", "basketball", "nba"),
        "dallas mavericks": ("6", "basketball", "nba"),
        "mavs": ("6", "basketball", "nba"),
        "grizzlies": ("29", "basketball", "nba"),
        "memphis grizzlies": ("29", "basketball", "nba"),
        "timberwolves": ("16", "basketball", "nba"),
        "minnesota timberwolves": ("16", "basketball", "nba"),
        "thunder": ("25", "basketball", "nba"),
        "oklahoma city thunder": ("25", "basketball", "nba"),
        "pelicans": ("3", "basketball", "nba"),
        "new orleans pelicans": ("3", "basketball", "nba"),
        "kings": ("23", "basketball", "nba"),
        "sacramento kings": ("23", "basketball", "nba"),
        "jazz": ("26", "basketball", "nba"),
        "utah jazz": ("26", "basketball", "nba"),
        "raptors": ("28", "basketball", "nba"),
        "toronto raptors": ("28", "basketball", "nba"),
        "hawks": ("1", "basketball", "nba"),
        "atlanta hawks": ("1", "basketball", "nba"),
        "hornets": ("30", "basketball", "nba"),
        "charlotte hornets": ("30", "basketball", "nba"),
        "magic": ("19", "basketball", "nba"),
        "orlando magic": ("19", "basketball", "nba"),
        "wizards": ("27", "basketball", "nba"),
        "washington wizards": ("27", "basketball", "nba"),
        "cavaliers": ("5", "basketball", "nba"),
        "cleveland cavaliers": ("5", "basketball", "nba"),
        "cavs": ("5", "basketball", "nba"),
        "pacers": ("11", "basketball", "nba"),
        "indiana pacers": ("11", "basketball", "nba"),
        "pistons": ("8", "basketball", "nba"),
        "detroit pistons": ("8", "basketball", "nba"),
        "rockets": ("10", "basketball", "nba"),
        "houston rockets": ("10", "basketball", "nba"),
        "san antonio spurs": ("24", "basketball", "nba"),
        "trail blazers": ("22", "basketball", "nba"),
        "portland trail blazers": ("22", "basketball", "nba"),
        "blazers": ("22", "basketball", "nba"),

        // MLB
        "yankees": ("10", "baseball", "mlb"),
        "new york yankees": ("10", "baseball", "mlb"),
        "red sox": ("2", "baseball", "mlb"),
        "boston red sox": ("2", "baseball", "mlb"),
        "dodgers": ("19", "baseball", "mlb"),
        "los angeles dodgers": ("19", "baseball", "mlb"),
        "cubs": ("16", "baseball", "mlb"),
        "chicago cubs": ("16", "baseball", "mlb"),
        "astros": ("18", "baseball", "mlb"),
        "houston astros": ("18", "baseball", "mlb"),
        "braves": ("15", "baseball", "mlb"),
        "atlanta braves": ("15", "baseball", "mlb"),
        "mets": ("21", "baseball", "mlb"),
        "new york mets": ("21", "baseball", "mlb"),
        "st. louis cardinals": ("24", "baseball", "mlb"),
        "san francisco giants": ("26", "baseball", "mlb"),
        "phillies": ("22", "baseball", "mlb"),
        "philadelphia phillies": ("22", "baseball", "mlb"),
        "blue jays": ("14", "baseball", "mlb"),
        "toronto blue jays": ("14", "baseball", "mlb"),
        "padres": ("25", "baseball", "mlb"),
        "san diego padres": ("25", "baseball", "mlb"),
        "nationals": ("20", "baseball", "mlb"),
        "washington nationals": ("20", "baseball", "mlb"),
        "orioles": ("1", "baseball", "mlb"),
        "baltimore orioles": ("1", "baseball", "mlb"),
        "rays": ("30", "baseball", "mlb"),
        "tampa bay rays": ("30", "baseball", "mlb"),
        "mariners": ("28", "baseball", "mlb"),
        "seattle mariners": ("28", "baseball", "mlb"),
        "angels": ("3", "baseball", "mlb"),
        "los angeles angels": ("3", "baseball", "mlb"),
        "rangers": ("13", "baseball", "mlb"),
        "texas rangers": ("13", "baseball", "mlb"),
        "athletics": ("11", "baseball", "mlb"),
        "oakland athletics": ("11", "baseball", "mlb"),
        "tigers": ("6", "baseball", "mlb"),
        "detroit tigers": ("6", "baseball", "mlb"),
        "twins": ("9", "baseball", "mlb"),
        "minnesota twins": ("9", "baseball", "mlb"),
        "white sox": ("4", "baseball", "mlb"),
        "chicago white sox": ("4", "baseball", "mlb"),
        "royals": ("7", "baseball", "mlb"),
        "kansas city royals": ("7", "baseball", "mlb"),
        "guardians": ("5", "baseball", "mlb"),
        "cleveland guardians": ("5", "baseball", "mlb"),
        "brewers": ("8", "baseball", "mlb"),
        "milwaukee brewers": ("8", "baseball", "mlb"),
        "pirates": ("23", "baseball", "mlb"),
        "pittsburgh pirates": ("23", "baseball", "mlb"),
        "reds": ("17", "baseball", "mlb"),
        "cincinnati reds": ("17", "baseball", "mlb"),
        "rockies": ("27", "baseball", "mlb"),
        "colorado rockies": ("27", "baseball", "mlb"),
        "diamondbacks": ("29", "baseball", "mlb"),
        "arizona diamondbacks": ("29", "baseball", "mlb"),
        "marlins": ("28", "baseball", "mlb"),

        // NHL
        "capitals": ("23", "hockey", "nhl"),
        "washington capitals": ("23", "hockey", "nhl"),
        "florida panthers": ("26", "hockey", "nhl"),
        "nashville predators": ("27", "hockey", "nhl"),
        "predators": ("27", "hockey", "nhl"),
        "winnipeg jets": ("28", "hockey", "nhl"),
        "Columbus Blue Jackets": ("29", "hockey", "nhl"),
        "Minnesota Wild": ("30", "hockey", "nhl"),
        "wild": ("30", "hockey", "nhl"),
        "penguins": ("16", "hockey", "nhl"),
        "pittsburgh penguins": ("16", "hockey", "nhl"),
        "bruins": ("1", "hockey", "nhl"),
        "boston bruins": ("1", "hockey", "nhl"),
        "new york rangers": ("13", "hockey", "nhl"),
        "lightning": ("20", "hockey", "nhl"),
        "tampa bay lightning": ("20", "hockey", "nhl"),
        "Ottawa Senators": ("14", "hockey", "nhl"),
        "Senators": ("14", "hockey", "nhl"),
        "canadiens": ("10", "hockey", "nhl"),
        "montreal canadiens": ("10", "hockey", "nhl"),
        "san jose sharks": ("18", "hockey", "nhl"),
        "sharks": ("18", "hockey", "nhl"),
        "blues": ("19", "hockey", "nhl"),
        "st louis blues": ("19", "hockey", "nhl"),
        "maple leafs": ("21", "hockey", "nhl"),
        "devils": ("11", "hockey", "nhl"),
        "new jersey devils": ("11", "hockey", "nhl"),
        "islanders": ("12", "hockey", "nhl"),
        "ducks": ("25", "hockey", "nhl"),
        "anaheim ducks": ("25", "hockey", "nhl"),
        "new york islanders": ("12", "hockey", "nhl"),
        "toronto maple leafs": ("21", "hockey", "nhl"),
        "blackhawks": ("4", "hockey", "nhl"),
        "Detroit Red Wings": ("5", "hockey", "nhl"),
        "Red Wings": ("5", "hockey", "nhl"),
        "chicago blackhawks": ("4", "hockey", "nhl"),
        "flyers": ("15", "hockey", "nhl"),
        "philadelphia flyers": ("15", "hockey", "nhl"),
        "Hurricanes": ("7", "hockey", "nhl"),
        "carolina hurricanes": ("7", "hockey", "nhl"),
        "avalanche": ("17", "hockey", "nhl"),
        "colorado avalanche": ("17", "hockey", "nhl"),
        "golden knights": ("37", "hockey", "nhl"),
        "vegas golden knights": ("37", "hockey", "nhl"),
        "oilers": ("6", "hockey", "nhl"),
        "edmonton oilers": ("6", "hockey", "nhl"),
        "flames": ("3", "hockey", "nhl"),
        "Buffalo Sabres": ("2", "hockey", "nhl"),
        "calgary flames": ("3", "hockey", "nhl"),
        "canucks": ("22", "hockey", "nhl"),
        "Los Angeles King": ("8", "hockey", "nhl"),
        "LA King": ("8", "hockey", "nhl"),
        "Dallas stars": ("9", "hockey", "nhl"),
        "stars": ("9", "hockey", "nhl"),
        "vancouver canucks": ("22", "hockey", "nhl"),

        // Premier League (eng.1)
        "arsenal": ("359", "soccer", "eng.1"),
        "chelsea": ("363", "soccer", "eng.1"),
        "liverpool": ("364", "soccer", "eng.1"),
        "manchester city": ("382", "soccer", "eng.1"),
        "man city": ("382", "soccer", "eng.1"),
        "manchester united": ("360", "soccer", "eng.1"),
        "man united": ("360", "soccer", "eng.1"),
        "man utd": ("360", "soccer", "eng.1"),
        "tottenham": ("367", "soccer", "eng.1"),
        "spurs": ("367", "soccer", "eng.1"),
        "newcastle": ("361", "soccer", "eng.1"),
        "aston villa": ("362", "soccer", "eng.1"),
        "west ham": ("371", "soccer", "eng.1"),
        "brighton": ("331", "soccer", "eng.1"),
        "fulham": ("370", "soccer", "eng.1"),
        "brentford": ("337", "soccer", "eng.1"),
        "crystal palace": ("384", "soccer", "eng.1"),
        "everton": ("368", "soccer", "eng.1"),
        "nottingham forest": ("393", "soccer", "eng.1"),
        "wolves": ("380", "soccer", "eng.1"),
        "wolverhampton": ("380", "soccer", "eng.1"),
        "bournemouth": ("349", "soccer", "eng.1"),
        "ipswich": ("373", "soccer", "eng.1"),
        "leicester": ("375", "soccer", "eng.1"),
        "southampton": ("376", "soccer", "eng.1"),

        // Championship (eng.2)
        "wrexham": ("683", "soccer", "eng.2"),
        "wrexham afc": ("683", "soccer", "eng.2"),
        "wrexham a.f.c": ("683", "soccer", "eng.2"),

        // La Liga (esp.1)
        "real madrid": ("86", "soccer", "esp.1"),
        "barcelona": ("83", "soccer", "esp.1"),
        "atletico madrid": ("1068", "soccer", "esp.1"),
        "atletico": ("1068", "soccer", "esp.1"),
        "sevilla": ("95", "soccer", "esp.1"),
        "real sociedad": ("89", "soccer", "esp.1"),
        "villarreal": ("102", "soccer", "esp.1"),
        "athletic bilbao": ("93", "soccer", "esp.1"),
        "real betis": ("88", "soccer", "esp.1"),
        "valencia": ("94", "soccer", "esp.1"),

        // Bundesliga (ger.1)
        "bayern munich": ("132", "soccer", "ger.1"),
        "bayern": ("132", "soccer", "ger.1"),
        "borussia dortmund": ("124", "soccer", "ger.1"),
        "dortmund": ("124", "soccer", "ger.1"),
        "bvb": ("124", "soccer", "ger.1"),
        "rb leipzig": ("23826", "soccer", "ger.1"),
        "bayer leverkusen": ("131", "soccer", "ger.1"),
        "leverkusen": ("131", "soccer", "ger.1"),
        "eintracht frankfurt": ("9823", "soccer", "ger.1"),
        "borussia monchengladbach": ("130", "soccer", "ger.1"),
        "wolfsburg": ("11420", "soccer", "ger.1"),
        "hoffenheim": ("10189", "soccer", "ger.1"),

        // Serie A (ita.1)
        "juventus": ("111", "soccer", "ita.1"),
        "inter milan": ("110", "soccer", "ita.1"),
        "inter": ("110", "soccer", "ita.1"),
        "ac milan": ("103", "soccer", "ita.1"),
        "milan": ("103", "soccer", "ita.1"),
        "napoli": ("114", "soccer", "ita.1"),
        "as roma": ("104", "soccer", "ita.1"),
        "roma": ("104", "soccer", "ita.1"),
        "lazio": ("112", "soccer", "ita.1"),
        "atalanta": ("106", "soccer", "ita.1"),
        "fiorentina": ("109", "soccer", "ita.1"),
        "torino": ("116", "soccer", "ita.1"),

        // Ligue 1 (fra.1)
        "psg": ("160", "soccer", "fra.1"),
        "paris saint-germain": ("160", "soccer", "fra.1"),
        "paris saint germain": ("160", "soccer", "fra.1"),
        "marseille": ("162", "soccer", "fra.1"),
        "lyon": ("161", "soccer", "fra.1"),
        "monaco": ("163", "soccer", "fra.1"),
        "lille": ("165", "soccer", "fra.1"),
        "nice": ("168", "soccer", "fra.1"),
        "rennes": ("173", "soccer", "fra.1"),
        "lens": ("166", "soccer", "fra.1"),
    ]

    // MARK: - Team detection

    func detectTeam(in text: String) -> ESPNTeam? {
        // Only search the first line — ignore appended game info
        let firstLine = text.components(separatedBy: "\n").first ?? text
        let lower = firstLine.lowercased()
        
        let sortedKeys = teamLookup.keys.sorted { $0.count > $1.count }
        for key in sortedKeys {
            if lower.contains(key) {
                let value = teamLookup[key]!
                return ESPNTeam(
                    id: value.id,
                    name: key.capitalized,
                    abbreviation: "",
                    sport: value.sport,
                    league: value.league
                )
            }
        }
        return nil
    }

    // MARK: - Fetch upcoming games

    func fetchUpcomingGames(for team: ESPNTeam) async -> [ESPNGame] {
        let urlString = "https://site.api.espn.com/apis/site/v2/sports/\(team.sport)/\(team.league)/teams/\(team.id)/schedule"
        guard let url = URL(string: urlString) else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return parseSchedule(data: data, league: team.league)
        } catch {
            print("ESPN fetch error: \(error)")
            return []
        }
    }

    // MARK: - Fetch scoreboard

    func fetchScoreboard(sport: String, league: String) async -> [ESPNGame] {
        let urlString = "https://site.api.espn.com/apis/site/v2/sports/\(sport)/\(league)/scoreboard"
        guard let url = URL(string: urlString) else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return parseScoreboard(data: data, league: league)
        } catch {
            print("ESPN scoreboard error: \(error)")
            return []
        }
    }
    // MARK: - Fetch Team Record
    func fetchTeamRecord(for team: ESPNTeam) async -> String {
        let urlString = "https://site.api.espn.com/apis/site/v2/sports/\(team.sport)/\(team.league)/teams/\(team.id)/schedule"
        guard let url = URL(string: urlString) else { return "" }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let teamData = json["team"] as? [String: Any],
                  let record = teamData["record"] as? [String: Any],
                  let items = record["items"] as? [[String: Any]],
                  let overall = items.first(where: { ($0["type"] as? String) == "total" }),
                  let summary = overall["summary"] as? String else { return "" }
            return summary
        } catch { return "" }
    }
    // MARK: - Fetch standings

    func fetchStandings(for team: ESPNTeam) async -> [ESPNStandingEntry] {
        let endpoints = [
            "https://site.api.espn.com/apis/v2/sports/\(team.sport)/\(team.league)/standings",
            "https://site.api.espn.com/apis/v2/sports/\(team.sport)/\(team.league)/standings?seasontype=2",
            "https://site.api.espn.com/apis/site/v2/sports/\(team.sport)/\(team.league)/standings?group=1",
        ]
        for urlString in endpoints {
            guard let url = URL(string: urlString) else { continue }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let result = parseStandings(data: data, teamName: team.name, league: team.league)
                if !result.isEmpty { return result }
            } catch { continue }
        }
        return []
    }

    // MARK: - Parse schedule

    private func parseSchedule(data: Data, league: String) -> [ESPNGame] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let events = json["events"] as? [[String: Any]] else { return [] }

        var games: [ESPNGame] = []

        for event in events {
            guard let id = event["id"] as? String,
                  let dateStr = event["date"] as? String,
                  let date = parseESPNDate(dateStr) else { continue }

            let competitions = event["competitions"] as? [[String: Any]]
            let competition = competitions?.first
            let competitors = competition?["competitors"] as? [[String: Any]] ?? []

            var homeTeam = ""
            var awayTeam = ""
            var homeScore: String? = nil
            var awayScore: String? = nil
            var homeWon: Bool? = nil

            for competitor in competitors {
                let name = (competitor["team"] as? [String: Any])?["displayName"] as? String ?? ""
                let score: String?
                if let s = competitor["score"] as? String, !s.isEmpty {
                    score = s
                } else if let n = competitor["score"] as? Int {
                    score = String(n)
                } else if let d = competitor["score"] as? Double {
                    score = String(Int(d))
                } else if let scoreObj = competitor["score"] as? [String: Any] {
                    if let display = scoreObj["displayValue"] as? String, !display.isEmpty {
                        score = display
                    } else if let val = scoreObj["value"] as? Double {
                        score = String(Int(val))
                    } else {
                        score = nil
                    }
                } else {
                    score = nil
                }
                let isHome = competitor["homeAway"] as? String == "home"
                let winner: Bool
                if let w = competitor["winner"] as? Bool {
                    winner = w
                } else if let wStr = competitor["winner"] as? String {
                    winner = wStr == "true"
                } else {
                    winner = false
                }
                if isHome {
                    homeTeam = name
                    homeScore = score
                    homeWon = winner
                } else {
                    awayTeam = name
                    awayScore = score
                }
            }

            let statusType = (competition?["status"] as? [String: Any])?["type"] as? [String: Any]
            let statusName = statusType?["name"] as? String ?? ""
            let completed = (statusType?["completed"] as? Int) == 1 ||
                            (statusType?["completed"] as? Bool) == true
            let status: ESPNGame.GameStatus
            switch statusName {
            case "STATUS_IN_PROGRESS": status = .inProgress
            case "STATUS_FINAL", "STATUS_FULL_TIME", "STATUS_FT": status = .final_
            case "STATUS_POSTPONED": status = .postponed
            default: status = completed ? .final_ : .scheduled
            }

            let venue = ((competition?["venue"] as? [String: Any])?["fullName"] as? String)
            let broadcasts = competition?["broadcasts"] as? [[String: Any]]
            let broadcast = (broadcasts?.first?["names"] as? [String])?.first

            games.append(ESPNGame(
                id: id,
                homeTeam: homeTeam,
                awayTeam: awayTeam,
                homeScore: homeScore,
                awayScore: awayScore,
                homeWon: homeWon,
                date: date,
                status: status,
                venue: venue,
                broadcast: broadcast,
                league: league.uppercased()
            ))
        }

        return games.sorted { $0.date < $1.date }
    }

    // MARK: - Parse scoreboard

    private func parseScoreboard(data: Data, league: String) -> [ESPNGame] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let events = json["events"] as? [[String: Any]] else { return [] }

        var games: [ESPNGame] = []

        for event in events {
            guard let id = event["id"] as? String,
                  let dateStr = event["date"] as? String,
                  let date = parseESPNDate(dateStr) else { continue }

            let competitions = event["competitions"] as? [[String: Any]]
            let competition = competitions?.first
            let competitors = competition?["competitors"] as? [[String: Any]] ?? []

            var homeTeam = ""
            var awayTeam = ""
            var homeScore: String? = nil
            var awayScore: String? = nil
            var homeWon: Bool? = nil

            for competitor in competitors {
                let name = (competitor["team"] as? [String: Any])?["displayName"] as? String ?? ""
                let score: String?
                if let s = competitor["score"] as? String, !s.isEmpty {
                    score = s
                } else if let n = competitor["score"] as? Int {
                    score = String(n)
                } else if let d = competitor["score"] as? Double {
                    score = String(Int(d))
                } else if let scoreObj = competitor["score"] as? [String: Any] {
                    if let display = scoreObj["displayValue"] as? String, !display.isEmpty {
                        score = display
                    } else if let val = scoreObj["value"] as? Double {
                        score = String(Int(val))
                    } else {
                        score = nil
                    }
                } else {
                    score = nil
                }
                let isHome = competitor["homeAway"] as? String == "home"
                let winner: Bool
                if let w = competitor["winner"] as? Bool {
                    winner = w
                } else if let wStr = competitor["winner"] as? String {
                    winner = wStr == "true"
                } else {
                    winner = false
                }
                if isHome {
                    homeTeam = name
                    homeScore = score
                    homeWon = winner
                } else {
                    awayTeam = name
                    awayScore = score
                }
            }

            let statusType = (competition?["status"] as? [String: Any])?["type"] as? [String: Any]
            let statusName = statusType?["name"] as? String ?? ""
            let completed = (statusType?["completed"] as? Int) == 1 ||
                            (statusType?["completed"] as? Bool) == true
            let status: ESPNGame.GameStatus
            switch statusName {
            case "STATUS_IN_PROGRESS": status = .inProgress
            case "STATUS_FINAL", "STATUS_FULL_TIME", "STATUS_FT": status = .final_
            case "STATUS_POSTPONED": status = .postponed
            default: status = completed ? .final_ : .scheduled
            }

            let venue = ((competition?["venue"] as? [String: Any])?["fullName"] as? String)
            let broadcasts = competition?["broadcasts"] as? [[String: Any]]
            let broadcast = (broadcasts?.first?["names"] as? [String])?.first

            games.append(ESPNGame(
                id: id,
                homeTeam: homeTeam,
                awayTeam: awayTeam,
                homeScore: homeScore,
                awayScore: awayScore,
                homeWon: homeWon,
                date: date,
                status: status,
                venue: venue,
                broadcast: broadcast,
                league: league.uppercased()
            ))
        }

        return games.sorted { $0.date < $1.date }
    }

    // MARK: - Parse standings

    private func parseStandings(data: Data, teamName: String, league: String) -> [ESPNStandingEntry] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let children = json["children"] as? [[String: Any]] else {
            print("📊 Standings: no children key found")
            return []
        }

        let isSoccer = ["eng.1","eng.2","esp.1","ger.1","ita.1","fra.1"].contains(league.lowercased())
        let isHockey = league.lowercased() == "nhl"
        let teamLower = teamName.lowercased()
        // Use only the nickname (last word) to avoid city-name false matches
        // e.g. "mets" not "york" so Yankees don't match when user has Mets
        let teamNickname = teamLower.split(separator: " ").last.map(String.init) ?? teamLower

        for division in children {
            guard let standings = division["standings"] as? [String: Any],
                  let entries = standings["entries"] as? [[String: Any]] else { continue }

            let divisionNames = entries.compactMap {
                ($0["team"] as? [String: Any])?["displayName"] as? String
            }
            let containsUserTeam = divisionNames.contains { name in
                let nameLower = name.lowercased()
                return nameLower.contains(teamLower) || nameLower.contains(teamNickname)
            }
            guard containsUserTeam else { continue }

            var result: [ESPNStandingEntry] = []
            for entry in entries {
                guard let teamInfo = entry["team"] as? [String: Any],
                      let name = teamInfo["displayName"] as? String,
                      let stats = entry["stats"] as? [[String: Any]] else { continue }

                var wins = 0
                var losses = 0
                var draws = 0
                var otLosses = 0
                var points = 0
                var pct = ""
                var gb = "-"

                for stat in stats {
                    let statName = stat["name"] as? String ?? ""
                    let value = stat["value"] as? Double ?? 0
                    let displayValue = stat["displayValue"] as? String ?? ""
                    switch statName {
                    case "wins": wins = Int(value)
                    case "losses": losses = Int(value)
                    case "ties", "draws": draws = Int(value)
                    case "otLosses", "overtimeLosses": otLosses = Int(value)
                    case "points": points = Int(value)
                    case "winPercent", "winPct":
                        pct = displayValue.isEmpty ? String(format: "%.3f", value) : displayValue
                    case "gamesBehind":
                        gb = displayValue.isEmpty ? (value == 0 ? "-" : String(format: "%.1f", value)) : displayValue
                    default: break
                    }
                }

                let nameLower = name.lowercased()
                let isUserTeam = nameLower.contains(teamLower) || nameLower.contains(teamNickname)

                result.append(ESPNStandingEntry(
                    teamName: name,
                    wins: wins,
                    losses: losses,
                    draws: draws,
                    otLosses: otLosses,
                    points: points,
                    winPct: pct,
                    gamesBehind: gb,
                    isSoccer: isSoccer,
                    isHockey: isHockey,
                    isUserTeam: isUserTeam
                ))
            }

            return result.sorted {
                if $0.isSoccer || $0.isHockey { return $0.points > $1.points }
                return $0.wins > $1.wins
            }
        }

        return []
    }

    private func parseESPNDate(_ str: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: str) { return date }

        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime, .withTimeZone]
        if let date = fallback.date(from: str) { return date }

        let manual = DateFormatter()
        manual.locale = Locale(identifier: "en_US_POSIX")
        manual.dateFormat = "yyyy-MM-dd'T'HH:mmZ"
        return manual.date(from: str)
    }
    }

    extension UserDefaults {
        var showSportsInUpcoming: Bool {
            get { bool(forKey: "showSportsInUpcoming") }
            set { set(newValue, forKey: "showSportsInUpcoming") }
        }
    }
