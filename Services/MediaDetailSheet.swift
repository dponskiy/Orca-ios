//
//  MediaDetailSheet.swift
//  Orca
//

import SwiftUI
import SwiftData

struct MediaDetailSheet: View {
    let title: String
    let type: String  // "movie", "tv", "book"
    let existingPosterURL: URL?
    // Supplied when opened from a shelf or list — enables the status controls.
    // Nil when opened from Discover, where there's nothing to update yet.
    var item: WatchlistItem? = nil
    // Host fires the rating prompt; this sheet only moves the status.
    var onCompleted: ((WatchlistItem) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var detail: MediaDetail? = nil
    @State private var isLoading = true
    @State private var showPosterPicker = false

    private let tmdb = TMDBService.shared

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if let detail {
                    detailView(detail)
                } else {
                    errorView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.oceanTeal)
                }
                // Posters are matched by title search, which guesses wrong on
                // remakes and generic titles. Nothing detects that automatically —
                // this is the manual correction.
                if type != "book" {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showPosterPicker = true
                        } label: {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 15))
                                .foregroundColor(.oceanTeal)
                        }
                    }
                }
            }
        }
        .task {
            let tmdbType = type == "show" ? "tv" : type
            detail = await tmdb.fetchDetail(title: title, type: tmdbType)
            isLoading = false
        }
        .sheet(isPresented: $showPosterPicker) {
            PosterPickerSheet(title: title, type: type == "show" ? "tv" : type)
        }
    }

    // MARK: - Detail View

    private func detailView(_ detail: MediaDetail) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                // Backdrop header
                backdropHeader(detail)

                // Content
                VStack(alignment: .leading, spacing: 20) {
                    statusSection

                    // Title + meta
                    VStack(alignment: .leading, spacing: 6) {
                        Text(detail.title)
                            .font(.custom("DMSans-Medium", size: 22))
                            .foregroundColor(.deepNavy)

                        HStack(spacing: 10) {
                            if !detail.year.isEmpty {
                                Text(detail.year)
                                    .font(.custom("DMMono-Regular", size: 13))
                                    .foregroundColor(.gray)
                            }
                            if let runtime = detail.runtime {
                                Text("·").foregroundColor(.gray.opacity(0.4))
                                Text(runtime)
                                    .font(.custom("DMMono-Regular", size: 13))
                                    .foregroundColor(.gray)
                            }
                            if detail.rating > 0 {
                                Text("·").foregroundColor(.gray.opacity(0.4))
                                HStack(spacing: 3) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.coral)
                                    Text(String(format: "%.1f", detail.rating))
                                        .font(.custom("DMMono-Regular", size: 13))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }

                    // Genre chips
                    if !detail.genres.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(detail.genres.prefix(5), id: \.self) { genre in
                                    Text(genre)
                                        .font(.custom("DMSans-Medium", size: 12))
                                        .foregroundColor(.oceanTeal)
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(Color.oceanTeal.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    // External link (books → Google Books)
                    if let url = detail.externalURL {
                        Link(destination: url) {
                            HStack(spacing: 8) {
                                Image(systemName: "books.vertical")
                                    .font(.system(size: 13))
                                Text("View on Open Library")
                                    .font(.custom("DMSans-Medium", size: 14))
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.oceanTeal)
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(Color.oceanTeal.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // Overview
                    if !detail.overview.isEmpty && detail.overview != "No description available." {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(detail.mediaType == "book" ? "DESCRIPTION" : "OVERVIEW")
                                .font(.custom("DMSans-Medium", size: 11))
                                .foregroundColor(.gray)
                                .tracking(0.5)
                            Text(detail.overview)
                                .font(.custom("DMSans-Regular", size: 15))
                                .foregroundColor(.deepNavy)
                                .lineSpacing(4)
                        }
                    }

                    // Cast / Authors
                    if !detail.cast.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(detail.mediaType == "book" ? "AUTHORS" : "CAST")
                                .font(.custom("DMSans-Medium", size: 11))
                                .foregroundColor(.gray)
                                .tracking(0.5)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(detail.cast) { member in
                                        castCard(member: member, isBook: detail.mediaType == "book")
                                    }
                                }
                                .padding(.bottom, 4)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .background(Color.pearl.ignoresSafeArea())
    }

    // MARK: - Backdrop Header

    private func backdropHeader(_ detail: MediaDetail) -> some View {
        ZStack(alignment: .bottom) {
            // Blurred backdrop
            Group {
                if let url = detail.backdropURL ?? detail.posterURL ?? existingPosterURL {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color.deepNavy
                        }
                    }
                } else {
                    Color.deepNavy
                }
            }
            .frame(maxWidth: .infinity).frame(height: 220)
            .clipped()
            .blur(radius: 20)
            .overlay(Color.black.opacity(0.5))

            // Gradient fade to pearl
            LinearGradient(
                colors: [Color.clear, Color.pearl],
                startPoint: UnitPoint(x: 0.5, y: 0.4),
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity).frame(height: 220)

            // Poster — sits half in the header, half below
            if let url = detail.posterURL ?? existingPosterURL {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        posterPlaceholder
                    }
                }
                .frame(width: 110, height: 163)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 6)
                .offset(y: 40)
            } else {
                posterPlaceholder
                    .frame(width: 110, height: 163)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .offset(y: 40)
            }
        }
        .frame(maxWidth: .infinity).frame(height: 220)
        .padding(.bottom, 44) // room for the poster overhang
    }

    private var posterPlaceholder: some View {
        ZStack {
            Color.mist
            Image(systemName: type == "book" ? "book.closed.fill" : type == "movie" ? "film.fill" : "tv.fill")
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.4))
        }
    }

    // MARK: - Cast Card

    private func castCard(member: CastMember, isBook: Bool) -> some View {
        VStack(spacing: 6) {
            if isBook {
                ZStack {
                    Circle()
                        .fill(Color.oceanTeal.opacity(0.12))
                        .frame(width: 60, height: 60)
                    Image(systemName: "person.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.oceanTeal.opacity(0.6))
                }
            } else if let url = member.photoURL {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Circle().fill(Color.mist)
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.mist)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.gray.opacity(0.3))
                    )
            }

            Text(member.name)
                .font(.custom("DMSans-Medium", size: 12))
                .foregroundColor(.deepNavy)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 72)

            if !member.character.isEmpty && !isBook {
                Text(member.character)
                    .font(.custom("DMSans-Regular", size: 11))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .frame(width: 72)
            }
        }
    }

    // MARK: - Loading / Error

    private var loadingView: some View {
        VStack(spacing: 16) {
            if let url = existingPosterURL {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 178)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else { Color.clear }
                }
                .frame(width: 120, height: 178)
            }
            ProgressView().tint(.oceanTeal)
            Text("Loading details...")
                .font(.custom("DMSans-Regular", size: 14))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.pearl)
    }

    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.4))
            Text("Couldn't load details")
                .font(.custom("DMSans-Medium", size: 16))
                .foregroundColor(.deepNavy)
            Text("Check your connection and try again")
                .font(.custom("DMSans-Regular", size: 14))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.pearl)
    }

    // MARK: - Status
    //
    // Shelves have no rows to swipe, so changing where something lives happens here.

    private struct StatusOption: Identifiable {
        let id: String        // stored WatchlistItem.status value
        let label: String
        let icon: String
    }

    private var statusOptions: [StatusOption] {
        let isBook = type == "book"
        return [
            StatusOption(id: "queued",    label: "Up next",  icon: "bookmark"),
            StatusOption(id: "watching",  label: isBook ? "Reading" : "Watching", icon: "play.circle"),
            StatusOption(id: "completed", label: "Finished", icon: "checkmark.circle")
        ]
    }

    @ViewBuilder
    private var statusSection: some View {
        if let item {
            VStack(alignment: .leading, spacing: 8) {
                Text("STATUS")
                    .font(.custom("DMSans-Medium", size: 11))
                    .foregroundColor(.gray)
                    .tracking(0.5)

                HStack(spacing: 8) {
                    ForEach(statusOptions) { option in
                        let active = item.status.lowercased() == option.id
                        Button {
                            setStatus(option.id, on: item)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: option.icon).font(.system(size: 14))
                                Text(option.label).font(.custom("DMSans-Medium", size: 12))
                            }
                            .foregroundColor(active ? .white : .oceanTeal)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(active ? Color.oceanTeal : Color.oceanTeal.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if (item.rating ?? 0) > 0 || !(item.comment ?? "").isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        if let rating = item.rating, rating > 0 {
                            HStack(spacing: 3) {
                                ForEach(0..<min(rating, 5), id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 11)).foregroundColor(.coral)
                                }
                                Text("your rating")
                                    .font(.custom("DMSans-Regular", size: 11)).foregroundColor(.gray)
                                    .padding(.leading, 4)
                            }
                        }
                        if let comment = item.comment, !comment.isEmpty {
                            Text(comment)
                                .font(.custom("DMSans-Regular", size: 14))
                                .foregroundColor(.deepNavy)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.coral.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func setStatus(_ newStatus: String, on item: WatchlistItem) {
        guard item.status.lowercased() != newStatus else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(duration: 0.25)) {
            item.status = newStatus
            item.completedAt = (newStatus == "completed") ? Date() : nil
            if newStatus != "completed" { item.rating = nil; item.comment = nil }
            item.updatedAt = Date()
        }
        try? modelContext.save()
        if newStatus == "completed" {
            // Host owns the rating prompt — dismiss first so sheets don't stack
            let finished = item
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onCompleted?(finished) }
        }
    }
}

// MARK: - Poster Picker
//
// Shows every poster TMDB returns for the title so a wrong first-result match
// can be corrected. The choice is stored locally (never synced), so a bad guess
// is always fixable and never propagates to the user's other devices.

struct PosterPickerSheet: View {
    let title: String
    let type: String

    @Environment(\.dismiss) private var dismiss
    @State private var tmdb = TMDBService.shared
    @State private var options: [URL] = []
    @State private var isLoading = true

    private let columns = [GridItem(.flexible(), spacing: 12),
                           GridItem(.flexible(), spacing: 12),
                           GridItem(.flexible(), spacing: 12)]

    private var currentURL: URL? { tmdb.posterURL(title: title, type: type) ?? nil }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack { Spacer(); ProgressView().tint(.oceanTeal); Spacer() }
                } else if options.isEmpty {
                    VStack(spacing: 10) {
                        Spacer()
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: 34)).foregroundColor(.gray.opacity(0.35))
                        Text("No other posters found")
                            .font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy)
                        Text("TMDB only has one image for this title")
                            .font(.custom("DMSans-Regular", size: 13)).foregroundColor(.gray)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        Text("Tap the poster that matches")
                            .font(.custom("DMSans-Regular", size: 13))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16).padding(.top, 12)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(options, id: \.absoluteString) { url in
                                let isCurrent = url == currentURL
                                Button {
                                    tmdb.setPosterOverride(title: title, type: type, url: url)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    dismiss()
                                } label: {
                                    AsyncImage(url: url) { phase in
                                        if case .success(let img) = phase {
                                            img.resizable().scaledToFit()
                                        } else {
                                            ZStack { Color.mist; ProgressView().scaleEffect(0.6) }
                                                .aspectRatio(0.667, contentMode: .fit)
                                        }
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isCurrent ? Color.oceanTeal : Color.clear, lineWidth: 2.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Color.pearl.ignoresSafeArea())
            .navigationTitle("Choose Poster")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.gray)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Reset") {
                        tmdb.clearPosterOverride(title: title, type: type)
                        dismiss()
                    }
                    .foregroundColor(.oceanTeal)
                }
            }
        }
        .task {
            options = await tmdb.posterOptions(title: title, type: type)
            isLoading = false
        }
    }
}
