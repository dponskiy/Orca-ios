//
//  SmiskiView.swift
//  Orca

import SwiftUI
import SwiftData

// MARK: - Main series list (embedded in CollectiblesView)

struct SmiskiCollectionContent: View {
    @Query private var allItems: [SmiskiItem]
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @State private var showBrowser = false
    @State private var showGallery = false
    @State private var detailItem: SmiskiItem? = nil

    private var ownedCount: Int { allItems.filter { $0.isOwned }.count }
    private var chasingCount: Int { allItems.filter { !$0.isOwned }.count }

    private var touchedSeries: [(series: SmiskiSeriesInfo, owned: Int, chasing: Int)] {
        SmiskiCatalog.allSeries.compactMap { series in
            let seriesItems = allItems.filter { $0.seriesId == series.id }
            guard !seriesItems.isEmpty else { return nil }
            return (series, seriesItems.filter { $0.isOwned }.count, seriesItems.filter { !$0.isOwned }.count)
        }
        .sorted { $0.owned > $1.owned }
    }

    var body: some View {
        // VStack (not Group) — Group distributes modifiers to each child, which
        // re-anchors presentations on content changes and resets their state
        VStack(spacing: 0) {
            if !allItems.isEmpty {
                smiskiStatsStrip
            }
            if !touchedSeries.isEmpty {
                browseButton
                seriesSection
                allOwnedSection
            } else {
                emptyState
            }
        }
        .sheet(item: $detailItem) { item in
            SmiskiItemDetailSheet(item: item)
                .presentationDetents([.height(300)])
        }
    }

    private var smiskiStatsStrip: some View {
        HStack(spacing: 0) {
            statCell(value: "\(ownedCount)", label: "Owned")
            Divider().frame(height: 36)
            statCell(value: "\(chasingCount)", label: "Chasing")
            Divider().frame(height: 36)
            statCell(value: "\(touchedSeries.count)", label: "Series")
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

    private var seriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("YOUR SERIES")
                    .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).tracking(0.5)
                Spacer()
                Button { showBrowser = true } label: {
                    Text("Browse all").font(.custom("DMSans-Medium", size: 13)).foregroundColor(.oceanTeal)
                }
            }
            .padding(.horizontal, 20)

            ForEach(touchedSeries, id: \.series.id) { item in
                NavigationLink(destination: SmiskiSeriesDetailView(series: item.series)) {
                    seriesRow(series: item.series, owned: item.owned, chasing: item.chasing)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 20)
        .sheet(isPresented: $showBrowser) { SmiskiAllSeriesView() }
    }

