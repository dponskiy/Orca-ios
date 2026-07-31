//
//  AppleIntelligenceService.swift
//  Orca
//
//  Requires: iOS 26+, iPhone 15 Pro or later (hardware gate via isAvailable)
//  Fallback: all methods return nil or the original Sonar value on unsupported devices
//

import Foundation
import FoundationModels

final class AppleIntelligenceService {

    static let shared = AppleIntelligenceService()
    private init() {}

    // MARK: - Availability
    var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    // MARK: - Generable Output Types

    @Generable
    struct EchoClassification {
        @Guide(description: """
            Exactly one of: Health, Kids, Birthday, Gifts, Travel, Cooking, Dining, Sports, \
            Events, Shopping, Home, School, Work, Pets, Finance, Holidays, To-Do, Games, \
            Movies, Books, Clothes, Workout, Notes
            """)
        var echoName: String

        @Guide(description: "Your confidence in this classification from 0.0 to 1.0")
        var confidence: Double
    }

    @Generable
    struct ImpliedPingResult {
        @Guide(description: """
            True if the text implies a future deadline, expiration, renewal, \
            or time-sensitive event the user did not explicitly ask to be reminded about
            """)
        var hasImpliedDeadline: Bool

        @Guide(description: "Short label for the implied deadline, e.g. 'passport expires', 'lease renewal due', 'car registration'")
        var label: String?

        @Guide(description: "Estimated number of time units until the event. Nil if not determinable.")
        var relativeValue: Int?

        @Guide(description: "Time unit for relativeValue. One of: days, weeks, months. Nil if not determinable.")
        var relativeUnit: String?
    }

    @Generable
    struct ActionabilityResult {
        @Guide(description: """
            True if the text represents something the user intends or needs to do in the future. \
            False for past observations, completed events, or reference notes.
            """)
        var isActionable: Bool

        @Guide(description: "Confidence in this determination from 0.0 to 1.0")
        var confidence: Double
    }

    @Generable
    struct MediaTitleResult {
        @Guide(description: """
            The exact title of the book, movie, TV show, or other media item mentioned. \
            Just the title — no author, no 'by', no surrounding words. \
            For example: 'Atomic Habits', 'The Bear', 'Inception'. \
            Nil if no clear title can be identified.
            """)
        var title: String?
    }

    @Generable
    struct ParsedGroceryItem {
        @Guide(description: """
            Clean canonical item name, capitalized, no quantity. \
            E.g. 'Almond Milk', 'Chicken Breast', 'Tofu', 'Sourdough Bread'. \
            Remove filler words like 'some', 'a', 'the', 'those', 'get me'.
            """)
        var name: String

        @Guide(description: """
            Quantity and unit ONLY if a specific amount or unit was explicitly stated. \
            E.g. '2 cans', '1 dozen', 'large', '3 lbs'. \
            MUST be nil if no quantity was mentioned or if quantity is just '1' with no unit. \
            Never default to '1' — nil is correct when no quantity is specified.
            """)
        var quantity: String?

        @Guide(description: """
            Best grocery store aisle for this item. Exactly one of: \
            Produce, Meat, Seafood, Dairy & Eggs, Deli & Prepared, Bakery & Bread, \
            Frozen, Canned & Jarred, Pasta Rice & Grains, Breakfast, Snacks, \
            Beverages, Beer Wine & Spirits, Condiments & Sauces, Oils & Vinegars, \
            Baking & Spices, Supplements, Body Care, Household, Pet, Other
            """)
        var aisle: String
    }

    @Generable
    struct GroceryParseResult {
        @Guide(description: """
            All grocery items explicitly mentioned in the input, each as a separate entry. \
            CRITICAL: Only include items the user actually said. \
            Do NOT infer, suggest, add, or expand items not explicitly stated. \
            If the user said 3 items, return exactly 3 items.
            """)
        var items: [ParsedGroceryItem]
    }

