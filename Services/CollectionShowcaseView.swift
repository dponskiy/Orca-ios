//
//  CollectionShowcaseView.swift
//  Orca

import SwiftUI
import SwiftData

// MARK: - Normalized item

struct ShowcaseItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let subtitle: String
    let imageURL: String?
    let isOwned: Bool
    let badge: String?
    let placeholderEmoji: String
    let types: [String]
}

// MARK: - Colors

private let roomBg  = Color(red: 0.032, green: 0.024, blue: 0.059)  // deep indigo-black
private let caseBg  = Color(red: 0.067, green: 0.060, blue: 0.118)  // display-case interior

// MARK: - Gallery card

struct ShowcaseCard: View {
    let item: ShowcaseItem
    var isCompact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Display case — image with spotlight from above
            ZStack {
                caseBg
                artImage
                // Spotlight: soft light from top-center, simulates gallery downlighting
                LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.clear],
                    startPoint: UnitPoint(x: 0.5, y: 0),
                    endPoint: UnitPoint(x: 0.5, y: 0.55)
                )
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(0.78, contentMode: .fit)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 10, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 10
            ))

            // Hairline — the edge of the display case lid
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.5)

            // Museum label
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Group {
                        if isCompact {
                            Text(item.name)
                                .font(.custom("DMSans-Medium", size: 10))
                                .lineLimit(1)
                        } else {
                            // Reserve two lines so every card in a shelf row is the same
                            // height — a wrapping name ("Charizard VSTAR") must not make
                            // its card taller than its neighbors
                            ZStack(alignment: .topLeading) {
                                Text(" \n ")
                                    .font(.custom("DMSans-Medium", size: 12))
                                    .hidden()
                                Text(item.name)
                                    .font(.custom("DMSans-Medium", size: 12))
                                    .lineLimit(2)
                            }
                        }
                    }
                    .foregroundColor(.white.opacity(0.86))
                    // In compact (4-col) show only set/subtitle; in normal also append the badge (rarity etc)
                    Group {
                        if !isCompact, let badge = item.badge {
                            Text("\(item.subtitle.uppercased()) · \(badge.uppercased())")
                        } else {
                            Text(item.subtitle.uppercased())
                        }
                    }
                    .font(.custom("DMMono-Regular", size: 8))
                    .foregroundColor(.white.opacity(0.22))
                    .tracking(0.5)
                    .lineLimit(1)
                }
                Spacer(minLength: 6)
                // Collection status dot — refined indicator, not a shouting border
                Circle()
                    .fill(item.isOwned ? Color(red: 0.18, green: 0.75, blue: 0.65)
                                       : Color(red: 0.95, green: 0.45, blue: 0.45))
                    .frame(width: 5, height: 5)
                    .padding(.top, 4)
                    .opacity(0.85)
            }
            .padding(.horizontal, 11)
            .padding(.top, 9)
            .padding(.bottom, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(roomBg)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 10,
                bottomTrailingRadius: 10, topTrailingRadius: 0
            ))
        }
        .background(roomBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.5)
        )
        // Heavier shadow — items float off the wall
        .shadow(color: .black.opacity(0.55), radius: 12, y: 6)
    }

    @ViewBuilder
    private var artImage: some View {
        if let urlStr = item.imageURL, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFit().padding(12)
                default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Text(item.placeholderEmoji).font(.system(size: 36)).opacity(0.20)
    }
}

// MARK: - Wall tile (dense mode — artwork only)

private struct WallTile: View {
    let item: ShowcaseItem
    let isCard: Bool   // Pokémon cards fill the tile edge-to-edge; other art gets breathing room

    private let chaseColor = Color(red: 0.95, green: 0.45, blue: 0.45)

    var body: some View {
        ZStack {
            caseBg
            if let urlStr = item.imageURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFit().padding(isCard ? 0 : 2)
                    } else {
                        tinyPlaceholder
                    }
                }
            } else {
                tinyPlaceholder
            }
        }
        .aspectRatio(isCard ? 0.72 : 1.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .overlay(
            // Chase pieces stay visible on the wall — a faint outline marks the gaps
            item.isOwned
                ? nil
                : RoundedRectangle(cornerRadius: 2).strokeBorder(chaseColor.opacity(0.7), lineWidth: 1)
        )
    }

    private var tinyPlaceholder: some View {
        Text(item.placeholderEmoji).font(.system(size: 11)).opacity(0.15)
    }
}

// MARK: - Main showcase

