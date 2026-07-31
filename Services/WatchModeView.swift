//
//  WatchModeView.swift
//  Orca
//

import SwiftUI
import SwiftData

struct WatchModeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService
    @Query(sort: \WatchlistItem.createdAt, order: .reverse) private var items: [WatchlistItem]

    @State private var selectedTab: Tab = .queue
    @State private var showAddSheet = false
    @State private var ratingItem: WatchlistItem? = nil
    @State private var editItem: WatchlistItem? = nil
    @State private var addedToast = false
    @State private var tmdb = TMDBService.shared
    @State private var detailItem: WatchlistItem? = nil
    @State private var detailTMDBItem: TMDBItem? = nil
    @State private var detailBookCoverURL: URL? = nil
    @State private var selectedGenre: TMDBService.DiscoverGenre? = nil
    @State private var completedTypeFilter: String? = nil

    enum Tab { case queue, completed, discover }

    private var watchingItems: [WatchlistItem] { items.filter { $0.status == "watching" } }
    private var queuedItems: [WatchlistItem]   { items.filter { $0.status == "queued" } }
    private var completedItems: [WatchlistItem] {
        items.filter { $0.status == "completed" }
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
    }
    private var filteredCompletedItems: [WatchlistItem] {
        guard let filter = completedTypeFilter else { return completedItems }
        return completedItems.filter { $0.itemType == filter }
    }

    private var queuedShows: [WatchlistItem]  { queuedItems.filter { $0.itemType == "show" } }
    private var queuedMovies: [WatchlistItem] { queuedItems.filter { $0.itemType == "movie" } }
    private var queuedBooks: [WatchlistItem]  { queuedItems.filter { $0.itemType == "book" } }

    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }
    private var completedThisYear: [WatchlistItem] {
        completedItems.filter {
            guard let d = $0.completedAt else { return false }
            return Calendar.current.component(.year, from: d) == currentYear
        }
    }
    private var avgRating: Double? {
        let rated = completedThisYear.compactMap { $0.rating }
        guard !rated.isEmpty else { return nil }
        return Double(rated.reduce(0, +)) / Double(rated.count)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabPicker

                if selectedTab == .queue {
                    queueContent
                } else if selectedTab == .completed {
                    completedContent
                } else {
                    discoverContent
                }
            }
            .background(Color.pearl.ignoresSafeArea())
            .task(id: items.map(\.id)) {
                let all = items.map { (title: $0.title, type: $0.itemType == "show" ? "tv" : $0.itemType) }
                await tmdb.ensurePosters(for: all)
            }
            .navigationTitle("Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.oceanTeal)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus").font(.system(size: 13, weight: .medium))
                            Text("Add Media").font(.custom("DMSans-Medium", size: 14))
                        }
                        .foregroundColor(.oceanTeal)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddWatchItemSheet { title, type, service, season in
                let item = WatchlistItem(title: title, itemType: type, streamingService: service, season: season)
                modelContext.insert(item)
                if let userId = authService.userId {
                    Task { await SupabaseSyncService.shared.pushWatchlistItem(item, userId: userId) }
                }
            }
        }
        .sheet(item: $ratingItem) { item in
            RateWatchItemSheet(item: item) {
                if let userId = authService.userId {
                    Task { await SupabaseSyncService.shared.pushWatchlistItem(item, userId: userId) }
                }
            } onReturnToQueue: {
                item.status = "queued"
                item.completedAt = nil
                item.rating = nil
                item.comment = nil
                item.updatedAt = Date()
                if let userId = authService.userId {
                    Task { await SupabaseSyncService.shared.pushWatchlistItem(item, userId: userId) }
                }
            } onReturnToWatching: {
                item.status = "watching"
                item.completedAt = nil
                item.updatedAt = Date()
                if let userId = authService.userId {
                    Task { await SupabaseSyncService.shared.pushWatchlistItem(item, userId: userId) }
                }
            }
        }
        .sheet(item: $editItem) { item in
            EditWatchItemSheet(item: item) {
                if let userId = authService.userId {
                    Task { await SupabaseSyncService.shared.pushWatchlistItem(item, userId: userId) }
                }
            }
        }
        .sheet(item: $detailItem) { item in
            MediaDetailSheet(
                title: item.title,
                type: item.itemType,
                existingPosterURL: tmdbPosterURL(for: item)
            )
        }
        .sheet(item: $detailTMDBItem) { item in
            MediaDetailSheet(
                title: item.title,
                type: item.watchlistType,
                existingPosterURL: item.posterURL ?? detailBookCoverURL
            )
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            tabButton(label: "Queue", icon: "bookmark.fill",
                      count: watchingItems.count + queuedItems.count, tab: .queue)
            tabButton(label: "Done", icon: "checkmark.circle.fill",
                      count: completedItems.count, tab: .completed)
            tabButton(label: "Discover", icon: "sparkles", count: 0, tab: .discover)
        }
        .padding(3)
        .background(Color.mist)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.white)
    }

    private func tabButton(label: String, icon: String, count: Int, tab: Tab) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { selectedTab = tab }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(.custom("DMSans-Medium", size: 13))
                if count > 0 {
                    Text("\(count)")
                        .font(.custom("DMMono-Regular", size: 10))
                        .foregroundColor(selectedTab == tab ? .white.opacity(0.8) : .gray)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(selectedTab == tab ? Color.white.opacity(0.2) : Color.gray.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(selectedTab == tab ? .white : .deepNavy)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selectedTab == tab ? Color.oceanTeal : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 11))
        }
    }

    // MARK: - Queue Content

    @ViewBuilder
    private var queueContent: some View {
        if watchingItems.isEmpty && queuedItems.isEmpty {
            emptyState(icon: "🎬", title: "Nothing queued yet",
                       subtitle: "Tap Add Media to add a show, movie or book")
        } else {
            List {
                // Now Watching — pinned at top
                if !watchingItems.isEmpty {
                    Section {
                        ForEach(watchingItems) { item in watchingRow(item: item) }
                    } header: {
                        Label("NOW WATCHING", systemImage: "play.circle.fill")
                            .font(.custom("DMSans-Medium", size: 11))
                            .foregroundColor(.coral)
                            .textCase(nil)
                    }
                }

                // Queue by type
                if !queuedShows.isEmpty {
                    Section {
                        ForEach(queuedShows) { item in queueRow(item: item) }
                    } header: {
                        Text("📺  SHOWS")
                            .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).textCase(nil)
                    }
                }
                if !queuedMovies.isEmpty {
                    Section {
                        ForEach(queuedMovies) { item in queueRow(item: item) }
                    } header: {
                        Text("🎬  MOVIES")
                            .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).textCase(nil)
                    }
                }
                if !queuedBooks.isEmpty {
                    Section {
                        ForEach(queuedBooks) { item in queueRow(item: item) }
                    } header: {
                        Text("📚  BOOKS")
                            .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).textCase(nil)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.pearl)
        }
    }

    // MARK: - Now Watching Row

    private func watchingRow(item: WatchlistItem) -> some View {
        HStack(spacing: 12) {
            posterThumbnail(url: tmdbPosterURL(for: item), type: item.itemType) { detailItem = item }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy).lineLimit(2)
                HStack(spacing: 6) {
                    if let service = item.streamingService { streamingPill(service: service) }
                    if let s = item.season { seasonBadge(s) }
                }
            }
            Spacer()

            Button {
                withAnimation(.spring(duration: 0.3)) {
                    item.status = "completed"
                    item.completedAt = Date()
                    item.updatedAt = Date()
                }
                if let userId = authService.userId {
                    Task { await SupabaseSyncService.shared.pushWatchlistItem(item, userId: userId) }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { ratingItem = item }
            } label: {
                ZStack {
                    Circle().fill(Color.coral.opacity(0.15)).frame(width: 32, height: 32)
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold)).foregroundColor(.coral)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                let id = item.id
                modelContext.delete(item)
                Task { await SupabaseSyncService.shared.deleteWatchlistItem(id: id) }
            } label: { Label("Delete", systemImage: "trash") }

            Button {
                item.status = "queued"
                item.updatedAt = Date()
                if let userId = authService.userId {
                    Task { await SupabaseSyncService.shared.pushWatchlistItem(item, userId: userId) }
                }
            } label: { Label("Back to Queue", systemImage: "arrow.uturn.left") }
            .tint(.oceanTeal)
        }
    }

    // MARK: - Queue Row

    private func queueRow(item: WatchlistItem) -> some View {
        HStack(spacing: 12) {
            posterThumbnail(url: tmdbPosterURL(for: item), type: item.itemType) { detailItem = item }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy).lineLimit(2)
                HStack(spacing: 6) {
                    if let service = item.streamingService { streamingPill(service: service) }
                    if let s = item.season { seasonBadge(s) }
                }
            }
            Spacer()

            Button {
                withAnimation(.spring(duration: 0.3)) {
                    item.status = "watching"
                    item.updatedAt = Date()
                }
                if let userId = authService.userId {
                    Task { await SupabaseSyncService.shared.pushWatchlistItem(item, userId: userId) }
                }
            } label: {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                let id = item.id
                modelContext.delete(item)
                Task { await SupabaseSyncService.shared.deleteWatchlistItem(id: id) }
            } label: { Label("Delete", systemImage: "trash") }

            Button { editItem = item } label: { Label("Edit", systemImage: "pencil") }
            .tint(.oceanTeal)
        }
    }

    // MARK: - Completed Content

    @ViewBuilder
    private var completedContent: some View {
        if completedItems.isEmpty {
            emptyState(icon: "✅", title: "Nothing completed yet",
                       subtitle: "Mark items as done to see them here")
        } else {
            List {
                // Stats strip
                Section {
                    statsStrip
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }

                Section {
                    ForEach(filteredCompletedItems) { item in completedRow(item: item) }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.pearl)
        }
    }

    private var statsStrip: some View {
        let shows  = completedThisYear.filter { $0.itemType == "show" }.count
        let movies = completedThisYear.filter { $0.itemType == "movie" }.count
        let books  = completedThisYear.filter { $0.itemType == "book" }.count

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if shows > 0 {
                    statPill(emoji: "📺", value: "\(shows)", label: shows == 1 ? "show" : "shows",
                             type: "show", isActive: completedTypeFilter == "show")
                }
                if movies > 0 {
                    statPill(emoji: "🎬", value: "\(movies)", label: movies == 1 ? "movie" : "movies",
                             type: "movie", isActive: completedTypeFilter == "movie")
                }
                if books > 0 {
                    statPill(emoji: "📚", value: "\(books)", label: books == 1 ? "book" : "books",
                             type: "book", isActive: completedTypeFilter == "book")
                }
                if let avg = avgRating {
                    statPill(emoji: "⭐", value: String(format: "%.1f", avg), label: "avg rating",
                             type: nil, isActive: false)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func statPill(emoji: String, value: String, label: String, type: String?, isActive: Bool) -> some View {
        Button {
            guard let type else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                completedTypeFilter = completedTypeFilter == type ? nil : type
            }
        } label: {
            HStack(spacing: 6) {
                Text(emoji).font(.system(size: 14))
                VStack(alignment: .leading, spacing: 0) {
                    Text(value)
                        .font(.custom("DMSans-Medium", size: 15))
                        .foregroundColor(isActive ? .white : .deepNavy)
                    Text(label)
                        .font(.custom("DMSans-Regular", size: 11))
                        .foregroundColor(isActive ? .white.opacity(0.8) : .gray)
                }
                if isActive {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.leading, 2)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(isActive ? Color.oceanTeal : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                isActive ? Color.oceanTeal : Color.black.opacity(0.07), lineWidth: isActive ? 0 : 0.5))
            .shadow(color: isActive ? Color.oceanTeal.opacity(0.25) : .clear, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(type == nil)
    }

    // MARK: - Completed Row

    private func completedRow(item: WatchlistItem) -> some View {
        HStack(spacing: 12) {
            posterThumbnail(url: tmdbPosterURL(for: item), type: item.itemType) { detailItem = item }

            Button { ratingItem = item } label: {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.title)
                            .font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy).lineLimit(2)
                        HStack(spacing: 8) {
                            if let service = item.streamingService { streamingPill(service: service) }
                            if let rating = item.rating {
                                HStack(spacing: 2) {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: star <= rating ? "star.fill" : "star")
                                            .font(.system(size: 10))
                                            .foregroundColor(star <= rating ? .coral : .gray.opacity(0.3))
                                    }
                                }
                            }
                        }
                        if let comment = item.comment, !comment.isEmpty {
                            Text(comment)
                                .font(.custom("DMSans-Regular", size: 13)).foregroundColor(.gray).lineLimit(2)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 11)).foregroundColor(.gray.opacity(0.4))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .swipeActions(edge: .leading) {
            Button {
                item.status = "watching"
                item.completedAt = nil
                item.updatedAt = Date()
                if let userId = authService.userId {
                    Task { await SupabaseSyncService.shared.pushWatchlistItem(item, userId: userId) }
                }
            } label: { Label("Watching", systemImage: "play.circle") }
            .tint(.coral)

            Button {
                item.status = "queued"
                item.completedAt = nil
                item.rating = nil
                item.comment = nil
                item.updatedAt = Date()
                if let userId = authService.userId {
                    Task { await SupabaseSyncService.shared.pushWatchlistItem(item, userId: userId) }
                }
            } label: { Label("Re-queue", systemImage: "arrow.uturn.left") }
            .tint(.oceanTeal)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                let id = item.id
                modelContext.delete(item)
                Task { await SupabaseSyncService.shared.deleteWatchlistItem(id: id) }
            } label: { Label("Delete", systemImage: "trash") }
        }
    }

    // MARK: - Discover Content

    @ViewBuilder
    private var discoverContent: some View {
        let movies = selectedGenre == nil ? tmdb.trendingMovies : tmdb.genreMovies
        let shows  = selectedGenre == nil ? tmdb.trendingShows  : tmdb.genreShows
        let books  = selectedGenre == nil ? tmdb.trendingBooks  : tmdb.genreBooks
        let isSpinning = tmdb.isLoading || tmdb.isGenreLoading
        let movieTitle = selectedGenre == nil ? "🎬 Trending Movies" : "🎬 \(selectedGenre!.label) Movies"
        let showTitle  = selectedGenre == nil ? "📺 Trending Shows"  : "📺 \(selectedGenre!.label) Shows"
        let bookTitle  = selectedGenre == nil ? "📚 Trending Books"  : "📚 \(selectedGenre!.label) Books"

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Genre chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        genreChip(label: "All", selected: selectedGenre == nil) {
                            withAnimation(.easeOut(duration: 0.2)) { selectedGenre = nil }
                        }
                        ForEach(TMDBService.genres) { genre in
                            genreChip(label: genre.label, selected: selectedGenre == genre) {
                                withAnimation(.easeOut(duration: 0.2)) { selectedGenre = genre }
                                Task { await tmdb.fetchByGenre(genre) }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 4)

                if isSpinning {
                    HStack {
                        Spacer()
                        ProgressView().tint(.oceanTeal)
                        Spacer()
                    }
                    .frame(height: 200)
                } else {
                    if !movies.isEmpty { discoverSection(title: movieTitle, items: movies) }
                    if !shows.isEmpty  { discoverSection(title: showTitle,  items: shows) }
                    if !books.isEmpty  { discoverBookSection(title: bookTitle, books: books) }
                }

                Spacer().frame(height: 20)
            }
            .padding(.top, 12)
        }
        .background(Color.pearl)
        .overlay(alignment: .bottom) {
            if addedToast {
                Text("Added to Queue ✓")
                    .font(.custom("DMSans-Medium", size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(Color.deepNavy.opacity(0.9))
                    .clipShape(Capsule())
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: addedToast)
        .task {
            if tmdb.trendingMovies.isEmpty { await tmdb.fetchTrending() }
        }
        .task(id: tmdb.trendingBooks.map(\.id).joined()) {
            await tmdb.ensureBookCovers(for: tmdb.trendingBooks)
        }
        .task(id: tmdb.genreBooks.map(\.id).joined()) {
            await tmdb.ensureBookCovers(for: tmdb.genreBooks)
        }
        .task(id: (tmdb.trendingMovies + tmdb.trendingShows + tmdb.genreMovies + tmdb.genreShows).map { "\($0.id)" }.joined()) {
            let missingPosters = (tmdb.trendingMovies + tmdb.trendingShows + tmdb.genreMovies + tmdb.genreShows)
                .filter { $0.posterURL == nil }
                .map { (title: $0.title, type: $0.mediaType) }
            await tmdb.ensurePosters(for: missingPosters)
        }
    }

    private func genreChip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.custom("DMSans-Medium", size: 13))
                .foregroundColor(selected ? .white : .deepNavy)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(selected ? Color.oceanTeal : Color.mist)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func discoverSection(title: String, items: [TMDBItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.custom("DMSans-Medium", size: 15))
                .foregroundColor(.deepNavy)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        discoverCard(item: item)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func discoverBookSection(title: String, books: [TrendingBook]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.custom("DMSans-Medium", size: 15))
                .foregroundColor(.deepNavy)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(books) { book in discoverBookCard(book: book) }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func discoverBookCard(book: TrendingBook) -> some View {
        let alreadyQueued = items.contains { $0.title.lowercased() == book.title.lowercased() }
        let coverURL = book.coverURL ?? (tmdb.bookCoverCache[book.title] ?? nil)
        return VStack(alignment: .leading, spacing: 0) {
            // Cover
            Group {
                if let url = coverURL {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            ZStack { Color.mist; Image(systemName: "book.closed").font(.system(size: 28)).foregroundColor(.gray.opacity(0.4)) }
                        }
                    }
                } else {
                    ZStack { Color.mist; Image(systemName: "book.closed").font(.system(size: 28)).foregroundColor(.gray.opacity(0.4)) }
                }
            }
            .frame(width: 130, height: 190)
            .clipped()
            .onTapGesture {
                detailBookCoverURL = coverURL
                detailTMDBItem = TMDBItem(id: abs(book.title.hashValue), title: book.title, overview: "", posterPath: nil, releaseYear: book.year, rating: 0, mediaType: "book")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(book.title)
                    .font(.custom("DMSans-Medium", size: 13)).foregroundColor(.deepNavy).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if !book.author.isEmpty {
                    Text(book.author)
                        .font(.custom("DMSans-Regular", size: 11)).foregroundColor(.gray).lineLimit(1)
                }

                Button {
                    guard !alreadyQueued else { return }
                    let newItem = WatchlistItem(title: book.title, itemType: "book", streamingService: nil)
                    modelContext.insert(newItem)
                    if let userId = authService.userId {
                        Task { await SupabaseSyncService.shared.pushWatchlistItem(newItem, userId: userId) }
                    }
                    showToast()
                } label: {
                    Text(alreadyQueued ? "In Queue ✓" : "+ Add to Queue")
                        .font(.custom("DMSans-Medium", size: 12))
                        .foregroundColor(alreadyQueued ? .gray : .white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(alreadyQueued ? Color.mist : Color.oceanTeal)
                        .clipShape(Capsule())
                }
                .disabled(alreadyQueued)
            }
            .padding(10)
        }
        .frame(width: 130)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.07), lineWidth: 0.5))
    }

    private func discoverCard(item: TMDBItem) -> some View {
        let alreadyQueued = items.contains { $0.title == item.title }
        let posterURL = item.posterURL ?? (tmdb.posterCache["\(item.title)|||\(item.mediaType)"] ?? nil)
        return VStack(alignment: .leading, spacing: 0) {
            // Poster
            AsyncImage(url: posterURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure, .empty:
                    ZStack {
                        Color.mist
                        Image(systemName: item.mediaType == "movie" ? "film" : "tv")
                            .font(.system(size: 28)).foregroundColor(.gray.opacity(0.4))
                    }
                @unknown default:
                    Color.mist
                }
            }
            .frame(width: 130, height: 190)
            .clipped()
            .onTapGesture { detailTMDBItem = item }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.custom("DMSans-Medium", size: 13))
                    .foregroundColor(.deepNavy)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    if item.rating > 0 {
                        Image(systemName: "star.fill").font(.system(size: 9)).foregroundColor(.coral)
                        Text(String(format: "%.1f", item.rating))
                            .font(.custom("DMMono-Regular", size: 11)).foregroundColor(.gray)
                    }
                    if !item.releaseYear.isEmpty {
                        Text("·").foregroundColor(.gray.opacity(0.5)).font(.system(size: 10))
                        Text(item.releaseYear)
                            .font(.custom("DMMono-Regular", size: 11)).foregroundColor(.gray)
                    }
                }

                Button {
                    guard !alreadyQueued else { return }
                    let newItem = WatchlistItem(title: item.title, itemType: item.watchlistType, streamingService: nil)
                    modelContext.insert(newItem)
                    if let userId = authService.userId {
                        Task { await SupabaseSyncService.shared.pushWatchlistItem(newItem, userId: userId) }
                    }
                    showToast()
                } label: {
                    Text(alreadyQueued ? "In Queue ✓" : "+ Add to Queue")
                        .font(.custom("DMSans-Medium", size: 12))
                        .foregroundColor(alreadyQueued ? .gray : .white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(alreadyQueued ? Color.mist : Color.oceanTeal)
                        .clipShape(Capsule())
                }
                .disabled(alreadyQueued)
            }
            .padding(10)
        }
        .frame(width: 130)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.07), lineWidth: 0.5))
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Text(icon).font(.system(size: 48))
            Text(title).font(.custom("DMSans-Medium", size: 18)).foregroundColor(.deepNavy)
            Text(subtitle)
                .font(.custom("DMSans-Regular", size: 14)).foregroundColor(.gray)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func posterThumbnail(url: URL?, type: String, onTap: (() -> Void)? = nil) -> some View {
        let fallbackIcon = type == "movie" ? "film" : type == "book" ? "book.closed" : "tv"
        let content = Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fill)
                    default:
                        placeholderPoster(icon: fallbackIcon)
                    }
                }
            } else {
                placeholderPoster(icon: fallbackIcon)
            }
        }
        .frame(width: 44, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 6))

        if let onTap {
            Button(action: onTap) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    private func seasonBadge(_ season: Int) -> some View {
        Text("S\(season)")
            .font(.custom("DMMono-Regular", size: 11))
            .foregroundColor(.deepNavy.opacity(0.6))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.mist)
            .clipShape(Capsule())
    }

    private func placeholderPoster(icon: String) -> some View {
        ZStack {
            Color.mist
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(.gray.opacity(0.4))
        }
    }

    private func tmdbPosterURL(for item: WatchlistItem) -> URL? {
        let tmdbType = item.itemType == "show" ? "tv" : item.itemType
        return tmdb.posterCache["\(item.title)|||\(tmdbType)"] ?? nil
    }

    private func showToast() {
        withAnimation { addedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { addedToast = false }
        }
    }

    private func typeLabel(_ type: String) -> String {
        switch type {
        case "show": return "Show"
        case "movie": return "Movie"
        case "book": return "Book"
        default: return type.capitalized
        }
    }

    func streamingPill(service: String) -> some View {
        let color = streamingColor(service)
        return Text(service)
            .font(.custom("DMMono-Regular", size: 11))
            .foregroundColor(color)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    func streamingColor(_ service: String) -> Color {
        switch service {
        case "Netflix":           return Color(red: 0.9, green: 0.1, blue: 0.1)
        case "HBO Max", "Max":   return Color(red: 0.35, green: 0.1, blue: 0.8)
        case "Apple TV+":         return Color(red: 0.15, green: 0.15, blue: 0.15)
        case "Hulu":              return Color(red: 0.1, green: 0.7, blue: 0.4)
        case "Disney+":           return Color(red: 0.05, green: 0.2, blue: 0.7)
        case "Prime Video":       return Color(red: 0.0, green: 0.5, blue: 0.8)
        case "Peacock":           return Color(red: 0.1, green: 0.4, blue: 0.85)
        case "Paramount+":        return Color(red: 0.05, green: 0.3, blue: 0.75)
        case "Showtime":          return Color(red: 0.7, green: 0.05, blue: 0.05)
        case "Starz":             return Color(red: 0.3, green: 0.3, blue: 0.3)
        case "Crunchyroll":       return Color(red: 0.95, green: 0.4, blue: 0.0)
        case "Kindle", "Audible": return Color(red: 0.95, green: 0.55, blue: 0.0)
        case "Library", "Libby": return Color(red: 0.2, green: 0.5, blue: 0.3)
        case "YouTube":           return Color(red: 0.85, green: 0.1, blue: 0.1)
        case "Spotify":           return Color(red: 0.1, green: 0.7, blue: 0.3)
        default:                  return Color.oceanTeal
        }
    }
}

