//
//  MediaShowcaseView.swift
//  Orca
//
//  A quiet corner of a cafe rather than a rental store. The collectibles gallery is
//  a cold museum — deliberately the opposite room. Same shelf construction underneath
//  so they still feel like one app, but warm wood and lamplight instead of display
//  lighting, and small covers with plenty of air: density reads as inventory, space
//  reads as calm.
//

import SwiftUI
import SwiftData

// MARK: - Palette

// Daylight version of the same cafe — the warmth comes from paper and oak rather
// than from darkness, so this sits beside Orca's other screens instead of fighting
// them. oceanTeal is left for anything interactive so the app still feels like itself.
let cafeBg     = Color(red: 0.961, green: 0.937, blue: 0.898)  // warm paper
let sleeveBg   = Color(red: 0.898, green: 0.859, blue: 0.800)  // empty cover slot
let lampGlow   = Color(red: 0.760, green: 0.510, blue: 0.220)  // amber, deep enough to read on paper
let shelfWood  = Color(red: 0.780, green: 0.647, blue: 0.478)  // light oak
let inkPrimary = Color(red: 0.196, green: 0.157, blue: 0.125)  // warm charcoal
let inkMuted   = Color(red: 0.549, green: 0.482, blue: 0.416)
let inkSoft    = Color(red: 0.325, green: 0.271, blue: 0.227)

// MARK: - Sections

private enum MediaAisle: String, CaseIterable, Identifiable {
    case watching, queued, watched
    var id: String { rawValue }

    var label: String {
        switch self {
        case .watching: return "Currently watching"
        case .queued:   return "Up next"
        case .watched:  return "Finished"
        }
    }
    var caption: String {
        switch self {
        case .watching: return "no rush"
        case .queued:   return "when you get to it"
        case .watched:  return "things you've been through"
        }
    }
    var statuses: Set<String> {
        switch self {
        case .watching: return ["watching", "reading", "in progress"]
        case .queued:   return ["queued", "want", "planned", ""]
        case .watched:  return ["watched", "completed", "finished", "done", "read"]
        }
    }
}

// MARK: - Film grain
//
// The signature of the lofi look — analog warmth. Static and drawn once; without it
// the flat background reads as empty rather than atmospheric.

struct FilmGrain: View {
    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x9E3779B97F4A7C15
            func next() -> Double {
                seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
                return Double(seed % 1000) / 1000.0
            }
            let count = Int((size.width * size.height) / 900)
            for _ in 0..<count {
                let x = next() * size.width
                let y = next() * size.height
                let a = 0.012 + next() * 0.028
                // Dark speckle on paper — the light equivalent of film grain
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 1.2, height: 1.2)),
                    with: .color(.black.opacity(a))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Main showcase

struct MediaShowcaseView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var items: [WatchlistItem]
    @State private var tmdb = TMDBService.shared

    @State private var typeFilter: String = "All"
    @State private var detailItem: WatchlistItem?

    private let typeOptions = ["All", "Movies", "Shows", "Books"]

    var body: some View {
        NavigationStack {
            ZStack {
                cafeBg.ignoresSafeArea()

                // One light source, off in the corner
                RadialGradient(
                    colors: [lampGlow.opacity(0.10), .clear],
                    center: UnitPoint(x: 0.92, y: 0.06),
                    startRadius: 4, endRadius: 320
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                FilmGrain().ignoresSafeArea()

                if items.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        typeBar
                        shelfScroll
                    }
                }
            }
            .navigationTitle("Your Shelf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.oceanTeal)
                }
            }
            .toolbarBackground(cafeBg, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .sheet(item: $detailItem) { item in
                MediaDetailSheet(
                    title: item.title,
                    type: item.itemType == "show" ? "tv" : item.itemType,
                    existingPosterURL: posterURL(for: item)
                )
            }
            .task { await loadPosters() }
            .onChange(of: items.count) { _, _ in Task { await loadPosters() } }
        }
    }

    // MARK: Poster resolution

    private func posterURL(for item: WatchlistItem) -> URL? {
        tmdb.posterURL(title: item.title, type: tmdbType(for: item)) ?? nil
    }

    /// Built in this view's body so the poster-cache read is tracked here — that's
    /// what makes the shelves refresh once posters resolve in the background.
    private var posterMap: [UUID: URL] {
        var map: [UUID: URL] = [:]
        for item in items { if let url = posterURL(for: item) { map[item.id] = url } }
        return map
    }

    private func tmdbType(for item: WatchlistItem) -> String {
        switch item.itemType {
        case "movie": return "movie"
        case "book":  return "book"
        default:      return "tv"
        }
    }

    private func loadPosters() async {
        await tmdb.ensurePosters(for: items.map { (title: $0.title, type: tmdbType(for: $0)) })
    }

    // MARK: Filter

    private var typeBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(typeOptions, id: \.self) { opt in
                    Button {
                        withAnimation(.easeOut(duration: 0.25)) { typeFilter = opt }
                    } label: {
                        Text(opt.lowercased())
                            .font(.custom("DMSans-Regular", size: 13))
                            .foregroundColor(typeFilter == opt ? inkPrimary : inkMuted)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(typeFilter == opt ? shelfWood.opacity(0.35) : .clear)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
    }

    // MARK: Shelves

    private var shelfScroll: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 30) {
                ForEach(MediaAisle.allCases) { aisle in
                    let shelf = itemsFor(aisle)
                    if !shelf.isEmpty {
                        shelfSection(aisle, items: shelf)
                    }
                }
            }
            .padding(.top, 14)
            .padding(.bottom, 60)
        }
    }

    private func shelfSection(_ aisle: MediaAisle, items shelf: [WatchlistItem]) -> some View {
        MediaShelf(
            label: aisle.label,
            caption: aisle.caption,
            items: shelf,
            posters: posterMap,
            onTap: { detailItem = $0 }
        )
    }

    // MARK: Filtering

    private var filteredItems: [WatchlistItem] {
        switch typeFilter {
        case "Movies": return items.filter { $0.itemType == "movie" }
        case "Shows":  return items.filter { $0.itemType == "show" }
        case "Books":  return items.filter { $0.itemType == "book" }
        default:       return items
        }
    }

    private func itemsFor(_ aisle: MediaAisle) -> [WatchlistItem] {
        filteredItems
            .filter { aisle.statuses.contains($0.status.lowercased()) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "cup.and.saucer")
                .font(.system(size: 34))
                .foregroundColor(lampGlow.opacity(0.35))
            Text("nothing on the shelf yet")
                .font(.custom("DMSans-Regular", size: 15))
                .foregroundColor(inkSoft)
            Text("add a movie, show, or book and it'll live here")
                .font(.custom("DMSans-Regular", size: 12))
                .foregroundColor(inkMuted)
            Spacer()
        }
    }
}

