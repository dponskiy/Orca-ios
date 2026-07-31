//
//  MediaDetailSheet.swift
//  Orca
//

import SwiftUI

struct MediaDetailSheet: View {
    let title: String
    let type: String  // "movie", "tv", "book"
    let existingPosterURL: URL?

    @Environment(\.dismiss) private var dismiss
    @State private var detail: MediaDetail? = nil
    @State private var isLoading = true

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
            }
        }
        .task {
            let tmdbType = type == "show" ? "tv" : type
            detail = await tmdb.fetchDetail(title: title, type: tmdbType)
            isLoading = false
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
}
