//
//  RecipePhotoTests.swift
//  OrcaTests
//
//  Finding the dish's photo in a recipe page.
//
//  The first version of this skipped the page entirely and handed the recipe's own URL
//  to an image downloader, so every card quietly fetched HTML, failed to make a picture
//  of it, and showed nothing. These cases are the page shapes that have to work.
//

import Testing
import Foundation
@testable import Orca

struct RecipePhotoTests {

    private static let page = URL(string: "https://example.com/recipes/sunday-sauce")!

    private func found(_ html: String) -> String? {
        RecipePhoto.imageURL(inHTML: html, page: Self.page)
    }

    @Test("og:image is found with the attributes either way round")
    func readsOpenGraph() {
        #expect(found(#"<meta property="og:image" content="https://cdn.example.com/sauce.jpg">"#)
                == "https://cdn.example.com/sauce.jpg")
        #expect(found(#"<meta content="https://cdn.example.com/sauce.jpg" property="og:image" />"#)
                == "https://cdn.example.com/sauce.jpg")
        #expect(found("<meta property='og:image' content='https://cdn.example.com/x.png'>")
                == "https://cdn.example.com/x.png")
    }

    @Test("Structured data is read in the three shapes sites write it")
    func readsJSONLD() {
        #expect(found(#"{"@type":"Recipe","image":"https://cdn.example.com/dish.jpg"}"#)
                == "https://cdn.example.com/dish.jpg")
        #expect(found(#"{"image":["https://cdn.example.com/one.jpg","https://cdn.example.com/two.jpg"]}"#)
                == "https://cdn.example.com/one.jpg")
        #expect(found(#"{"image":{"@type":"ImageObject","url":"https://cdn.example.com/obj.jpg"}}"#)
                == "https://cdn.example.com/obj.jpg")
    }

    @Test("The recipe's own image wins over the page's sharing image")
    func structuredDataWins() {
        // og:image on a blog is sometimes the site logo; the recipe's image is the dish
        let html = """
        <meta property="og:image" content="https://cdn.example.com/site-logo.png">
        <script type="application/ld+json">{"@type":"Recipe","image":"https://cdn.example.com/dish.jpg"}</script>
        """
        #expect(found(html) == "https://cdn.example.com/dish.jpg")
    }

    @Test("A relative path is resolved against the page it came from")
    func resolvesRelative() {
        #expect(found(#"<meta property="og:image" content="/images/sauce.jpg">"#)
                == "https://example.com/images/sauce.jpg")
    }

    @Test("Escaped ampersands in a query string are unescaped")
    func unescapes() {
        #expect(found(#"<meta property="og:image" content="https://cdn.example.com/x.jpg?w=600&amp;q=80">"#)
                == "https://cdn.example.com/x.jpg?w=600&q=80")
    }

    @Test("twitter:image is taken when nothing better is there")
    func fallsBackToTwitter() {
        #expect(found(#"<meta name="twitter:image" content="https://cdn.example.com/t.jpg">"#)
                == "https://cdn.example.com/t.jpg")
    }

    @Test("A page with no picture returns nothing rather than a guess")
    func noImage() {
        #expect(found("<html><body><h1>Sunday Sauce</h1></body></html>") == nil)
        #expect(found("") == nil)
    }
}
