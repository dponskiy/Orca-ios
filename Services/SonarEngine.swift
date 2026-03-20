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
    let endDate: Date?
    let dateConfidence: Double?
    let tags: [String]
    let shouldCreatePing: Bool
    let pingRecurrence: Ping.Recurrence
    let isActionable: Bool
    let pingFireDate: Date?
    let pingFireTime: Date?
    let pingSuggestions: [PingSuggestion]
    let shouldOfferRecipeFetch: Bool
}

class SonarEngine {

    private let keywordMap: [(echo: String, keywords: [String], priority: Int)] = [
        ("Health", ["doctor", "medicine", "prescription", "appointment", "dentist", "therapy", "vitamin", "hospital", "symptoms", "allergy", "medication", "pharmacy", "sick", "pain", "blood pressure", "checkup", "nurse", "clinic", "urgent care", "specialist", "surgeon", "physical", "lab results", "diagnosis", "chronic", "inflammation", "fever", "nausea", "injury", "rehab", "physical therapy"], 1),
        ("Kids", ["daycare", "teacher", "parent", "pediatrician", "baby", "child", "kid", "daughter", "son", "playground", "soccer practice", "ballet", "tutor", "school pickup", "drop off kids", "nanny", "babysitter", "kindergarten", "preschool", "school project"], 2),
        ("Birthday", ["birthday", "bday", "turning", "birthday party", "birthday gift", "birthday present", "happy birthday", "years old", "born"], 3),
        ("Gifts", ["present", "gift", "christmas gift", "anniversary gift", "wishes", "wants", "wish list", "registry", "surprise", "wrapping", "send gift", "gift card"], 4),
        ("Travel", ["flight", "hotel", "airport", "vacation", "trip", "booking", "passport", "luggage", "airbnb", "rental car", "itinerary", "resort", "cruise", "destination", "departure", "arrival", "layover", "boarding", "check-in", "check in", "visa", "packing", "suitcase", "travel insurance", "jet lag", "timezone"], 5),
        ("Cooking", ["recipe", "ingredient", "cook", "bake", "tablespoon", "teaspoon", "oven", "stove", "marinade", "seasoning", "prep", "simmer", "saute", "roast", "grill", "homemade", "meal prep", "leftovers", "slow cooker", "instant pot", "air fryer", "degrees fahrenheit", "degrees celsius", "preheat", "chop", "dice", "mince", "boil", "fry", "whisk", "fold", "knead"], 6),
        ("Dining", ["restaurant", "reservation", "menu", "waiter", "takeout", "delivery", "brunch", "lunch", "cafe", "appetizer", "entree", "dessert", "cocktail", "bar", "don't order", "dont order", "avoid ordering", "never order", "skip the", "dish was", "food was", "place was", "ate at", "eating at", "tried at", "recommend", "good at", "bad at", "overrated", "underrated", "must try", "never again", "great spot", "good spot", "yelp", "opentable", "resy", "uber eats", "doordash", "grubhub", "table for", "outdoor seating", "happy hour", "prix fixe", "tasting menu", "michelin", "omakase"], 7),
        ("Sports", ["game", "score", "team", "season", "ticket", "stadium", "coach", "player", "league", "tournament", "playoffs", "workout", "gym", "match", "training", "practice", "race", "marathon", "yoga", "pilates", "crossfit", "lifting", "cardio", "spin class", "personal trainer", "sports bar", "fantasy league", "draft"], 8),
        ("Events", ["concert", "show", "festival", "conference", "expo", "recital", "performance", "gala", "ceremony", "graduation", "prom", "meetup", "gathering", "networking", "keynote", "panel", "workshop", "seminar", "opening night", "premiere", "launch event", "happy hour", "cocktail party", "wedding", "engagement", "baby shower", "retirement party"], 9),
        ("Shopping", ["price", "store", "coupon", "sale", "amazon", "size", "return", "shipping", "discount", "brand", "mall", "target", "walmart", "costco", "online order", "tracking number", "out of stock", "waitlist", "sold out", "best buy", "apple store", "wish list", "add to cart", "checkout"], 10),
        ("Home", ["plumber", "electrician", "repair", "mortgage", "rent", "landlord", "furniture", "paint", "garden", "lawn", "roof", "garage", "basement", "kitchen", "bathroom", "renovate", "move", "handyman", "contractor", "lease", "hoa", "property tax", "homeowners", "pest control", "hvac", "water heater", "dishwasher", "washer", "dryer", "cleaning service", "deep clean"], 11),
        ("School", ["class", "exam", "test", "study", "professor", "lecture", "semester", "tuition", "campus", "assignment", "essay", "grade", "gpa", "syllabus", "textbook", "homework", "school", "finals", "midterm", "thesis", "dissertation", "graduation", "financial aid", "fafsa", "scholarship", "college", "university", "degree", "major", "minor", "internship", "student loan"], 12),
        ("Work", ["meeting", "deadline", "project", "email", "boss", "coworker", "presentation", "report", "salary", "interview", "client", "office", "standup", "promotion", "review", "slack", "zoom", "teams", "onboarding", "offboarding", "performance review", "quarterly", "sprint", "backlog", "jira", "confluence", "okr", "kpi", "pipeline", "forecast", "proposal", "contract", "invoice", "expense report", "reimbursement", "travel approval"], 13),
        ("Pets", ["vet", "dog", "cat", "puppy", "kitten", "pet food", "grooming", "walk", "collar", "leash", "litter", "treats", "adoption", "vaccine", "flea", "heartworm", "tick", "microchip", "spay", "neuter", "boarding", "pet sitter", "aquarium", "fish", "bird", "hamster", "rabbit"], 14),
        ("Finance", ["bank", "savings", "investment", "tax", "credit card", "payment", "budget", "insurance", "loan", "interest", "401k", "stocks", "debt", "refund", "subscription", "venmo", "zelle", "wire transfer", "direct deposit", "w2", "1099", "irs", "audit", "estate planning", "will", "trust", "beneficiary", "premium", "deductible", "copay", "hsa", "fsa", "roth ira", "dividend", "capital gains"], 15),
        ("Holidays", ["christmas", "thanksgiving", "easter", "halloween", "new year", "valentine", "fourth of july", "independence day", "labor day", "memorial day", "hanukkah", "kwanzaa", "diwali", "mothers day", "fathers day", "presidents day", "martin luther king", "columbus day", "veterans day", "passover", "ramadan", "eid"], 16),
        ("To-Do", ["laundry", "vacuum", "dishes", "clean", "trash", "recycle", "mop", "dust", "organize", "declutter", "iron", "sweep", "garbage", "errands", "chores", "errand", "pick up", "drop off", "run", "stop by", "swing by", "grab", "need to", "have to", "got to", "gotta", "don't forget", "dont forget", "reminder", "task", "to-do", "todo", "checklist", "errand run", "dry cleaning", "post office", "bank", "hardware store", "pharmacy", "drugstore", "gas station", "car wash", "oil change", "DMV", "MVA", "returns", "exchange", "package", "mail", "ups", "fedex", "usps"], 17),
        ("Games", ["xbox", "playstation", "nintendo", "switch", "steam", "gaming", "controller", "multiplayer", "level", "quest", "raid", "download", "dlc", "console", "pc gaming", "esports", "twitch", "speedrun", "achievements", "trophy", "walkthrough", "patch", "update", "early access", "game pass", "ps5", "ps4", "xbox series"], 18),
        ("Movies", ["movie", "film", "cinema", "theater", "theatre", "netflix", "hulu", "disney+", "hbo", "prime video", "streaming", "watch", "director", "actor", "actress", "sequel", "trailer", "blockbuster", "documentary", "series", "episode", "season", "binge", "screenplay", "imdb", "rotten tomatoes", "apple tv", "peacock", "paramount", "showtime", "starz", "criterion", "4k", "blu-ray", "short film", "indie film"], 19),
        ("Books", ["book", "read", "reading", "novel", "author", "chapter", "kindle", "audible", "library", "bookstore", "fiction", "nonfiction", "memoir", "biography", "audiobook", "bestseller", "hardcover", "paperback", "goodreads", "page", "plot", "genre", "publisher", "literature", "ebook", "book club", "book review", "recommended reading", "sequel", "trilogy", "series", "graphic novel", "comic book"], 20),
        ("Clothes", ["shirt", "pants", "shoes", "dress", "jacket", "coat", "outfit", "wear", "wearing", "clothes", "clothing", "jeans", "sweater", "hoodie", "socks", "underwear", "suit", "tie", "hat", "scarf", "gloves", "boots", "sneakers", "dry clean", "tailored", "alterations", "wardrobe", "fashion", "style", "nordstrom", "zara", "h&m", "uniqlo", "lululemon", "nike", "adidas", "size medium", "size large", "size small"], 21),
    ]

