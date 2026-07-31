//
//  TMDBService.swift
//  Orca
//

import Foundation

struct TMDBItem: Identifiable {
    let id: Int
    let title: String
    let overview: String
    let posterPath: String?
    let releaseYear: String
    let rating: Double
    let mediaType: String // "movie" or "tv"

    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w200\(path)")
    }

    var watchlistType: String {
        if mediaType == "tv" { return "show" }
        if mediaType == "book" { return "book" }
        return "movie"
    }
    // sheet(item:) needs Identifiable — use string so UUID-based sheet doesn't conflict
    var sheetId: String { "\(id)-\(mediaType)" }
}

struct MediaDetail {
    let title: String
    let overview: String
    let posterURL: URL?
    let backdropURL: URL?
    let rating: Double
    let year: String
    let genres: [String]
    let runtime: String?
    let cast: [CastMember]
    let mediaType: String
    let externalURL: URL?
}

struct TrendingBook: Identifiable {
    let id: String
    let title: String
    let author: String
    let coverURL: URL?
    let year: String
}

struct CastMember: Identifiable {
    let id: Int
    let name: String
    let character: String
    let photoURL: URL?
}

@Observable
class TMDBService {
    static let shared = TMDBService()

    var trendingMovies: [TMDBItem] = []
    var trendingShows: [TMDBItem] = []
    var trendingBooks: [TrendingBook] = []
    var genreMovies: [TMDBItem] = []
    var genreShows: [TMDBItem] = []
    var genreBooks: [TrendingBook] = []
    var isLoading = false
    var isGenreLoading = false

    // keyed by "title|||type" → poster URL (nil = not found, absent = not fetched yet)
    var posterCache: [String: URL?] = [:]

    // keyed by book title → cover URL for discover cards that had no cover_i
    var bookCoverCache: [String: URL?] = [:]

    private let baseURL = "https://api.themoviedb.org/3"

    // MARK: - Genre definitions

    struct DiscoverGenre: Identifiable, Equatable {
        let id: String
        let label: String
        let movieGenreId: Int?
        let tvGenreId: Int?
        let olSubject: String?
    }

    static let genres: [DiscoverGenre] = [
        DiscoverGenre(id: "action",    label: "Action",     movieGenreId: 28,    tvGenreId: 10759, olSubject: "action"),
        DiscoverGenre(id: "comedy",    label: "Comedy",     movieGenreId: 35,    tvGenreId: 35,    olSubject: "humor"),
        DiscoverGenre(id: "drama",     label: "Drama",      movieGenreId: 18,    tvGenreId: 18,    olSubject: "drama"),
        DiscoverGenre(id: "horror",    label: "Horror",     movieGenreId: 27,    tvGenreId: 9648,  olSubject: "horror"),
        DiscoverGenre(id: "scifi",     label: "Sci-Fi",     movieGenreId: 878,   tvGenreId: 10765, olSubject: "science_fiction"),
        DiscoverGenre(id: "romance",   label: "Romance",    movieGenreId: 10749, tvGenreId: nil,   olSubject: "romance"),
        DiscoverGenre(id: "thriller",  label: "Thriller",   movieGenreId: 53,    tvGenreId: 9648,  olSubject: "thriller"),
        DiscoverGenre(id: "fantasy",   label: "Fantasy",    movieGenreId: 14,    tvGenreId: 10765, olSubject: "fantasy"),
        DiscoverGenre(id: "animation", label: "Animation",  movieGenreId: 16,    tvGenreId: 16,    olSubject: nil),
    ]

    // MARK: - Trending

    func fetchTrending() async {
        guard !isLoading else { return }
        isLoading = true
        async let movies = fetchTrendingMovies()
        async let shows = fetchTrendingShows()
        async let books = fetchTrendingBooks()
        let (m, s, b) = await (movies, shows, books)
        trendingMovies = m
        trendingShows = s
        trendingBooks = b
        isLoading = false
    }

