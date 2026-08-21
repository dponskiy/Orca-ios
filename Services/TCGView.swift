//
//  TCGView.swift (CollectiblesView)
//  Orca

import SwiftUI
import SwiftData
import Supabase

// MARK: - Category enum

enum CollectibleCategory: String, CaseIterable {
    case pokemon = "Pokémon"
    case lego = "Lego"
    case smiski = "Smiski"
    case games = "Games"

    var icon: String {
        switch self {
        case .pokemon: return "sparkles"
        case .lego: return "cube.box.fill"
        case .smiski: return "figure.wave"
        case .games: return "gamecontroller.fill"
        }
    }
}

// MARK: - Collectibles hub (tab root)

struct CollectiblesView: View {
    @State private var selectedCategory: CollectibleCategory = .pokemon
    @State private var showSearch = false
    @State private var showSetBrowser = false
    @State private var triggerPokemonShare = false
    @Environment(\.dismiss) private var dismiss
    @AppStorage("infoBannerDismissed_collectibles") private var bannerDismissed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    categoryPicker
                    if !bannerDismissed { collectiblesInfoBanner }
                    if selectedCategory == .pokemon { tapHintBanner }

                    switch selectedCategory {
                    case .pokemon:
                        PokemonCollectionContent(showSetBrowser: $showSetBrowser, showSearch: $showSearch, triggerShare: $triggerPokemonShare)
                    case .lego:
                        LegoCollectionContent()
                    case .smiski:
                        SmiskiCollectionContent()
                    case .games:
                        GameCollectionContent()
                    }

                    Spacer().frame(height: 40)
                }
            }
            .background(Color.pearl.ignoresSafeArea())
            .navigationTitle("Collectibles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    // Gallery lives on each tab's own button now — a toolbar copy
                    // meant a second fullScreenCover in this tree, and stacked
                    // presentation modifiers destabilise each other's state.
                    if selectedCategory == .pokemon {
                        HStack(spacing: 16) {
                            Button { triggerPokemonShare = true } label: {
                                Image(systemName: "square.and.arrow.up").foregroundColor(.oceanTeal)
                            }
                            Button { showSearch = true } label: {
                                Image(systemName: "magnifyingglass").foregroundColor(.oceanTeal)
                            }
                        }
                    }
                }
            }
            // One sheet, not two siblings — see activeSheet
            .sheet(item: activeSheet) { which in
                switch which {
                case .setBrowser: TCGSetBrowserView()
                case .search:     TCGSearchView()
                }
            }
        }
    }

    // Collapses the two Bool flags into a single presentation so the sheets can't
    // fight. The Bools stay because child views bind to them.
    private enum CollectibleSheet: String, Identifiable {
        case setBrowser, search
        var id: String { rawValue }
    }

    private var activeSheet: Binding<CollectibleSheet?> {
        Binding(
            get: {
                if showSetBrowser { return .setBrowser }
                if showSearch     { return .search }
                return nil
            },
            set: { newValue in
                showSetBrowser = (newValue == .setBrowser)
                showSearch     = (newValue == .search)
            }
        )
    }

    // MARK: - Info Banner

    private var collectiblesInfoBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 13))
                .foregroundColor(.oceanTeal.opacity(0.7))
                .padding(.top, 1)
            Text("Track your Pokémon cards, Lego sets, Smiski, and more. See your collection's estimated value all in one place.")
                .font(.custom("DMSans-Regular", size: 12))
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button { withAnimation { bannerDismissed = true } } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.mist.opacity(0.6))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Tap hint

    private var tapHintBanner: some View {
        HStack(spacing: 0) {
            hintPill(icon: "1.circle.fill", label: "Own", color: .oceanTeal)
            Image(systemName: "arrow.right").font(.system(size: 9)).foregroundColor(.gray.opacity(0.4)).padding(.horizontal, 4)
            hintPill(icon: "2.circle.fill", label: "Chase", color: .coral)
            Image(systemName: "arrow.right").font(.system(size: 9)).foregroundColor(.gray.opacity(0.4)).padding(.horizontal, 4)
            hintPill(icon: "3.circle.fill", label: "Remove", color: .gray)
            Spacer()
            hintPill(icon: "hand.draw.fill", label: "Hold → PSA grade", color: .deepNavy)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.white)
        .overlay(Divider(), alignment: .bottom)
    }

    private func hintPill(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11)).foregroundColor(color)
            Text(label).font(.custom("DMSans-Regular", size: 11)).foregroundColor(.gray)
        }
    }

    // MARK: - Category picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(CollectibleCategory.allCases, id: \.self) { cat in
                    Button { withAnimation(.easeOut(duration: 0.15)) { selectedCategory = cat } } label: {
                        HStack(spacing: 7) {
                            Image(systemName: cat.icon).font(.system(size: 13))
                            Text(cat.rawValue).font(.custom("DMSans-Medium", size: 14))
                        }
                        .foregroundColor(selectedCategory == cat ? .white : .deepNavy)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(selectedCategory == cat ? Color.oceanTeal : Color.mist)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
        }
        .background(Color.white)
        .overlay(Divider(), alignment: .bottom)
    }
}

