//
//  SonarEngine.swift
//  Orca
//
//  Created by David Piliponskiy on 2/24/26.
//

import Foundation
import NaturalLanguage

struct PingSuggestion {
    let fireDate: Date?
    let fireTime: Date?
    let recurrence: Ping.Recurrence
}

struct SonarResult {
    let echoId: UUID?
    let echoName: String
    let echoConfidence: Double
    let detectedDate: Date?
    let dateConfidence: Double?
    let tags: [String]
    let shouldCreatePing: Bool
    let pingRecurrence: Ping.Recurrence
    let isActionable: Bool
    let pingFireDate: Date?
    let pingFireTime: Date?
    let pingSuggestions: [PingSuggestion]
}

class SonarEngine {
    
    private let keywordMap: [(echo: String, keywords: [String], priority: Int)] = [
        ("Health", ["doctor", "medicine", "prescription", "appointment", "dentist", "therapy", "vitamin", "hospital", "symptoms", "allergy", "medication", "pharmacy", "sick", "pain", "blood pressure", "checkup"], 1),
        ("Kids", ["school", "homework", "daycare", "teacher", "parent", "pediatrician", "baby", "child", "kid", "daughter", "son", "playground", "soccer practice", "ballet", "tutor"], 2),
        ("Birthday", ["birthday", "bday", "turning", "birthday party", "birthday gift", "birthday present"], 3),
        ("Gifts", ["present", "gift", "christmas gift", "anniversary gift", "wishes", "wants", "wish list", "registry", "surprise"], 4),
        ("Travel", ["flight", "hotel", "airport", "vacation", "trip", "booking", "passport", "luggage", "airbnb", "rental car", "itinerary", "resort", "cruise", "destination"], 5),
        ("Cooking", ["recipe", "ingredient", "cook", "bake", "tablespoon", "teaspoon", "oven", "stove", "marinade", "seasoning", "prep", "simmer", "saute", "roast", "grill"], 6),
        ("Dining", ["restaurant", "reservation", "menu", "waiter", "takeout", "delivery", "brunch", "dinner", "lunch", "cafe", "appetizer", "entree", "dessert", "cocktail", "bar"], 7),
        ("Sports", ["game", "score", "team", "season", "ticket", "stadium", "coach", "player", "league", "tournament", "playoffs", "practice", "workout", "gym", "match"], 8),
        ("Events", ["concert", "show", "festival", "conference", "expo", "recital", "performance", "gala", "ceremony", "graduation", "prom", "meetup", "gathering"], 9),
        ("Shopping", ["buy", "price", "store", "coupon", "sale", "amazon", "size", "return", "order", "shipping", "discount", "brand", "mall", "target", "walmart", "costco"], 10),
        ("Home", ["plumber", "electrician", "repair", "mortgage", "rent", "landlord", "furniture", "paint", "garden", "lawn", "roof", "garage", "basement", "kitchen", "bathroom", "renovate", "move"], 11),
        ("School", ["class", "exam", "test", "study", "professor", "lecture", "semester", "tuition", "campus", "assignment", "essay", "grade", "gpa", "syllabus", "textbook"], 12),
        ("Work", ["meeting", "deadline", "project", "email", "boss", "coworker", "presentation", "report", "salary", "interview", "client", "office", "standup", "promotion", "review"], 13),
        ("Pets", ["vet", "dog", "cat", "puppy", "kitten", "pet food", "grooming", "walk", "collar", "leash", "litter", "treats", "adoption", "vaccine", "flea"], 14),
        ("Finance", ["bank", "savings", "investment", "tax", "credit card", "payment", "budget", "insurance", "loan", "interest", "401k", "stocks", "debt", "refund", "subscription"], 15),
        ("Holidays", ["christmas", "thanksgiving", "easter", "halloween", "new year", "valentine", "fourth of july", "independence day", "labor day", "memorial day", "hanukkah", "kwanzaa", "diwali"], 16),
        ("Chores", ["laundry", "vacuum", "dishes", "clean", "trash", "recycle", "mop", "dust", "organize", "declutter", "iron", "sweep", "garbage", "errands"], 17),
        ("Games", ["xbox", "playstation", "nintendo", "switch", "steam", "gaming", "controller", "multiplayer", "level", "quest", "raid", "download", "dlc", "console"], 18),
    ]
    
    private let reminderKeywords = ["remind", "remember", "don't forget", "dont forget", "every monday", "every tuesday", "every wednesday", "every thursday", "every friday", "every saturday", "every sunday", "every week", "every month", "every year", "every day", "daily", "weekly", "monthly", "yearly", "annually", "appointment", "deadline", "due date"]
    
    private let actionKeywords = ["buy", "get", "pick up", "pickup", "call", "email", "send", "schedule", "book", "cancel", "return", "fix", "clean", "make", "order", "pay", "finish", "submit", "renew", "sign up", "signup", "register", "drop off", "dropoff", "mail", "ship", "text", "message", "contact", "set up", "setup", "install", "update", "replace", "check", "review", "prepare", "plan", "arrange", "confirm", "reschedule", "refill", "restock", "wash", "take", "bring", "move", "file", "print", "scan", "deposit", "transfer", "apply", "complete", "grab", "find", "look into", "follow up", "respond", "reply", "game", "concert", "show", "match", "party", "dinner", "event", "appointment", "meeting", "flight", "reservation", "practice", "class", "exam", "recital", "performance"]
    