    private func fetchTrendingBooks() async -> [TrendingBook] {
        guard let url = URL(string: "https://openlibrary.org/trending/weekly.json?limit=12") else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OLTrendingResponse.self, from: data)
            return response.works.compactMap { work in
                guard let title = work.title else { return nil }
                let coverURL = work.cover_i.map { URL(string: "https://covers.openlibrary.org/b/id/\($0)-M.jpg") } ?? nil
                return TrendingBook(
                    id: work.key ?? title,
                    title: title,
                    author: work.author_name?.first ?? "",
                    coverURL: coverURL,
                    year: work.first_publish_year.map { "\($0)" } ?? ""
                )
            }
        } catch {
            print("❌ Open Library trending failed: \(error)")
            return []
        }
    }

    private func fetchTrendingMovies() async -> [TMDBItem] {
        guard let url = URL(string: "\(baseURL)/trending/movie/week") else { return [] }
        return await fetch(url: url, mediaType: "movie")
    }

    private func fetchTrendingShows() async -> [TMDBItem] {
        guard let url = URL(string: "\(baseURL)/trending/tv/week") else { return [] }
        return await fetch(url: url, mediaType: "tv")
    }

    // MARK: - Poster lookup for existing items

    func ensurePosters(for items: [(title: String, type: String)]) async {
        for item in items {
            let key = cacheKey(title: item.title, type: item.type)
            guard posterCache[key] == nil else { continue }
            let url: URL?
            if item.type == "book" {
                url = await searchBookCover(title: item.title)
            } else {
                url = await searchPoster(title: item.title, type: item.type)
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            posterCache[key] = url
        }
    }

    func ensureBookCovers(for books: [TrendingBook]) async {
        for book in books where book.coverURL == nil {
            guard bookCoverCache[book.title] == nil else { continue }
            bookCoverCache[book.title] = await searchBookCover(title: book.title)
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    func posterURL(title: String, type: String) -> URL?? {
        posterCache[cacheKey(title: title, type: type)]
    }

    private func cacheKey(title: String, type: String) -> String { "\(title)|||\(type)" }

    private func cleanTitle(_ title: String) -> String {
        var s = title
        let patterns = [
            #"\s*[\(\-]?\s*szn\.?\s*\d+"#,
            #"\s*[\(\-]?\s*season\.?\s*\d+"#,
            #"\s*[\(\-]?\s*s\d{1,2}(e\d{1,2})?"#,
            #"\s*[\(\-]?\s*ep(isode)?\.?\s*\d+"#,
            #"\s*[\(\-]?\s*bk\.?\s*\d+"#,
            #"\s*[\(\-]?\s*book\.?\s*\d+"#,
            #"\s*[\(\-]?\s*vol(ume)?\.?\s*\d+"#,
            #"\s*[\(\-]?\s*part\.?\s*\d+"#,
            #"\s*\(\d{4}\)"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(s.startIndex..., in: s)
                s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "")
            }
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    private func searchBookCover(title: String) async -> URL? {
        let cleaned = cleanTitle(title)

        // Try Google Books first (no printType filter — covers audiobooks too)
        if let url = await googleBookscover(query: cleaned) { return url }

        // Fallback: Open Library
        return await openLibraryCover(query: cleaned)
    }

    private func googleBookscover(query: String) async -> URL? {
        var components = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "maxResults", value: "5")
        ]
        guard let url = components?.url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(GoogleBooksResponse.self, from: data)
            // pick first result that actually has a cover
            guard let thumbnail = response.items?.compactMap({ $0.volumeInfo.imageLinks?.thumbnail }).first
            else { return nil }
            let httpsURL = thumbnail
                .replacingOccurrences(of: "http://", with: "https://")
                .replacingOccurrences(of: "zoom=1", with: "zoom=2")
            return URL(string: httpsURL)
        } catch {
            return nil
        }
    }

    private func openLibraryCover(query: String) async -> URL? {
        // Also try with common "and the" insertion for series like "Harry Potter Chamber of Secrets"
        let queries = [query, expandedTitle(query)]

        for q in queries {
            var components = URLComponents(string: "https://openlibrary.org/search.json")
            components?.queryItems = [
                URLQueryItem(name: "title", value: q),
                URLQueryItem(name: "limit", value: "5"),
                URLQueryItem(name: "fields", value: "cover_i")
            ]
            guard let url = components?.url else { continue }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(OpenLibraryResponse.self, from: data)
                if let coverId = response.docs?.compactMap({ $0.cover_i }).first {
                    return URL(string: "https://covers.openlibrary.org/b/id/\(coverId)-M.jpg")
                }
            } catch { continue }
        }
        return nil
    }

    // Heuristic: "Harry Potter Chamber of Secrets" → "Harry Potter and the Chamber of Secrets"
    private func expandedTitle(_ title: String) -> String {
        let words = title.split(separator: " ")
        guard words.count >= 3 else { return title }
        // If there's no "and" or "the" after the first two words, try inserting "and the"
        let lower = title.lowercased()
        guard !lower.contains(" and ") && !lower.contains(" and the ") else { return title }
        // Insert "and the" after the second word
        let prefix = words.prefix(2).joined(separator: " ")
        let suffix = words.dropFirst(2).joined(separator: " ")
        return "\(prefix) and the \(suffix)"
    }

    private func searchPoster(title: String, type: String) async -> URL? {
        let endpoint = type == "movie" ? "search/movie" : "search/tv"
        let cleanedTitle = cleanTitle(title)
        var components = URLComponents(string: "\(baseURL)/\(endpoint)")
        components?.queryItems = [URLQueryItem(name: "query", value: cleanedTitle), URLQueryItem(name: "page", value: "1")]
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(Config.tmdbReadToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TMDBResponse.self, from: data)
            guard let first = response.results.first, let path = first.poster_path else { return nil }
            return URL(string: "https://image.tmdb.org/t/p/w200\(path)")
        } catch {
            return nil
        }
    }

    // MARK: - Genre fetching

    func fetchByGenre(_ genre: DiscoverGenre) async {
        guard !isGenreLoading else { return }
        isGenreLoading = true

        async let movies = fetchMoviesByGenre(genre)
        async let shows = fetchShowsByGenre(genre)
        async let books = fetchBooksByGenre(genre)
        let (m, s, b) = await (movies, shows, books)
        genreMovies = m
        genreShows = s
        genreBooks = b
        isGenreLoading = false
    }

    private func fetchMoviesByGenre(_ genre: DiscoverGenre) async -> [TMDBItem] {
        guard let genreId = genre.movieGenreId,
              let url = URL(string: "\(baseURL)/discover/movie?with_genres=\(genreId)&sort_by=popularity.desc&page=1")
        else { return [] }
        return await fetch(url: url, mediaType: "movie")
    }

    private func fetchShowsByGenre(_ genre: DiscoverGenre) async -> [TMDBItem] {
        guard let genreId = genre.tvGenreId,
              let url = URL(string: "\(baseURL)/discover/tv?with_genres=\(genreId)&sort_by=popularity.desc&page=1")
        else { return [] }
        return await fetch(url: url, mediaType: "tv")
    }

    private func fetchBooksByGenre(_ genre: DiscoverGenre) async -> [TrendingBook] {
        guard let subject = genre.olSubject,
              let url = URL(string: "https://openlibrary.org/subjects/\(subject).json?limit=12")
        else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OLSubjectResponse.self, from: data)
            return response.works.compactMap { work in
                let coverURL = work.cover_id.map { URL(string: "https://covers.openlibrary.org/b/id/\($0)-M.jpg") } ?? nil
                return TrendingBook(
                    id: work.key,
                    title: work.title,
                    author: work.authors?.first?.name ?? "",
                    coverURL: coverURL,
                    year: ""
                )
            }
        } catch { return [] }
    }

    // MARK: - Detail fetching

    var detailCache: [String: MediaDetail] = [:]

    func fetchDetail(title: String, type: String) async -> MediaDetail? {
        let key = "\(title)|||detail|||\(type)"
        if let cached = detailCache[key] { return cached }

        if type == "book" {
            let detail = await fetchBookDetail(title: title)
            if let detail { detailCache[key] = detail }
            return detail
        }

        // Search TMDB for ID
        let endpoint = type == "tv" ? "search/tv" : "search/movie"
        var components = URLComponents(string: "\(baseURL)/\(endpoint)")
        components?.queryItems = [URLQueryItem(name: "query", value: cleanTitle(title))]
        guard let searchURL = components?.url else { return nil }

        guard let searchResult = await tmdbSearchFirst(url: searchURL, mediaType: type) else { return nil }

        // Fetch detail + credits in parallel
        let detailEndpoint = type == "tv" ? "tv/\(searchResult.id)" : "movie/\(searchResult.id)"
        guard let detailURL = URL(string: "\(baseURL)/\(detailEndpoint)"),
              let creditsURL = URL(string: "\(baseURL)/\(detailEndpoint)/credits") else { return nil }

        async let detailData = authorizedData(from: detailURL)
        async let creditsData = authorizedData(from: creditsURL)

        let (dData, cData) = await (detailData, creditsData)

        var genres: [String] = []
        var runtime: String? = nil
        var backdropPath: String? = nil

        if let dData {
            if type == "movie", let r = try? JSONDecoder().decode(TMDBMovieDetail.self, from: dData) {
                genres = r.genres?.map(\.name) ?? []
                if let mins = r.runtime, mins > 0 {
                    runtime = "\(mins / 60)h \(mins % 60)m"
                }
                backdropPath = r.backdrop_path
            } else if type == "tv", let r = try? JSONDecoder().decode(TMDBTVDetail.self, from: dData) {
                genres = r.genres?.map(\.name) ?? []
                if let seasons = r.number_of_seasons {
                    runtime = "\(seasons) season\(seasons == 1 ? "" : "s")"
                }
                backdropPath = r.backdrop_path
            }
        }

        var cast: [CastMember] = []
        if let cData, let credits = try? JSONDecoder().decode(TMDBCredits.self, from: cData) {
            cast = credits.cast.prefix(10).map { c in
                let photo = c.profile_path.map { URL(string: "https://image.tmdb.org/t/p/w200\($0)") } ?? nil
                return CastMember(id: c.id, name: c.name, character: c.character ?? "", photoURL: photo)
            }
        }

        let backdropURL = backdropPath.map { URL(string: "https://image.tmdb.org/t/p/w780\($0)") } ?? nil
        let posterURL = searchResult.posterPath.map { URL(string: "https://image.tmdb.org/t/p/w500\($0)") } ?? nil

        let detail = MediaDetail(
            title: searchResult.title,
            overview: searchResult.overview,
            posterURL: posterURL,
            backdropURL: backdropURL ?? posterURL,
            rating: searchResult.rating,
            year: searchResult.releaseYear,
            genres: genres,
            runtime: runtime,
            cast: cast,
            mediaType: type,
            externalURL: nil
        )
        detailCache[key] = detail
        return detail
    }

    private func fetchBookDetail(title: String) async -> MediaDetail? {
        // 1. Primary: Open Library (no quota limits)
        if let detail = await openLibraryDetail(title: title) { return detail }

        // 2. Fallback: Google Books
        if let detail = await googleBooksDetail(title: title) { return detail }

        // 3. Last resort: minimal card so we never show the error screen
        return MediaDetail(
            title: title, overview: "", posterURL: nil, backdropURL: nil,
            rating: 0, year: "", genres: [], runtime: nil, cast: [],
            mediaType: "book", externalURL: nil
        )
    }

    private func openLibraryDetail(title: String) async -> MediaDetail? {
        let query = cleanTitle(title)
        var components = URLComponents(string: "https://openlibrary.org/search.json")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "1"),
            URLQueryItem(name: "fields", value: "key,title,author_name,cover_i,first_publish_year,subject")
        ]
        guard let url = components?.url,
              let (searchData, _) = try? await URLSession.shared.data(from: url),
              let searchResponse = try? JSONDecoder().decode(OLSearchResponse.self, from: searchData),
              let doc = searchResponse.docs?.first
        else { return nil }

        let coverURL = doc.cover_i.map { URL(string: "https://covers.openlibrary.org/b/id/\($0)-L.jpg") } ?? nil
        let year = doc.first_publish_year.map { String($0) } ?? ""
        let authors = doc.author_name ?? []
        let cast: [CastMember] = authors.enumerated().map { i, a in
            CastMember(id: i, name: a, character: "Author", photoURL: nil)
        }
        // Filter subjects to human-readable genre-like terms
        let genres = (doc.subject ?? [])
            .filter { !$0.contains(":") && !$0.hasPrefix("series:") && $0.count < 30 }
            .prefix(5)
            .map { $0 }

        // Fetch description from works endpoint
        var overview = ""
        if let key = doc.key,
           let worksURL = URL(string: "https://openlibrary.org\(key).json"),
           let (worksData, _) = try? await URLSession.shared.data(from: worksURL),
           let worksResponse = try? JSONDecoder().decode(OLWorksResponse.self, from: worksData) {
            overview = worksResponse.descriptionText ?? ""
        }

        return MediaDetail(
            title: doc.title ?? title,
            overview: overview,
            posterURL: coverURL, backdropURL: coverURL,
            rating: 0, year: year,
            genres: Array(genres),
            runtime: nil,
            cast: cast, mediaType: "book",
            externalURL: URL(string: "https://openlibrary.org\(doc.key ?? "")")
        )
    }

    private func googleBooksDetail(title: String) async -> MediaDetail? {
        let query = cleanTitle(title)
        var components = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")
        components?.queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "maxResults", value: "5")]
        guard let url = components?.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let response = try? JSONDecoder().decode(GoogleBooksResponse.self, from: data),
              let items = response.items, !items.isEmpty,
              let volume = items.first(where: { $0.volumeInfo.title != nil })
        else { return nil }

        let info = volume.volumeInfo
        let thumbnail = info.imageLinks?.thumbnail?
            .replacingOccurrences(of: "http://", with: "https://")
            .replacingOccurrences(of: "zoom=1", with: "zoom=5")
        let posterURL = thumbnail.flatMap { URL(string: $0) }
        let cast: [CastMember] = (info.authors ?? []).enumerated().map { i, a in
            CastMember(id: i, name: a, character: "Author", photoURL: nil)
        }
        return MediaDetail(
            title: info.title ?? title,
            overview: info.description ?? "",
            posterURL: posterURL, backdropURL: posterURL,
            rating: 0,
            year: String((info.publishedDate ?? "").prefix(4)),
            genres: info.categories ?? [],
            runtime: info.pageCount.map { "\($0) pages" },
            cast: cast, mediaType: "book",
            externalURL: info.infoLink.flatMap { URL(string: $0) }
        )
    }

    private func tmdbSearchFirst(url: URL, mediaType: String) async -> TMDBItem? {
        guard let data = await authorizedData(from: url),
              let response = try? JSONDecoder().decode(TMDBResponse.self, from: data),
              let first = response.results.first else { return nil }
        let title = first.title ?? first.name ?? ""
        let year = String((first.release_date ?? first.first_air_date ?? "").prefix(4))
        return TMDBItem(id: first.id, title: title, overview: first.overview ?? "",
                        posterPath: first.poster_path, releaseYear: year,
                        rating: first.vote_average ?? 0, mediaType: mediaType)
    }

    private func authorizedData(from url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(Config.tmdbReadToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        return try? await URLSession.shared.data(for: request).0
    }

    // MARK: - Generic fetch

    private func fetch(url: URL, mediaType: String) async -> [TMDBItem] {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(Config.tmdbReadToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TMDBResponse.self, from: data)
            return response.results.prefix(10).map { result in
                let title = result.title ?? result.name ?? "Unknown"
                let dateStr = result.release_date ?? result.first_air_date ?? ""
                let year = String(dateStr.prefix(4))
                return TMDBItem(
                    id: result.id,
                    title: title,
                    overview: result.overview ?? "",
                    posterPath: result.poster_path,
                    releaseYear: year,
                    rating: result.vote_average ?? 0,
                    mediaType: mediaType
                )
            }
        } catch {
            print("❌ TMDB fetch failed: \(error)")
            return []
        }
    }
}