    private let reminderKeywords = ["remind", "remember", "don't forget", "dont forget", "every monday", "every tuesday", "every wednesday", "every thursday", "every friday", "every saturday", "every sunday", "every week", "every month", "every year", "every day", "daily", "weekly", "monthly", "yearly", "annually", "appointment", "deadline", "due date"]

    private let actionKeywords = ["buy", "get", "pick up", "pickup", "call", "email", "send", "schedule", "book", "cancel", "return", "fix", "clean", "make", "order", "pay", "finish", "submit", "renew", "sign up", "signup", "register", "drop off", "dropoff", "mail", "ship", "text", "message", "contact", "set up", "setup", "install", "update", "replace", "check", "review", "prepare", "plan", "arrange", "confirm", "reschedule", "refill", "restock", "wash", "take", "bring", "move", "file", "print", "scan", "deposit", "transfer", "apply", "complete", "grab", "find", "look into", "follow up", "respond", "reply", "game", "concert", "show", "match", "party", "dinner", "event", "appointment", "meeting", "flight", "reservation", "practice", "class", "exam", "recital", "performance"]

    private let negativePatterns = ["don't order", "dont order", "never order", "don't get", "dont get", "never get", "avoid", "never again", "don't go", "dont go", "never go", "skip the", "not worth", "wouldn't recommend", "don't recommend", "dont recommend", "stay away", "worst", "terrible", "awful", "disgusting", "overpriced"]

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

