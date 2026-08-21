//
//  LegoView.swift
//  Orca

import SwiftUI
import SwiftData

// MARK: - Main Lego content (embedded in CollectiblesView)

struct LegoCollectionContent: View {
    @Query private var allSets: [LegoSet]
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @State private var service = RebrickableService.shared
    @State private var showBrowser = false
    @State private var showSearch = false
    @State private var showGallery = false
    @State private var setToRemove: LegoSet? = nil
    @State private var detailSet: LegoSet? = nil

    private var ownedSets: [LegoSet] { allSets.filter { $0.isOwned } }
    private var wantedSets: [LegoSet] { allSets.filter { !$0.isOwned } }
    private var ownedByTheme: [(themeName: String, sets: [LegoSet])] {
        let grouped = Dictionary(grouping: ownedSets) { $0.themeName }
        return grouped.keys
            .sorted()
            .map { (themeName: $0, sets: grouped[$0]!.sorted { $0.year > $1.year }) }
    }

    var body: some View {
        // VStack (not Group) is a stable anchor — sheet modifiers stay on the same
        // view even when the conditional content inside changes entirely (e.g. first
        // insert going from emptyState → stats+collection). Group distributes modifiers
        // to each child, so a content swap re-anchors the sheet and resets nav state.
        VStack(spacing: 0) {
            if !service.hasApiKey {
                apiKeyPrompt
            } else {
                if !allSets.isEmpty { legoStatsStrip }
                if allSets.isEmpty { emptyState } else { legoBrowseButtons }
                if !ownedSets.isEmpty { legoCollectionSection }
                if !wantedSets.isEmpty { wantListSection }
            }
        }
        .sheet(isPresented: $showBrowser) { LegoThemeBrowserView() }
        .sheet(isPresented: $showSearch) { LegoSearchView() }
        .sheet(item: $detailSet) { set in
            LegoSetDetailSheet(set: set)
                .presentationDetents([.height(320)])
        }
        .alert("Remove \(setToRemove?.name ?? "set")?", isPresented: Binding(get: { setToRemove != nil }, set: { if !$0 { setToRemove = nil } })) {
            Button("Remove", role: .destructive) {
                if let set = setToRemove {
                    let id = set.id
                    modelContext.delete(set)
                    try? modelContext.save()
                    Task { await SupabaseSyncService.shared.deleteLegoSet(id: id) }
                    setToRemove = nil
                }
            }
            Button("Cancel", role: .cancel) { setToRemove = nil }
        } message: {
            Text("This will remove it from your collection.")
        }
    }

    private var legoStatsStrip: some View {
        HStack(spacing: 0) {
            statCell(value: "\(ownedSets.count)", label: "Owned")
            Divider().frame(height: 36)
            statCell(value: "\(wantedSets.count)", label: "Want List")
            Divider().frame(height: 36)
            statCell(value: "\(ownedByTheme.count)", label: "Themes")
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

    private var legoCollectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("YOUR COLLECTION")
                    .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).tracking(0.5)
                Spacer()
                Button { showBrowser = true } label: {
                    Text("Browse").font(.custom("DMSans-Medium", size: 13)).foregroundColor(.oceanTeal)
                }
            }
            .padding(.horizontal, 20)