    @Generable
    struct PersonFilterResult {
        @Guide(description: """
            Only the names from the input list that are actual human person names. \
            Remove any that are brands, companies, products, places, or non-human proper nouns. \
            Return empty array if none are actual people.
            """)
        var actualPeople: [String]
    }

    @Generable
    struct UnknownExerciseResult {
        @Guide(description: """
            The canonical exercise name, properly capitalized. \
            E.g. 'Cable Fly', 'Hack Squat', 'Nordic Curl', 'Farmers Carry'. \
            Return nil if no exercise can be identified.
            """)
        var canonicalName: String?

        @Guide(description: """
            The primary muscle group targeted. Exactly one of: \
            chest, back, legs, shoulders, biceps, triceps, core, glutes, traps, cardio, recovery. \
            Return nil if not determinable.
            """)
        var muscleGroup: String?

        @Guide(description: "True if this is a cardio exercise (running, cycling, swimming, rowing, etc.)")
        var isCardio: Bool
    }

    @Generable
    struct WorkoutSummaryResult {
        @Guide(description: """
            A concise one-line summary of the workout session. \
            Max 60 characters. Include the session type if clear, key highlight (e.g. PR), \
            and exercise count if multiple. \
            Examples: \
            'Push day · Bench PR · 4 exercises', \
            'Leg day · 315 squat · 5 exercises', \
            'Morning run · 6.2 mi · 8:45/mi', \
            'Upper body · 3 exercises', \
            'Full body · 45 min'. \
            Never include the date — that's handled separately.
            """)
        var summary: String
    }

    // MARK: - Echo Classification

