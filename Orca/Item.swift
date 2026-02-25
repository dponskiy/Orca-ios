//
//  Item.swift
//  Orca
//
//  Created by David Piliponskiy on 2/24/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
