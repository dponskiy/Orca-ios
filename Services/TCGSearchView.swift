//
//  TCGSearchView.swift
//  Orca

import SwiftUI
import SwiftData

struct TCGSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Query private var existingCards: [TCGCard]

    @State private var query = ""
    @State private var service = PokemonTCGService.shared
    @State private var addedIds: Set<String> = []
    @State private var pendingStatus: [String: String] = [:]  // pokemonId → "owned"|"chasing"
    @FocusState private var searchFocused: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    TextField("Search Pokémon cards...", text: $query)
                        .font(.custom("DMSans-Regular", size: 15))
                        .focused($searchFocused)
                        .onSubmit { Task { await service.search(query: query) } }
                        .onChange(of: query) { _, val in
                            if val.isEmpty { service.clearSearch() }
                        }
                    if service.isSearching {
                        ProgressView().scaleEffect(0.8).tint(.oceanTeal)
                    } else if !query.isEmpty {
                        Button { query = ""; service.searchResults = [] } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray.opacity(0.5))
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.mist)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(16)
                .submitLabel(.search)

                if service.isSearching {
                    Spacer()
                    ProgressView().tint(.oceanTeal).scaleEffect(1.3)
                    Spacer()
                } else if service.searchFailed {
                    searchError
                } else if query.isEmpty || service.searchResults.isEmpty && service.lastSearchQuery.isEmpty {
                    emptySearch
                } else if service.searchResults.isEmpty {
                    noResults
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(service.searchResults) { card in
                                searchCard(card)
                                    .onAppear {
                                        // Start fetching next page when within 6 cards of the end
                                        let results = service.searchResults
                                        if let idx = results.firstIndex(where: { $0.id == card.id }),
                                           idx >= results.count - 6,
                                           results.count < service.searchTotalCount {
                                            Task { await service.searchMore() }
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 16)

                        // Bottom indicator — always tappable when cards remain, so a
                        // failed page fetch can be retried. Auto-scroll can't recover
                        // on its own: the cards that trigger it are already on screen.
                        if service.isLoadingMore {
                            ProgressView()
                                .tint(.oceanTeal)
                                .padding(.vertical, 20)
                        } else if service.searchResults.count < service.searchTotalCount {
                            let remaining = service.searchTotalCount - service.searchResults.count
                            Button {
                                Task { await service.searchMore() }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: service.loadMoreFailed
                                          ? "arrow.clockwise" : "chevron.down")
                                        .font(.system(size: 10, weight: .semibold))
                                    Text(service.loadMoreFailed
                                         ? "Couldn't load — tap to retry"
                                         : "Load \(remaining) more")
                                        .font(.custom("DMSans-Medium", size: 13))
                                }
                                .foregroundColor(service.loadMoreFailed ? .coral : .oceanTeal)
                                .padding(.horizontal, 18).padding(.vertical, 9)
                                .background((service.loadMoreFailed ? Color.coral : Color.oceanTeal).opacity(0.1))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 16)
                        }

                        Spacer().frame(height: 16)
                    }
                }
            }
            .background(Color.pearl.ignoresSafeArea())
            .navigationTitle("Add Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.oceanTeal)
                }
            }
            .onAppear { searchFocused = true }
        }
    }

    // MARK: - Search Card Cell

    private func searchCard(_ card: PokemonCard) -> some View {
        let alreadyAdded = existingCards.contains { $0.pokemonId == card.id }
            || addedIds.contains(card.id)
        let status = pendingStatus[card.id]

        return VStack(spacing: 0) {
            AsyncImage(url: card.imageURL) { phase in
                if case .success(let img) = phase {
                    img.resizable().aspectRatio(contentMode: .fill)
                } else {
                    ZStack { Color.mist; ProgressView().scaleEffect(0.6) }
                }
            }
            .aspectRatio(0.72, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                alreadyAdded
                    ? RoundedRectangle(cornerRadius: 8).stroke(Color.oceanTeal, lineWidth: 2)
                    : nil
            )

            VStack(spacing: 6) {
                Text(card.name)
                    .font(.custom("DMSans-Medium", size: 10))
                    .foregroundColor(.deepNavy)
                    .lineLimit(1)

                if let price = card.marketPrice {
                    Text("$\(String(format: "%.2f", price))")
                        .font(.custom("DMMono-Regular", size: 10))
                        .foregroundColor(.gray)
                }

                if alreadyAdded {
                    Text("Added ✓")
                        .font(.custom("DMSans-Medium", size: 10))
                        .foregroundColor(.oceanTeal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(Color.oceanTeal.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    HStack(spacing: 6) {
                        addButton(label: "Own", icon: "checkmark", color: .oceanTeal) {
                            add(card: card, status: "owned")
                        }
                        addButton(label: "Chase", icon: "sparkle", color: .coral) {
                            add(card: card, status: "chasing")
                        }
                    }
                }
            }
            .padding(6)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    private func addButton(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 9, weight: .bold))
                Text(label).font(.custom("DMSans-Medium", size: 10))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func add(card: PokemonCard, status: String) {
        let tcgCard = TCGCard(
            pokemonId: card.id,
            name: card.name,
            setId: card.setId,
            setName: card.setName,
            number: card.number,
            imageURL: card.imageURL?.absoluteString ?? "",
            largeImageURL: card.largeImageURL?.absoluteString ?? "",
            rarity: card.rarity
        )
        tcgCard.statusRaw = status
        tcgCard.types = card.types
        tcgCard.marketPrice = card.marketPrice
        tcgCard.lowPrice = card.lowPrice
        tcgCard.highPrice = card.highPrice
        tcgCard.priceVariant = card.priceVariant
        modelContext.insert(tcgCard)
        addedIds.insert(card.id)
        if let userId = authService.userId { Task { await SupabaseSyncService.shared.pushTCGCard(tcgCard, userId: userId) } }
    }

    // MARK: - States

    private var emptySearch: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(.oceanTeal.opacity(0.25))
            Text("Search for a Pokémon")
                .font(.custom("DMSans-Medium", size: 17))
                .foregroundColor(.deepNavy)
            Text("Try \"Charizard\", \"Pikachu\", or a set name")
                .font(.custom("DMSans-Regular", size: 14))
                .foregroundColor(.gray)
            Spacer()
        }
    }

    private var noResults: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.gray.opacity(0.3))
            Text("No cards found")
                .font(.custom("DMSans-Medium", size: 17))
                .foregroundColor(.deepNavy)
            Text("Try a different name or spelling")
                .font(.custom("DMSans-Regular", size: 14))
                .foregroundColor(.gray)
            Spacer()
        }
    }

    private var searchError: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "wifi.slash")
                .font(.system(size: 36))
                .foregroundColor(.gray.opacity(0.3))
            Text("Search failed")
                .font(.custom("DMSans-Medium", size: 17))
                .foregroundColor(.deepNavy)
            Text("Check your connection and try again")
                .font(.custom("DMSans-Regular", size: 14))
                .foregroundColor(.gray)
            Button {
                Task { await service.search(query: query) }
            } label: {
                Text("Retry")
                    .font(.custom("DMSans-Medium", size: 15))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 11)
                    .background(Color.oceanTeal)
                    .clipShape(Capsule())
            }
            Spacer()
        }
    }
}