    func classifyEcho(
        text: String,
        currentEcho: String,
        currentConfidence: Double
    ) async -> String {
        guard isAvailable, currentConfidence < 0.8 else { return currentEcho }

        let prompt = """
        Classify this personal memory note into exactly one category. \
        Use the current system guess as context — only correct it if you are more confident.

        Category definitions:
        • Health — doctors, medications, appointments, symptoms, therapy, mental health
        • Kids — daycare, school pickups, pediatrician, homework, activities, childcare
        • Birthday — birthday dates, birthday parties, birthday gifts, age milestones
        • Gifts — gift ideas, presents, wish lists, what someone wants for an occasion
        • Travel — flights, hotels, trips, bookings, passports, destinations, road trips
        • Cooking — making food at home, recipes, ingredients, meal prep, baking
        • Dining — restaurants, eating out, specific dishes at a venue, food delivery, cafes
        • Sports — teams, games, scores, athletes, leagues, fantasy, betting
        • Events — concerts, shows, festivals, conferences, weddings, parties, tickets
        • Shopping — products to buy, prices, stores, orders, deals, tracking packages
        • Home — repairs, rent, landlord, renovations, furniture, household tasks, mortgage
        • School — classes, exams, professors, tuition, assignments, grades, college
        • Work — meetings, deadlines, projects, colleagues, interviews, salary, clients
        • Pets — vet visits, pet food, grooming, dog walks, medications, boarding
        • Finance — stocks, tickers, prices, budgets, investing, banking, taxes, crypto
        • Holidays — Christmas, Thanksgiving, Halloween, holiday shopping, decorations
        • To-Do — tasks, errands, reminders, chores, things to get done
        • Games — video games, consoles, gaming sessions, achievements, esports
        • Movies — films, TV shows, streaming content to watch or currently watching
        • Books — books to read, currently reading, audiobooks, book recommendations
        • Clothes — clothing, outfits, shoes, fashion, shopping for apparel, alterations
        • Workout — exercise sessions, gym, runs, lifting, fitness tracking, personal records
        • Notes — catch-all: observations, references, or anything that doesn't clearly fit above

        Current system guess: \(currentEcho) (confidence: \(String(format: "%.2f", currentConfidence)))
        Memory: "\(text)"
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt, generating: EchoClassification.self)
            let result = response.content
            return result.confidence > currentConfidence ? result.echoName : currentEcho
        } catch {
            return currentEcho
        }
    }

    // MARK: - Implied Ping Detection

    func detectImpliedPing(text: String) async -> (label: String, date: Date?)? {
        guard isAvailable else { return nil }

        let prompt = """
        Analyze this personal memory note for implied future deadlines, expirations, renewals, \
        or time-sensitive events.

        Positive examples — things to flag:
        • "my passport expires next month" → expiration, ~1 month out
        • "lease renewal coming up in the fall" → renewal, ~3–4 months out
        • "car registration is due soon" → registration due, near future
        • "annual physical coming up" → appointment needed
        • "gym membership renews in a few weeks" → renewal, ~2–3 weeks

        Do NOT flag if:
        • The user already mentioned a specific date or said "remind me"
        • The text is a past observation with no future pressure
        • The text describes something already completed

        Memory: "\(text)"
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt, generating: ImpliedPingResult.self)
            let result = response.content
            guard result.hasImpliedDeadline, let label = result.label else { return nil }
            return (label, resolveRelativeDate(value: result.relativeValue, unit: result.relativeUnit))
        } catch {
            return nil
        }
    }

    // MARK: - Actionability Detection

    func detectActionability(text: String) async -> Bool? {
        guard isAvailable else { return nil }

        let prompt = """
        Determine if this personal memory note represents something the user needs or intends to do.

        Actionable = future intent, tasks, plans, conditional goals, implied obligations.
        Not actionable = past observations, completed events, reference notes, general info.

        Examples:
        • "need to call the dentist next week" → actionable
        • "had an amazing dinner at Nobu last night" → NOT actionable
        • "mom's birthday is in two weeks, get her a gift" → actionable
        • "just finished Atomic Habits, really liked it" → NOT actionable
        • "AAPL dropped to 180 today" → NOT actionable (observation)
        • "buy AAPL if it drops below 170" → actionable (conditional intent)
        • "passport expires in 3 months" → actionable (implied task)
        • "hit a new bench PR today, 225 for 5" → NOT actionable (completed)
        • "need to renew gym membership before it expires" → actionable

        Memory: "\(text)"
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt, generating: ActionabilityResult.self)
            let result = response.content
            guard result.confidence >= 0.65 else { return nil }
            return result.isActionable
        } catch {
            return nil
        }
    }

    // MARK: - Media Title Extraction

    func extractMediaTitle(from text: String) async -> String? {
        let fallback = extractMediaTitleFallback(from: text)
        guard isAvailable else { return fallback }

        let prompt = """
        Extract the media title from this note. Return only the exact title of the book, \
        movie, TV show, podcast, or other media item — nothing else. No author name, \
        no studio, no surrounding words.

        Examples:
        • "Just finished Atomic Habits, loved it" → Atomic Habits
        • "Watching The Bear on Hulu" → The Bear
        • "Finally saw Inception last night" → Inception
        • "Reading Sapiens right now" → Sapiens
        • "Want to watch Severance" → Severance
        • "Listened to How I Built This today" → How I Built This

        Memory: "\(text)"
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt, generating: MediaTitleResult.self)
            return response.content.title ?? fallback
        } catch {
            return fallback
        }
    }

    private func extractMediaTitleFallback(from text: String) -> String? {
        let lower = text.lowercased()
        let patterns = [
            "just finished ", "finished reading ", "finished watching ",
            "just watched ", "currently reading ", "currently watching ",
            "now watching ", "reading ", "watching ", "want to watch ",
            "want to read ", "need to watch ", "need to read ",
            "finally watched ", "finally read ", "just read ", "listened to ",
        ]
        for pattern in patterns {
            if lower.hasPrefix(pattern) {
                let after = String(text.dropFirst(pattern.count))
                let stripped = after
                    .components(separatedBy: CharacterSet(charactersIn: ",.!"))
                    .first?
                    .trimmingCharacters(in: .whitespaces)
                if let stripped, stripped.count > 2 { return stripped }
            }
            if let range = lower.range(of: pattern) {
                let after = String(text[range.upperBound...])
                let stripped = after
                    .components(separatedBy: CharacterSet(charactersIn: ",.!"))
                    .first?
                    .trimmingCharacters(in: .whitespaces)
                if let stripped, stripped.count > 2 { return stripped }
            }
        }
        return nil
    }

    // MARK: - Person vs Brand Disambiguation

    func filterPeople(_ candidates: [String], from text: String) async -> [String] {
        guard isAvailable, !candidates.isEmpty else { return candidates }

        let prompt = """
        From this list of detected names, keep only ones that are actual human person names. \
        Remove brands, companies, products, places, or anything that isn't a real person's name.

        Examples of what to REMOVE:
        - Nike, Adidas, Apple, Google, Amazon, Tesla, Netflix, Spotify (brands)
        - iPhone, MacBook, AirPods, PlayStation (products)
        - Gucci, Prada, Zara, Lululemon (fashion brands)
        - Manhattan, Brooklyn, Paris (places)
        - Uber, Lyft, DoorDash, Venmo (apps/services)

        Examples of what to KEEP:
        - Sarah, Mike, James, Emma (clearly human names)
        - Any name used in personal context like "call Mike" or "get Sarah a gift"
        - Less common names that are clearly human in context

        Context (the full memory): "\(text)"
        Candidate names: \(candidates.joined(separator: ", "))
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt, generating: PersonFilterResult.self)
            let filtered = response.content.actualPeople
            return filtered.isEmpty && !candidates.isEmpty ? candidates : filtered
        } catch {
            return candidates
        }
    }

    // MARK: - Unknown Exercise Recognition

    func recognizeExercise(from text: String) async -> (name: String, muscleGroup: String, isCardio: Bool)? {
        guard isAvailable else { return nil }

        let prompt = """
        Identify the exercise being described in this workout note. \
        Return the canonical exercise name, primary muscle group, and whether it's cardio.

        Examples:
        • "did some face pulls" → Face Pull, shoulders, false
        • "reverse pec deck" → Rear Delt Fly, shoulders, false
        • "nordic hamstring curls" → Nordic Curl, legs, false
        • "farmers carry with 70s" → Farmers Carry, traps, false
        • "band pull aparts" → Band Pull Apart, shoulders, false
        • "sled push" → Sled Push, legs, false
        • "battle ropes for 3 rounds" → Battle Ropes, cardio, true
        • "zone 2 cardio on the bike" → Cycling, cardio, true
        • "went for a swim" → Swim, cardio, true

        Return nil for name if no exercise can be identified — do not guess randomly.

        Workout note: "\(text)"
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt, generating: UnknownExerciseResult.self)
            let result = response.content
            guard let name = result.canonicalName,
                  let muscle = result.muscleGroup else { return nil }
            return (name, muscle, result.isCardio)
        } catch {
            return nil
        }
    }

    // MARK: - Workout Session Summarization

    func summarizeWorkout(from text: String) async -> String? {
        guard isAvailable else { return nil }

        let prompt = """
        Summarize this workout session as a single concise line (max 60 chars). \
        Include the most useful details: session type, standout achievement (PR, distance, weight), \
        and exercise count if multiple. Never include the date.

        Examples of good summaries:
        • "Push day · Bench PR · 4 exercises"
        • "Leg day · 315 squat · 5 exercises"
        • "Morning run · 6.2 mi · 8:45/mi pace"
        • "Upper body · 3 exercises · felt strong"
        • "Full body · 45 min · 5 exercises"
        • "Swim · 1 mile · 38 min"
        • "Cycling · 22 mi · 18.5 mph"

        Workout log:
        "\(text)"
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt, generating: WorkoutSummaryResult.self)
            let summary = response.content.summary
            return summary.isEmpty ? nil : summary
        } catch {
            return nil
        }
    }

    // MARK: - Grocery Input Parsing

    func parseGroceryInput(_ input: String) async -> [ParsedGroceryItem] {
        guard isAvailable else { return parseGroceryFallback(input) }

        let prompt = """
        Parse this grocery input into individual items.

        CRITICAL RULES:
        1. Only extract items the user explicitly mentioned — never infer, suggest, or add items
        2. If the user said 3 items, return exactly 3 items
        3. Do not expand brand names into product lines
        4. Do not add complementary items (e.g. if user says "eggs" don't also add "butter")
        5. Quantity should be nil unless a specific amount or unit was stated
        6. Never set quantity to "1" — if no quantity was mentioned, quantity must be nil

        The input may be:
        - A single item: "almond milk"
        - Multiple items: "milk eggs and butter"
        - A voice transcription: "get me some tofu tempeh and those impossible burgers"
        - Items with quantities: "2 cans of diced tomatoes, a dozen eggs, 3 lbs chicken breast"

        For each item:
        - Extract just the clean canonical name (capitalize, remove filler words)
        - Extract quantity ONLY if explicitly stated with an amount or unit
        - Assign the best grocery store aisle

        Input: "\(input)"
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt, generating: GroceryParseResult.self)
            return response.content.items
        } catch {
            return parseGroceryFallback(input)
        }
    }

    private func parseGroceryFallback(_ input: String) -> [ParsedGroceryItem] {
        let parts = input
            .components(separatedBy: ",")
            .flatMap { $0.components(separatedBy: " and ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.map { text in
            let capitalized = text.prefix(1).uppercased() + text.dropFirst().lowercased()
            return ParsedGroceryItem(name: capitalized, quantity: nil, aisle: "Other")
        }
    }

    // MARK: - Aisle Resolution for "Other" Items

    func resolveAisles(for items: [String]) async -> [String: String] {
        guard isAvailable, !items.isEmpty else { return [:] }

        let itemList = items.map { "- \($0)" }.joined(separator: "\n")

        let prompt = """
        For each of these grocery items that couldn't be automatically categorized, \
        assign the best grocery store aisle. Return exactly one aisle per item.

        Available aisles: Produce, Meat, Seafood, Dairy & Eggs, Deli & Prepared, \
        Bakery & Bread, Frozen, Canned & Jarred, Pasta Rice & Grains, Breakfast, \
        Snacks, Beverages, Beer Wine & Spirits, Condiments & Sauces, Oils & Vinegars, \
        Baking & Spices, Supplements, Body Care, Household, Pet, Other

        Examples of tricky items:
        - Tofu → Produce
        - Tempeh → Produce
        - Kimchi → Condiments & Sauces
        - Kombucha → Beverages
        - Miso paste → Condiments & Sauces
        - Oat milk → Dairy & Eggs
        - Impossible burger → Meat
        - Protein bar → Snacks
        - Edamame → Produce
        - Nori → Canned & Jarred
        - Matcha powder → Baking & Spices

        Items to classify:
        \(itemList)

        Respond with each item and its aisle, one per line, format: "Item Name: Aisle"
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            return parseAisleResponse(response.content, items: items)
        } catch {
            return [:]
        }
    }

    private func parseAisleResponse(_ text: String, items: [String]) -> [String: String] {
        var result: [String: String] = [:]
        let lines = text.components(separatedBy: "\n").filter { $0.contains(":") }
        for line in lines {
            let parts = line.components(separatedBy: ":").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2 else { continue }
            let itemName = parts[0].trimmingCharacters(in: CharacterSet(charactersIn: "- "))
            let aisle = parts[1]
            if let match = items.first(where: {
                $0.lowercased().hasPrefix(itemName.lowercased().prefix(4))
            }) {
                result[match] = aisle
            }
        }
        return result
    }

    // MARK: - Enhance

    func enhance(text: String, sonarResult: SonarResult, echos: [Echo]) async -> SonarResult {
        guard isAvailable else { return sonarResult }

        async let echoName = classifyEcho(
            text: text,
            currentEcho: sonarResult.echoName,
            currentConfidence: sonarResult.echoConfidence
        )
        async let aiActionable = detectActionability(text: text)

        let impliedPing: (label: String, date: Date?)?
        if sonarResult.shouldCreatePing {
            impliedPing = nil
        } else {
            // Only run the expensive LLM check if the text has forward-looking deadline language.
            // Pure reference notes ("my shoe size is 11", "wifi password is abc") should never produce pings.
            let lower = text.lowercased()
            let impliedDeadlineWords = ["expires", "expiring", "expiration", "renewal", "renew", "due", "overdue",
                                        "coming up", "running out", "runs out", "deadline", "cut off", "cutoff",
                                        "end of", "last day", "need to renew", "need to update", "registration",
                                        "membership", "subscription", "warranty", "recall", "appointment needed",
                                        "schedule", "book", "haven't", "should", "remind"]
            let hasImpliedDeadlineSignal = impliedDeadlineWords.contains { lower.contains($0) }
            impliedPing = hasImpliedDeadlineSignal ? await detectImpliedPing(text: text) : nil
        }

        let resolvedEchoName = await echoName
        let resolvedActionable = await aiActionable
        let echo = echos.first { $0.name == resolvedEchoName }

        let filteredPeople: [String]
        if !sonarResult.detectedPeople.isEmpty {
            filteredPeople = await filterPeople(sonarResult.detectedPeople, from: text)
        } else {
            filteredPeople = sonarResult.detectedPeople
        }

        var enhancedPingSuggestions = sonarResult.pingSuggestions
        var enhancedShouldCreatePing = sonarResult.shouldCreatePing
        var enhancedPingFireDate = sonarResult.pingFireDate
        var enhancedPingFireTime = sonarResult.pingFireTime

        if let implied = impliedPing {
            let suggestion = PingSuggestion(
                fireDate: implied.date,
                fireTime: implied.date,
                recurrence: .none
            )
            enhancedPingSuggestions = [suggestion]
            enhancedShouldCreatePing = true
            enhancedPingFireDate = implied.date
            enhancedPingFireTime = implied.date
        }

        return SonarResult(
            echoId: echo?.id ?? sonarResult.echoId,
            echoName: resolvedEchoName,
            echoConfidence: sonarResult.echoConfidence,
            detectedDate: sonarResult.detectedDate,
            endDate: sonarResult.endDate,
            dateConfidence: sonarResult.dateConfidence,
            tags: sonarResult.tags,
            shouldCreatePing: enhancedShouldCreatePing,
            pingRecurrence: sonarResult.pingRecurrence,
            isActionable: resolvedActionable ?? sonarResult.isActionable,
            pingFireDate: enhancedPingFireDate,
            pingFireTime: enhancedPingFireTime,
            pingSuggestions: enhancedPingSuggestions,
            shouldOfferRecipeFetch: sonarResult.shouldOfferRecipeFetch,
            suggestedLocationName: sonarResult.suggestedLocationName,
            hasRestaurantSignal: sonarResult.hasRestaurantSignal,
            detectedPeople: filteredPeople,
            estimatedMinutes: sonarResult.estimatedMinutes,
            checklistItems: sonarResult.checklistItems
        )
    }

    // MARK: - Helpers

    private func resolveRelativeDate(value: Int?, unit: String?) -> Date? {
        guard let value, let unit else { return nil }
        let calendar = Calendar.current
        let now = Date()
        switch unit.lowercased() {
        case "days":   return calendar.date(byAdding: .day, value: value, to: now)
        case "weeks":  return calendar.date(byAdding: .weekOfYear, value: value, to: now)
        case "months": return calendar.date(byAdding: .month, value: value, to: now)
        default:       return nil
        }
    }
}