    private let autoYearlyKeywords = ["birthday", "bday", "anniversary", "christmas", "thanksgiving", "easter", "halloween", "new year", "valentine", "hanukkah", "kwanzaa", "diwali", "independence day", "fourth of july", "memorial day", "labor day"]
    
    private let weekdayMap: [(String, Int)] = [
        ("sunday", 1), ("sundays", 1),
        ("monday", 2), ("mondays", 2),
        ("tuesday", 3), ("tuesdays", 3),
        ("wednesday", 4), ("wednesdays", 4),
        ("thursday", 5), ("thursdays", 5),
        ("friday", 6), ("fridays", 6),
        ("saturday", 7), ("saturdays", 7),
    ]
    
    // MARK: - Main Process
    
    func process(text: String, echos: [Echo]) -> SonarResult {
        let lower = text.lowercased()
        
        let echoResult = assignEcho(text: lower, echos: echos)
        let dateResults = detectDates(text: text)
        let tags = generateTags(text: text, echoName: echoResult.name)
        let actionable = detectAction(text: lower)
        let pingSuggestions = buildPingSuggestions(text: lower, dates: dateResults)
        
        let eventDate = dateResults.eventDate
        let eventConfidence = dateResults.eventConfidence
        
        let primary = pingSuggestions.first
        
        return SonarResult(
            echoId: echoResult.id,
            echoName: echoResult.name,
            echoConfidence: echoResult.confidence,
            detectedDate: eventDate,
            dateConfidence: eventConfidence,
            tags: tags,
            shouldCreatePing: !pingSuggestions.isEmpty,
            pingRecurrence: primary?.recurrence ?? Ping.Recurrence.none,
            isActionable: actionable,
            pingFireDate: primary?.fireDate,
            pingFireTime: primary?.fireTime,
            pingSuggestions: pingSuggestions
        )
    }
    
    // MARK: - Action Detection
    
    private func detectAction(text: String) -> Bool {
        return actionKeywords.contains { keyword in
            text.contains(keyword)
        }
    }
    
    // MARK: - Echo Assignment
    
    private func assignEcho(text: String, echos: [Echo]) -> (id: UUID?, name: String, confidence: Double) {
        var bestMatch: (name: String, priority: Int, matchCount: Int)?
        
        for entry in keywordMap {
            let matchCount = entry.keywords.filter { text.contains($0) }.count
            if matchCount > 0 {
                if bestMatch == nil || matchCount > bestMatch!.matchCount || (matchCount == bestMatch!.matchCount && entry.priority < bestMatch!.priority) {
                    bestMatch = (entry.echo, entry.priority, matchCount)
                }
            }
        }
        
        if let match = bestMatch {
            let echo = echos.first { $0.name == match.name }
            let confidence = match.matchCount >= 2 ? 0.9 : 0.6
            return (echo?.id, match.name, confidence)
        }
        
        let notesEcho = echos.first { $0.name == "Notes" }
        return (notesEcho?.id, "Notes", 0.3)
    }
    
    // MARK: - Date Detection
    
    private func detectDates(text: String) -> (eventDate: Date?, eventConfidence: Double?, reminderDate: Date?, reminderTime: Date?) {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        
        guard let matches = detector?.matches(in: text, range: range) else {
            return (nil, nil, nil, nil)
        }
        
        let dates = matches.compactMap { $0.date }
        guard !dates.isEmpty else { return (nil, nil, nil, nil) }
        
        let hasAbsoluteDate = text.contains(where: { $0.isNumber })
        let confidence = hasAbsoluteDate ? 0.9 : 0.6
        
        if dates.count == 1 {
            // Check for relative offset like "an hour before"
            let lower = text.lowercased()
            let hasReminderPhrase = lower.contains("remind") || lower.contains("don't forget") || lower.contains("dont forget")
            
            if hasReminderPhrase, let offset = detectRelativeOffset(text: lower) {
                let eventDate = dates[0]
                let reminderDate = eventDate.addingTimeInterval(offset)
                return (eventDate, confidence, reminderDate, reminderDate)
            }
            
            return (dates[0], confidence, nil, nil)
        }
        
        // Multiple dates found — sort by distance from now
        let sorted = dates.sorted { abs($0.timeIntervalSinceNow) < abs($1.timeIntervalSinceNow) }
        let nearest = sorted.first!
        let furthest = sorted.last!
        
        let lower = text.lowercased()
        let hasReminderPhrase = lower.contains("remind") || lower.contains("don't forget") || lower.contains("dont forget")
        
        if hasReminderPhrase && nearest != furthest {
            return (furthest, confidence, nearest, nearest)
        }
        
        return (furthest, confidence, nil, nil)
    }
    
    // MARK: - Relative Offset Detection
    
