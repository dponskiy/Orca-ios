//
//  TCGSetDetailView.swift
//  Orca

import SwiftUI
import SwiftData

struct TCGSetDetailView: View {
    let setId: String
    let setName: String

    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Query private var allCards: [TCGCard]
    @State private var service = PokemonTCGService.shared
    @State private var filter: CardFilter = .all
    @State private var actionCard: PokemonCard? = nil
    @State private var detailCard: TCGCard? = nil

    enum CardFilter: String, CaseIterable {
        case all = "All"
        case owned = "Owned"
        case missing = "Missing"
        case chasing = "Chasing"
    }

    private var myCards: [TCGCard] { allCards.filter { $0.setId == setId } }
    private var ownedIds: Set<String> { Set(myCards.filter { $0.isOwned }.map { $0.pokemonId }) }
    private var chasingIds: Set<String> { Set(myCards.filter { !$0.isOwned }.map { $0.pokemonId }) }

    private var setCards: [PokemonCard] { service.setCards[setId] ?? [] }
    private var isLoading: Bool { service.isFetchingCards.contains(setId) }

    private var displayCards: [PokemonCard] {
        switch filter {
        case .all: return setCards
        case .owned: return setCards.filter { ownedIds.contains($0.id) }
        case .missing: return setCards.filter { !ownedIds.contains($0.id) && !chasingIds.contains($0.id) }
        case .chasing: return setCards.filter { chasingIds.contains($0.id) }
        }
    }

    private var ownedCount: Int { ownedIds.count }
    private var collectionValue: Double {
        myCards.filter { $0.isOwned }.compactMap { $0.marketPrice }.reduce(0, +)
    }
    private var completion: Double {
        let total = setCards.isEmpty ? 1 : setCards.count
        return Double(ownedCount) / Double(total)
    }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Set header
            setHeader

            // Filter tabs
            filterBar

