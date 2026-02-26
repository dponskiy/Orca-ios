//
//  SonarEngine.swift
//  Orca
//
//  Created by David Piliponskiy on 2/24/26.
//

import Foundation
import NaturalLanguage

struct SonarResult {
    let echoId: UUID?
    let echoName: String
    let echoConfidence: Double
    let detectedDate: Date?
    let dateConfidence: Double?
    let tags: [String]
    let shouldCreatePing: Bool
    let pingRecurrence: Ping.Recurrence
}

class SonarEngine {
    
    private let keywordMap: [(echo: String, keywords: [String], priority: Int)] = [
        ("Health", ["doctor", "medicine", "prescription", "appointment", "dentist", "therapy", "vitamin", "hospital", "symptoms", "allergy", "medication", "pharmacy", "sick", "pain", "blood pressure", "checkup"], 1),
        ("Kids", ["school", "homework", "daycare", "teacher", "parent", "pediatrician", "baby", "child", "kid", "daughter", "son", "playground", "soccer practice", "ballet", "tutor"], 2),
        ("Gifts", ["birthday", "present", "gift", "christmas", "anniversary", "wedding", "wishes", "wants", "wish list", "registry", "surprise"], 3),
        ("Travel", ["flight", "hotel", "airport", "vacation", "trip", "booking", "passport", "luggage", "airbnb", "rental car", "itinerary", "resort", "cruise", "destination"], 4),
        ("Cooking", ["recipe", "ingredient", "cook", "bake", "tablespoon", "teaspoon", "oven", "stove", "marinade", "seasoning", "prep", "simmer", "saute", "roast", "grill"], 5),
        ("Dining", ["restaurant", "reservation", "menu", "order", "waiter", "takeout", "delivery", "brunch", "dinner", "lunch", "cafe", "appetizer", "entree", "dessert", "cocktail", "bar"], 6),
        ("Sports", ["game", "score", "team", "season", "ticket", "stadium", "coach", "player", "league", "tournament", "playoffs", "practice", "workout", "gym", "match"], 7),
        ("Shopping", ["buy", "price", "store", "coupon", "sale", "amazon", "size", "return", "order", "shipping", "discount", "brand", "mall", "target", "walmart", "costco"], 8),
        ("Home", ["plumber", "electrician", "repair", "mortgage", "rent", "landlord", "furniture", "paint", "garden", "lawn", "roof", "garage", "basement", "kitchen", "bathroom", "renovate", "move"], 9),
        ("Work", ["meeting", "deadline", "project", "email", "boss", "coworker", "presentation", "report", "salary", "interview", "client", "office", "standup", "promotion", "review"], 10),
        ("Pets", ["vet", "dog", "cat", "puppy", "kitten", "pet food", "grooming", "walk", "collar", "leash", "litter", "treats", "adoption", "vaccine", "flea"], 11),
        ("Finance", ["bank", "savings", "investment", "tax", "credit card", "payment", "budget", "insurance", "loan", "interest", "401k", "stocks", "debt", "mortgage", "refund", "subscription"], 12),
        ("Chores", ["laundry", "vacuum", "dishes", "clean", "trash", "recycle", "mop", "dust", "organize", "declutter", "iron", "sweep", "garbage", "errands"], 13),
        ("Games", ["xbox", "playstation", "nintendo", "switch", "steam", "gaming", "controller", "multiplayer", "level", "quest", "raid", "download", "update", "dlc", "console"], 14),
    ]
    
    private let reminderKeywords = ["remind", "remember", "don't forget", "dont forget", "every monday", "every tuesday", "every wednesday", "every thursday", "every friday", "every saturday", "every sunday", "every week", "every month", "every year", "every day", "daily", "weekly", "monthly", "yearly", "annually", "birthday", "appointment", "deadline", "due date"]
    