    private func seriesRow(series: SmiskiSeriesInfo, owned: Int, chasing: Int) -> some View {
        let total = series.figures.count
        let progress: Double = Double(owned) / Double(max(total, 1))

        return HStack(spacing: 14) {
            Text(series.emoji)
                .font(.system(size: 26))
                .frame(width: 40, height: 40)
                .background(Color.oceanTeal.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(series.name).font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy)
                    Spacer()
                    Text("\(owned)/\(total)").font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.mist).frame(height: 5)
                        RoundedRectangle(cornerRadius: 3).fill(Color.oceanTeal)
                            .frame(width: geo.size.width * progress, height: 5)
                    }
                }
                .frame(height: 5)
                if chasing > 0 {
                    Text("\(chasing) chasing").font(.custom("DMSans-Regular", size: 11)).foregroundColor(.coral)
                }
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
            Button { showBrowser = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.grid.2x2")
                    Text("Browse Series").font(.custom("DMSans-Medium", size: 15))
                }
                .foregroundColor(.oceanTeal)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color.oceanTeal.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
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
        }
        .padding(.horizontal, 20).padding(.top, 20)
        .sheet(isPresented: $showBrowser) { SmiskiAllSeriesView() }
        .fullScreenCover(isPresented: $showGallery) { CollectionShowcaseView(category: .smiski) }
    }

    private var allOwnedSection: some View {
        let owned = allItems.filter { $0.isOwned }.sorted { $0.seriesName < $1.seriesName }
        let chasing = allItems.filter { !$0.isOwned }.sorted { $0.seriesName < $1.seriesName }
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

        return VStack(alignment: .leading, spacing: 12) {
            if !owned.isEmpty {
                Text("ALL OWNED")
                    .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).tracking(0.5)
                    .padding(.horizontal, 20)
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(owned) { item in ownedFigureCell(item, isOwned: true) }
                }
                .padding(.horizontal, 16)
            }
            if !chasing.isEmpty {
                Text("CHASING")
                    .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.coral).tracking(0.5)
                    .padding(.horizontal, 20)
                    .padding(.top, owned.isEmpty ? 0 : 16)
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(chasing) { item in ownedFigureCell(item, isOwned: false) }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 24)
    }

    private func ownedFigureCell(_ item: SmiskiItem, isOwned: Bool) -> some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.22, green: 0.40, blue: 0.22))
                    .opacity(isOwned ? 1 : 0.5)
                if let urlStr = item.imageURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().aspectRatio(contentMode: .fit).padding(6)
                                .saturation(isOwned ? 1 : 0.35)
                        } else { Text("👻").font(.system(size: 18)) }
                    }
                } else {
                    Text("👻").font(.system(size: 18))
                        .saturation(isOwned ? 1 : 0.35)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .shadow(color: isOwned ? Color.oceanTeal.opacity(0.25) : .clear, radius: 6, y: 2)

            Text(item.figureName)
                .font(.custom("DMSans-Medium", size: 9))
                .foregroundColor(isOwned ? .deepNavy : .gray)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
            Text(item.seriesName)
                .font(.custom("DMSans-Regular", size: 8))
                .foregroundColor(.gray.opacity(0.7))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .onTapGesture { cycleSmiskiItem(item) }
        .onLongPressGesture { detailItem = item }
    }

    private func cycleSmiskiItem(_ item: SmiskiItem) {
        if item.isOwned {
            item.isOwned = false
            try? modelContext.save()
            if let userId = authService.userId {
                Task { await SupabaseSyncService.shared.pushSmiskiItem(item, userId: userId) }
            }
        } else {
            let id = item.id
            modelContext.delete(item)
            try? modelContext.save()
            Task { await SupabaseSyncService.shared.deleteSmiskiItem(id: id) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)
            Text("👻").font(.system(size: 56))
            VStack(spacing: 8) {
                Text("Start your Smiski collection")
                    .font(.custom("DMSans-Medium", size: 20)).foregroundColor(.deepNavy)
                Text("Browse series and tap figures you own\nor ones you're chasing.")
                    .font(.custom("DMSans-Regular", size: 14)).foregroundColor(.gray).multilineTextAlignment(.center)
            }
            Button { showBrowser = true } label: {
                Text("Browse Series").font(.custom("DMSans-Medium", size: 16)).foregroundColor(.white)
                    .padding(.horizontal, 32).padding(.vertical, 13)
                    .background(Color.oceanTeal).clipShape(Capsule())
            }
        }
        .padding(.horizontal, 40).padding(.top, 20)
        .sheet(isPresented: $showBrowser) { SmiskiAllSeriesView() }
    }
}

// MARK: - All series browser (sheet)

