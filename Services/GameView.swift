//
//  GameView.swift
//  Orca

import SwiftUI
import SwiftData

// MARK: - Collection content

struct GameCollectionContent: View {
    @Query private var allGames: [GameItem]
    @Environment(\.modelContext) private var modelContext

    @State private var showSearch = false
    @State private var showBrowse = false
    @State private var showGallery = false
    @State private var detailGame: GameItem? = nil

    private var ownedCount:    Int { allGames.filter { $0.isOwned }.count }
    private var wishlistCount: Int { allGames.filter { !$0.isOwned }.count }

    // Group all games (owned + wishlist) by the console the user plays it on
    private var platformGroups: [(platform: String, games: [GameItem])] {
        let grouped = Dictionary(grouping: allGames) { game -> String in
            let p = game.primaryPlatform
            return p.isEmpty ? (game.platformNames.first ?? "Other") : p
        }
        return grouped.keys.sorted().map { key in
            (platform: key, games: grouped[key]!.sorted { $0.name < $1.name })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !allGames.isEmpty { statsStrip }
            if !allGames.isEmpty { actionButtons }
            ForEach(platformGroups, id: \.platform) { group in
                gameRow(group.platform, games: group.games)
            }
            if allGames.isEmpty { emptyState }
        }
        .sheet(isPresented: $showSearch) { GameSearchView() }
        .sheet(isPresented: $showBrowse) { GameBrowseView() }
        .sheet(item: $detailGame) { GameDetailSheet(game: $0) }
        .fullScreenCover(isPresented: $showGallery) { CollectionShowcaseView(category: .games) }
    }

    // MARK: Stats

    private var statsStrip: some View {
        HStack(spacing: 0) {
            statCell(value: "\(ownedCount)",                    label: "Owned")
            Divider().frame(height: 36)
            statCell(value: "\(wishlistCount)",                 label: "Wishlist")
            Divider().frame(height: 36)
            statCell(value: "\(platformGroups.count)",          label: "Consoles")
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

    // MARK: Horizontal scroll row per console

    private func gameRow(_ platform: String, games: [GameItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(platform.uppercased())
                    .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).tracking(0.5)
                Text("· \(games.count)").font(.custom("DMMono-Regular", size: 11)).foregroundColor(.gray.opacity(0.5))
            }
            .padding(.horizontal, 20).padding(.top, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(games) { game in
                        gameCard(game).onTapGesture { detailGame = game }
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 4)
            }
        }
    }

    private func gameCard(_ game: GameItem) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            AsyncImage(url: URL(string: game.coverURL)) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: ZStack { Color.mist; Text("🎮").font(.system(size: 24)) }
                }
            }
            .frame(width: 90, height: 122)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(game.isOwned ? Color.oceanTeal : Color.coral, lineWidth: 1.5)
            )

            Text(game.name)
                .font(.custom("DMSans-Medium", size: 11))
                .foregroundColor(.deepNavy)
                .lineLimit(2)
                .frame(width: 90, alignment: .leading)
        }
    }

    // MARK: Empty / buttons

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 44))
                .foregroundColor(.oceanTeal.opacity(0.25))
            Text("Start your game library")
                .font(.custom("DMSans-Medium", size: 18))
                .foregroundColor(.deepNavy)
            Text("Search for titles or browse by console")
                .font(.custom("DMSans-Regular", size: 14))
                .foregroundColor(.gray)
            actionButtons
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button { showSearch = true } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "magnifyingglass")
                        Text("Search Games").font(.custom("DMSans-Medium", size: 15))
                            .lineLimit(1).minimumScaleFactor(0.85)
                    }
                    .foregroundColor(.oceanTeal)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.oceanTeal.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                Button { showBrowse = true } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "list.bullet")
                        Text("Browse Consoles").font(.custom("DMSans-Medium", size: 15))
                            .lineLimit(1).minimumScaleFactor(0.85)
                    }
                    .foregroundColor(.oceanTeal)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.oceanTeal.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            if !allGames.isEmpty {
                Button { showGallery = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.grid.2x2.fill")
                        Text("Gallery").font(.custom("DMSans-Medium", size: 15))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.oceanTeal)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 6)
    }
}

// MARK: - Search

