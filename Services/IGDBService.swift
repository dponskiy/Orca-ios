//
//  IGDBService.swift
//  Orca

import Foundation
import Observation

struct IGDBGame: Identifiable {
    let id: Int
    let name: String
    let coverURL: URL?
    let genreNames: [String]
    let platformNames: [String]
    let rating: Double?
    let releaseYear: Int?
    let summary: String?
}

struct IGDBGenre: Identifiable {
    let id: Int
    let name: String
}

struct IGDBPlatform: Identifiable {
    let id: Int
    let name: String   // full name shown in picker
    let short: String  // abbreviation shown on cards

    static let curated: [IGDBPlatform] = [
        IGDBPlatform(id: 508, name: "Nintendo Switch 2", short: "Switch 2"),
        IGDBPlatform(id: 130, name: "Nintendo Switch",  short: "Switch"),
        IGDBPlatform(id: 169, name: "PlayStation 5",    short: "PS5"),
        IGDBPlatform(id: 48,  name: "PlayStation 4",    short: "PS4"),
        IGDBPlatform(id: 167, name: "Xbox Series X|S",  short: "Xbox Series"),
        IGDBPlatform(id: 49,  name: "Xbox One",         short: "Xbox One"),
        IGDBPlatform(id: 6,   name: "PC (Windows)",     short: "PC"),
        IGDBPlatform(id: 14,  name: "Mac",              short: "Mac"),
        IGDBPlatform(id: 39,  name: "iOS",              short: "iOS"),
        IGDBPlatform(id: 34,  name: "Android",          short: "Android"),
        IGDBPlatform(id: 9,   name: "PlayStation 3",    short: "PS3"),
        IGDBPlatform(id: 12,  name: "Xbox 360",         short: "Xbox 360"),
        IGDBPlatform(id: 41,  name: "Wii U",            short: "Wii U"),
        IGDBPlatform(id: 5,   name: "Wii",              short: "Wii"),
        IGDBPlatform(id: 37,  name: "Nintendo 3DS",     short: "3DS"),
        IGDBPlatform(id: 20,  name: "Nintendo DS",      short: "DS"),
        IGDBPlatform(id: 4,   name: "Nintendo 64",      short: "N64"),
        IGDBPlatform(id: 19,  name: "Super Nintendo",   short: "SNES"),
        IGDBPlatform(id: 18,  name: "NES",              short: "NES"),
        IGDBPlatform(id: 8,   name: "PlayStation 2",    short: "PS2"),
        IGDBPlatform(id: 7,   name: "PlayStation",      short: "PS1"),
    ]
}

@Observable
class IGDBService {
    static let shared = IGDBService()

    private let clientId     = Config.igdbClientId
    private let clientSecret = Config.igdbClientSecret
    private let baseURL      = "https://api.igdb.com/v4"
    private let tokenURL     = "https://id.twitch.tv/oauth2/token"

    private var accessToken: String?
    private var tokenExpiry: Date = .distantPast

    var searchResults: [IGDBGame] = []
    var isSearching = false

    var genres: [IGDBGenre] = []
    var isFetchingGenres = false

    var browseResults: [IGDBGame] = []
    var isBrowsing = false

    private init() {
        // Restore cached token from UserDefaults
        if let tok = UserDefaults.standard.string(forKey: "igdb_token"),
           let exp = UserDefaults.standard.object(forKey: "igdb_token_expiry") as? Date {
            accessToken = tok
            tokenExpiry = exp
        }
    }

    // MARK: - Token

    private func validToken() async throws -> String {
        if let tok = accessToken, Date() < tokenExpiry { return tok }
        return try await refreshToken()
    }

    private func refreshToken() async throws -> String {
        var comps = URLComponents(string: tokenURL)!
        comps.queryItems = [
            URLQueryItem(name: "client_id",     value: clientId),
            URLQueryItem(name: "client_secret", value: clientSecret),
            URLQueryItem(name: "grant_type",    value: "client_credentials")
        ]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        let (data, _) = try await URLSession.shared.data(for: req)
        let resp = try JSONDecoder().decode(TwitchTokenResp.self, from: data)
        let expiry = Date().addingTimeInterval(TimeInterval(resp.expires_in - 300))
        await MainActor.run {
            accessToken = resp.access_token
            tokenExpiry = expiry
        }
        UserDefaults.standard.set(resp.access_token, forKey: "igdb_token")
        UserDefaults.standard.set(expiry, forKey: "igdb_token_expiry")
        return resp.access_token
    }

    // MARK: - Request helper

    private func post(endpoint: String, body: String) async throws -> Data {
        let token = try await validToken()
        var req = URLRequest(url: URL(string: "\(baseURL)/\(endpoint)")!)
        req.httpMethod = "POST"
        req.setValue(clientId,            forHTTPHeaderField: "Client-ID")
        req.setValue("Bearer \(token)",   forHTTPHeaderField: "Authorization")
        req.setValue("application/json",  forHTTPHeaderField: "Accept")
        req.httpBody = body.data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }

