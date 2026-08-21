//
//  PokemonTCGService.swift
//  Orca

import Foundation
import Observation

struct PokemonSet: Identifiable {
    let id: String
    let name: String
    let series: String
    let total: Int
    let printedTotal: Int
    let releaseDate: String
    let symbolURL: URL?
    let logoURL: URL?
}

struct PokemonCard: Identifiable {
    let id: String
    let name: String
    let setId: String
    let setName: String
    let number: String
    let imageURL: URL?
    let largeImageURL: URL?
    let rarity: String?
    let types: [String]
    let marketPrice: Double?
    let lowPrice: Double?
    let highPrice: Double?
    let priceVariant: String?
    let availableVariants: [String]
}

@Observable
class PokemonTCGService {
    static let shared = PokemonTCGService()
    private init() {}

    private let baseURL = "https://api.pokemontcg.io/v2"

    var allSets: [PokemonSet] = []
    var isFetchingSets = false
    var fetchSetsError = false
    var setCards: [String: [PokemonCard]] = [:]   // setId → cards
    var isFetchingCards: Set<String> = []
    var fetchCardsErrors: Set<String> = []
    var searchResults: [PokemonCard] = []
    var isSearching = false
    var isLoadingMore = false
    var searchFailed = false
    // A page fetch failed (the public API rate-limits without a key). Surfaces a
    // tappable retry — otherwise the list is stuck: the cards whose .onAppear would
    // re-trigger loading are already on screen and never fire again.
    var loadMoreFailed = false
    private(set) var searchTotalCount = 0
    private var searchPage = 1
    private(set) var lastSearchQuery = ""
    private var activeSearchTask: Task<Void, Never>?

    func fetchSets() async {
        guard allSets.isEmpty, !isFetchingSets else { return }
        await MainActor.run { isFetchingSets = true; fetchSetsError = false }

        guard let url = URL(string: "\(baseURL)/sets?orderBy=-releaseDate&pageSize=250"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let response = try? JSONDecoder().decode(PTCGSetsResponse.self, from: data)
        else {
            await MainActor.run { isFetchingSets = false; fetchSetsError = true }
            return
        }

        let sets = response.data.map { raw in
            PokemonSet(
                id: raw.id,
                name: raw.name,
                series: raw.series,
                total: raw.total,
                printedTotal: raw.printedTotal,
                releaseDate: raw.releaseDate,
                symbolURL: raw.images?.symbol.flatMap { URL(string: $0) },
                logoURL: raw.images?.logo.flatMap { URL(string: $0) }
            )
        }

        await MainActor.run {
            allSets = sets
            isFetchingSets = false
        }
    }

    func fetchCards(setId: String) async {
        guard setCards[setId] == nil, !isFetchingCards.contains(setId) else { return }
        await MainActor.run { isFetchingCards.insert(setId); fetchCardsErrors.remove(setId) }

        var components = URLComponents(string: "\(baseURL)/cards")
        components?.queryItems = [
            URLQueryItem(name: "q", value: "set.id:\(setId)"),
            URLQueryItem(name: "pageSize", value: "250"),
            URLQueryItem(name: "orderBy", value: "number"),
            URLQueryItem(name: "select", value: "id,name,set,number,images,rarity,types,tcgplayer")
        ]

        guard let url = components?.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let response = try? JSONDecoder().decode(PTCGResponse.self, from: data)
        else {
            await MainActor.run { isFetchingCards.remove(setId); fetchCardsErrors.insert(setId) }
            return
        }

        let cards = response.data.map { parseCard($0) }

        guard !cards.isEmpty else {
            await MainActor.run { isFetchingCards.remove(setId); fetchCardsErrors.insert(setId) }
            return
        }

        await MainActor.run {
            setCards[setId] = cards
            isFetchingCards.remove(setId)
        }
    }

    func search(query: String) async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else {
            await MainActor.run { searchResults = []; searchTotalCount = 0; searchFailed = false }
            return
        }
        // Cancel any in-flight search before starting a new one
        activeSearchTask?.cancel()
        await MainActor.run { isSearching = true; searchResults = []; searchTotalCount = 0; searchPage = 1; lastSearchQuery = q; searchFailed = false; loadMoreFailed = false; isLoadingMore = false }

        let task = Task {
            guard let result = await fetchPage(query: q, page: 1) else {
                if !Task.isCancelled {
                    await MainActor.run { isSearching = false; searchFailed = true }
                }
                return
            }
            if !Task.isCancelled {
                await MainActor.run {
                    searchResults = result.cards
                    searchTotalCount = result.totalCount
                    isSearching = false
                    searchFailed = false
                }
            }
        }
        activeSearchTask = task
        await task.value
    }

    func clearSearch() {
        activeSearchTask?.cancel()
        activeSearchTask = nil
        searchResults = []
        searchTotalCount = 0
        searchFailed = false
        lastSearchQuery = ""
        isSearching = false
        isLoadingMore = false
    }