struct GameSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Query private var allGames: [GameItem]

    @State private var query = ""
    @State private var service = IGDBService.shared
    @State private var localStatus: [Int: String] = [:]
    @State private var platformFilter: IGDBPlatform? = nil   // nil = All
    @FocusState private var searchFocused: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                platformFilterRow
                Divider()
                if service.searchResults.isEmpty && !service.isSearching {
                    emptyPrompt
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(service.searchResults) { game in searchCard(game) }
                        }
                        .padding(.horizontal, 16).padding(.bottom, 30)
                    }
                }
            }
            .background(Color.pearl.ignoresSafeArea())
            .navigationTitle("Search Games")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.oceanTeal)
                }
            }
            .onAppear { searchFocused = true }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundColor(.gray)
            TextField("Search games...", text: $query)
                .font(.custom("DMSans-Regular", size: 15))
                .focused($searchFocused)
                .onSubmit { runSearch() }
                .onChange(of: query) { _, val in if val.isEmpty { service.searchResults = [] } }
                .submitLabel(.search)
            if service.isSearching {
                ProgressView().scaleEffect(0.8).tint(.oceanTeal)
            } else if !query.isEmpty {
                Button { query = ""; service.searchResults = [] } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.mist)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 10)
    }

    // Compact console filter so user can narrow results to a platform
    private var platformFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterChip("All", selected: platformFilter == nil) { platformFilter = nil; runSearch() }
                ForEach(IGDBPlatform.curated) { p in
                    filterChip(p.short, selected: platformFilter?.id == p.id) {
                        platformFilter = p; runSearch()
                    }
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 10)
        }
    }

    private func filterChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.custom("DMSans-Medium", size: 12))
                .foregroundColor(selected ? .white : .deepNavy)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(selected ? Color.oceanTeal : Color.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(selected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func runSearch() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        Task { await service.search(query: query, platformId: platformFilter?.id) }
    }

    private func effectiveStatus(for igdbId: Int) -> String? {
        if let local = localStatus[igdbId] { return local.isEmpty ? nil : local }
        if allGames.first(where: { $0.igdbId == igdbId &&  $0.isOwned }) != nil { return "owned" }
        if allGames.first(where: { $0.igdbId == igdbId && !$0.isOwned }) != nil { return "want" }
        return nil
    }

    private func cycleGame(_ game: IGDBGame) {
        // primary platform = selected filter, or first in the game's list
        let primary = platformFilter?.short ?? game.platformNames.first ?? ""
        switch effectiveStatus(for: game.id) {
        case nil:
            localStatus[game.id] = "owned"
            let item = GameItem(igdbId: game.id, name: game.name,
                                coverURL: game.coverURL?.absoluteString ?? "",
                                genreNames: game.genreNames, platformNames: game.platformNames,
                                rating: game.rating, releaseYear: game.releaseYear,
                                summary: game.summary, isOwned: true,
                                primaryPlatform: primary)
            modelContext.insert(item)
            try? modelContext.save()
            if let userId = authService.userId {
                Task { await SupabaseSyncService.shared.pushGameItem(item, userId: userId) }
            }
        case "owned":
            localStatus[game.id] = "want"
            if let e = allGames.first(where: { $0.igdbId == game.id }) {
                e.isOwned = false
                try? modelContext.save()
                if let userId = authService.userId {
                    Task { await SupabaseSyncService.shared.pushGameItem(e, userId: userId) }
                }
            }
        default:
            localStatus[game.id] = ""
            if let e = allGames.first(where: { $0.igdbId == game.id }) {
                let id = e.id
                modelContext.delete(e)
                try? modelContext.save()
                Task { await SupabaseSyncService.shared.deleteGameItem(id: id) }
            }
        }
    }

    private func searchCard(_ game: IGDBGame) -> some View {
        let status  = effectiveStatus(for: game.id)
        let isOwned = status == "owned"
        let accent: Color = isOwned ? .oceanTeal : .coral

        return VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: game.coverURL) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: ZStack { Color.mist; Text("🎮").font(.system(size: 22)) }
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(0.72, contentMode: .fit)
                .clipped()

                if status != nil {
                    Image(systemName: isOwned ? "checkmark.circle.fill" : "heart.fill")
                        .font(.system(size: 14)).foregroundColor(accent)
                        .padding(5).background(Color.white).clipShape(Circle()).padding(5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(status == nil ? Color.clear : accent, lineWidth: 2))

            VStack(alignment: .leading, spacing: 3) {
                Text(game.name)
                    .font(.custom("DMSans-Medium", size: 10)).foregroundColor(.deepNavy).lineLimit(2)
                // Platform chips — shows where the game is available
                if !game.platformNames.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 3) {
                            ForEach(game.platformNames.prefix(4), id: \.self) { p in
                                Text(p)
                                    .font(.custom("DMMono-Regular", size: 7))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4).padding(.vertical, 2)
                                    .background(Color.deepNavy.opacity(0.55))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .padding(6).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        .onTapGesture { cycleGame(game) }
    }

    private var emptyPrompt: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "gamecontroller").font(.system(size: 40)).foregroundColor(.oceanTeal.opacity(0.25))
            Text("Search for a game").font(.custom("DMSans-Medium", size: 17)).foregroundColor(.deepNavy)
            Text("Filter by console first to get the right version")
                .font(.custom("DMSans-Regular", size: 13)).foregroundColor(.gray).multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 30)
    }
}