struct SmiskiAllSeriesView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var allItems: [SmiskiItem]
    @State private var searchText = ""

    private var filteredSeries: [SmiskiSeriesInfo] {
        guard !searchText.isEmpty else { return SmiskiCatalog.allSeries }
        return SmiskiCatalog.allSeries.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filteredSeries) { series in
                        NavigationLink(destination: SmiskiSeriesDetailView(series: series)) {
                            seriesCard(series: series)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .padding(.bottom, 30)
            }
            .background(Color.pearl.ignoresSafeArea())
            .searchable(text: $searchText, prompt: "Search series...")
            .navigationTitle("Smiski Series")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.oceanTeal)
                }
            }
        }
    }

    private func seriesCard(series: SmiskiSeriesInfo) -> some View {
        let myItems = allItems.filter { $0.seriesId == series.id }
        let owned = myItems.filter { $0.isOwned }.count
        let total = series.figures.count
        let hasAny = owned > 0

        return VStack(spacing: 0) {
            ZStack {
                Color(red: 0.22, green: 0.40, blue: 0.22).opacity(hasAny ? 0.85 : 0.3)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                if let firstURL = series.regularFigures.first?.imageURL.flatMap({ URL(string: $0) }) {
                    AsyncImage(url: firstURL) { phase in
                        if case .success(let img) = phase {
                            img.resizable().aspectRatio(contentMode: .fit).padding(8)
                                .saturation(hasAny ? 1 : 0)
                        } else { Text(series.emoji).font(.system(size: 36)) }
                    }
                } else {
                    Text(series.emoji).font(.system(size: 36))
                }
            }
            .frame(maxWidth: .infinity).frame(height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(series.name)
                    .font(.custom("DMSans-Medium", size: 12)).foregroundColor(.deepNavy).lineLimit(2)
                HStack {
                    Text("\(total) figures").font(.custom("DMMono-Regular", size: 10)).foregroundColor(.gray)
                    Spacer()
                    if hasAny { Text("\(owned)/\(total)").font(.custom("DMSans-Medium", size: 10)).foregroundColor(.oceanTeal) }
                }
                if hasAny {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(Color.mist).frame(height: 3)
                            RoundedRectangle(cornerRadius: 2).fill(Color.oceanTeal)
                                .frame(width: geo.size.width * (Double(owned) / Double(max(total, 1))), height: 3)
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

// MARK: - Series detail (figure grid)

struct SmiskiSeriesDetailView: View {
    let series: SmiskiSeriesInfo

    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Query private var allItems: [SmiskiItem]
    @State private var actionFigure: SmiskiFigureInfo? = nil

    private var myItems: [SmiskiItem] { allItems.filter { $0.seriesId == series.id } }
    private var ownedIds: Set<String> { Set(myItems.filter { $0.isOwned }.map { $0.figureId }) }
    private var chasingIds: Set<String> { Set(myItems.filter { !$0.isOwned }.map { $0.figureId }) }

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                seriesHeader
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(series.regularFigures) { figure in figureCell(figure) }
                    if let secret = series.secretFigure {
                        figureCell(secret)
                    }
                }
                .padding(12)
            }
        }
        .background(Color.pearl.ignoresSafeArea())
        .navigationTitle(series.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $actionFigure) { figure in
            SmiskiActionSheet(
                figure: figure,
                existingItem: myItems.first(where: { $0.figureId == figure.id }),
                onAction: { action in handleAction(action, for: figure) }
            )
            .presentationDetents([.height(260)])
        }
    }

    private var seriesHeader: some View {
        let owned = ownedIds.count
        let total = series.figures.count
        let progress = Double(owned) / Double(max(total, 1))

        return VStack(spacing: 10) {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(owned) / \(total)")
                        .font(.custom("DMSans-Medium", size: 22)).foregroundColor(.deepNavy)
                    Text("figures owned")
                        .font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                }
                Spacer()
                Text(series.emoji).font(.system(size: 40))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.mist).frame(height: 7)
                    RoundedRectangle(cornerRadius: 4).fill(
                        LinearGradient(colors: [.oceanTeal, .seafoam], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: geo.size.width * min(progress, 1.0), height: 7)
                    .animation(.spring(duration: 0.4), value: owned)
                }
            }
            .frame(height: 7)
            Text("\(Int(progress * 100))% complete")
                .font(.custom("DMMono-Regular", size: 11)).foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Color.white)
        .overlay(Divider(), alignment: .bottom)
    }

    private func figureCell(_ figure: SmiskiFigureInfo) -> some View {
        let isOwned = ownedIds.contains(figure.id)
        let isChasing = chasingIds.contains(figure.id)
        let saturation: Double = isOwned ? 1 : (isChasing ? 0.35 : 0)
        let opacity: Double = isOwned ? 1 : (isChasing ? 0.75 : 0.55)

        return ZStack(alignment: .topTrailing) {
            VStack(spacing: 5) {
                ZStack {
                    // Dark green circle background matching the Smiski brand
                    Circle()
                        .fill(Color(red: 0.22, green: 0.40, blue: 0.22))
                        .saturation(isOwned ? 1 : (isChasing ? 0.3 : 0))
                        .opacity(isOwned ? 1 : 0.6)

                    if let urlStr = figure.imageURL, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .padding(6)
                                    .saturation(saturation)
                                    .opacity(opacity)
                                    .animation(.easeInOut(duration: 0.45), value: isOwned)
                            case .empty:
                                ProgressView().scaleEffect(0.5).tint(.white.opacity(0.5))
                            default:
                                Text("👻").font(.system(size: 20)).opacity(0.6)
                            }
                        }
                    } else {
                        Text("👻")
                            .font(.system(size: figure.isSecret ? 22 : 18))
                            .saturation(saturation)
                            .opacity(opacity)
                    }

                    // Glow ring when owned
                    if isOwned {
                        Circle()
                            .stroke(Color.oceanTeal.opacity(0.5), lineWidth: 2)
                            .scaleEffect(1.05)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .shadow(color: isOwned ? Color.oceanTeal.opacity(0.3) : .clear, radius: 8, y: 2)
                .animation(.easeInOut(duration: 0.45), value: isOwned)

                Text(figure.name)
                    .font(.custom("DMSans-Medium", size: 9))
                    .foregroundColor(isOwned ? .deepNavy : .gray.opacity(0.7))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .onTapGesture {
                if myItems.first(where: { $0.figureId == figure.id }) == nil {
                    addFigure(figure, status: "owned")
                } else {
                    actionFigure = figure
                }
            }

            // Status badge
            if isChasing {
                Image(systemName: "sparkle")
                    .font(.system(size: 8, weight: .bold)).foregroundColor(.white)
                    .padding(4).background(Color.coral).clipShape(Circle()).padding(2)
            } else if isOwned {
                Image(systemName: "checkmark")
                    .font(.system(size: 7, weight: .bold)).foregroundColor(.white)
                    .padding(4).background(Color.oceanTeal).clipShape(Circle()).padding(2)
            }
        }
    }

    private func addFigure(_ figure: SmiskiFigureInfo, status: String) {
        let item = SmiskiItem(
            figureId: figure.id,
            seriesId: series.id,
            seriesName: series.name,
            figureName: figure.name,
            isSecret: figure.isSecret
        )
        item.statusRaw = status
        modelContext.insert(item)
        try? modelContext.save()
        if let userId = authService.userId {
            Task { await SupabaseSyncService.shared.pushSmiskiItem(item, userId: userId) }
        }
    }

    private func handleAction(_ action: SmiskiAction, for figure: SmiskiFigureInfo) {
        let existing = myItems.first(where: { $0.figureId == figure.id })
        switch action {
        case .markOwned:
            if let e = existing {
                e.isOwned = true
                try? modelContext.save()
                if let userId = authService.userId { Task { await SupabaseSyncService.shared.pushSmiskiItem(e, userId: userId) } }
            } else { addFigure(figure, status: "owned") }
        case .markChasing:
            if let e = existing {
                e.isOwned = false
                try? modelContext.save()
                if let userId = authService.userId { Task { await SupabaseSyncService.shared.pushSmiskiItem(e, userId: userId) } }
            } else { addFigure(figure, status: "chasing") }
        case .remove:
            if let e = existing {
                let id = e.id
                modelContext.delete(e)
                try? modelContext.save()
                Task { await SupabaseSyncService.shared.deleteSmiskiItem(id: id) }
            }
        }
    }
}