            // Grid
            if isLoading {
                Spacer()
                ProgressView().tint(.oceanTeal)
                Text("Loading cards...").font(.custom("DMSans-Regular", size: 14)).foregroundColor(.gray).padding(.top, 8)
                Spacer()
            } else if service.fetchCardsErrors.contains(setId) {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "wifi.slash").font(.system(size: 28)).foregroundColor(.gray.opacity(0.6))
                    Text("Couldn't load cards").font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy)
                    Text("Check your connection and try again.")
                        .font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                    Button { Task { await service.fetchCards(setId: setId) } } label: {
                        Text("Retry")
                            .font(.custom("DMSans-Medium", size: 13))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24).padding(.vertical, 9)
                            .background(Color.oceanTeal)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 2)
                }
                Spacer()
            } else if displayCards.isEmpty {
                Spacer()
                Text(filter == .missing ? "You have all these! 🎉" : "No cards here yet")
                    .font(.custom("DMSans-Medium", size: 16)).foregroundColor(.gray)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(displayCards) { card in
                            cardCell(card)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(Color.pearl.ignoresSafeArea())
        .navigationTitle(setName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $actionCard) { card in
            TCGCardActionSheet(card: card, existingCard: myCards.first(where: { $0.pokemonId == card.id })) { action in
                handleAction(action, for: card)
            }
            .presentationDetents([.height(320)])
        }
        .sheet(item: $detailCard) { card in
            TCGCardDetailSheet(card: card)
        }
        .task { await service.fetchCards(setId: setId) }
    }

    // MARK: - Set Header

    private var setHeader: some View {
        VStack(spacing: 10) {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(ownedCount) / \(setCards.isEmpty ? "?" : "\(setCards.count)")")
                        .font(.custom("DMSans-Medium", size: 22)).foregroundColor(.deepNavy)
                    Text("cards owned")
                        .font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                }
                Spacer()
                if collectionValue > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("$\(String(format: "%.2f", collectionValue))")
                            .font(.custom("DMSans-Medium", size: 22)).foregroundColor(.oceanTeal)
                        Text("est. value")
                            .font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                    }
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.mist).frame(height: 7)
                    RoundedRectangle(cornerRadius: 4).fill(
                        LinearGradient(colors: [.oceanTeal, .seafoam], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: geo.size.width * min(completion, 1.0), height: 7)
                    .animation(.spring(duration: 0.4), value: ownedCount)
                }
            }
            .frame(height: 7)

            Text("\(Int(completion * 100))% complete")
                .font(.custom("DMMono-Regular", size: 11)).foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Color.white)
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - Filter Bar

    private func hintPill(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11)).foregroundColor(color)
            Text(label).font(.custom("DMSans-Regular", size: 11)).foregroundColor(.gray)
        }
    }

    private var filterBar: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CardFilter.allCases, id: \.self) { f in
                        Button {
                            withAnimation(.easeOut(duration: 0.15)) { filter = f }
                        } label: {
                            Text(filterLabel(f))
                                .font(.custom("DMSans-Medium", size: 13))
                                .foregroundColor(filter == f ? .white : .deepNavy)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(filter == f ? Color.oceanTeal : Color.mist)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
            }
            HStack(spacing: 0) {
                hintPill(icon: "hand.point.up.fill", label: "Tap to own", color: .oceanTeal)
                Image(systemName: "arrow.right").font(.system(size: 9)).foregroundColor(.gray.opacity(0.4)).padding(.horizontal, 4)
                hintPill(icon: "hand.point.up.fill", label: "Again to chase", color: .coral)
                Image(systemName: "arrow.right").font(.system(size: 9)).foregroundColor(.gray.opacity(0.4)).padding(.horizontal, 4)
                hintPill(icon: "hand.point.up.fill", label: "Again to remove", color: .gray)
                Spacer()
                hintPill(icon: "hand.draw.fill", label: "Hold → PSA", color: .deepNavy)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .background(Color.white)
        .overlay(Divider(), alignment: .bottom)
    }

    private func filterLabel(_ f: CardFilter) -> String {
        switch f {
        case .all: return "All (\(setCards.count))"
        case .owned: return "Owned (\(ownedCount))"
        case .missing: return "Missing (\(setCards.count - ownedCount - chasingIds.count))"
        case .chasing: return "Chasing (\(chasingIds.count))"
        }
    }

    // MARK: - Card Cell

    private func cardCell(_ card: PokemonCard) -> some View {
        let isOwned = ownedIds.contains(card.id)
        let isChasing = chasingIds.contains(card.id)

        return ZStack(alignment: .topTrailing) {
            AsyncImage(url: card.imageURL) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                        .saturation(isOwned ? 1 : (isChasing ? 0.3 : 0))
                        .opacity(isOwned ? 1 : (isChasing ? 0.7 : 0.45))
                        .animation(.easeInOut(duration: 0.25), value: isOwned)
                case .empty:
                    RoundedRectangle(cornerRadius: 8).fill(Color.mist)
                        .overlay(ProgressView().scaleEffect(0.5))
                default:
                    RoundedRectangle(cornerRadius: 8).fill(Color.mist)
                }
            }
            .aspectRatio(0.72, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: isOwned ? Color.oceanTeal.opacity(0.2) : Color.black.opacity(0.06),
                    radius: isOwned ? 8 : 3, y: 2)
            .onTapGesture { handleTap(card) }
            .onLongPressGesture { actionCard = card }

            // Status badge
            if isChasing {
                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Color.coral)
                    .clipShape(Circle())
                    .padding(4)
            } else if isOwned {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Color.oceanTeal)
                    .clipShape(Circle())
                    .padding(4)
            }
        }
    }

    // MARK: - Actions

    private func handleTap(_ card: PokemonCard) {
        guard let existing = myCards.first(where: { $0.pokemonId == card.id }) else {
            addCard(card, status: "owned")
            return
        }
        if existing.isOwned {
            existing.isOwned = false
            try? modelContext.save()
            if let userId = authService.userId { Task { await SupabaseSyncService.shared.pushTCGCard(existing, userId: userId) } }
        } else {
            let id = existing.id
            modelContext.delete(existing)
            try? modelContext.save()
            Task { await SupabaseSyncService.shared.deleteTCGCard(id: id) }
        }
    }

    private func handleAction(_ action: TCGCardAction, for card: PokemonCard) {
        switch action {
        case .markOwned:
            if let existing = myCards.first(where: { $0.pokemonId == card.id }) {
                existing.isOwned = true
                try? modelContext.save()
                if let userId = authService.userId { Task { await SupabaseSyncService.shared.pushTCGCard(existing, userId: userId) } }
            } else {
                addCard(card, status: "owned")
            }
        case .markChasing:
            if let existing = myCards.first(where: { $0.pokemonId == card.id }) {
                existing.isOwned = false
                try? modelContext.save()
                if let userId = authService.userId { Task { await SupabaseSyncService.shared.pushTCGCard(existing, userId: userId) } }
            } else {
                addCard(card, status: "chasing")
            }
        case .viewDetail:
            detailCard = myCards.first(where: { $0.pokemonId == card.id })
        case .remove:
            if let existing = myCards.first(where: { $0.pokemonId == card.id }) {
                let id = existing.id
                modelContext.delete(existing)
                try? modelContext.save()
                Task { await SupabaseSyncService.shared.deleteTCGCard(id: id) }
            }
        }
    }

    private func addCard(_ card: PokemonCard, status: String) {
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
        try? modelContext.save()
        if let userId = authService.userId { Task { await SupabaseSyncService.shared.pushTCGCard(tcgCard, userId: userId) } }
    }
}