// MARK: - Browse by console

struct GameBrowseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Query private var allGames: [GameItem]

    @State private var service = IGDBService.shared
    @State private var selectedPlatform: IGDBPlatform = IGDBPlatform.curated[0]
    @State private var localStatus: [Int: String] = [:]
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                consolePicker
                searchBar
                Divider()
                gameGrid
            }
            .background(Color.pearl.ignoresSafeArea())
            .navigationTitle("Browse by Console")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.oceanTeal)
                }
            }
            .task { await service.fetchGames(platformId: selectedPlatform.id) }
            .onChange(of: selectedPlatform.id) { _, _ in
                searchText = ""
                Task { await service.fetchGames(platformId: selectedPlatform.id) }
            }
        }
    }

    private var consolePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(IGDBPlatform.curated) { platform in
                    let selected = selectedPlatform.id == platform.id
                    Button { selectedPlatform = platform } label: {
                        Text(platform.short)
                            .font(.custom("DMSans-Medium", size: 13))
                            .foregroundColor(selected ? .white : .deepNavy)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(selected ? Color.oceanTeal : Color.white)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(selected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .background(Color.white)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 13)).foregroundColor(.gray)
            TextField("Search on \(selectedPlatform.short)…", text: $searchText)
                .font(.custom("DMSans-Regular", size: 14))
                .focused($searchFocused)
                .onSubmit { Task { await service.fetchGames(platformId: selectedPlatform.id, query: searchText) } }
                .submitLabel(.search)
                .onChange(of: searchText) { _, val in
                    if val.isEmpty { Task { await service.fetchGames(platformId: selectedPlatform.id) } }
                }
            if service.isBrowsing {
                ProgressView().scaleEffect(0.7).tint(.oceanTeal)
            } else if !searchText.isEmpty {
                Button { searchText = ""; Task { await service.fetchGames(platformId: selectedPlatform.id) } } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.mist)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Color.white)
    }

    private var gameGrid: some View {
        Group {
            if service.isBrowsing {
                VStack { Spacer(); ProgressView(); Spacer() }.frame(maxWidth: .infinity)
            } else if service.browseResults.isEmpty {
                VStack { Spacer(); Text("No results").foregroundColor(.gray); Spacer() }.frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(service.browseResults) { game in browseCard(game) }
                    }
                    .padding(14).padding(.bottom, 30)
                }
            }
        }
    }

    private func effectiveStatus(for igdbId: Int) -> String? {
        if let local = localStatus[igdbId] { return local.isEmpty ? nil : local }
        if allGames.first(where: { $0.igdbId == igdbId &&  $0.isOwned }) != nil { return "owned" }
        if allGames.first(where: { $0.igdbId == igdbId && !$0.isOwned }) != nil { return "want" }
        return nil
    }

    private func cycleGame(_ game: IGDBGame) {
        switch effectiveStatus(for: game.id) {
        case nil:
            localStatus[game.id] = "owned"
            let item = GameItem(igdbId: game.id, name: game.name,
                                coverURL: game.coverURL?.absoluteString ?? "",
                                genreNames: game.genreNames, platformNames: game.platformNames,
                                rating: game.rating, releaseYear: game.releaseYear,
                                summary: game.summary, isOwned: true,
                                primaryPlatform: selectedPlatform.short)
            modelContext.insert(item)
            try? modelContext.save()
            if let userId = authService.userId {
                Task { await SupabaseSyncService.shared.pushGameItem(item, userId: userId) }
            }
        case "owned":
            localStatus[game.id] = "want"
            if let e = allGames.first(where: { $0.igdbId == game.id }) {
                e.isOwned = false
                try? modelContext.save()
                if let userId = authService.userId {
                    Task { await SupabaseSyncService.shared.pushGameItem(e, userId: userId) }
                }
            }
        default:
            localStatus[game.id] = ""
            if let e = allGames.first(where: { $0.igdbId == game.id }) {
                let id = e.id
                modelContext.delete(e)
                try? modelContext.save()
                Task { await SupabaseSyncService.shared.deleteGameItem(id: id) }
            }
        }
    }

    private func browseCard(_ game: IGDBGame) -> some View {
        let status  = effectiveStatus(for: game.id)
        let isOwned = status == "owned"
        let accent: Color = isOwned ? .oceanTeal : .coral

        return VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: game.coverURL) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: ZStack { Color.mist; Text("🎮").font(.system(size: 20)) }
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(0.72, contentMode: .fit)
                .clipped()

                if status != nil {
                    Image(systemName: isOwned ? "checkmark.circle.fill" : "heart.fill")
                        .font(.system(size: 14)).foregroundColor(accent)
                        .padding(5).background(Color.white).clipShape(Circle()).padding(5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(status == nil ? Color.clear : accent, lineWidth: 2))

            VStack(alignment: .leading, spacing: 2) {
                Text(game.name)
                    .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.deepNavy).lineLimit(2)
                if let year = game.releaseYear {
                    Text("\(year)").font(.custom("DMMono-Regular", size: 9)).foregroundColor(.gray)
                }
                if let r = game.rating {
                    Text(String(format: "★ %.1f", r))
                        .font(.custom("DMSans-Medium", size: 9)).foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        .onTapGesture { cycleGame(game) }
    }
}