            ForEach(ownedByTheme, id: \.themeName) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.themeName)
                        .font(.custom("DMSans-Medium", size: 12)).foregroundColor(.gray)
                        .padding(.horizontal, 20)
                    ForEach(group.sets) { set in
                        legoSetRow(set)
                            .padding(.horizontal, 20)
                            .onTapGesture { cycleLegoSet(set) }
                            .onLongPressGesture { detailSet = set }
                            .contextMenu {
                                Button(role: .destructive) { setToRemove = set } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .padding(.top, 20)
    }

    private var wantListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WANT LIST")
                .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).tracking(0.5)
                .padding(.horizontal, 20)

            ForEach(wantedSets.sorted { $0.addedAt > $1.addedAt }) { set in
                legoSetRow(set)
                    .padding(.horizontal, 20)
                    .onTapGesture { cycleLegoSet(set) }
                    .onLongPressGesture { detailSet = set }
                    .contextMenu {
                        Button(role: .destructive) { setToRemove = set } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
            }
        }
        .padding(.top, 20)
    }

    private func legoSetRow(_ set: LegoSet) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: set.imageURL)) { phase in
                if case .success(let img) = phase {
                    img.resizable().aspectRatio(contentMode: .fill)
                } else {
                    ZStack { Color.mist; Image(systemName: "cube.box").foregroundColor(.gray.opacity(0.4)) }
                }
            }
            .frame(width: 52, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(set.name).font(.custom("DMSans-Medium", size: 14)).foregroundColor(.deepNavy).lineLimit(2)
                HStack(spacing: 6) {
                    Text(set.setNum).font(.custom("DMMono-Regular", size: 11)).foregroundColor(.gray)
                    Text("·").foregroundColor(.gray)
                    Text("\(set.numParts) pcs").font(.custom("DMMono-Regular", size: 11)).foregroundColor(.gray)
                    Text("·").foregroundColor(.gray)
                    Text("\(set.year)").font(.custom("DMMono-Regular", size: 11)).foregroundColor(.gray)
                }
            }
            Spacer()
            Image(systemName: set.isOwned ? "checkmark.circle.fill" : "heart.fill")
                .foregroundColor(set.isOwned ? .oceanTeal : .coral)
                .font(.system(size: 16))
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.07), lineWidth: 0.5))
    }

    private func cycleLegoSet(_ set: LegoSet) {
        if set.isOwned {
            set.isOwned = false
            try? modelContext.save()
            if let userId = authService.userId {
                Task { await SupabaseSyncService.shared.pushLegoSet(set, userId: userId) }
            }
        } else {
            let id = set.id
            modelContext.delete(set)
            try? modelContext.save()
            Task { await SupabaseSyncService.shared.deleteLegoSet(id: id) }
        }
    }

    private var legoBrowseButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button { showSearch = true } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "rectangle.grid.2x2")
                        Text("Browse Sets").font(.custom("DMSans-Medium", size: 15))
                    }
                    .foregroundColor(.oceanTeal)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.oceanTeal.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                Button { showBrowser = true } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "list.bullet")
                        Text("Browse Themes").font(.custom("DMSans-Medium", size: 15))
                    }
                    .foregroundColor(.oceanTeal)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.oceanTeal.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

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
            .fullScreenCover(isPresented: $showGallery) { CollectionShowcaseView(category: .lego) }
        }
        .padding(.horizontal, 20).padding(.top, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)
            Image(systemName: "cube.box.fill")
                .font(.system(size: 48)).foregroundColor(.oceanTeal.opacity(0.25))
            VStack(spacing: 8) {
                Text("Start your Lego collection")
                    .font(.custom("DMSans-Medium", size: 20)).foregroundColor(.deepNavy)
                Text("Search for a set or browse by theme\nto add sets you own or want.")
                    .font(.custom("DMSans-Regular", size: 14)).foregroundColor(.gray).multilineTextAlignment(.center)
            }
            HStack(spacing: 12) {
                Button { showSearch = true } label: {
                    Text("Search Sets").font(.custom("DMSans-Medium", size: 15)).foregroundColor(.white)
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(Color.deepNavy).clipShape(Capsule())
                }
                Button { showBrowser = true } label: {
                    Text("Browse Themes").font(.custom("DMSans-Medium", size: 15)).foregroundColor(.oceanTeal)
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(Color.oceanTeal.opacity(0.1)).clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 40).padding(.top, 20)
    }

    private var apiKeyPrompt: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)
            Image(systemName: "key.fill")
                .font(.system(size: 40)).foregroundColor(.oceanTeal.opacity(0.4))
            Text("Rebrickable API Key Required")
                .font(.custom("DMSans-Medium", size: 18)).foregroundColor(.deepNavy)
            Text("Add your free Rebrickable API key to\nConfig.rebrickableApiKey to enable Lego browsing.\n\nSign up free at rebrickable.com/api/")
                .font(.custom("DMSans-Regular", size: 14)).foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 40).padding(.top, 20)
    }
}