// MARK: - Pokémon collection content

struct PokemonCollectionContent: View {
    @Binding var showSetBrowser: Bool
    @Binding var showSearch: Bool
    @Binding var triggerShare: Bool
    @State private var showGallery = false

    // Collapses this view's three sheets into one presentation (see the .sheet below)
    private enum PokemonSheet: Identifiable {
        case shareOptions, shareLink, card(UUID)
        var id: String {
            switch self {
            case .shareOptions:   return "shareOptions"
            case .shareLink:      return "shareLink"
            case .card(let uuid): return uuid.uuidString
            }
        }
    }

    private var pokemonSheet: Binding<PokemonSheet?> {
        Binding(
            get: {
                if showShareOptions          { return .shareOptions }
                if showShareSheet            { return .shareLink }
                if let card = detailCard     { return .card(card.id) }
                return nil
            },
            set: { newValue in
                switch newValue {
                case .shareOptions: showShareOptions = true;  showShareSheet = false; detailCard = nil
                case .shareLink:    showShareOptions = false; showShareSheet = true;  detailCard = nil
                case .card, .none:
                    // .card is only ever set by tapping a card, which assigns
                    // detailCard directly; nil means the sheet was dismissed
                    showShareOptions = false; showShareSheet = false
                    if newValue == nil { detailCard = nil }
                }
            }
        )
    }

    @Query(sort: \TCGCard.addedAt, order: .reverse) private var allCards: [TCGCard]
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @State private var service = PokemonTCGService.shared
    @State private var detailCard: TCGCard? = nil
    @State private var setsExpanded = false
    @State private var showShareOptions = false
    @State private var shareListType = "owned"
    @State private var shareIncludePrice = true
    @State private var shareExcludedRarities: Set<String> = []
    @State private var shareURL: URL? = nil
    @State private var showShareSheet = false
    @State private var isCreatingShareLink = false

    private var ownedCards: [TCGCard]  { allCards.filter { $0.isOwned } }
    private var chasingCards: [TCGCard] { allCards.filter { !$0.isOwned } }
    private var collectionValue: Double { ownedCards.compactMap { $0.marketPrice }.reduce(0, +) }

    private var shareAvailableRarities: [String] {
        let cards = shareListType == "owned" ? ownedCards : chasingCards
        return Array(Set(cards.compactMap { $0.rarity })).sorted { rarityOrder($0) < rarityOrder($1) }
    }