    // MARK: - Search

    func search(query: String, platformId: Int? = nil) async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { await MainActor.run { searchResults = [] }; return }
        await MainActor.run { isSearching = true }
        do {
            let platformClause = platformId.map { " & platforms = (\($0))" } ?? ""
            let body = """
            search "\(q)";
            fields name,cover.url,genres.name,platforms.abbreviation,platforms.name,rating,first_release_date,summary;
            where version_parent = null\(platformClause);
            limit 20;
            """
            let data = try await post(endpoint: "games", body: body)
            let games = (try? JSONDecoder().decode([RawGame].self, from: data))?.map(parseGame) ?? []
            await MainActor.run { searchResults = games; isSearching = false }
        } catch {
            await MainActor.run { isSearching = false }
        }
    }

    // MARK: - Browse by genre

    func fetchGenres() async {
        guard genres.isEmpty, !isFetchingGenres else { return }
        await MainActor.run { isFetchingGenres = true }
        do {
            let data = try await post(endpoint: "genres", body: "fields id,name; limit 50; sort name asc;")
            let raw = (try? JSONDecoder().decode([RawGenre].self, from: data)) ?? []
            let result = raw.map { IGDBGenre(id: $0.id, name: $0.name) }
            await MainActor.run { genres = result; isFetchingGenres = false }
        } catch {
            await MainActor.run { isFetchingGenres = false }
        }
    }

    func fetchGames(genreId: Int) async {
        await MainActor.run { isBrowsing = true; browseResults = [] }
        do {
            let body = """
            fields name,cover.url,genres.name,platforms.abbreviation,platforms.name,rating,first_release_date,summary;
            where genres = (\(genreId)) & version_parent = null & cover != null;
            sort rating desc;
            limit 40;
            """
            let data = try await post(endpoint: "games", body: body)
            let games = (try? JSONDecoder().decode([RawGame].self, from: data))?.map(parseGame) ?? []
            await MainActor.run { browseResults = games; isBrowsing = false }
        } catch {
            await MainActor.run { isBrowsing = false }
        }
    }

    func fetchGames(platformId: Int, query: String = "") async {
        await MainActor.run { isBrowsing = true; browseResults = [] }
        do {
            let q = query.trimmingCharacters(in: .whitespaces)
            let body: String
            if q.isEmpty {
                body = """
                fields name,cover.url,genres.name,platforms.abbreviation,platforms.name,rating,first_release_date,summary;
                where platforms = (\(platformId)) & version_parent = null & cover != null;
                sort rating desc;
                limit 40;
                """
            } else {
                body = """
                search "\(q)";
                fields name,cover.url,genres.name,platforms.abbreviation,platforms.name,rating,first_release_date,summary;
                where platforms = (\(platformId)) & version_parent = null;
                limit 20;
                """
            }
            let data = try await post(endpoint: "games", body: body)
            let games = (try? JSONDecoder().decode([RawGame].self, from: data))?.map(parseGame) ?? []
            await MainActor.run { browseResults = games; isBrowsing = false }
        } catch {
            await MainActor.run { isBrowsing = false }
        }
    }

    // MARK: - Parse

    private func parseGame(_ raw: RawGame) -> IGDBGame {
        let coverURL: URL? = raw.cover?.url.flatMap { s -> URL? in
            let https = s.hasPrefix("//") ? "https:\(s)" : s
            let big   = https.replacingOccurrences(of: "t_thumb", with: "t_cover_big")
            return URL(string: big)
        }
        let year: Int? = raw.first_release_date.map {
            Calendar.current.component(.year, from: Date(timeIntervalSince1970: TimeInterval($0)))
        }
        return IGDBGame(
            id: raw.id,
            name: raw.name,
            coverURL: coverURL,
            genreNames: raw.genres?.map { $0.name } ?? [],
            platformNames: raw.platforms?.compactMap { $0.abbreviation ?? $0.name } ?? [],
            rating: raw.rating.map { $0 / 10.0 },
            releaseYear: year,
            summary: raw.summary
        )
    }
}

// MARK: - Private decodables

private struct TwitchTokenResp: Decodable {
    let access_token: String
    let expires_in: Int
}

private struct RawGame: Decodable {
    let id: Int
    let name: String
    let cover: RawCover?
    let genres: [RawGenre]?
    let platforms: [RawPlatform]?
    let rating: Double?
    let first_release_date: Int?
    let summary: String?
}

private struct RawCover: Decodable {
    let url: String?
}

private struct RawGenre: Decodable {
    let id: Int
    let name: String
}

private struct RawPlatform: Decodable {
    let abbreviation: String?
    let name: String?
}