// MARK: - Add Watch Item Sheet

struct AddWatchItemSheet: View {
    let onAdd: (String, String, String?, Int?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var itemType = "show"
    @State private var streamingService: String? = nil
    @State private var customService = ""
    @State private var showCustomService = false
    @State private var season: Int? = nil
    @FocusState private var titleFocused: Bool

    private let showServices  = ["Netflix", "HBO Max", "Apple TV+", "Hulu", "Disney+", "Prime Video", "Peacock", "Paramount+", "Showtime", "YouTube", "Other"]
    private let movieServices = ["Netflix", "HBO Max", "Apple TV+", "Hulu", "Disney+", "Prime Video", "Peacock", "Paramount+", "Showtime", "Starz", "YouTube", "Other"]
    private let bookServices  = ["Kindle", "Audible", "Library", "Physical", "Other"]

    private var services: [String] {
        switch itemType {
        case "book":  return bookServices
        case "movie": return movieServices
        default:      return showServices
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Title...", text: $title)
                        .font(.custom("DMSans-Regular", size: 16)).foregroundColor(.deepNavy)
                        .focused($titleFocused)
                } header: {
                    Text("Title").font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).textCase(nil)
                }

                Section {
                    HStack(spacing: 8) {
                        typeButton(label: "📺 Show", type: "show")
                        typeButton(label: "🎬 Movie", type: "movie")
                        typeButton(label: "📚 Book", type: "book")
                    }
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                } header: {
                    Text("Type").font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).textCase(nil)
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(services, id: \.self) { service in
                                Button {
                                    if service == "Other" {
                                        showCustomService = true; streamingService = nil
                                    } else {
                                        streamingService = service; showCustomService = false; customService = ""
                                    }
                                } label: {
                                    Text(service)
                                        .font(.custom("DMSans-Medium", size: 13))
                                        .foregroundColor(streamingService == service ? .white : .deepNavy)
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(streamingService == service ? Color.oceanTeal : Color.mist)
                                        .clipShape(Capsule()).fixedSize()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)

                    if showCustomService {
                        TextField("Service name...", text: $customService)
                            .font(.custom("DMSans-Regular", size: 15)).foregroundColor(.deepNavy)
                            .onChange(of: customService) { _, val in streamingService = val.isEmpty ? nil : val }
                    }
                } header: {
                    Text("Where to watch / read").font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).textCase(nil)
                }

