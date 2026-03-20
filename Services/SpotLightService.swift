//
//  SpotlightService.swift
//  Orca
//
//  Created by David Piliponskiy on 3/16/26.
//

import Foundation
import CoreSpotlight
import CoreLocation

class SpotlightService {
    static let shared = SpotlightService()
    private init() {}
    
    // MARK: - Index Memory
    
    func indexMemory(_ memory: Memory, echoName: String, echoEmoji: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.title = "\(echoEmoji) \(echoName)"
            attributeSet.contentDescription = memory.text
            attributeSet.keywords = memory.tags + [echoName, "orca", "memory"]
            
            if let date = memory.detectedDate {
                attributeSet.startDate = date
            }
            
            let item = CSSearchableItem(
                uniqueIdentifier: memory.id.uuidString,
                domainIdentifier: "com.dponskiy.Orca.memories",
                attributeSet: attributeSet
            )
            
            item.expirationDate = .distantFuture
            
            CSSearchableIndex.default().indexSearchableItems([item]) { error in
                if let error = error {
                    print("❌ Spotlight index error: \(error)")
                } else {
                    print("✅ Indexed memory: \(memory.id)")
                }
            }
        }
    }
    
    // MARK: - Remove Memory
    
    func removeMemory(id: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: [id.uuidString]
        ) { error in
            if let error = error {
                print("❌ Spotlight remove error: \(error)")
            }
        }
    }
    
    // MARK: - Remove All
    
    func removeAll() {
        CSSearchableIndex.default().deleteAllSearchableItems { error in
            if let error = error {
                print("❌ Spotlight remove all error: \(error)")
            }
        }
    }
}