struct CollectionShowcaseView: View {
    let category: CollectibleCategory
    @Environment(\.dismiss) private var dismiss

    @Query private var legoSets:    [LegoSet]
    @Query private var tcgCards:    [TCGCard]
    @Query private var smiskiItems: [SmiskiItem]
    @Query private var gameItems:   [GameItem]

    @State private var ownershipFilter: OwnershipFilter = .all
    @State private var groupFilter: String = "All"
    @State private var typeFilter:  String = "All"

    // One sheet, not four. Sibling .sheet modifiers on the same view fight each
    // other in SwiftUI — the detail would present and then immediately dismiss.
    private enum ShowcaseDetail: Identifiable {
        case lego(LegoSet), card(TCGCard), smiski(SmiskiItem), game(GameItem)
        var id: UUID {
            switch self {
            case .lego(let s):   return s.id
            case .card(let c):   return c.id
            case .smiski(let s): return s.id
            case .game(let g):   return g.id
            }
        }
    }
    @State private var detailItem: ShowcaseDetail?

    @AppStorage("showcaseColumnCount") private var columnCount: Int = 2
    @AppStorage("wallSpotlightHintSeen") private var spotlightHintSeen = false

    // Wall-mode spotlight (finger loupe)
    @State private var wallWidth: CGFloat = 0
    @State private var spotlightIndex: Int? = nil
    @State private var spotlightLocation: CGPoint = .zero
    @State private var spotlightActive = false
    @State private var lastTouchLocation: CGPoint = .zero

    private let wallGap: CGFloat = 2
    private let wallPadH: CGFloat = 10
    private let wallPadTop: CGFloat = 8

    enum OwnershipFilter: String, CaseIterable {
        case all = "All", owned = "Owned", want = "Want"
    }