    func searchMore() async {
        // Claim the load atomically on the main actor. Several cards scroll into view
        // at once and each fires this; a non-isolated guard lets them all through and
        // they fetch the same page, appending duplicate ids.
        let claim: (query: String, page: Int)? = await MainActor.run {
            guard !lastSearchQuery.isEmpty, !isLoadingMore,
                  searchResults.count < searchTotalCount else { return nil }
            isLoadingMore = true
            loadMoreFailed = false
            return (lastSearchQuery, searchPage + 1)
        }
        guard let claim else { return }

        guard let result = await fetchPage(query: claim.query, page: claim.page) else {
            await MainActor.run { isLoadingMore = false; loadMoreFailed = true }
            return
        }
        await MainActor.run {
            // Dedupe defensively — a retry must never inject ids already on screen
            let existing = Set(searchResults.map { $0.id })
            searchResults.append(contentsOf: result.cards.filter { !existing.contains($0.id) })
            searchTotalCount = result.totalCount
            searchPage = claim.page
            isLoadingMore = false
            loadMoreFailed = false
        }
    }

    private func fetchPage(query: String, page: Int) async -> (cards: [PokemonCard], totalCount: Int)? {
        var components = URLComponents(string: "\(baseURL)/cards")
        // Large pages on purpose: the keyless public API rate-limits per request, not
        // per row, and latency barely moves with page size. One 250-card request beats
        // six 20-card ones — most searches now complete in a single round trip.
        components?.queryItems = [
            URLQueryItem(name: "q",        value: "name:\(query)*"),
            URLQueryItem(name: "pageSize", value: "250"),
            URLQueryItem(name: "page",     value: "\(page)"),
            URLQueryItem(name: "select",   value: "id,name,set,number,images,rarity,types,tcgplayer")
        ]
        guard let url = components?.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let response = try? JSONDecoder().decode(PTCGResponse.self, from: data)
        else { return nil }
        let cards = response.data.map { parseCard($0) }
        return (cards, response.totalCount ?? cards.count)
    }

    // MARK: - Helpers

    private func parseCard(_ raw: PTCGCard) -> PokemonCard {
        let prices = raw.tcgplayer?.prices
        let best = bestPrice(from: prices)
        let variants = availableVariants(from: prices)
        return PokemonCard(
            id: raw.id,
            name: raw.name,
            setId: raw.set?.id ?? "",
            setName: raw.set?.name ?? "",
            number: raw.number ?? "",
            imageURL: raw.images?.small.flatMap { URL(string: $0) },
            largeImageURL: raw.images?.large.flatMap { URL(string: $0) },
            rarity: raw.rarity,
            types: raw.types ?? [],
            marketPrice: best?.market,
            lowPrice: best?.low,
            highPrice: best?.high,
            priceVariant: best?.variant,
            availableVariants: variants
        )
    }

    private func bestPrice(from prices: PTCGPrices?) -> (market: Double?, low: Double?, high: Double?, variant: String?)? {
        guard let prices else { return nil }
        let order: [(String, PTCGPriceEntry?)] = [
            ("holofoil", prices.holofoil),
            ("reverseHolofoil", prices.reverseHolofoil),
            ("normal", prices.normal),
            ("firstEditionHolofoil", prices.firstEditionHolofoil),
            ("unlimited", prices.unlimited)
        ]
        for (name, entry) in order {
            if let e = entry, e.market != nil || e.low != nil {
                return (e.market, e.low, e.high, name)
            }
        }
        return nil
    }

    private func availableVariants(from prices: PTCGPrices?) -> [String] {
        guard let prices else { return [] }
        let all: [(String, PTCGPriceEntry?)] = [
            ("Normal", prices.normal),
            ("Holofoil", prices.holofoil),
            ("Reverse Holo", prices.reverseHolofoil),
            ("1st Edition Holo", prices.firstEditionHolofoil),
            ("Unlimited", prices.unlimited)
        ]
        return all.compactMap { name, entry in entry != nil ? name : nil }
    }

    func seriesGroups() -> [(series: String, sets: [PokemonSet])] {
        let grouped = Dictionary(grouping: allSets) { $0.series }
        return grouped.keys.sorted { a, b in
            let aDate = grouped[a]?.first?.releaseDate ?? ""
            let bDate = grouped[b]?.first?.releaseDate ?? ""
            return aDate > bDate
        }.map { series in
            (series: series, sets: (grouped[series] ?? []).sorted { $0.releaseDate > $1.releaseDate })
        }
    }
}

// MARK: - API Response Models

private struct PTCGSetsResponse: Decodable {
    let data: [PTCGSetRaw]
}

private struct PTCGSetRaw: Decodable {
    let id: String
    let name: String
    let series: String
    let total: Int
    let printedTotal: Int
    let releaseDate: String
    let images: PTCGSetImages?
}

private struct PTCGSetImages: Decodable {
    let symbol: String?
    let logo: String?
}

private struct PTCGResponse: Decodable {
    let data: [PTCGCard]
    let totalCount: Int?  // Optional — error responses won't have this field
}

private struct PTCGCard: Decodable {
    let id: String
    let name: String
    let set: PTCGSetRef?
    let number: String?
    let images: PTCGImages?
    let rarity: String?
    let types: [String]?
    let tcgplayer: PTCGPlayer?
}

private struct PTCGSetRef: Decodable {
    let id: String
    let name: String
}

private struct PTCGImages: Decodable {
    let small: String?
    let large: String?
}

private struct PTCGPlayer: Decodable {
    let prices: PTCGPrices?
}

private struct PTCGPrices: Decodable {
    let normal: PTCGPriceEntry?
    let holofoil: PTCGPriceEntry?
    let reverseHolofoil: PTCGPriceEntry?
    let firstEditionHolofoil: PTCGPriceEntry?
    let unlimited: PTCGPriceEntry?
}

private struct PTCGPriceEntry: Decodable {
    let low: Double?
    let mid: Double?
    let high: Double?
    let market: Double?
}
