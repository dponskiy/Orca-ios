//
//  LegoSet.swift
//  Orca

import SwiftData
import Foundation

@Model
final class LegoSet {
    var id: UUID = UUID()
    var setNum: String = ""      // e.g. "75192-1"
    var name: String = ""
    var year: Int = 0
    var themeId: Int = 0
    var themeName: String = ""
    var numParts: Int = 0
    var imageURL: String = ""
    var statusRaw: String = "owned"
    var addedAt: Date = Date()

    var isOwned: Bool {
        get { statusRaw == "owned" }
        set { statusRaw = newValue ? "owned" : "want" }
    }

    init(setNum: String, name: String, year: Int, themeId: Int, themeName: String, numParts: Int, imageURL: String) {
        self.id = UUID()
        self.setNum = setNum
        self.name = name
        self.year = year
        self.themeId = themeId
        self.themeName = themeName
        self.numParts = numParts
        self.imageURL = imageURL
        self.statusRaw = "owned"
        self.addedAt = Date()
    }
}
