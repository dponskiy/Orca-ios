//
//  Ping.swift
//  Orca
//
//  Created by David Piliponskiy on 2/24/26.
//

import SwiftData
import Foundation

@Model
class Ping {
    var id: UUID = UUID()
    var memoryId: UUID
    var fireDate: Date
    var fireTime: Date
    var recurrence: Recurrence = Recurrence.none
    var isActive: Bool = true
    var lastFired: Date?
    var followUpScheduled: Bool = false
    var createdAt: Date = Date()

    enum Recurrence: String, Codable {
        case none, daily, weekly, monthly, yearly
    }

    init(memoryId: UUID, fireDate: Date, recurrence: Recurrence = .none) {
        self.memoryId = memoryId
        self.fireDate = fireDate
        self.recurrence = recurrence
        self.fireTime = Calendar.current.date(
            bySettingHour: 9, minute: 0, second: 0, of: fireDate
        ) ?? fireDate
    }
}