// MARK: - Theme browser

struct LegoThemeBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var service = RebrickableService.shared
    @State private var searchText = ""
    @State private var navigationPath = NavigationPath()

    private var filteredThemes: [RBTheme] {
        guard !searchText.isEmpty else { return service.parentThemes }
        return service.parentThemes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if service.isFetchingThemes {
                    VStack(spacing: 16) {
                        Spacer()
                        ProgressView().tint(.oceanTeal)
                        Text("Loading themes...").font(.custom("DMSans-Regular", size: 14)).foregroundColor(.gray)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredThemes) { theme in
                            NavigationLink(value: theme) {
                                HStack {
                                    Image(systemName: "cube.box")
                                        .font(.system(size: 14))
                                        .foregroundColor(.oceanTeal)
                                        .frame(width: 28, height: 28)
                                        .background(Color.oceanTeal.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    Text(theme.name)
                                        .font(.custom("DMSans-Regular", size: 15))
                                        .foregroundColor(.deepNavy)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .navigationDestination(for: RBTheme.self) { theme in
                        LegoSetBrowserView(theme: theme)
                    }
                }
            }
            .background(Color.pearl.ignoresSafeArea())
            .searchable(text: $searchText, prompt: "Search themes...")
            .navigationTitle("Lego Themes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.oceanTeal)
                }
            }
            .task { await service.fetchThemes() }
        }
    }
}

// MARK: - Set browser for a theme

struct LegoSetBrowserView: View {
    let theme: RBTheme

    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Query private var allLegoSets: [LegoSet]
    @State private var service = RebrickableService.shared
    // nil = not in collection, "owned", "want", "" = locally removed
    @State private var localStatus: [String: String] = [:]

    private var sets: [RBSet] { service.themeSets[theme.id] ?? [] }
    private var isLoading: Bool { service.fetchingThemeIds.contains(theme.id) }

    private func effectiveStatus(for setNum: String) -> String? {
        if let local = localStatus[setNum] { return local.isEmpty ? nil : local }
        if allLegoSets.first(where: { $0.setNum == setNum && $0.isOwned }) != nil { return "owned" }
        if allLegoSets.first(where: { $0.setNum == setNum && !$0.isOwned }) != nil { return "want" }
        return nil
    }

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView().tint(.oceanTeal)
                    Text("Loading sets...").font(.custom("DMSans-Regular", size: 14)).foregroundColor(.gray)
                    Spacer()
                }
            } else if sets.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Text("No sets found").font(.custom("DMSans-Medium", size: 16)).foregroundColor(.gray)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(sets) { set in setCard(set: set) }
                    }
                    .padding(12)
                    .padding(.bottom, 30)
                }
            }
        }
        .background(Color.pearl.ignoresSafeArea())
        .navigationTitle(theme.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await service.fetchSets(themeId: theme.id) }
    }

    private func setCard(set: RBSet) -> some View {
        let status = effectiveStatus(for: set.setNum)
        let isOwned = status == "owned"
        let accent: Color = isOwned ? .oceanTeal : .coral

        return VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: set.imageURL) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fill)
                    case .empty:
                        ZStack { Color.mist; ProgressView().scaleEffect(0.5) }
                    default:
                        ZStack { Color.mist; Image(systemName: "cube.box").foregroundColor(.gray.opacity(0.3)) }
                    }
                }
                .frame(maxWidth: .infinity).frame(height: 100)
                .clipped()

                if status != nil {
                    Image(systemName: isOwned ? "checkmark.circle.fill" : "heart.fill")
                        .font(.system(size: 14))
                        .foregroundColor(accent)
                        .padding(5)
                        .background(Color.white)
                        .clipShape(Circle())
                        .padding(5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(status == nil ? Color.clear : accent, lineWidth: 2)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(set.name)
                    .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.deepNavy).lineLimit(2)
                HStack {
                    Text(set.setNum).font(.custom("DMMono-Regular", size: 9)).foregroundColor(.gray)
                    Spacer()
                    Text("\(set.numParts) pcs").font(.custom("DMMono-Regular", size: 9)).foregroundColor(.gray)
                }
                Text("\(set.year)").font(.custom("DMMono-Regular", size: 9)).foregroundColor(.gray)
            }
            .padding(.horizontal, 8).padding(.vertical, 8)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        .onTapGesture { cycleSet(set) }
    }

    private func cycleSet(_ set: RBSet) {
        let current = effectiveStatus(for: set.setNum)
        switch current {
        case nil:
            // Not in collection → Owned
            localStatus[set.setNum] = "owned"
            let legoSet = LegoSet(setNum: set.setNum, name: set.name, year: set.year,
                                  themeId: theme.id, themeName: theme.name,
                                  numParts: set.numParts, imageURL: set.imageURL?.absoluteString ?? "")
            legoSet.statusRaw = "owned"
            modelContext.insert(legoSet)
            try? modelContext.save()
            if let userId = authService.userId {
                Task { await SupabaseSyncService.shared.pushLegoSet(legoSet, userId: userId) }
            }
        case "owned":
            // Owned → Want
            localStatus[set.setNum] = "want"
            if let existing = allLegoSets.first(where: { $0.setNum == set.setNum }) {
                existing.isOwned = false
                try? modelContext.save()
                if let userId = authService.userId {
                    Task { await SupabaseSyncService.shared.pushLegoSet(existing, userId: userId) }
                }
            }
        default:
            // Want → Remove
            localStatus[set.setNum] = ""
            if let existing = allLegoSets.first(where: { $0.setNum == set.setNum }) {
                let id = existing.id
                modelContext.delete(existing)
                try? modelContext.save()
                Task { await SupabaseSyncService.shared.deleteLegoSet(id: id) }
            }
        }
    }
}