    private func rarityOrder(_ r: String) -> Int {
        let l = r.lowercased()
        if l == "common" { return 0 }
        if l == "uncommon" { return 1 }
        if l == "rare" { return 2 }
        if l.hasPrefix("rare holo") { return 3 }
        if l.contains("double rare") { return 4 }
        if l.contains("ultra rare") || l.contains("rare ultra") { return 5 }
        if l.contains("rare ex") || l.contains("rare gx") || l.contains("rare v") { return 5 }
        if l.contains("illustration rare") { return 6 }
        if l.contains("hyper") || l.contains("secret") { return 7 }
        if l.contains("rare") { return 4 }
        return 8
    }

    private var touchedSets: [(setId: String, setName: String, owned: Int, total: Int)] {
        let grouped = Dictionary(grouping: allCards) { $0.setId }
        return grouped.keys.compactMap { setId -> (String, String, Int, Int)? in
            let cards = grouped[setId] ?? []
            guard let first = cards.first else { return nil }
            let setTotal = service.allSets.first(where: { $0.id == setId })?.printedTotal ?? 0
            let owned = cards.filter { $0.isOwned }.count
            return (setId, first.setName, owned, setTotal)
        }
        .sorted { $0.2 > $1.2 }
    }

    var body: some View {
        // VStack (not Group) is a stable anchor — Group distributes modifiers to each
        // child, so a content swap re-anchors the presentation and resets its state
        // (which made the card detail sheet open and immediately close).
        VStack(spacing: 0) {
            if !allCards.isEmpty { statsStrip }
            // yourSetsSection hidden for now — set progress lives in the gallery
            if allCards.isEmpty { emptyState } else { browseButton }
            if !allCards.isEmpty { galleryShareButtons }
            if !allCards.isEmpty { allOwnedSection }
        }
        .fullScreenCover(isPresented: $showGallery) {
            CollectionShowcaseView(category: .pokemon)
        }
        .task { await service.fetchSets() }
        .onChange(of: triggerShare) { _, val in
            if val { shareExcludedRarities = []; showShareOptions = true; triggerShare = false }
        }
        // One sheet, not three siblings. Stacked presentation modifiers on the same
        // view destabilise each other — with a fullScreenCover among them, opening
        // a sheet inside the cover would reset the cover's state and close it again.
        .sheet(item: pokemonSheet) { which in
            switch which {
            case .shareOptions:
                CollectionShareOptionsSheet(
                    ownedCards: ownedCards,
                    chasingCards: chasingCards,
                    availableRarities: shareAvailableRarities,
                    listType: $shareListType,
                    includePrice: $shareIncludePrice,
                    excludedRarities: $shareExcludedRarities
                ) {
                    showShareOptions = false
                    Task { await createAndShareCollection(type: shareListType, includePrice: shareIncludePrice) }
                }
                .presentationDetents([.medium])
            case .shareLink:
                if let url = shareURL { ShareSheet(items: [url]) }
            case .card(let id):
                if let card = allCards.first(where: { $0.id == id }) {
                    TCGCardDetailSheet(card: card)
                }
            }
        }
        .overlay {
            if isCreatingShareLink {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView().tint(.white).scaleEffect(1.2)
                        Text("Creating link…")
                            .font(.custom("DMSans-Medium", size: 14))
                            .foregroundColor(.white)
                    }
                    .padding(28)
                    .background(Color.deepNavy.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private var statsStrip: some View {
        HStack(spacing: 0) {
            statCell(value: "\(ownedCards.count)", label: "Owned")
            Divider().frame(height: 36)
            statCell(value: "\(chasingCards.count)", label: "Chasing")
            Divider().frame(height: 36)
            statCell(value: "\(touchedSets.count)", label: "Sets")
            if collectionValue > 0 {
                Divider().frame(height: 36)
                statCell(value: "$\(String(format: "%.0f", collectionValue))", label: "Est. Value")
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .overlay(Divider(), alignment: .bottom)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.custom("DMSans-Medium", size: 20)).foregroundColor(.deepNavy)
            Text(label).font(.custom("DMSans-Regular", size: 11)).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }

    private var yourSetsSection: some View {
        let visibleSets = setsExpanded ? Array(touchedSets.prefix(3)) : []
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("YOUR SETS")
                    .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).tracking(0.5)
                Spacer()
                Button { showSetBrowser = true } label: {
                    Text("Browse all").font(.custom("DMSans-Medium", size: 13)).foregroundColor(.oceanTeal)
                }
            }
            .padding(.horizontal, 20)

            ForEach(visibleSets, id: \.setId) { item in
                NavigationLink(destination: TCGSetDetailView(setId: item.setId, setName: item.setName)) {
                    setRow(item: item)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }

            Button {
                withAnimation(.easeOut(duration: 0.2)) { setsExpanded.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Text(setsExpanded ? "Show less" : "Show top 3 sets")
                        .font(.custom("DMSans-Medium", size: 13)).foregroundColor(.oceanTeal)
                    Image(systemName: setsExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11)).foregroundColor(.oceanTeal)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 20)
    }

    private func setRow(item: (setId: String, setName: String, owned: Int, total: Int)) -> some View {
        let progress: Double = item.total > 0 ? Double(item.owned) / Double(item.total) : 0
        let set = service.allSets.first(where: { $0.id == item.setId })

        return HStack(spacing: 14) {
            Group {
                if let url = set?.symbolURL {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase { img.resizable().aspectRatio(contentMode: .fit) }
                        else { Color.clear }
                    }
                } else {
                    Image(systemName: "sparkles").font(.system(size: 20)).foregroundColor(.oceanTeal.opacity(0.4))
                }
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.setName).font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy)
                    Spacer()
                    Text("\(item.owned)\(item.total > 0 ? "/\(item.total)" : "") cards")
                        .font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.mist).frame(height: 5)
                        RoundedRectangle(cornerRadius: 3).fill(Color.oceanTeal)
                            .frame(width: geo.size.width * progress, height: 5)
                    }
                }
                .frame(height: 5)
            }
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.gray.opacity(0.3))
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.07), lineWidth: 0.5))
    }

    private var browseButton: some View {
        HStack(spacing: 10) {
            Button { showSetBrowser = true } label: {
                HStack(spacing: 7) {
                    Image(systemName: "rectangle.grid.2x2")
                    Text("Browse Sets").font(.custom("DMSans-Medium", size: 15))
                }
                .foregroundColor(.oceanTeal)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color.oceanTeal.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            Button { showSearch = true } label: {
                HStack(spacing: 7) {
                    Image(systemName: "sparkles")
                    Text("Browse Pokémon").font(.custom("DMSans-Medium", size: 15))
                }
                .foregroundColor(.oceanTeal)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color.oceanTeal.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 20).padding(.top, 20)
    }

    private var galleryShareButtons: some View {
        HStack(spacing: 10) {
            Button {
                showGallery = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2.fill")
                    Text("Gallery").font(.custom("DMSans-Medium", size: 15))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color.oceanTeal)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button {
                shareExcludedRarities = []
                showShareOptions = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Cards").font(.custom("DMSans-Medium", size: 15))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color.oceanTeal)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 20).padding(.top, 10)
    }

    private var allOwnedSection: some View {
        let owned = ownedCards.sorted { ($0.setName, $0.number) < ($1.setName, $1.number) }
        let chasing = chasingCards.sorted { ($0.setName, $0.number) < ($1.setName, $1.number) }
        let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

        return VStack(alignment: .leading, spacing: 12) {
            if !owned.isEmpty {
                Text("ALL OWNED")
                    .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).tracking(0.5)
                    .padding(.horizontal, 20)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(owned) { card in cardThumb(card) }
                }
                .padding(.horizontal, 16)
            }
            if !chasing.isEmpty {
                Text("CHASING")
                    .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.coral).tracking(0.5)
                    .padding(.horizontal, 20)
                    .padding(.top, owned.isEmpty ? 0 : 16)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(chasing) { card in cardThumb(card) }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 24)
    }

    private func cardThumb(_ card: TCGCard) -> some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: card.imageURL)) { phase in
                    if case .success(let img) = phase {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        ZStack { Color.mist; ProgressView().scaleEffect(0.5) }
                    }
                }
                .aspectRatio(0.72, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                if let grade = card.isOwned ? card.psaGrade : card.psaTargetGrade {
                    Text(card.isOwned ? "PSA \(grade)" : "\(grade)+")
                        .font(.custom("DMMono-Regular", size: 7))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(psaBadgeColor(grade))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .padding(3)
                }
            }
            .shadow(color: card.isOwned ? Color.oceanTeal.opacity(0.15) : .clear, radius: 4, y: 2)

            Text(card.name)
                .font(.custom("DMSans-Medium", size: 9))
                .foregroundColor(.deepNavy)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
            Text(card.setName)
                .font(.custom("DMSans-Regular", size: 8))
                .foregroundColor(.gray)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .onTapGesture { cycleTCGCard(card) }
        .onLongPressGesture { detailCard = card }
    }

    private func createAndShareCollection(type: String, includePrice: Bool) async {
        isCreatingShareLink = true
        defer { isCreatingShareLink = false }

        let baseCards = type == "owned" ? ownedCards : chasingCards
        let cards = shareExcludedRarities.isEmpty ? baseCards : baseCards.filter {
            guard let r = $0.rarity else { return true }
            return !shareExcludedRarities.contains(r)
        }
        guard !cards.isEmpty, let userId = authService.userId else { return }

        struct CardPayload: Encodable {
            let id: String
            let name: String
            let set_name: String
            let number: String
            let image_url: String
            let large_image_url: String
            let rarity: String?
            let market_price: Double?
        }
        struct CollectionPayload: Encodable {
            let owner_id: String
            let title: String
            let list_type: String
            let cards: [CardPayload]
        }
        struct IDRow: Decodable { let id: String }

        let payload = CollectionPayload(
            owner_id: userId.uuidString,
            title: type == "owned" ? "My Pokémon Collection" : "My Chase List",
            list_type: type,
            cards: cards.map { card in
                CardPayload(
                    id: card.pokemonId,
                    name: card.name,
                    set_name: card.setName,
                    number: card.number,
                    image_url: card.imageURL,
                    large_image_url: card.largeImageURL,
                    rarity: card.rarity,
                    market_price: includePrice ? card.marketPrice : nil
                )
            }
        )

        do {
            let result = try await SupabaseManager.shared.client
                .from("shared_collections")
                .insert(payload)
                .select("id")
                .single()
                .execute()
            let row = try JSONDecoder().decode(IDRow.self, from: result.data)
            if let url = URL(string: "https://orca-web-three.vercel.app?collection=\(row.id)") {
                shareURL = url
                showShareSheet = true
            }
        } catch {
            print("❌ Failed to create shared collection: \(error)")
        }
    }

    private func psaBadgeColor(_ grade: Int) -> Color {
        switch grade {
        case 10: return Color(red: 0.85, green: 0.6, blue: 0.1)
        case 9:  return Color(red: 0.2, green: 0.6, blue: 0.3)
        case 8:  return Color(red: 0.1, green: 0.5, blue: 0.8)
        default: return .gray
        }
    }

    private func cycleTCGCard(_ card: TCGCard) {
        if card.isOwned {
            card.isOwned = false
            try? modelContext.save()
            if let userId = authService.userId {
                Task { await SupabaseSyncService.shared.pushTCGCard(card, userId: userId) }
            }
        } else {
            let id = card.id
            modelContext.delete(card)
            try? modelContext.save()
            Task { await SupabaseSyncService.shared.deleteTCGCard(id: id) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)
            Image(systemName: "sparkles").font(.system(size: 48)).foregroundColor(.oceanTeal.opacity(0.25))
            VStack(spacing: 8) {
                Text("Start your Pokémon collection")
                    .font(.custom("DMSans-Medium", size: 20)).foregroundColor(.deepNavy)
                Text("Browse a set and tap cards you own.\nChase the ones you're hunting.")
                    .font(.custom("DMSans-Regular", size: 14)).foregroundColor(.gray).multilineTextAlignment(.center)
            }
            Button { showSetBrowser = true } label: {
                Text("Browse Sets").font(.custom("DMSans-Medium", size: 16)).foregroundColor(.white)
                    .padding(.horizontal, 32).padding(.vertical, 13)
                    .background(Color.oceanTeal).clipShape(Capsule())
            }
        }
        .padding(.horizontal, 40).padding(.top, 20)
    }
}

