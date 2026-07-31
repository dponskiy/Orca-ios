//
//  TCGSetBrowserView.swift
//  Orca

import SwiftUI
import SwiftData

struct TCGSetBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var allCards: [TCGCard]
    @State private var service = PokemonTCGService.shared
    @State private var searchText = ""

    private var cardsBySet: [String: [TCGCard]] {
        Dictionary(grouping: allCards) { $0.setId }
    }

    private var filteredGroups: [(series: String, sets: [PokemonSet])] {
        let groups = service.seriesGroups()
        guard !searchText.isEmpty else { return groups }
        return groups.compactMap { group in
            let filtered = group.sets.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            return filtered.isEmpty ? nil : (group.series, filtered)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if service.isFetchingSets {
                    VStack(spacing: 16) {
                        Spacer()
                        ProgressView().tint(.oceanTeal)
                        Text("Loading sets...").font(.custom("DMSans-Regular", size: 14)).foregroundColor(.gray)
                        Spacer()
                    }
                } else if service.fetchSetsError {
                    VStack(spacing: 14) {
                        Spacer()
                        Image(systemName: "wifi.slash").font(.system(size: 32)).foregroundColor(.gray.opacity(0.6))
                        Text("Couldn't load sets").font(.custom("DMSans-Medium", size: 16)).foregroundColor(.deepNavy)
                        Text("Check your connection and try again.")
                            .font(.custom("DMSans-Regular", size: 13)).foregroundColor(.gray)
                        Button { Task { await service.fetchSets() } } label: {
                            Text("Retry")
                                .font(.custom("DMSans-Medium", size: 14))
                                .foregroundColor(.white)
                                .padding(.horizontal, 28).padding(.vertical, 10)
                                .background(Color.oceanTeal)
                                .clipShape(Capsule())
                        }
                        .padding(.top, 4)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24, pinnedViews: [.sectionHeaders]) {
                            ForEach(filteredGroups, id: \.series) { group in
                                Section {
                                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                        ForEach(group.sets) { set in
                                            NavigationLink(destination: TCGSetDetailView(setId: set.id, setName: set.name)) {
                                                setCard(set: set)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                } header: {
                                    Text(group.series)
                                        .font(.custom("DMSans-Medium", size: 13))
                                        .foregroundColor(.gray)
                                        .tracking(0.3)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.pearl)
                                }
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .background(Color.pearl.ignoresSafeArea())
            .searchable(text: $searchText, prompt: "Search sets...")
            .navigationTitle("Pokémon Sets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.oceanTeal)
                }
            }
            .task { await service.fetchSets() }
        }
    }

    private func setCard(set: PokemonSet) -> some View {
        let myCards = cardsBySet[set.id] ?? []
        let owned = myCards.filter { $0.isOwned }.count
        let hasAny = owned > 0

        return VStack(spacing: 0) {
            // Logo
            ZStack {
                Color.deepNavy.opacity(0.04)
                if let url = set.logoURL {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().aspectRatio(contentMode: .fit).padding(12)
                        } else { Color.clear }
                    }
                } else {
                    Image(systemName: "sparkles").font(.system(size: 28)).foregroundColor(.oceanTeal.opacity(0.3))
                }
            }
            .frame(maxWidth: .infinity).frame(height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(set.name)
                    .font(.custom("DMSans-Medium", size: 12))
                    .foregroundColor(.deepNavy)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text("\(set.printedTotal) cards")
                        .font(.custom("DMMono-Regular", size: 10))
                        .foregroundColor(.gray)
                    Spacer()
                    if hasAny {
                        Text("\(owned)/\(set.printedTotal)")
                            .font(.custom("DMSans-Medium", size: 10))
                            .foregroundColor(.oceanTeal)
                    }
                }

                if hasAny {
                    let progress = Double(owned) / Double(max(set.printedTotal, 1))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(Color.mist).frame(height: 3)
                            RoundedRectangle(cornerRadius: 2).fill(Color.oceanTeal)
                                .frame(width: geo.size.width * progress, height: 3)
                        }
                    }
                    .frame(height: 3)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(hasAny ? Color.oceanTeal.opacity(0.25) : Color.black.opacity(0.07), lineWidth: hasAny ? 1 : 0.5)
        )
        .shadow(color: .black.opacity(hasAny ? 0.08 : 0.04), radius: 6, y: 2)
    }
}