// MARK: - Lego Set Detail Sheet (tap from collection / want list)

struct LegoSetDetailSheet: View {
    let set: LegoSet
    // Set when shown as an in-place overlay instead of a modal —
    // @Environment(\.dismiss) is inert outside a presentation.
    var onClose: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @State private var showRemoveConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 4).padding(.top, 12)

            HStack(spacing: 14) {
                AsyncImage(url: URL(string: set.imageURL)) { phase in
                    if case .success(let img) = phase {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        ZStack { Color.mist; Image(systemName: "cube.box").foregroundColor(.gray.opacity(0.4)) }
                    }
                }
                .frame(width: 64, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(set.name)
                        .font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy).lineLimit(2)
                    HStack(spacing: 6) {
                        Text(set.setNum).font(.custom("DMMono-Regular", size: 11)).foregroundColor(.gray)
                        Text("·").foregroundColor(.gray)
                        Text("\(set.numParts) pcs").font(.custom("DMMono-Regular", size: 11)).foregroundColor(.gray)
                        Text("·").foregroundColor(.gray)
                        Text("\(set.year)").font(.custom("DMMono-Regular", size: 11)).foregroundColor(.gray)
                    }
                    Text(set.themeName).font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                }
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 16)

            Divider().padding(.top, 16)

            HStack(spacing: 12) {
                statusButton(label: "Owned", icon: "checkmark.circle.fill",
                             active: set.isOwned, color: .oceanTeal) {
                    set.isOwned = true
                    try? modelContext.save()
                    if let userId = authService.userId {
                        Task { await SupabaseSyncService.shared.pushLegoSet(set, userId: userId) }
                    }
                }
                statusButton(label: "Want List", icon: "heart.fill",
                             active: !set.isOwned, color: .coral) {
                    set.isOwned = false
                    try? modelContext.save()
                    if let userId = authService.userId {
                        Task { await SupabaseSyncService.shared.pushLegoSet(set, userId: userId) }
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 16)

            Button { showRemoveConfirm = true } label: {
                Text("Remove from Collection")
                    .font(.custom("DMSans-Medium", size: 14)).foregroundColor(.coral)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.coral.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 20).padding(.top, 12)

            Spacer()
        }
        .background(Color.pearl.ignoresSafeArea())
        .alert("Remove \(set.name)?", isPresented: $showRemoveConfirm) {
            Button("Remove", role: .destructive) {
                let id = set.id
                modelContext.delete(set)
                try? modelContext.save()
                Task { await SupabaseSyncService.shared.deleteLegoSet(id: id) }
                close()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove it from your collection.")
        }
    }

    private func statusButton(label: String, icon: String, active: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 14))
                Text(label).font(.custom("DMSans-Medium", size: 14))
            }
            .foregroundColor(active ? .white : color)
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(active ? color : color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }
}