// MARK: - Response Models

private struct TMDBResponse: Decodable {
    let results: [TMDBResult]
}

private struct TMDBResult: Decodable {
    let id: Int
    let title: String?
    let name: String?
    let overview: String?
    let poster_path: String?
    let release_date: String?
    let first_air_date: String?
    let vote_average: Double?
}

private struct GoogleBooksResponse: Decodable {
    let items: [GoogleBooksItem]?
}

private struct GoogleBooksItem: Decodable {
    let volumeInfo: GoogleBooksVolumeInfo
}

private struct GoogleBooksVolumeInfo: Decodable {
    let title: String?
    let authors: [String]?
    let description: String?
    let publishedDate: String?
    let pageCount: Int?
    let categories: [String]?
    let imageLinks: GoogleBooksImageLinks?
    let infoLink: String?
}

private struct GoogleBooksImageLinks: Decodable {
    let thumbnail: String?
}

private struct OpenLibraryResponse: Decodable {
    let docs: [OpenLibraryDoc]?
}

private struct OpenLibraryDoc: Decodable {
    let cover_i: Int?
}

// Used by openLibraryDetail — richer search response
private struct OLSearchResponse: Decodable {
    let docs: [OLSearchDoc]?
}

private struct OLSearchDoc: Decodable {
    let key: String?
    let title: String?
    let author_name: [String]?
    let cover_i: Int?
    let first_publish_year: Int?
    let subject: [String]?
}

