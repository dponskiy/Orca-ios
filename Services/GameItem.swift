//
//  GameItem.swift
//  Orca

import SwiftData
import Foundation

@Model
final class GameItem {
    var id: UUID = UUID()
    var igdbId: Int = 0
    var name: String = ""
    var coverURL: String = ""
    var genreNames: [String] = []
    var platformNames: [String] = []
    var rating: Double? = nil
    var releaseYear: Int? = nil
    var summary: String? = nil
    var isOwned: Bool = true
    var primaryPlatform: String = ""   // which console the user plays it on
    var addedAt: Date = Date()

    init(igdbId: Int, name: String, coverURL: String,
         genreNames: [String], platformNames: [String],
         rating: Double?, releaseYear: Int?, summary: String?,
         isOwned: Bool, primaryPlatform: String = "") {
        self.igdbId = igdbId
        self.name = name
        self.coverURL = coverURL
        self.genreNames = genreNames
        self.platformNames = platformNames
        self.rating = rating
        self.releaseYear = releaseYear
        self.summary = summary
        self.isOwned = isOwned
        self.primaryPlatform = primaryPlatform.isEmpty ? (platformNames.first ?? "") : primaryPlatform
        self.addedAt = Date()
    }
}