// MARK: - Collection Share Options Sheet

struct CollectionShareOptionsSheet: View {
    let ownedCards: [TCGCard]
    let chasingCards: [TCGCard]
    let availableRarities: [String]
    @Binding var listType: String
    @Binding var includePrice: Bool
    @Binding var excludedRarities: Set<String>
    let onShare: () -> Void

    private var activeCards: [TCGCard] { listType == "owned" ? ownedCards : chasingCards }
    private var filteredCount: Int {
        excludedRarities.isEmpty ? activeCards.count : activeCards.filter {
            guard let r = $0.rarity else { return true }
            return !excludedRarities.contains(r)
        }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 4).padding(.top, 12)

            Text("Share Collection")
                .font(.custom("DMSans-Medium", size: 18)).foregroundColor(.deepNavy)
                .padding(.top, 16)

            ScrollView {
                VStack(spacing: 20) {
                    // List type picker
                    HStack(spacing: 8) {
                        listTypeButton(label: "Owned (\(ownedCards.count))", value: "owned")
                        listTypeButton(label: "Chase List (\(chasingCards.count))", value: "chasing")
                    }

                    // Rarity filter
                    if !availableRarities.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Include rarities")
                                    .font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy)
                                Spacer()
                                if !excludedRarities.isEmpty {
                                    Button("Select all") { excludedRarities = [] }
                                        .font(.custom("DMSans-Regular", size: 13)).foregroundColor(.oceanTeal)
                                }
                            }
                            FlowLayout(spacing: 8) {
                                ForEach(availableRarities, id: \.self) { rarity in
                                    rarityChip(rarity)
                                }
                            }
                        }
                    }

                    // Include price toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Include market prices")
                                .font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy)
                            Text("Shows estimated card values on the shared page")
                                .font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                        }
                        Spacer()
                        Toggle("", isOn: $includePrice).labelsHidden().tint(.oceanTeal)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)
            }

            Button {
                onShare()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text(filteredCount == activeCards.count
                         ? "Share \(filteredCount) cards"
                         : "Share \(filteredCount) of \(activeCards.count) cards")
                }
                .font(.custom("DMSans-Medium", size: 16)).foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(filteredCount > 0 ? Color.oceanTeal : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(filteredCount == 0)
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 32)
        }
        .background(Color.pearl)
    }

    private func rarityChip(_ rarity: String) -> some View {
        let excluded = excludedRarities.contains(rarity)
        return Button {
            if excluded { excludedRarities.remove(rarity) } else { excludedRarities.insert(rarity) }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: excluded ? "circle" : "checkmark.circle.fill")
                    .font(.system(size: 12))
                Text(rarity).font(.custom("DMSans-Regular", size: 13))
            }
            .foregroundColor(excluded ? .gray : .deepNavy)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(excluded ? Color.mist.opacity(0.5) : Color.mist)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(excluded ? Color.clear : Color.oceanTeal.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: excluded)
    }

    private func listTypeButton(label: String, value: String) -> some View {
        Button { listType = value } label: {
            Text(label)
                .font(.custom("DMSans-Medium", size: 14))
                .foregroundColor(listType == value ? .white : .deepNavy)
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(listType == value ? Color.oceanTeal : Color.mist)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// Simple flow layout for wrapping chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 { y += rowHeight + spacing; x = 0; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX { y += rowHeight + spacing; x = bounds.minX; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