// MARK: - Shared shelf
//
// One shelf: a heading, a row of covers, and the plank they stand on. Used both by
// the standalone gallery and by the Queue / Done tabs so the two can't drift apart.

struct MediaShelf: View {
    let label: String
    let caption: String
    let items: [WatchlistItem]
    let posters: [UUID: URL]
    var emptyMessage: String = ""
    var accessory: AnyView? = nil
    let onTap: (WatchlistItem) -> Void
    var coverWidth: CGFloat = 68

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.custom("DMSans-Regular", size: 16))
                    .foregroundColor(inkPrimary)
                Text(caption)
                    .font(.custom("DMSans-Regular", size: 11))
                    .foregroundColor(inkMuted)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, accessory == nil ? 16 : 12)

            if let accessory {
                accessory.padding(.bottom, 16)
            }

            if items.isEmpty {
                Text(emptyMessage)
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundColor(inkMuted)
                    .padding(.horizontal, 20)
                    .frame(height: 60, alignment: .center)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 16) {
                        ForEach(items) { item in
                            cover(item).onTapGesture { onTap(item) }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            // Worn plank, not a lit retail ledge
            RoundedRectangle(cornerRadius: 2)
                .fill(shelfWood)
                .frame(height: 5)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .shadow(color: .black.opacity(0.14), radius: 4, y: 3)
        }
    }

    private func cover(_ item: WatchlistItem) -> some View {
        let isBook = item.itemType == "book"
        let h = coverWidth / (isBook ? 0.66 : 0.667)

        return VStack(alignment: .leading, spacing: 6) {
            ZStack {
                sleeveBg
                if let url = posters[item.id] {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                        } else {
                            coverFallback(item)
                        }
                    }
                } else {
                    coverFallback(item)
                }
            }
            .frame(width: coverWidth, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .shadow(color: .black.opacity(0.18), radius: 6, y: 3)

            // Single line, truncated — a wrapping title pushed the star row to a
            // different height on each cover, which read as broken alignment.
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.custom("DMSans-Regular", size: 10))
                    .foregroundColor(inkSoft)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let rating = item.rating, rating > 0 {
                    HStack(spacing: 1.5) {
                        ForEach(0..<min(rating, 5), id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundColor(lampGlow)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(width: coverWidth, height: 28, alignment: .topLeading)
        }
    }

    private func coverFallback(_ item: WatchlistItem) -> some View {
        VStack(spacing: 3) {
            Image(systemName: item.itemType == "book" ? "book.closed"
                            : item.itemType == "movie" ? "film" : "tv")
                .font(.system(size: 14))
                .foregroundColor(inkMuted.opacity(0.5))
            Text(item.title)
                .font(.custom("DMSans-Regular", size: 8))
                .foregroundColor(inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 4)
        }
    }
}
