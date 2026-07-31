//
//  SmiskiItem.swift
//  Orca

import SwiftData
import Foundation

@Model
final class SmiskiItem {
    var id: UUID = UUID()
    var figureId: String = ""
    var seriesId: String = ""
    var seriesName: String = ""
    var figureName: String = ""
    var isSecret: Bool = false
    var statusRaw: String = "owned"
    var addedAt: Date = Date()

    var isOwned: Bool {
        get { statusRaw == "owned" }
        set { statusRaw = newValue ? "owned" : "chasing" }
    }

    var imageURL: String? {
        SmiskiCatalog.allSeries
            .first(where: { $0.id == seriesId })?
            .figures.first(where: { $0.id == figureId })?
            .imageURL
    }

    init(figureId: String, seriesId: String, seriesName: String, figureName: String, isSecret: Bool = false) {
        self.id = UUID()
        self.figureId = figureId
        self.seriesId = seriesId
        self.seriesName = seriesName
        self.figureName = figureName
        self.isSecret = isSecret
        self.statusRaw = "owned"
        self.addedAt = Date()
    }
}
