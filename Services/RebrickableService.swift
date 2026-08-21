//
//  RebrickableService.swift
//  Orca

import Foundation
import Observation

// MARK: - Public types

struct RBTheme: Identifiable, Decodable, Hashable {
    let id: Int
    let parentId: Int?
    let name: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case parentId = "parent_id"
    }
}

struct RBSet: Identifiable, Decodable {
    let setNum: String
    let name: String
    let year: Int
    let themeId: Int
    let numParts: Int
    let setImgUrl: String?

    var id: String { setNum }
    var imageURL: URL? { setImgUrl.flatMap { URL(string: $0) } }

    enum CodingKeys: String, CodingKey {
        case setNum = "set_num"
        case name, year
        case themeId = "theme_id"
        case numParts = "num_parts"
        case setImgUrl = "set_img_url"
    }
}

// MARK: - Service

@Observable
final class RebrickableService {
    static let shared = RebrickableService()
    private init() {}

    private let base = "https://rebrickable.com/api/v3/lego/"

    var themes: [RBTheme] = []
    var themeSets: [Int: [RBSet]] = [:]
    var isFetchingThemes = false
    var fetchingThemeIds: Set<Int> = []
    var searchResults: [RBSet] = []
    var isSearching = false

    var hasApiKey: Bool { !Config.rebrickableApiKey.isEmpty }

    var parentThemes: [RBTheme] {
        themes.filter { $0.parentId == nil }.sorted { $0.name < $1.name }
    }

    func themeChildren(of parentId: Int) -> [RBTheme] {
        themes.filter { $0.parentId == parentId }.sorted { $0.name < $1.name }
    }

    // MARK: - Fetch all themes

    func fetchThemes() async {
        guard hasApiKey, themes.isEmpty, !isFetchingThemes else { return }
        isFetchingThemes = true
        defer { isFetchingThemes = false }

        var allThemes: [RBTheme] = []
        var page = 1
        while true {
            guard let url = URL(string: "\(base)themes/?page_size=1000&page=\(page)") else { break }
            guard let data = try? await fetch(url: url),
                  let resp = try? JSONDecoder().decode(RBListResponse<RBTheme>.self, from: data),
                  !resp.results.isEmpty else { break }
            allThemes.append(contentsOf: resp.results)
            if resp.next == nil { break }
            page += 1
        }
        themes = allThemes
    }

    // MARK: - Fetch sets for a theme

    func fetchSets(themeId: Int) async {
        guard hasApiKey, themeSets[themeId] == nil, !fetchingThemeIds.contains(themeId) else { return }
        fetchingThemeIds.insert(themeId)
        defer { fetchingThemeIds.remove(themeId) }

        var allSets: [RBSet] = []
        var page = 1
        while true {
            guard let url = URL(string: "\(base)sets/?theme_id=\(themeId)&page_size=100&ordering=-year&page=\(page)") else { break }
            guard let data = try? await fetch(url: url),
                  let resp = try? JSONDecoder().decode(RBListResponse<RBSet>.self, from: data),
                  !resp.results.isEmpty else { break }
            allSets.append(contentsOf: resp.results)
            if resp.next == nil { break }
            page += 1
        }
        themeSets[themeId] = allSets
    }

    // MARK: - Search

    func search(query: String) async {
        guard hasApiKey, !query.isEmpty else { searchResults = []; return }
        isSearching = true
        defer { isSearching = false }

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "\(base)sets/?search=\(encoded)&page_size=50&ordering=-year") else { return }
        guard let data = try? await fetch(url: url),
              let resp = try? JSONDecoder().decode(RBListResponse<RBSet>.self, from: data) else { return }
        searchResults = resp.results
    }

    // MARK: - Private

    private func fetch(url: URL) async throws -> Data {
        var req = URLRequest(url: url)
        req.setValue("key \(Config.rebrickableApiKey)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }
}

// MARK: - Response wrapper

private struct RBListResponse<T: Decodable>: Decodable {
    let count: Int
    let next: String?
    let results: [T]
}
