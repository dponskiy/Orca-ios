//
//  Memory.swift
//  Orca
//
//  Created by David Piliponskiy on 2/24/26.
//

import SwiftData
import Foundation

@Model
class Memory {
    var id: UUID = UUID()
    var text: String
    var echoId: UUID
    var tags: [String] = []
    var detectedDate: Date?
    var imageData: Data?
    var captureType: CaptureType = CaptureType.voice
    var sonarConfidence: Double = 1.0
    var echoConfidence: Double = 1.0
    var dateConfidence: Double?
    var wasEdited: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var syncStatus: SyncStatus = SyncStatus.pending

    enum CaptureType: String, Codable {
        case voice, screenshot, typed
    }

    enum SyncStatus: String, Codable {
        case synced, pending, failed
    }

    init(text: String, echoId: UUID, captureType: CaptureType = .voice) {
        self.text = text
        self.echoId = echoId
        self.captureType = captureType
    }
}