                if itemType == "show" {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                Button {
                                    withAnimation { season = nil }
                                } label: {
                                    Text("Any")
                                        .font(.custom("DMSans-Medium", size: 13))
                                        .foregroundColor(season == nil ? .white : .deepNavy)
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(season == nil ? Color.oceanTeal : Color.mist)
                                        .clipShape(Capsule()).fixedSize()
                                }
                                .buttonStyle(.plain)

                                ForEach(1...20, id: \.self) { s in
                                    Button {
                                        withAnimation { season = s }
                                    } label: {
                                        Text("S\(s)")
                                            .font(.custom("DMSans-Medium", size: 13))
                                            .foregroundColor(season == s ? .white : .deepNavy)
                                            .padding(.horizontal, 12).padding(.vertical, 7)
                                            .background(season == s ? Color.oceanTeal : Color.mist)
                                            .clipShape(Capsule()).fixedSize()
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    } header: {
                        Text("Season").font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).textCase(nil)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.gray)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add") {
                        let trimmed = title.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        onAdd(trimmed, itemType, streamingService, itemType == "show" ? season : nil)
                        dismiss()
                    }
                    .font(.custom("DMSans-Medium", size: 15))
                    .foregroundColor(title.isEmpty ? .gray : .oceanTeal)
                    .disabled(title.isEmpty)
                }
            }
            .onAppear { titleFocused = true }
        }
    }

    private func typeButton(label: String, type: String) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                itemType = type; streamingService = nil; showCustomService = false; customService = ""
            }
        } label: {
            Text(label)
                .font(.custom("DMSans-Medium", size: 13))
                .foregroundColor(itemType == type ? .white : .deepNavy)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(itemType == type ? Color.oceanTeal : Color.mist)
                .clipShape(Capsule()).fixedSize()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Edit Watch Item Sheet

struct EditWatchItemSheet: View {
    let item: WatchlistItem
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var itemType = "show"
    @State private var streamingService: String? = nil
    @State private var customService = ""
    @State private var showCustomService = false
    @State private var season: Int? = nil
    @FocusState private var titleFocused: Bool

    private let showServices  = ["Netflix", "HBO Max", "Apple TV+", "Hulu", "Disney+", "Prime Video", "Peacock", "Paramount+", "Showtime", "YouTube", "Other"]
    private let movieServices = ["Netflix", "HBO Max", "Apple TV+", "Hulu", "Disney+", "Prime Video", "Peacock", "Paramount+", "Showtime", "Starz", "YouTube", "Other"]
    private let bookServices  = ["Kindle", "Audible", "Library", "Physical", "Other"]

    private var services: [String] {
        switch itemType {
        case "book":  return bookServices
        case "movie": return movieServices
        default:      return showServices
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Title...", text: $title)
                        .font(.custom("DMSans-Regular", size: 16)).foregroundColor(.deepNavy)
                        .focused($titleFocused)
                } header: {
                    Text("Title").font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).textCase(nil)
                }

                Section {
                    HStack(spacing: 8) {
                        typeButton(label: "📺 Show", type: "show")
                        typeButton(label: "🎬 Movie", type: "movie")
                        typeButton(label: "📚 Book", type: "book")
                    }
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                } header: {
                    Text("Type").font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).textCase(nil)
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(services, id: \.self) { service in
                                Button {
                                    if service == "Other" {
                                        showCustomService = true; streamingService = nil
                                    } else {
                                        streamingService = service; showCustomService = false; customService = ""
                                    }
                                } label: {
                                    Text(service)
                                        .font(.custom("DMSans-Medium", size: 13))
                                        .foregroundColor(streamingService == service ? .white : .deepNavy)
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(streamingService == service ? Color.oceanTeal : Color.mist)
                                        .clipShape(Capsule()).fixedSize()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)

                    if showCustomService {
                        TextField("Service name...", text: $customService)
                            .font(.custom("DMSans-Regular", size: 15)).foregroundColor(.deepNavy)
                            .onChange(of: customService) { _, val in streamingService = val.isEmpty ? nil : val }
                    }
                } header: {
                    Text("Where to watch / read").font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).textCase(nil)
                }

                if itemType == "show" {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                Button {
                                    withAnimation { season = nil }
                                } label: {
                                    Text("Any")
                                        .font(.custom("DMSans-Medium", size: 13))
                                        .foregroundColor(season == nil ? .white : .deepNavy)
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(season == nil ? Color.oceanTeal : Color.mist)
                                        .clipShape(Capsule()).fixedSize()
                                }
                                .buttonStyle(.plain)

                                ForEach(1...20, id: \.self) { s in
                                    Button {
                                        withAnimation { season = s }
                                    } label: {
                                        Text("S\(s)")
                                            .font(.custom("DMSans-Medium", size: 13))
                                            .foregroundColor(season == s ? .white : .deepNavy)
                                            .padding(.horizontal, 12).padding(.vertical, 7)
                                            .background(season == s ? Color.oceanTeal : Color.mist)
                                            .clipShape(Capsule()).fixedSize()
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    } header: {
                        Text("Season").font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).textCase(nil)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.gray)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        let trimmed = title.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        item.title = trimmed
                        item.itemType = itemType
                        item.streamingService = streamingService
                        item.season = itemType == "show" ? season : nil
                        item.updatedAt = Date()
                        onSave()
                        dismiss()
                    }
                    .font(.custom("DMSans-Medium", size: 15))
                    .foregroundColor(title.isEmpty ? .gray : .oceanTeal)
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                title = item.title
                itemType = item.itemType
                season = item.season
                if let existing = item.streamingService {
                    let known = showServices + movieServices + bookServices
                    if known.contains(existing) {
                        streamingService = existing
                    } else {
                        streamingService = existing; customService = existing; showCustomService = true
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func typeButton(label: String, type: String) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                itemType = type; streamingService = nil; showCustomService = false; customService = ""
            }
        } label: {
            Text(label)
                .font(.custom("DMSans-Medium", size: 13))
                .foregroundColor(itemType == type ? .white : .deepNavy)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(itemType == type ? Color.oceanTeal : Color.mist)
                .clipShape(Capsule()).fixedSize()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Rate Watch Item Sheet

struct RateWatchItemSheet: View {
    let item: WatchlistItem
    let onSave: () -> Void
    let onReturnToQueue: () -> Void
    let onReturnToWatching: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var rating: Int = 0
    @State private var comment: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(item.title)
                        .font(.custom("DMSans-Medium", size: 16)).foregroundColor(.deepNavy)
                } header: {
                    Text("Finished").font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).textCase(nil)
                }

                Section {
                    HStack(spacing: 16) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                withAnimation(.spring(duration: 0.2)) { rating = star }
                            } label: {
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.system(size: 34))
                                    .foregroundColor(star <= rating ? .coral : .gray.opacity(0.3))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                } header: {
                    Text("Rating").font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).textCase(nil)
                }

                Section {
                    TextField("What did you think? (optional)", text: $comment, axis: .vertical)
                        .font(.custom("DMSans-Regular", size: 15)).foregroundColor(.deepNavy).lineLimit(4)
                } header: {
                    Text("Comment").font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).textCase(nil)
                }

                Section {
                    Button {
                        onReturnToWatching()
                        dismiss()
                    } label: {
                        Label("Still Watching", systemImage: "play.circle")
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(.coral)
                    }

                    Button {
                        onReturnToQueue()
                        dismiss()
                    } label: {
                        Label("Move Back to Queue", systemImage: "arrow.uturn.left")
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(.oceanTeal)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Rate it")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }.foregroundColor(.gray)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        if rating > 0 { item.rating = rating }
                        if !comment.trimmingCharacters(in: .whitespaces).isEmpty { item.comment = comment }
                        item.updatedAt = Date()
                        onSave()
                        dismiss()
                    }
                    .font(.custom("DMSans-Medium", size: 15)).foregroundColor(.oceanTeal)
                }
            }
            .onAppear {
                rating = item.rating ?? 0
                comment = item.comment ?? ""
            }
        }
        .presentationDetents([.medium, .large])
    }
}
