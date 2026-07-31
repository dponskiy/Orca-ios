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
            URLQueryItem(name: "select", value: "id,name,set,number,images,rarity,tcgplayer")
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
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            await MainActor.run { searchResults = [] }
            return
        }
        await MainActor.run { isSearching = true }

        var components = URLComponents(string: "\(baseURL)/cards")
        components?.queryItems = [
            URLQueryItem(name: "q", value: "name:\(query)*"),
            URLQueryItem(name: "pageSize", value: "20"),
            URLQueryItem(name: "select", value: "id,name,set,number,images,rarity,tcgplayer")
        ]

        guard let url = components?.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let response = try? JSONDecoder().decode(PTCGResponse.self, from: data)
        else {
            await MainActor.run { isSearching = false }
            return
        }

        let cards = response.data.map { parseCard($0) }
        await MainActor.run {
            searchResults = cards
            isSearching = false
        }
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
}

private struct PTCGCard: Decodable {
    let id: String
    let name: String
    let set: PTCGSetRef?
    let number: String?
    let images: PTCGImages?
    let rarity: String?
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