// MARK: - Action sheet

enum SmiskiAction { case markOwned, markChasing, remove }

struct SmiskiActionSheet: View {
    let figure: SmiskiFigureInfo
    let existingItem: SmiskiItem?
    let onAction: (SmiskiAction) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showRemoveConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 4).padding(.top, 12)

            HStack(spacing: 14) {
                Text("👻").font(.system(size: 44))
                VStack(alignment: .leading, spacing: 4) {
                    Text(figure.name).font(.custom("DMSans-Medium", size: 16)).foregroundColor(.deepNavy)
                    if figure.isSecret {
                        Text("Secret Figure").font(.custom("DMSans-Regular", size: 12)).foregroundColor(.coral)
                    }
                    if let item = existingItem {
                        Text(item.isOwned ? "Owned" : "Chasing")
                            .font(.custom("DMMono-Regular", size: 12))
                            .foregroundColor(item.isOwned ? .oceanTeal : .coral)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 16)

            Divider().padding(.top, 14)

            VStack(spacing: 0) {
                if existingItem?.isOwned != true {
                    actionRow(icon: "checkmark.circle.fill", label: "Mark as Owned", color: .oceanTeal) {
                        onAction(.markOwned); dismiss()
                    }
                }
                if existingItem?.isOwned != false {
                    actionRow(icon: "sparkle", label: "Add to Chase List", color: .coral) {
                        onAction(.markChasing); dismiss()
                    }
                }
                if existingItem != nil {
                    actionRow(icon: "trash", label: "Remove from Collection", color: .coral) {
                        showRemoveConfirm = true
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 4)
        }
        .background(Color.pearl)
        .alert("Remove \(figure.name)?", isPresented: $showRemoveConfirm) {
            Button("Remove", role: .destructive) { onAction(.remove); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove it from your collection.")
        }
    }

    private func actionRow(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16)).foregroundColor(color).frame(width: 24)
                Text(label).font(.custom("DMSans-Regular", size: 15))
                    .foregroundColor(label.contains("Remove") ? .coral : .deepNavy)
                Spacer()
            }
            .padding(.vertical, 14).padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .overlay(Divider(), alignment: .bottom)
    }
}