    private func detectRelativeOffset(text: String) -> TimeInterval? {
        let patterns: [(String, TimeInterval)] = [
            ("(an?|1|one)\\s+hours?\\s+before", -3600),
            ("(2|two)\\s+hours?\\s+before", -7200),
            ("(3|three)\\s+hours?\\s+before", -10800),
            ("(4|four)\\s+hours?\\s+before", -14400),
            ("half\\s+(an?\\s+)?hours?\\s+before", -1800),
            ("(30|thirty)\\s+minutes?\\s+before", -1800),
            ("(15|fifteen)\\s+minutes?\\s+before", -900),
            ("(45|forty.?five)\\s+minutes?\\s+before", -2700),
            ("(a|1|one)\\s+days?\\s+before", -86400),
            ("(2|two)\\s+days?\\s+before", -172800),
            ("(a|1|one)\\s+weeks?\\s+before", -604800),
        ]
        
        for (pattern, offset) in patterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return offset
            }
        }
        return nil
    }
    
    // MARK: - Ping Suggestions Builder
    
    private func buildPingSuggestions(text: String, dates: (eventDate: Date?, eventConfidence: Double?, reminderDate: Date?, reminderTime: Date?)) -> [PingSuggestion] {
        var suggestions: [PingSuggestion] = []
        
        // Check for multi-weekday recurring ("every saturday and sunday")
        let multiWeekdays = detectMultiWeekdays(text: text)
        if !multiWeekdays.isEmpty {
            let calendar = Calendar.current
            for weekday in multiWeekdays {
                let nextDate = nextOccurrence(of: weekday)
                suggestions.append(PingSuggestion(
                    fireDate: nextDate,
                    fireTime: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date()),
                    recurrence: .weekly
                ))
            }
            return suggestions
        }
        
        // Check for auto-yearly events (birthdays, holidays, etc.)
        let isAutoYearly = autoYearlyKeywords.contains { text.contains($0) }
        if isAutoYearly, let eventDate = dates.eventDate {
            let calendar = Calendar.current
            let defaultTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: eventDate)
            
            suggestions.append(PingSuggestion(
                fireDate: eventDate,
                fireTime: defaultTime,
                recurrence: .yearly
            ))
            
            // If there's also a separate reminder date, add that too
            if let reminderDate = dates.reminderDate {
                suggestions.append(PingSuggestion(
                    fireDate: reminderDate,
                    fireTime: dates.reminderTime,
                    recurrence: Ping.Recurrence.none
                ))
            }
            
            return suggestions
        }
        
        // Standard reminder detection
        guard dates.eventDate != nil else { return [] }
        
        let hasReminderIntent = reminderKeywords.contains { text.contains($0) }
        guard hasReminderIntent else { return [] }
        
        var recurrence: Ping.Recurrence = Ping.Recurrence.none
        
        if text.contains("every day") || text.contains("daily") {
            recurrence = .daily
        } else if text.contains("every week") || text.contains("weekly") {
            recurrence = .weekly
        } else if text.contains("every month") || text.contains("monthly") {
            recurrence = .monthly
        } else if text.contains("every year") || text.contains("yearly") || text.contains("annually") {
            recurrence = .yearly
        }
        
        if let reminderDate = dates.reminderDate {
            suggestions.append(PingSuggestion(
                fireDate: reminderDate,
                fireTime: dates.reminderTime,
                recurrence: recurrence
            ))
        } else {
            suggestions.append(PingSuggestion(
                fireDate: dates.eventDate,
                fireTime: nil,
                recurrence: recurrence
            ))
        }
        
        return suggestions
    }
    
    // MARK: - Multi-Weekday Detection
    
    private func detectMultiWeekdays(text: String) -> [Int] {
        guard text.contains("every") else { return [] }
        
        var weekdays: [Int] = []
        for (name, number) in weekdayMap {
            if text.contains(name) {
                if !weekdays.contains(number) {
                    weekdays.append(number)
                }
            }
        }
        
        return weekdays.count >= 2 ? weekdays : (weekdays.count == 1 && text.contains("every") ? weekdays : [])
    }
    
    private func nextOccurrence(of weekday: Int) -> Date {
        let calendar = Calendar.current
        let today = Date()
        let todayWeekday = calendar.component(.weekday, from: today)
        var daysUntil = (weekday - todayWeekday + 7) % 7
        if daysUntil == 0 { daysUntil = 7 }
        return calendar.date(byAdding: .day, value: daysUntil, to: today) ?? today
    }
    
    // MARK: - Tag Generation
    
    private func generateTags(text: String, echoName: String) -> [String] {
        var tags: [String] = []
        
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = text
        
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            if let tag = tag, tag == .personalName || tag == .placeName || tag == .organizationName {
                let word = String(text[range]).lowercased()
                if !tags.contains(word) && word.count > 2 {
                    tags.append(word)
                }
            }
            return true
        }
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, range in
            if let tag = tag, tag == .noun {
                let word = String(text[range]).lowercased()
                if !tags.contains(word) && word.count > 3 {
                    tags.append(word)
                }
            }
            return true
        }
        
        if !tags.contains(echoName.lowercased()) {
            tags.append(echoName.lowercased())
        }
        
        return Array(tags.prefix(6))
    }
}