// Works endpoint for description
private struct OLWorksResponse: Decodable {
    // description can be a String or {"type":..., "value":"..."}
    let description: OLDescription?

    var descriptionText: String? {
        switch description {
        case .string(let s): return s
        case .object(let o): return o.value
        case nil: return nil
        }
    }

    enum OLDescription: Decodable {
        case string(String)
        case object(OLDescriptionObject)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let s = try? container.decode(String.self) {
                self = .string(s)
            } else {
                self = .object(try container.decode(OLDescriptionObject.self))
            }
        }
    }

    struct OLDescriptionObject: Decodable {
        let value: String
    }
}

private struct OLTrendingResponse: Decodable {
    let works: [OLWork]
}

private struct OLWork: Decodable {
    let key: String?
    let title: String?
    let author_name: [String]?
    let cover_i: Int?
    let first_publish_year: Int?
}

private struct OLSubjectResponse: Decodable {
    let works: [OLSubjectWork]
}

private struct OLSubjectWork: Decodable {
    let key: String
    let title: String
    let cover_id: Int?
    let authors: [OLSubjectAuthor]?
}

private struct OLSubjectAuthor: Decodable {
    let name: String
}

private struct TMDBMovieDetail: Decodable {
    let genres: [TMDBGenre]?
    let runtime: Int?
    let backdrop_path: String?
}

private struct TMDBTVDetail: Decodable {
    let genres: [TMDBGenre]?
    let number_of_seasons: Int?
    let backdrop_path: String?
}

private struct TMDBGenre: Decodable {
    let name: String
}

private struct TMDBCredits: Decodable {
    let cast: [TMDBCastResult]
}

private struct TMDBCastResult: Decodable {
    let id: Int
    let name: String
    let character: String?
    let profile_path: String?
}

private struct GoogleBooksVolumeDetail: Decodable {
    let title: String?
    let authors: [String]?
    let description: String?
    let publishedDate: String?
    let pageCount: Int?
    let categories: [String]?
    let imageLinks: GoogleBooksImageLinks?
}