    private var isWallMode: Bool { columnCount >= 10 }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack {
                roomBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    filterBar

                    if category == .pokemon, !pokemonTypeOptions.isEmpty {
                        typeFilterBar
                    }

                    gridSizeBar

                    if filteredItems.isEmpty {
                        emptyState
                    } else {
                        galleryScroll
                    }
                }
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white.opacity(0.55))
                }
            }
            .toolbarBackground(roomBg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        // Presented in place, not as a sheet. The gallery is already a
        // fullScreenCover inside a sheet, and a third nested modal was being torn
        // down the instant it appeared. An overlay is part of this view, so nothing
        // in the presentation chain above can dismiss it.
        .overlay {
            if let detail = detailItem {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { detailItem = nil } }

                    detailContent(detail)
                        .background(Color.pearl)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 40)
                        .shadow(color: .black.opacity(0.5), radius: 24, y: 8)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: detailItem?.id)
    }

    @ViewBuilder
    private func detailContent(_ detail: ShowcaseDetail) -> some View {
        let close = { withAnimation(.easeOut(duration: 0.2)) { detailItem = nil } }
        switch detail {
        case .lego(let set):    LegoSetDetailSheet(set: set, onClose: close)
        case .card(let card):   TCGCardDetailSheet(card: card, onClose: close)
        case .smiski(let item): SmiskiItemDetailSheet(item: item, onClose: close)
        case .game(let game):   GameDetailSheet(game: game, onClose: close)
        }
    }

    // MARK: Scroll content

    private var galleryScroll: some View {
        ScrollView {
            // Gallery entrance header — scrolls away as you enter the exhibit
            galleryHeader
                .padding(.bottom, 6)

            if isWallMode {
                if !spotlightHintSeen {
                    spotlightHint
                }
                wallGrid
            } else {
                shelfStack
            }
        }
    }

    // One-time hint — disappears forever after the first spotlight use
    private var spotlightHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 11))
            Text("Hold anywhere for spotlight")
                .font(.custom("DMSans-Regular", size: 12))
        }
        .foregroundColor(.white.opacity(0.45))
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
        .padding(.top, 4)
        .transition(.opacity)
    }

    // MARK: Shelf view — rows of pieces standing on lit ledges

    private var shelfRows: [[ShowcaseItem]] {
        let items = filteredItems
        guard columnCount > 0 else { return [] }
        return stride(from: 0, to: items.count, by: columnCount).map {
            Array(items[$0..<min($0 + columnCount, items.count)])
        }
    }

    private var shelfStack: some View {
        let gap: CGFloat = columnCount >= 4 ? 6 : 10
        return LazyVStack(spacing: 30) {
            ForEach(Array(shelfRows.enumerated()), id: \.offset) { _, row in
                shelfRow(row, gap: gap)
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 50)
        .animation(.easeOut(duration: 0.22), value: filteredItems)
    }

    private func shelfRow(_ row: [ShowcaseItem], gap: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: gap) {
                ForEach(row) { item in
                    ShowcaseCard(item: item, isCompact: columnCount >= 4)
                        .onTapGesture { handleTap(item) }
                }
                // Partial last row: empty slots keep card widths consistent,
                // and the shelf runs full width — room to grow
                if row.count < columnCount {
                    ForEach(0..<(columnCount - row.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 14)
            .zIndex(1)  // card shadows fall onto the ledge below

            shelfLedge
        }
    }

    // The ledge: lit top edge, solid front face, shadow cast into the room below
    private var shelfLedge: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.16))
                .frame(height: 1.5)
            Rectangle()
                .fill(Color(red: 0.118, green: 0.106, blue: 0.196))
                .frame(height: 8)
            LinearGradient(
                colors: [Color.black.opacity(0.45), Color.clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 16)
        }
        .allowsHitTesting(false)
    }

    // MARK: Wall view — the whole collection at a glance

    private var wallAspect: CGFloat { category == .pokemon ? 0.72 : 1.0 }
    private var wallTileWidth: CGFloat { max(0, (wallWidth - wallPadH * 2 - wallGap * 9) / 10) }
    private var wallTileHeight: CGFloat { wallTileWidth > 0 ? wallTileWidth / wallAspect : 0 }

    private var wallGrid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: wallGap), count: 10)
        let items = filteredItems
        return LazyVGrid(columns: cols, spacing: wallGap) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                WallTile(item: item, isCard: category == .pokemon)
                    .scaleEffect(spotlightIndex == idx ? 1.18 : 1.0)
                    .zIndex(spotlightIndex == idx ? 1 : 0)
                    .onTapGesture { handleTap(item) }
            }
        }
        .padding(.horizontal, wallPadH)
        .padding(.top, wallPadTop)
        .padding(.bottom, 50)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { wallWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, w in wallWidth = w }
            }
        )
        .coordinateSpace(name: "wall")
        .gesture(spotlightGesture)
        .overlay { roomDarkness }
        .overlay(alignment: .topLeading) { spotlightOverlay }
        .animation(.spring(duration: 0.22), value: spotlightIndex)
        .animation(.easeOut(duration: 0.18), value: spotlightActive)
    }

    // Darkness falls over the whole wall; a pool of light follows the finger.
    // Tiles inside the beam stay lit, everything beyond fades into the room.
    @ViewBuilder
    private var roomDarkness: some View {
        if spotlightActive {
            GeometryReader { geo in
                RadialGradient(
                    colors: [.clear, .clear, Color.black.opacity(0.72)],
                    center: UnitPoint(
                        x: spotlightLocation.x / max(geo.size.width, 1),
                        y: spotlightLocation.y / max(geo.size.height, 1)
                    ),
                    startRadius: 0,
                    endRadius: 150
                )
            }
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    // MARK: Wall spotlight — hold, then sweep a finger like a flashlight beam

    // One composed gesture: a passive zero-distance drag records the finger position
    // from touch-down (so ignition needs no movement), running simultaneously with
    // the hold-then-sweep sequence. Composed — not sibling modifiers — because
    // sibling gestures compete and the instant drag would starve the long press.
    private var spotlightGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.2)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("wall")))
            .onChanged { value in
                switch value {
                case .second(true, nil):
                    // Hold completed — the beam ignites right under the finger,
                    // before any movement (the simultaneous recorder has the point)
                    guard !spotlightActive else { break }
                    spotlightActive = true
                    withAnimation(.easeOut(duration: 0.3)) { spotlightHintSeen = true }
                    spotlightLocation = lastTouchLocation
                    spotlightIndex = wallIndex(at: lastTouchLocation)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                case .second(true, let drag?):
                    if !spotlightActive {
                        spotlightActive = true
                        withAnimation(.easeOut(duration: 0.3)) { spotlightHintSeen = true }
                    }
                    spotlightLocation = drag.location
                    let idx = wallIndex(at: drag.location)
                    if idx != spotlightIndex {
                        spotlightIndex = idx
                        if idx != nil { UISelectionFeedbackGenerator().selectionChanged() }
                    }
                default:
                    break
                }
            }
            .onEnded { _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    spotlightActive = false
                    spotlightIndex = nil
                }
            }
            .simultaneously(
                with: DragGesture(minimumDistance: 0, coordinateSpace: .named("wall"))
                    .onChanged { lastTouchLocation = $0.location }
            )
    }

    private func wallIndex(at point: CGPoint) -> Int? {
        guard wallTileWidth > 0 else { return nil }
        let x = point.x - wallPadH
        let y = point.y - wallPadTop
        guard x >= 0, y >= 0 else { return nil }
        let col = Int(x / (wallTileWidth + wallGap))
        let row = Int(y / (wallTileHeight + wallGap))
        guard col >= 0, col < 10, row >= 0 else { return nil }
        let idx = row * 10 + col
        guard idx < filteredItems.count else { return nil }
        return idx
    }

    @ViewBuilder
    private var spotlightOverlay: some View {
        if let idx = spotlightIndex, idx < filteredItems.count {
            let loupeW: CGFloat = 96
            let loupeH = loupeW / wallAspect
            let x = min(max(spotlightLocation.x, loupeW / 2 + 14), max(wallWidth - loupeW / 2 - 14, loupeW / 2 + 14))
            let y = max(spotlightLocation.y - (loupeH / 2 + 54), loupeH / 2 + 8)
            spotlightLoupe(for: filteredItems[idx], width: loupeW, height: loupeH)
                .position(x: x, y: y)
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
        }
    }

    private func spotlightLoupe(for item: ShowcaseItem, width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 6) {
            ZStack {
                caseBg
                if let urlStr = item.imageURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFit()
                        } else {
                            Text(item.placeholderEmoji).font(.system(size: 28)).opacity(0.2)
                        }
                    }
                } else {
                    Text(item.placeholderEmoji).font(.system(size: 28)).opacity(0.2)
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.7), radius: 18, y: 8)

            VStack(spacing: 1) {
                Text(item.name)
                    .font(.custom("DMSans-Medium", size: 11))
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(1)
                Text(item.subtitle.uppercased())
                    .font(.custom("DMMono-Regular", size: 7))
                    .foregroundColor(.white.opacity(0.38))
                    .tracking(0.5)
                    .lineLimit(1)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.black.opacity(0.55)))
        }
        .background(
            // The beam — a soft pool of light around the lifted piece
            RadialGradient(
                colors: [Color.white.opacity(0.16), Color.clear],
                center: .center, startRadius: 6, endRadius: 120
            )
            .frame(width: 240, height: 240)
        )
    }

    // "Walk into the room" header — large title, ghost count in corner
    private var galleryHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("GALLERY")
                        .font(.custom("DMMono-Regular", size: 9))
                        .foregroundColor(.white.opacity(0.18))
                        .tracking(3)
                    Text(categoryTitle)
                        .font(.custom("DMSans-Medium", size: 26))
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                // Ghost count — large, very faint
                Text("\(filteredItems.count)")
                    .font(.system(size: 52, weight: .thin).monospacedDigit())
                    .foregroundColor(.white.opacity(0.06))
            }
            // Room divider
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.5)
        }
        .padding(.horizontal, 18)
        .padding(.top, 22)
    }

    private func handleTap(_ item: ShowcaseItem) {
        switch category {
        case .lego:    if let s = legoSets.first(where:    { $0.id == item.id }) { detailItem = .lego(s) }
        case .pokemon: if let c = tcgCards.first(where:    { $0.id == item.id }) { detailItem = .card(c) }
        case .smiski:  if let s = smiskiItems.first(where: { $0.id == item.id }) { detailItem = .smiski(s) }
        case .games:   if let g = gameItems.first(where:   { $0.id == item.id }) { detailItem = .game(g) }
        }
    }

    // MARK: Filter bars

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(OwnershipFilter.allCases, id: \.rawValue) { f in
                    museumChip(f.rawValue, selected: ownershipFilter == f) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            ownershipFilter = f; groupFilter = "All"; typeFilter = "All"
                        }
                    }
                }
                if groupOptions.count > 1 {
                    thinDivider
                    ForEach(groupOptions, id: \.self) { g in
                        museumChip(g, selected: groupFilter == g) {
                            withAnimation(.easeOut(duration: 0.2)) { groupFilter = g; typeFilter = "All" }
                        }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 11)
        }
        .background(roomBg)
        .overlay(Rectangle().fill(Color.white.opacity(0.07)).frame(height: 0.5), alignment: .bottom)
    }

    private var typeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                museumChip("All", selected: typeFilter == "All") {
                    withAnimation(.easeOut(duration: 0.2)) { typeFilter = "All" }
                }
                thinDivider
                ForEach(pokemonTypeOptions, id: \.self) { type in
                    typeChip(type, selected: typeFilter == type) {
                        withAnimation(.easeOut(duration: 0.2)) { typeFilter = type }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 10)
        }
        .background(roomBg)
        .overlay(Rectangle().fill(Color.white.opacity(0.05)).frame(height: 0.5), alignment: .bottom)
    }

    // Minimal bar — just the grid-size control
    private var gridSizeBar: some View {
        HStack {
            Spacer()
            HStack(spacing: 2) {
                ForEach([2, 3, 4], id: \.self) { cols in
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { columnCount = cols }
                    } label: {
                        Image(systemName: gridIcon(for: cols))
                            .font(.system(size: 12, weight: columnCount == cols ? .semibold : .regular))
                            .foregroundColor(columnCount == cols ? .white.opacity(0.80) : .white.opacity(0.22))
                            .frame(width: 28, height: 26)
                            .background(columnCount == cols ? Color.white.opacity(0.09) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                }

                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 0.5, height: 14)
                    .padding(.horizontal, 4)

                // Wall mode — the whole collection as a dense mosaic
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { columnCount = 10 }
                } label: {
                    Image(systemName: "circle.grid.3x3.fill")
                        .font(.system(size: 11, weight: isWallMode ? .semibold : .regular))
                        .foregroundColor(isWallMode ? .white.opacity(0.80) : .white.opacity(0.22))
                        .frame(width: 28, height: 26)
                        .background(isWallMode ? Color.white.opacity(0.09) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 5)
        .background(roomBg)
    }

    private func gridIcon(for cols: Int) -> String {
        switch cols {
        case 2:  return "square.grid.2x2"
        case 3:  return "square.grid.3x3"
        default: return "square.grid.4x3.fill"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text(categoryEmoji).font(.system(size: 40)).opacity(0.18)
            Text("Nothing here")
                .font(.custom("DMSans-Medium", size: 15))
                .foregroundColor(.white.opacity(0.20))
            Spacer()
        }
    }

    // MARK: Chip styles

    // Refined museum chip — subtle, not bold
    private func museumChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.custom("DMSans-Medium", size: 12))
                .foregroundColor(selected ? .white.opacity(0.88) : .white.opacity(0.36))
                .padding(.horizontal, 11).padding(.vertical, 5)
                .background(selected ? Color.white.opacity(0.12) : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        selected ? Color.white.opacity(0.16) : Color.white.opacity(0.07),
                        lineWidth: 0.5
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private func typeChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let emoji = typeEmoji(label) { Text(emoji).font(.system(size: 10)) }
                Text(label)
                    .font(.custom("DMSans-Medium", size: 12))
                    .foregroundColor(selected ? .white.opacity(0.92) : .white.opacity(0.36))
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(selected ? typeColor(label).opacity(0.28) : Color.clear)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(selected ? typeColor(label).opacity(0.4) : Color.white.opacity(0.07), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private var thinDivider: some View {
        Rectangle().fill(Color.white.opacity(0.10)).frame(width: 0.5, height: 16)
    }

    // MARK: Type helpers

    private func typeEmoji(_ type: String) -> String? {
        switch type {
        case "Fire":      return "🔥"
        case "Water":     return "💧"
        case "Grass":     return "🌿"
        case "Lightning": return "⚡️"
        case "Psychic":   return "🔮"
        case "Fighting":  return "🥊"
        case "Darkness":  return "🌑"
        case "Metal":     return "⚙️"
        case "Dragon":    return "🐉"
        case "Fairy":     return "✨"
        case "Colorless": return "⭐️"
        default:          return nil
        }
    }

    private func typeColor(_ type: String) -> Color {
        switch type {
        case "Fire":      return Color(red: 1.0,  green: 0.45, blue: 0.2)
        case "Water":     return Color(red: 0.3,  green: 0.65, blue: 1.0)
        case "Grass":     return Color(red: 0.35, green: 0.8,  blue: 0.45)
        case "Lightning": return Color(red: 1.0,  green: 0.85, blue: 0.2)
        case "Psychic":   return Color(red: 0.85, green: 0.35, blue: 0.85)
        case "Fighting":  return Color(red: 0.9,  green: 0.5,  blue: 0.25)
        case "Darkness":  return Color(red: 0.55, green: 0.4,  blue: 0.75)
        case "Metal":     return Color(red: 0.65, green: 0.75, blue: 0.8)
        case "Dragon":    return Color(red: 0.45, green: 0.3,  blue: 0.9)
        case "Fairy":     return Color(red: 0.95, green: 0.6,  blue: 0.8)
        default:          return .white
        }
    }

    private var pokemonTypeOptions: [String] {
        Array(Set(tcgCards.flatMap { $0.types })).sorted()
    }

    // MARK: Group options

    private var groupOptions: [String] {
        var opts = ["All"]
        switch category {
        case .lego:    opts += Set(legoSets.map    { $0.themeName }).sorted()
        case .pokemon: opts += Set(tcgCards.map    { $0.setName }).sorted()
        case .smiski:  opts += Set(smiskiItems.map { $0.seriesName }).sorted()
        case .games:
            opts += Set(gameItems.map {
                $0.primaryPlatform.isEmpty ? ($0.platformNames.first ?? "Other") : $0.primaryPlatform
            }).sorted()
        }
        return opts
    }

    // MARK: Item generation

    private var filteredItems: [ShowcaseItem] {
        var result = allItems

        switch ownershipFilter {
        case .owned: result = result.filter {  $0.isOwned }
        case .want:  result = result.filter { !$0.isOwned }
        case .all:   break
        }

        if typeFilter != "All", category == .pokemon {
            result = result.filter { $0.types.contains(typeFilter) }
        }

        if groupFilter != "All" {
            let ids: Set<UUID>
            switch category {
            case .lego:    ids = Set(legoSets.filter    { $0.themeName == groupFilter }.map { $0.id })
            case .pokemon: ids = Set(tcgCards.filter    { $0.setName == groupFilter }.map { $0.id })
            case .smiski:  ids = Set(smiskiItems.filter { $0.seriesName == groupFilter }.map { $0.id })
            case .games:
                ids = Set(gameItems.filter {
                    ($0.primaryPlatform.isEmpty ? ($0.platformNames.first ?? "Other") : $0.primaryPlatform) == groupFilter
                }.map { $0.id })
            }
            result = result.filter { ids.contains($0.id) }
        }

        return result
    }

    private var allItems: [ShowcaseItem] {
        switch category {
        case .lego:
            return legoSets.map { set in
                ShowcaseItem(id: set.id,
                             name: set.name,
                             subtitle: "\(set.themeName)\(set.year > 0 ? " · \(set.year)" : "")",
                             imageURL: set.imageURL.isEmpty ? nil : set.imageURL,
                             isOwned: set.isOwned,
                             badge: set.numParts > 0 ? "\(set.numParts) pcs" : nil,
                             placeholderEmoji: "🧱", types: [])
            }
        case .pokemon:
            return tcgCards.map { card in
                ShowcaseItem(id: card.id,
                             name: card.name,
                             subtitle: card.setName,
                             imageURL: card.largeImageURL.isEmpty ? (card.imageURL.isEmpty ? nil : card.imageURL) : card.largeImageURL,
                             isOwned: card.isOwned,
                             badge: card.rarity,
                             placeholderEmoji: "✨", types: card.types)
            }
        case .smiski:
            return smiskiItems.map { s in
                ShowcaseItem(id: s.id,
                             name: s.figureName,
                             subtitle: s.seriesName,
                             imageURL: s.imageURL,
                             isOwned: s.isOwned,
                             badge: s.isSecret ? "Secret" : nil,
                             placeholderEmoji: "👻", types: [])
            }
        case .games:
            return gameItems.map { game in
                ShowcaseItem(id: game.id,
                             name: game.name,
                             subtitle: "\(game.genreNames.first ?? "Game")\(game.releaseYear != nil ? " · \(game.releaseYear!)" : "")",
                             imageURL: game.coverURL.isEmpty ? nil : game.coverURL,
                             isOwned: game.isOwned,
                             badge: game.rating != nil ? String(format: "★ %.1f", game.rating!) : nil,
                             placeholderEmoji: "🎮", types: [])
            }
        }
    }

    private var categoryTitle: String {
        switch category {
        case .pokemon: return "Pokémon"
        case .lego:    return "Lego"
        case .smiski:  return "Smiski"
        case .games:   return "Games"
        }
    }

    private var categoryEmoji: String {
        switch category {
        case .pokemon: return "✨"
        case .lego:    return "🧱"
        case .smiski:  return "👻"
        case .games:   return "🎮"
        }
    }
}
