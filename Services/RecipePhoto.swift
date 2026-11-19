//
//  RecipePhoto.swift
//  Orca
//
//  The picture on a recipe card.
//
//  RecipeExtractor has always fetched one — structured data first, then the page's
//  og:image — and the import threw it away. Two reasons it's kept now, and kept as a
//  file rather than a link:
//
//  A stored URL is a hotlink. Sites reorganise, URLs expire, some refuse requests that
//  don't come from their own pages, and the card goes blank months later with nothing to
//  explain it. A downscaled copy is about 50-80KB and can't break.
//
//  Recipes imported before this existed have no picture, so rather than a migration that
//  fetches everything at once, a card with no photo asks for its own when it first
//  appears. The shelf fills in as you browse it.
//

import Foundation
import UIKit

enum RecipePhoto {

    /// Wide enough for a card on any phone, small enough not to matter.
    private static let maxWidth: CGFloat = 600

    /// Downloads and downscales, or nil if there's nothing usable at the other end.
    static func fetch(from urlString: String) async -> Data? {
        guard let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true else { return nil }

        var request = URLRequest(url: url, timeoutInterval: 12)
        // No identifying details: a plain client, as any browser would send.
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode ?? 0 < 400,
              let image = UIImage(data: data)
        else { return nil }

        return downscaled(image)
    }

    /// The URL a recipe was imported from, so an old recipe can fetch its own picture
    /// the first time its card is drawn.
    static func sourceURL(for memory: Memory) -> String? {
        guard let url = memory.url, !url.isEmpty else { return nil }
        return url
    }

    /// Finds the picture on a recipe page and brings it back.
    ///
    /// A recipe stores the page it came from, not the photo, so a card filling itself in
    /// has to read the page first. Handing that page straight to `fetch` downloads HTML
    /// and quietly makes nothing of it, which is exactly what the first version did.
    ///
    /// The recipe's own structured image is preferred over the page's `og:image`: the
    /// first is the dish, the second is whatever the site wants shown when the page is
    /// shared, which on a blog is sometimes the logo.
    static func fetchFromPage(_ pageURL: String) async -> Data? {
        guard let url = URL(string: pageURL), url.scheme?.hasPrefix("http") == true else { return nil }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode ?? 0 < 400,
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1),
              let found = imageURL(inHTML: html, page: url)
        else { return nil }

        return await fetch(from: found)
    }

    /// The first usable image reference in the page, structured data before social tags.
    static func imageURL(inHTML html: String, page: URL) -> String? {
        let patterns = [
            // JSON-LD: "image": "https://…" or "image": ["https://…", …] or {"url": "…"}
            #""image"\s*:\s*"(https?://[^"]+)""#,
            #""image"\s*:\s*\[\s*"(https?://[^"]+)""#,
            #""image"\s*:\s*\{[^}]*?"url"\s*:\s*"(https?://[^"]+)""#,
            // og:image, with the attributes either way round
            #"<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']"#,
            #"<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']"#,
            #"<meta[^>]+name=["']twitter:image["'][^>]+content=["']([^"']+)["']"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: html)
            else { continue }

            let found = String(html[range])
                .replacingOccurrences(of: "&amp;", with: "&")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Sites write these relative as often as not.
            if found.hasPrefix("http") { return found }
            if let absolute = URL(string: found, relativeTo: page)?.absoluteString { return absolute }
        }
        return nil
    }

    private static func downscaled(_ image: UIImage) -> Data? {
        let scale = min(1, maxWidth / max(image.size.width, 1))
        guard scale < 1 else { return image.jpegData(compressionQuality: 0.8) }

        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format)
            .image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            .jpegData(compressionQuality: 0.8)
    }
}