// MARK: - Detail sheet

struct GameDetailSheet: View {
    let game: GameItem
    // Set when shown as an in-place overlay instead of a modal —
    // @Environment(\.dismiss) is inert outside a presentation.
    var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Cover hero
                    HStack {
                        Spacer()
                        AsyncImage(url: URL(string: game.coverURL)) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().scaledToFit()
                                    .frame(width: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                            default:
                                RoundedRectangle(cornerRadius: 12).fill(Color.mist)
                                    .frame(width: 160, height: 220)
                                    .overlay(Text("🎮").font(.system(size: 40)))
                            }
                        }
                        Spacer()
                    }
                    .padding(.top, 24).padding(.bottom, 20)

                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(game.name)
                                .font(.custom("DMSans-Medium", size: 22)).foregroundColor(.deepNavy)
                            HStack(spacing: 10) {
                                if let year = game.releaseYear {
                                    Text("\(year)").font(.custom("DMMono-Regular", size: 13)).foregroundColor(.gray)
                                }
                                if let r = game.rating {
                                    Text(String(format: "★ %.1f / 10", r))
                                        .font(.custom("DMSans-Medium", size: 13)).foregroundColor(.orange)
                                }
                            }
                        }

                        Text(game.isOwned ? "✓ In Your Library" : "♥ On Your Wishlist")
                            .font(.custom("DMSans-Medium", size: 13))
                            .foregroundColor(game.isOwned ? .oceanTeal : .coral)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background((game.isOwned ? Color.oceanTeal : Color.coral).opacity(0.1))
                            .clipShape(Capsule())

                        if !game.genreNames.isEmpty {
                            infoRow("Genres", value: game.genreNames.joined(separator: ", "))
                        }
                        if !game.platformNames.isEmpty {
                            infoRow("Platforms", value: game.platformNames.joined(separator: " · "))
                        }

                        if let summary = game.summary, !summary.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("ABOUT").font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).tracking(0.5)
                                Text(summary)
                                    .font(.custom("DMSans-Regular", size: 14)).foregroundColor(.deepNavy)
                                    .lineLimit(8)
                            }
                        }

                        // Toggle owned/wishlist
                        Button {
                            game.isOwned.toggle()
                            try? modelContext.save()
                            if let userId = authService.userId {
                                Task { await SupabaseSyncService.shared.pushGameItem(game, userId: userId) }
                            }
                        } label: {
                            Text(game.isOwned ? "Move to Wishlist" : "Mark as Owned")
                                .font(.custom("DMSans-Medium", size: 14)).foregroundColor(.oceanTeal)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color.oceanTeal.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)

                        Button {
                            let id = game.id
                            modelContext.delete(game)
                            try? modelContext.save()
                            Task { await SupabaseSyncService.shared.deleteGameItem(id: id) }
                            close()
                        } label: {
                            Text("Remove from Collection")
                                .font(.custom("DMSans-Medium", size: 14)).foregroundColor(.red)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color.red.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20).padding(.bottom, 30)
                }
            }
            .background(Color.pearl.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { close() }.foregroundColor(.oceanTeal)
                }
            }
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).tracking(0.5)
            Text(value)
                .font(.custom("DMSans-Regular", size: 14)).foregroundColor(.deepNavy)
        }
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }
}