        let entities = extractEntities(text: text)
        let echoResult = assignEcho(text: lower, echos: echos, entities: entities)
        let dateResults = detectDates(text: text)
        let tags = generateTags(text: text, echoName: echoResult.name, entities: entities)
        let actionable = detectAction(text: lower)
        let pingSuggestions = buildPingSuggestions(text: lower, dates: dateResults)

        let primary = pingSuggestions.first

        let detectedURL = detectURL(text: text)
        let isCookingEcho = echoResult.name.lowercased().contains("cook") ||
                            echoResult.name.lowercased().contains("recipe")
        let shouldOfferRecipeFetch = isCookingEcho && detectedURL != nil

        return SonarResult(
            echoId: echoResult.id,
            echoName: echoResult.name,
            echoConfidence: echoResult.confidence,
            detectedDate: dateResults.eventDate,
            endDate: dateResults.endDate,
            dateConfidence: dateResults.eventConfidence,
            tags: tags,
            shouldCreatePing: !pingSuggestions.isEmpty,
            pingRecurrence: primary?.recurrence ?? Ping.Recurrence.none,
            isActionable: actionable,
            pingFireDate: primary?.fireDate,
            pingFireTime: primary?.fireTime,
            pingSuggestions: pingSuggestions,
            shouldOfferRecipeFetch: shouldOfferRecipeFetch
        )
    }

    // MARK: - Named Entity Recognition

    private func extractEntities(text: String) -> (people: [String], places: [String], organizations: [String]) {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var people: [String] = []
        var places: [String] = []
        var organizations: [String] = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: [.omitWhitespace, .omitPunctuation, .joinNames]) { tag, range in
            let entity = String(text[range])
            switch tag {
            case .personalName: people.append(entity.lowercased())
            case .placeName: places.append(entity.lowercased())
            case .organizationName: organizations.append(entity.lowercased())
            default: break
            }
            return true
        }
        return (people, places, organizations)
    }

    // MARK: - Action Detection

    private func detectAction(text: String) -> Bool {
        let lower = text.lowercased()
        // Don't mark as actionable if it's a negative command or observation
        if negativePatterns.contains(where: { lower.contains($0) }) { return false }
        // Don't mark as actionable for pure observations/notes about food/places
        let observationPatterns = ["was great", "was amazing", "was terrible", "was good", "was bad", "is great", "is amazing", "tasted", "loved the", "hated the", "tried the"]
        if observationPatterns.contains(where: { lower.contains($0) }) { return false }
        return actionKeywords.contains { keyword in lower.contains(keyword) }
    }

    // MARK: - Echo Assignment

    private func assignEcho(text: String, echos: [Echo], entities: (people: [String], places: [String], organizations: [String])) -> (id: UUID?, name: String, confidence: Double) {
        var scores: [(name: String, score: Double, priority: Int)] = []

        // Keyword matching
        for entry in keywordMap {
            let matchCount = entry.keywords.filter { text.contains($0) }.count
            if matchCount > 0 {
                let baseScore = Double(matchCount)
                scores.append((entry.echo, baseScore, entry.priority))
            }
        }

        // NL Entity boosting
        // Organizations boost Dining (restaurants), Work, or Events
        for org in entities.organizations {
            let orgLower = org.lowercased()
            // Food-related org names boost Dining
            let foodIndicators = ["restaurant", "cafe", "kitchen", "grill", "bar", "bistro", "eatery", "diner", "brasserie", "tavern", "pub", "house", "garden", "table", "shanghai", "tokyo", "thai", "sushi", "pizza", "burger", "taco", "bbq", "noodle", "dumpling"]
            if foodIndicators.contains(where: { orgLower.contains($0) }) {
                if let idx = scores.firstIndex(where: { $0.name == "Dining" }) {
                    scores[idx].score += 2.0
                } else {
                    scores.append(("Dining", 1.5, 7))
                }
            }
        }

        // Place names with food context boost Dining
        let textLower = text.lowercased()
        let diningContextWords = ["eat", "ate", "food", "dish", "order", "menu", "lunch", "dinner", "brunch", "breakfast", "taste", "flavor", "delicious", "portions", "service", "waiter"]
        let hasDiningContext = diningContextWords.contains { textLower.contains($0) }
        if !entities.organizations.isEmpty && hasDiningContext {
            if let idx = scores.firstIndex(where: { $0.name == "Dining" }) {
                scores[idx].score += 1.5
            } else {
                scores.append(("Dining", 1.5, 7))
            }
        }

        // People names with health context boost Health
        let healthContextWords = ["doctor", "dr.", "appointment", "prescription", "diagnosis", "symptoms", "hospital", "clinic", "therapy"]
        let hasHealthContext = healthContextWords.contains { textLower.contains($0) }
        if !entities.people.isEmpty && hasHealthContext {
            if let idx = scores.firstIndex(where: { $0.name == "Health" }) {
                scores[idx].score += 1.0
            }
        }

        // People names with work context boost Work
        let workContextWords = ["meeting", "call", "email", "project", "deadline", "client", "office", "zoom", "slack", "presentation"]
        let hasWorkContext = workContextWords.contains { textLower.contains($0) }
        if !entities.people.isEmpty && hasWorkContext {
            if let idx = scores.firstIndex(where: { $0.name == "Work" }) {
                scores[idx].score += 1.0
            }
        }

        // Find best match — highest score, tiebreak by priority
        if let best = scores.max(by: { a, b in
            a.score < b.score || (a.score == b.score && a.priority > b.priority)
        }) {
            let echo = echos.first { $0.name == best.name }
            let confidence = best.score >= 2.0 ? 0.9 : 0.65
            return (echo?.id, best.name, confidence)
        }

        let notesEcho = echos.first { $0.name == "Notes" }
        return (notesEcho?.id, "Notes", 0.3)
    }

    // MARK: - Date Detection

    private func detectDates(text: String) -> (eventDate: Date?, endDate: Date?, eventConfidence: Double?, reminderDate: Date?, reminderTime: Date?) {
        let lower = text.lowercased()
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)

        let rangeKeywords = [" through ", " until ", " thru ", " - ", "–", "—"]
        for keyword in rangeKeywords {
            if lower.contains(keyword), let splitRange = lower.range(of: keyword) {
                var firstHalf = String(text[text.startIndex..<splitRange.lowerBound])
                let secondHalf = String(text[splitRange.upperBound...])

                if firstHalf.lowercased().hasPrefix("from ") {
                    firstHalf = String(firstHalf.dropFirst(5))
                }
                if let fromRange = firstHalf.range(of: " from ", options: .caseInsensitive) {
                    firstHalf = String(firstHalf[fromRange.upperBound...])
                }

                let range1 = NSRange(firstHalf.startIndex..<firstHalf.endIndex, in: firstHalf)
                let range2 = NSRange(secondHalf.startIndex..<secondHalf.endIndex, in: secondHalf)

                let dates1 = detector?.matches(in: firstHalf, range: range1).compactMap { $0.date } ?? []
                let dates2 = detector?.matches(in: secondHalf, range: range2).compactMap { $0.date } ?? []

                if let startDate = dates1.first, let endDate = dates2.first {
                    return (startDate, endDate, 0.9, nil, nil)
                }
            }
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = detector?.matches(in: text, range: range) ?? []
        let dates = matches.compactMap { $0.date }

        let hasAbsoluteDate = text.contains(where: { $0.isNumber })
        let confidence = hasAbsoluteDate ? 0.9 : 0.6

        guard !dates.isEmpty else { return (nil, nil, nil, nil, nil) }

        if dates.count == 1 {
            let hasReminderPhrase = lower.contains("remind") || lower.contains("don't forget") || lower.contains("dont forget")
            if hasReminderPhrase, let offset = detectRelativeOffset(text: lower) {
                let eventDate = dates[0]
                let reminderDate = eventDate.addingTimeInterval(offset)
                return (eventDate, nil, confidence, reminderDate, reminderDate)
            }
            return (dates[0], nil, confidence, nil, nil)
        }

        let sorted = dates.sorted { abs($0.timeIntervalSinceNow) < abs($1.timeIntervalSinceNow) }
        let nearest = sorted.first!
        let furthest = sorted.last!

        let hasReminderPhrase = lower.contains("remind") || lower.contains("don't forget") || lower.contains("dont forget")
        if hasReminderPhrase && nearest != furthest {
            return (furthest, nil, confidence, nearest, nearest)
        }

        return (furthest, nil, confidence, nil, nil)
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

    private func buildPingSuggestions(text: String, dates: (eventDate: Date?, endDate: Date?, eventConfidence: Double?, reminderDate: Date?, reminderTime: Date?)) -> [PingSuggestion] {
        var suggestions: [PingSuggestion] = []
        let calendar = Calendar.current
        let hasEvery = text.contains("every")

        let hasSpecificTime = text.range(of: #"\bat\s+\d"#, options: .regularExpression) != nil ||
                              text.range(of: #"\d+\s*(am|pm)"#, options: .regularExpression) != nil

        let weekdays = detectWeekdays(text: text)
        if !weekdays.isEmpty {
            let recurrence: Ping.Recurrence = (hasEvery || weekdays.count >= 2) ? .weekly : .none
            for weekday in weekdays {
                let nextDate = nextOccurrence(of: weekday)
                var fireTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())
                if let eventDate = dates.eventDate {
                    let components = calendar.dateComponents([.hour, .minute], from: eventDate)
                    if components.hour != 0 || components.minute != 0 { fireTime = eventDate }
                }
                suggestions.append(PingSuggestion(fireDate: nextDate, fireTime: fireTime, recurrence: recurrence))
            }
            return suggestions
        }

        let isAutoYearly = autoYearlyKeywords.contains { text.contains($0) }
        if isAutoYearly, let eventDate = dates.eventDate {
            let defaultTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: eventDate)
            suggestions.append(PingSuggestion(
                fireDate: eventDate,
                fireTime: hasSpecificTime ? eventDate : defaultTime,
                recurrence: .yearly
            ))
            if let reminderDate = dates.reminderDate {
                suggestions.append(PingSuggestion(
                    fireDate: reminderDate,
                    fireTime: dates.reminderTime ?? (hasSpecificTime ? eventDate : nil),
                    recurrence: Ping.Recurrence.none
                ))
            }
            return suggestions
        }

        if text.contains("every day") || text.contains("daily") {
            let fireDate = dates.eventDate ?? Date()
            suggestions.append(PingSuggestion(fireDate: fireDate, fireTime: dates.eventDate, recurrence: .daily))
            return suggestions
        }
        if text.contains("every week") || text.contains("weekly") {
            let fireDate = dates.eventDate ?? Date()
            suggestions.append(PingSuggestion(fireDate: fireDate, fireTime: dates.eventDate, recurrence: .weekly))
            return suggestions
        }
        if text.contains("every month") || text.contains("monthly") {
            let fireDate = dates.eventDate ?? Date()
            suggestions.append(PingSuggestion(fireDate: fireDate, fireTime: dates.eventDate, recurrence: .monthly))
            return suggestions
        }
        if text.contains("every year") || text.contains("yearly") || text.contains("annually") {
            let fireDate = dates.eventDate ?? Date()
            suggestions.append(PingSuggestion(fireDate: fireDate, fireTime: dates.eventDate, recurrence: .yearly))
            return suggestions
        }

        guard let eventDate = dates.eventDate else { return [] }

        let hasReminderIntent = reminderKeywords.contains { text.contains($0) }
        let isActionable = detectAction(text: text)
        guard hasReminderIntent || hasSpecificTime || isActionable else { return [] }

        if let reminderDate = dates.reminderDate {
            suggestions.append(PingSuggestion(
                fireDate: reminderDate,
                fireTime: dates.reminderTime ?? (hasSpecificTime ? eventDate : nil),
                recurrence: Ping.Recurrence.none
            ))
        } else {
            suggestions.append(PingSuggestion(
                fireDate: eventDate,
                fireTime: hasSpecificTime ? eventDate : nil,
                recurrence: Ping.Recurrence.none
            ))
        }
        return suggestions
    }

    // MARK: - Weekday Detection

    private func detectWeekdays(text: String) -> [Int] {
        var weekdays: [Int] = []
        for (name, number) in weekdayMap {
            if text.contains(name) {
                if !weekdays.contains(number) { weekdays.append(number) }
            }
        }
        if weekdays.count >= 2 { return weekdays }
        else if weekdays.count == 1 && text.contains("every") { return weekdays }
        return []
    }

    private func nextOccurrence(of weekday: Int) -> Date {
        let calendar = Calendar.current
        let today = Date()
        let todayWeekday = calendar.component(.weekday, from: today)
        var daysUntil = (weekday - todayWeekday + 7) % 7
        if daysUntil == 0 { daysUntil = 7 }
        return calendar.date(byAdding: .day, value: daysUntil, to: today) ?? today
    }

    // MARK: - URL Detection

    func detectURL(text: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let matches = detector?.matches(in: text, range: range),
              let firstMatch = matches.first,
              let url = firstMatch.url else { return nil }
        return url.absoluteString
    }

    // MARK: - Checklist Detection

    func detectChecklist(text: String) -> [String]? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if lines.count >= 3 { return lines }

        let commaItems = text.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if commaItems.count >= 3 { return commaItems }

        return nil
    }

    // MARK: - Tag Generation

    private func generateTags(text: String, echoName: String, entities: (people: [String], places: [String], organizations: [String])) -> [String] {
        var tags: [String] = []

        // Add named entities as tags first — highest quality
        for person in entities.people { if !tags.contains(person) && person.count > 2 { tags.append(person) } }
        for place in entities.places { if !tags.contains(place) && place.count > 2 { tags.append(place) } }
        for org in entities.organizations { if !tags.contains(org) && org.count > 2 { tags.append(org) } }

        // Fill remaining slots with nouns
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            if tags.count >= 6 { return false }
            if let tag = tag, tag == .noun {
                let word = String(text[range]).lowercased()
                if !tags.contains(word) && word.count > 3 { tags.append(word) }
            }
            return true
        }

        if !tags.contains(echoName.lowercased()) { tags.append(echoName.lowercased()) }
        return Array(tags.prefix(6))
    }
}