// MARK: - Card Action Sheet

enum TCGCardAction {
    case markOwned, markChasing, viewDetail, remove
}

struct TCGCardActionSheet: View {
    let card: PokemonCard
    let existingCard: TCGCard?
    let onAction: (TCGCardAction) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showRemoveConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 4).padding(.top, 12)

            HStack(spacing: 14) {
                if let url = card.imageURL {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase { img.resizable().aspectRatio(contentMode: .fill) }
                        else { Color.mist }
                    }
                    .frame(width: 60, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.name).font(.custom("DMSans-Medium", size: 16)).foregroundColor(.deepNavy)
                    Text(card.setName).font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                    if let rarity = card.rarity {
                        Text(rarity).font(.custom("DMMono-Regular", size: 11)).foregroundColor(.gray)
                    }
                    if let price = card.marketPrice {
                        Text("$\(String(format: "%.2f", price)) market")
                            .font(.custom("DMSans-Medium", size: 13)).foregroundColor(.oceanTeal)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 16)

            Divider().padding(.top, 16)

            VStack(spacing: 0) {
                if existingCard?.isOwned != true {
                    actionRow(icon: "checkmark.circle.fill", label: "Mark as Owned", color: .oceanTeal) {
                        onAction(.markOwned); dismiss()
                    }
                }
                if existingCard?.isOwned != false {
                    actionRow(icon: "sparkle", label: "Add to Chase List", color: .coral) {
                        onAction(.markChasing); dismiss()
                    }
                }
                if existingCard != nil {
                    actionRow(icon: "info.circle", label: "View Details", color: .deepNavy) {
                        onAction(.viewDetail); dismiss()
                    }
                    actionRow(icon: "trash", label: "Remove from Collection", color: .coral) {
                        showRemoveConfirm = true
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 8)
        }
        .background(Color.pearl)
        .alert("Remove \(card.name)?", isPresented: $showRemoveConfirm) {
            Button("Remove", role: .destructive) { onAction(.remove); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the card from your collection.")
        }
    }

    private func actionRow(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16)).foregroundColor(color).frame(width: 24)
                Text(label).font(.custom("DMSans-Regular", size: 15)).foregroundColor(label.contains("Remove") ? .coral : .deepNavy)
                Spacer()
            }
            .padding(.vertical, 14).padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .overlay(Divider(), alignment: .bottom)
    }
}