// MARK: - Smiski Item Detail Sheet (tap from ALL OWNED / CHASING grid)

struct SmiskiItemDetailSheet: View {
    let item: SmiskiItem
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

            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color(red: 0.22, green: 0.40, blue: 0.22))
                    if let urlStr = item.imageURL, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            if case .success(let img) = phase {
                                img.resizable().aspectRatio(contentMode: .fit).padding(6)
                            } else { Text("👻").font(.system(size: 22)) }
                        }
                    } else {
                        Text("👻").font(.system(size: 22))
                    }
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.figureName)
                        .font(.custom("DMSans-Medium", size: 16)).foregroundColor(.deepNavy)
                    Text(item.seriesName)
                        .font(.custom("DMSans-Regular", size: 13)).foregroundColor(.gray)
                    if item.isSecret {
                        Text("Secret Figure")
                            .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.coral)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 16)

            Divider().padding(.top, 16)

            HStack(spacing: 12) {
                statusButton(label: "In Collection", icon: "checkmark.circle.fill",
                             active: item.isOwned, color: .oceanTeal) {
                    item.isOwned = true
                    try? modelContext.save()
                    if let userId = authService.userId {
                        Task { await SupabaseSyncService.shared.pushSmiskiItem(item, userId: userId) }
                    }
                }
                statusButton(label: "Chasing", icon: "sparkle",
                             active: !item.isOwned, color: .coral) {
                    item.isOwned = false
                    try? modelContext.save()
                    if let userId = authService.userId {
                        Task { await SupabaseSyncService.shared.pushSmiskiItem(item, userId: userId) }
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 16)

            Button {
                showRemoveConfirm = true
            } label: {
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
        .alert("Remove \(item.figureName)?", isPresented: $showRemoveConfirm) {
            Button("Remove", role: .destructive) {
                let id = item.id
                modelContext.delete(item)
                try? modelContext.save()
                Task { await SupabaseSyncService.shared.deleteSmiskiItem(id: id) }
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