    func process(text: String, echos: [Echo]) -> SonarResult {
        let lower = text.lowercased()
        
        // Echo assignment
        let echoResult = assignEcho(text: lower, echos: echos)
        
        // Date detection
        let dateResult = detectDate(text: text)
        
        // Tag generation
        let tags = generateTags(text: text, echoName: echoResult.name)
        
        // Ping decision
        let pingResult = decidePing(text: lower, date: dateResult.date)
        
        return SonarResult(
            echoId: echoResult.id,
            echoName: echoResult.name,
            echoConfidence: echoResult.confidence,
            detectedDate: dateResult.date,
            dateConfidence: dateResult.confidence,
            tags: tags,
            shouldCreatePing: pingResult.shouldCreate,
            pingRecurrence: pingResult.recurrence
        )
    }
    
    private func assignEcho(text: String, echos: [Echo]) -> (id: UUID?, name: String, confidence: Double) {
        var bestMatch: (name: String, priority: Int, matchCount: Int)?
        
        for entry in keywordMap {
            let matchCount = entry.keywords.filter { text.contains($0) }.count
            if matchCount > 0 {
                if bestMatch == nil || entry.priority < bestMatch!.priority || matchCount > bestMatch!.matchCount {
                    bestMatch = (entry.echo, entry.priority, matchCount)
                }
            }
        }
        
        if let match = bestMatch {
            let echo = echos.first { $0.name == match.name }
            let confidence = match.matchCount >= 2 ? 0.9 : 0.6
            return (echo?.id, match.name, confidence)
        }
        
        // Fallback to Notes
        let notesEcho = echos.first { $0.name == "Notes" }
        return (notesEcho?.id, "Notes", 0.3)
    }
    
    private func detectDate(text: String) -> (date: Date?, confidence: Double?) {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        
        guard let matches = detector?.matches(in: text, range: range),
              let firstMatch = matches.first,
              let date = firstMatch.date else {
            return (nil, nil)
        }
        
        // Higher confidence for absolute dates, lower for relative
        let hasAbsoluteDate = text.contains(where: { $0.isNumber })
        let confidence = hasAbsoluteDate ? 0.9 : 0.6
        
        return (date, confidence)
    }
    
    private func generateTags(text: String, echoName: String) -> [String] {
        var tags: [String] = []
        
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = text
        
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation]
        
        // Extract proper nouns
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            if let tag = tag, tag == .personalName || tag == .placeName || tag == .organizationName {
                let word = String(text[range]).lowercased()
                if !tags.contains(word) && word.count > 2 {
                    tags.append(word)
                }
            }
            return true
        }
        
        // Extract significant nouns
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, range in
            if let tag = tag, tag == .noun {
                let word = String(text[range]).lowercased()
                if !tags.contains(word) && word.count > 3 {
                    tags.append(word)
                }
            }
            return true
        }
        
        // Add echo name as tag
        if !tags.contains(echoName.lowercased()) {
            tags.append(echoName.lowercased())
        }
        
        return Array(tags.prefix(6))
    }
    
    private func decidePing(text: String, date: Date?) -> (shouldCreate: Bool, recurrence: Ping.Recurrence) {
        guard date != nil else { return (false, .none) }
        
        let hasReminderIntent = reminderKeywords.contains { text.contains($0) }
        guard hasReminderIntent else { return (false, .none) }
        
        // Determine recurrence
        if text.contains("every day") || text.contains("daily") {
            return (true, .daily)
        }
        if text.contains("every week") || text.contains("weekly") ||
           text.contains("every monday") || text.contains("every tuesday") ||
           text.contains("every wednesday") || text.contains("every thursday") ||
           text.contains("every friday") || text.contains("every saturday") ||
           text.contains("every sunday") {
            return (true, .weekly)
        }
        if text.contains("every month") || text.contains("monthly") {
            return (true, .monthly)
        }
        if text.contains("every year") || text.contains("yearly") ||
           text.contains("annually") || text.contains("birthday") {
            return (true, .yearly)
        }
        
        return (true, .none)
    }
}