// MARK: - Lego search

struct LegoSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Query private var allLegoSets: [LegoSet]
    @State private var service = RebrickableService.shared
    @State private var query = ""
    @FocusState private var focused: Bool

    private var addedNums: Set<String> { Set(allLegoSets.map { $0.setNum }) }

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundColor(.gray)
                    TextField("Search Lego sets...", text: $query)
                        .font(.custom("DMSans-Regular", size: 15))
                        .focused($focused)
                        .onSubmit { focused = false; Task { await service.search(query: query) } }
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
                .padding(16)
                .submitLabel(.search)

                if service.searchResults.isEmpty && !service.isSearching {
                    Spacer()
                    Text("Search for any Lego set by name or number")
                        .font(.custom("DMSans-Regular", size: 14)).foregroundColor(.gray).multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(service.searchResults) { set in
                                searchResultCard(set: set)
                            }
                        }
                        .padding(.horizontal, 12).padding(.bottom, 30)
                    }
                }
            }
            .background(Color.pearl.ignoresSafeArea())
            .navigationTitle("Search Lego")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.oceanTeal)
                }
            }
            .onAppear { focused = true }
        }
    }

    private func searchResultCard(set: RBSet) -> some View {
        let alreadyAdded = addedNums.contains(set.setNum)

        return VStack(spacing: 0) {
            AsyncImage(url: set.imageURL) { phase in
                if case .success(let img) = phase {
                    img.resizable().aspectRatio(contentMode: .fill)
                } else {
                    ZStack { Color.mist; Image(systemName: "cube.box").foregroundColor(.gray.opacity(0.3)) }
                }
            }
            .frame(maxWidth: .infinity).frame(height: 90)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(set.name).font(.custom("DMSans-Medium", size: 11)).foregroundColor(.deepNavy).lineLimit(2)
                Text(set.setNum).font(.custom("DMMono-Regular", size: 9)).foregroundColor(.gray)
                Text("\(set.numParts) pcs · \(set.year)").font(.custom("DMMono-Regular", size: 9)).foregroundColor(.gray)

                if alreadyAdded {
                    Text("Added ✓").font(.custom("DMSans-Medium", size: 10)).foregroundColor(.oceanTeal)
                        .frame(maxWidth: .infinity).padding(.vertical, 4)
                        .background(Color.oceanTeal.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    HStack(spacing: 6) {
                        addBtn("Own", color: .oceanTeal) { addSet(set, status: "owned") }
                        addBtn("Want", color: .coral) { addSet(set, status: "want") }
                    }
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    private func addBtn(_ label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.custom("DMSans-Medium", size: 10)).foregroundColor(color)
                .frame(maxWidth: .infinity).padding(.vertical, 5)
                .background(color.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func addSet(_ set: RBSet, status: String) {
        let themeName = service.themes.first(where: { $0.id == set.themeId })?.name ?? "Lego"
        let legoSet = LegoSet(
            setNum: set.setNum,
            name: set.name,
            year: set.year,
            themeId: set.themeId,
            themeName: themeName,
            numParts: set.numParts,
            imageURL: set.imageURL?.absoluteString ?? ""
        )
        legoSet.statusRaw = status
        modelContext.insert(legoSet)
        try? modelContext.save()
        if let userId = authService.userId {
            Task { await SupabaseSyncService.shared.pushLegoSet(legoSet, userId: userId) }
        }
    }
}
