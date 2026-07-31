//
//  RecipeExtractor.swift
//  Orca
//
//  Created by David Piliponskiy on 3/3/26.
//

import Foundation

// MARK: - Recipe Result

struct RecipeResult {
    let title: String
    let ingredients: [String]
    let instructions: [String]
    let imageURL: String?
    let prepTime: String?
    let cookTime: String?
    let servings: String?
}

// MARK: - Extractor

actor RecipeExtractor {
    
    static let shared = RecipeExtractor()
    
    enum RecipeError: LocalizedError {
        case invalidURL
        case networkError(Error)
        case noRecipeFound
        case parseError
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:            return "Invalid URL"
            case .networkError(let e):   return "Network error: \(e.localizedDescription)"
            case .noRecipeFound:         return "No recipe found on this page"
            case .parseError:            return "Couldn't parse recipe data"
            }
        }
    }
    
    // MARK: - Public Entry Point
    
    func extract(from urlString: String) async throws -> RecipeResult {
        guard let url = URL(string: urlString) else {
            throw RecipeError.invalidURL
        }
        
        let html: String
        do {
            var request = URLRequest(url: url)
            request.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                forHTTPHeaderField: "User-Agent"
            )
            request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
            request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let string = String(data: data, encoding: .utf8)
                           ?? String(data: data, encoding: .isoLatin1) else {
                throw RecipeError.parseError
            }
            html = string
        } catch let error as RecipeError {
            throw error
        } catch {
            throw RecipeError.networkError(error)
        }
        
        return try parseRecipe(from: html)
    }
    
    // MARK: - Parsing
    
    private func parseRecipe(from html: String) throws -> RecipeResult {
        let scriptPattern = #"<script[^>]*type=["']application/ld\+json["'][^>]*>([\s\S]*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: scriptPattern, options: .caseInsensitive) else {
            throw RecipeError.parseError
        }
        
        let nsHTML = html as NSString
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        
        for match in matches {
            let range = match.range(at: 1)
            guard range.location != NSNotFound else { continue }
            let jsonString = nsHTML.substring(with: range)
            
            guard let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) else { continue }
            
            // Single object
            if let dict = json as? [String: Any],
               let result = try? extractFromDict(dict) {
                return result
            }
            
            // Array of objects
            if let array = json as? [[String: Any]] {
                for dict in array {
                    if let result = try? extractFromDict(dict) {
                        return result
                    }
                }
            }
            
            // @graph wrapper (common on WordPress sites)
            if let dict = json as? [String: Any],
               let graph = dict["@graph"] as? [[String: Any]] {
                for node in graph {
                    if let result = try? extractFromDict(node) {
                        return result
                    }
                }
            }
        }
        
        throw RecipeError.noRecipeFound
    }
    
    private func extractFromDict(_ dict: [String: Any]) throws -> RecipeResult {
        // Check @type — can be a String or [String]
        let typeMatches: Bool
        if let singleType = dict["@type"] as? String {
            typeMatches = singleType.lowercased() == "recipe"
        } else if let typeArray = dict["@type"] as? [String] {
            typeMatches = typeArray.map { $0.lowercased() }.contains("recipe")
        } else {
            typeMatches = false
        }
        
        guard typeMatches else {
            throw RecipeError.noRecipeFound
        }
        
        let title = dict["name"] as? String ?? "Recipe"
        
        // Ingredients
        let ingredients: [String]
        if let raw = dict["recipeIngredient"] as? [String] {
            ingredients = raw
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        } else {
            ingredients = []
        }
        
        // Instructions
        let instructions: [String]
        if let raw = dict["recipeInstructions"] as? [Any] {
            instructions = parseInstructions(raw)
        } else if let raw = dict["recipeInstructions"] as? String {
            instructions = [raw]
        } else {
            instructions = []
        }
        
        guard !ingredients.isEmpty || !instructions.isEmpty else {
            throw RecipeError.noRecipeFound
        }
        
        // Image
        let imageURL: String?
        if let img = dict["image"] as? String {
            imageURL = img
        } else if let imgDict = dict["image"] as? [String: Any] {
            imageURL = imgDict["url"] as? String
        } else if let imgArray = dict["image"] as? [String] {
            imageURL = imgArray.first
        } else {
            imageURL = nil
        }
        
        let prepTime = humanReadableDuration(dict["prepTime"] as? String)
        let cookTime = humanReadableDuration(dict["cookTime"] as? String)
        let servings = (dict["recipeYield"] as? String)
                    ?? (dict["recipeYield"] as? [String])?.first
        
        return RecipeResult(
            title: title,
            ingredients: ingredients,
            instructions: instructions,
            imageURL: imageURL,
            prepTime: prepTime,
            cookTime: cookTime,
            servings: servings
        )
    }
    
    // MARK: - Instruction Parsing
    
    private func parseInstructions(_ raw: [Any]) -> [String] {
        var steps: [String] = []
        for item in raw {
            if let str = item as? String {
                let cleaned = str.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty { steps.append(contentsOf: splitIfMultiStep(cleaned)) }
            } else if let dict = item as? [String: Any] {
                let itemType = (dict["@type"] as? String ?? "").lowercased()
                let isSection = itemType.contains("howtosection") || itemType.contains("howto")

                if isSection, let subItems = dict["itemListElement"] as? [Any] {
                    // HowToSection — always recurse into itemListElement, ignore text
                    steps.append(contentsOf: parseInstructions(subItems))
                } else if let subItems = dict["itemListElement"] as? [Any] {
                    // Any other container with itemListElement
                    steps.append(contentsOf: parseInstructions(subItems))
                } else if let text = dict["text"] as? String {
                    let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty { steps.append(contentsOf: splitIfMultiStep(cleaned)) }
                }
            }
        }
        return steps
    }

    /// If a single "step" string actually contains multiple numbered steps, split them.
    private func splitIfMultiStep(_ text: String) -> [String] {
        // Detect patterns like "1. Do this. 2. Do that." or "Step 1: ... Step 2: ..."
        let numberedPattern = #"(?<!\d)\d+\.\s"#
        let stepPattern = #"(?i)step\s+\d+[:\.]?\s"#
        let hasNumbered = text.range(of: numberedPattern, options: .regularExpression) != nil
        let hasStepLabel = text.range(of: stepPattern, options: .regularExpression) != nil

        guard hasNumbered || hasStepLabel else { return [text] }

        // Split on numbered list markers
        let splitRegex = try? NSRegularExpression(pattern: #"(?<!\d)(\d+)\.\s+"#)
        let ns = text as NSString
        let matches = splitRegex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []

        guard matches.count > 1 else { return [text] }

        var results: [String] = []
        for (i, match) in matches.enumerated() {
            let start = match.range.location + match.range.length
            let end = i + 1 < matches.count ? matches[i + 1].range.location : ns.length
            let step = ns.substring(with: NSRange(location: start, length: end - start))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !step.isEmpty { results.append(step) }
        }
        return results.isEmpty ? [text] : results
    }
    
    // MARK: - ISO 8601 Duration → Human Readable
    
    private func humanReadableDuration(_ iso: String?) -> String? {
        guard let iso = iso else { return nil }
        let pattern = #"PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: iso, range: NSRange(iso.startIndex..., in: iso)) else {
            return nil
        }
        let ns = iso as NSString
        var result = ""
        if match.range(at: 1).location != NSNotFound {
            result += "\(ns.substring(with: match.range(at: 1)))h "
        }
        if match.range(at: 2).location != NSNotFound {
            result += "\(ns.substring(with: match.range(at: 2)))m"
        }
        let trimmed = result.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - OCR Recipe Parser

struct RecipeOCRParser {

    struct OCRRecipeResult {
        let title: String
        let ingredients: [String]
        let instructions: [String]
        let prepTime: String?
        let cookTime: String?
        let servings: String?
    }

    // Matches any cookbook-style step numbering:
    //   ①②③… (Unicode circled)  |  (1)(2)(3)  |  1. 2. 3.  |  1) 2)
    private static let circledStepRegex = try? NSRegularExpression(
        pattern: #"^[①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳❶❷❸❹❺❻❼❽❾❿]"#)
    private static let numberedStepRegex = try? NSRegularExpression(pattern: #"^\d+[\.\)]\s+"#)
    private static let parenthesizedStepRegex = try? NSRegularExpression(pattern: #"^\(\d+\)\s*"#)

    static func detect(in text: String) -> OCRRecipeResult? {
        let lines = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard lines.count >= 3 else { return nil }

        let lower = text.lowercased()
        var score = 0

        let sectionKeywords = ["ingredients", "instructions", "directions", "method", "preparation", "steps", "procedure",
                               "produce", "pantry", "dairy", "meat", "protein"]
        for kw in sectionKeywords where lower.contains(kw) { score += 2 }

        let measurementRegex = try? NSRegularExpression(
            pattern: #"\b\d+\s*(\/\d+)?\s*(cup|tbsp|tsp|tablespoon|teaspoon|oz|ounce|lb|pound|g|gram|kg|ml|liter|litre|clove|pinch|dash|handful|bunch|slice|piece|can|package|bag|stick|sprig)s?\b"#,
            options: .caseInsensitive
        )
        var measurementCount = 0
        for line in lines {
            let r = NSRange(line.startIndex..., in: line)
            if (measurementRegex?.numberOfMatches(in: line, range: r) ?? 0) > 0 { measurementCount += 1 }
        }
        score += min(measurementCount * 2, 6)

        var numberedCount = 0
        for line in lines {
            let r = NSRange(line.startIndex..., in: line)
            if (numberedStepRegex?.numberOfMatches(in: line, range: r) ?? 0) > 0 { numberedCount += 1 }
            if (circledStepRegex?.numberOfMatches(in: line, range: r) ?? 0) > 0 { numberedCount += 1 }
            if (parenthesizedStepRegex?.numberOfMatches(in: line, range: r) ?? 0) > 0 { numberedCount += 1 }
        }
        score += min(numberedCount, 6)

        let cookingVerbs = ["preheat", "bake", "roast", "sauté", "saute", "simmer", "boil", "stir",
                            "whisk", "fold", "combine", "pour", "heat", "chop", "dice", "slice",
                            "mince", "grate", "season", "serve", "fry", "broil", "grill", "marinate"]
        score += min(cookingVerbs.filter { lower.contains($0) }.count, 4)

        guard score >= 5 else { return nil }
        return parse(lines: lines)
    }

    private static func parse(lines: [String]) -> OCRRecipeResult {
        var ingredientIdx: Int?
        var instructionIdx: Int?

        // Ingredient section headers: "Ingredients", "PRODUCE", "PANTRY", "DAIRY", "MEAT", etc.
        let ingredientHeaders = ["ingredient", "produce", "pantry", "dairy", "meat", "protein", "grocery"]
        // Instruction section headers: text keywords OR first circled/numbered step line
        let instructionHeaders = ["instruction", "direction", "method", "preparation", "step", "procedure", "how to"]

        for (i, line) in lines.enumerated() {
            let lower = line.lowercased()
            let r = NSRange(line.startIndex..., in: line)
            if ingredientIdx == nil, line.count < 40,
               ingredientHeaders.contains(where: { lower.contains($0) }) { ingredientIdx = i }
            if instructionIdx == nil {
                if line.count < 40,
                   instructionHeaders.contains(where: { lower.contains($0) }) { instructionIdx = i }
                // Unicode circled (①②…) or OCR-converted parenthesized (1)(2)… signals first instruction
                if (circledStepRegex?.numberOfMatches(in: line, range: r) ?? 0) > 0 { instructionIdx = i }
                if (parenthesizedStepRegex?.numberOfMatches(in: line, range: r) ?? 0) > 0 { instructionIdx = i }
            }
        }

        let metadataPatterns = ["min", "hour", "serving", "yield", "prep", "cook time", "rating", "by "]
        let titleLine: String
        if let ingIdx = ingredientIdx, ingIdx > 0 {
            let candidates = lines[0..<ingIdx].filter { line in
                let l = line.lowercased()
                return !metadataPatterns.contains(where: { l.contains($0) }) && line.count > 3
            }
            // Join consecutive short lines that make up a multi-line cookbook title.
            // Stop at the first long prose line (likely a description/intro sentence).
            var titleParts: [String] = []
            for candidate in candidates {
                if candidate.count > 55 { break }          // prose description starts here
                if candidate.hasSuffix(".") { break }      // sentence end = not a title word
                titleParts.append(candidate)
            }
            titleLine = titleParts.isEmpty ? (candidates.first ?? lines[0])
                                           : titleParts.joined(separator: " ")
        } else {
            titleLine = lines[0]
        }

        let ingStart = (ingredientIdx ?? -1) + 1
        let ingEnd = instructionIdx ?? lines.count
        var ingredients: [String] = []
        if ingStart < ingEnd {
            // Collect raw lines in order so we can detect wrapped continuations
            let rawIngLines = Array(lines[ingStart..<min(ingEnd, lines.count)])
            var merged: [String] = []
            for line in rawIngLines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                // A continuation line: starts lowercase, no digits at front, no measurement word,
                // short (< 30 chars) — likely the wrapped tail of the previous ingredient
                let firstChar = trimmed.unicodeScalars.first
                let startsLower = firstChar.map { CharacterSet.lowercaseLetters.contains($0) } ?? false
                let hasLeadingDigit = trimmed.first?.isNumber ?? false
                let measureStarters = ["cup", "tsp", "tbsp", "tablespoon", "teaspoon", "pound",
                                       "ounce", "gram", "kg", "ml", "oz", "lb", "bunch", "clove",
                                       "slice", "piece", "whole", "large", "medium", "small", "fresh"]
                let startsWithMeasure = measureStarters.contains(where: { trimmed.lowercased().hasPrefix($0) })

                if startsLower && !hasLeadingDigit && !startsWithMeasure
                    && trimmed.count < 35 && !merged.isEmpty
                    && !trimmed.hasPrefix("+") && !trimmed.hasPrefix("•") {
                    // Append to the previous ingredient
                    merged[merged.count - 1] += " " + trimmed
                } else if isIngredientLine(line) {
                    merged.append(trimmed)
                }
            }
            ingredients = merged
        }
        if ingredients.isEmpty { ingredients = lines.filter { isIngredientLine($0) } }

        // Cooking-verb fallback: if no step markers were found, look for the first line
        // after the ingredient section that starts with a recognized cooking action verb.
        // This handles recipes where circled/numbered markers are lost in OCR.
        if instructionIdx == nil {
            let cookVerbStarters = ["preheat", "heat ", "prepare", "cook ", "bake ", "roast ",
                                    "season the", "make the", "combine", "mix ", "stir ", "add the",
                                    "place the", "bring ", "transfer", "remove ", "in a medium",
                                    "in a large", "in the ", "set the", "pat the"]
            let searchFrom = max(ingStart, (ingredientIdx ?? -1) + 1)
            for i in searchFrom..<lines.count {
                let l = lines[i].lowercased()
                if lines[i].count > 15, cookVerbStarters.contains(where: { l.hasPrefix($0) }) {
                    instructionIdx = i
                    break
                }
            }
        }

        func stripStep(_ line: String) -> String {
            var s = line.replacingOccurrences(of: #"^\d+[\.\)]\s+"#, with: "", options: .regularExpression)
            s = s.replacingOccurrences(of: #"^[①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳❶❷❸❹❺❻❼❽❾❿]\s*"#, with: "", options: .regularExpression)
            s = s.replacingOccurrences(of: #"^\(\d+\)\s*"#, with: "", options: .regularExpression)
            s = s.replacingOccurrences(of: #"^[+•→◆\-]\s+"#, with: "", options: .regularExpression)
            return s
        }

        func isStepLine(_ line: String) -> Bool {
            let r = NSRange(line.startIndex..., in: line)
            if (numberedStepRegex?.numberOfMatches(in: line, range: r) ?? 0) > 0 { return true }
            if (circledStepRegex?.numberOfMatches(in: line, range: r) ?? 0) > 0 { return true }
            if (parenthesizedStepRegex?.numberOfMatches(in: line, range: r) ?? 0) > 0 { return true }
            return false
        }

        // Short metadata-only lines to skip in instruction collection (e.g. "Prep: 15 min")
        let shortMetaPatterns = ["prep:", "cook:", "total:", "serves", "yield", "makes", "rating"]

        func isMetaLine(_ line: String) -> Bool {
            let lower = line.lowercased()
            return line.count < 30 && shortMetaPatterns.contains(where: { lower.hasPrefix($0) })
        }

        // Merge continuation lines into parent steps so 44 fragments → ≤10 grouped steps
        func mergeIntoSteps(_ rawLines: [String]) -> [String] {
            var groups: [String] = []
            for line in rawLines {
                let stripped = stripStep(line)
                guard !stripped.isEmpty, stripped.count > 4 else { continue }
                guard !isMetaLine(line) else { continue }
                // A new step starts on: explicit step marker, bullet sub-step, or starts-with capital after a prior group
                let isNewStep = isStepLine(line)
                    || line.hasPrefix("+") || line.hasPrefix("•") || line.hasPrefix("→")
                    || groups.isEmpty
                    || (groups.count > 0 && stripped.first?.isUppercase == true && stripped.count > 20)
                if isNewStep {
                    groups.append(stripped)
                } else if !groups.isEmpty {
                    // Append to the current step
                    groups[groups.count - 1] += " " + stripped
                } else {
                    groups.append(stripped)
                }
            }
            return groups
        }

        var instructions: [String] = []
        if let instrIdx = instructionIdx {
            let instrLines = Array(lines[instrIdx...])
            // Collect candidate lines: step markers, bullets, or substantive prose (>15 chars, not short meta)
            let candidateLines = instrLines.filter { line in
                if isStepLine(line) { return true }
                if line.hasPrefix("+") || line.hasPrefix("•") || line.hasPrefix("→") { return true }
                if line.count <= 5 { return false }
                return line.count > 15 && !isMetaLine(line)
            }
            let merged = mergeIntoSteps(candidateLines)
            instructions = merged.isEmpty ? instrLines.filter { $0.count > 10 }.compactMap {
                let s = stripStep($0); return s.isEmpty ? nil : s
            } : merged
        } else {
            let stepLines = lines.filter { isStepLine($0) }
            instructions = mergeIntoSteps(stepLines)
        }

        // Extract prep time, cook time, servings from the first portion of OCR text
        let searchText = lines.prefix(min(25, lines.count)).joined(separator: "\n")

        func extractTimeField(pattern: String, from text: String) -> String? {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
            let nsText = text as NSString
            guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)),
                  match.numberOfRanges > 2,
                  let numRange = Range(match.range(at: 1), in: text),
                  let unitRange = Range(match.range(at: 2), in: text) else { return nil }
            let num = String(text[numRange])
            let unit = String(text[unitRange]).lowercased()
            let unitShort = (unit.hasPrefix("hour") || unit == "h" || unit.hasPrefix("hr")) ? "hr" : "min"
            return "\(num) \(unitShort)"
        }

        func extractServings(from text: String) -> String? {
            let pattern = #"(?:serves?|servings?|yield(?:s)?|makes?)\s*:?\s*(\d+(?:\s*[-–]\s*\d+)?)"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
            let nsText = text as NSString
            guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)),
                  match.numberOfRanges > 1,
                  let numRange = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[numRange])
        }

        let prepTime = extractTimeField(
            pattern: #"(?:prep(?:\s+time)?|preparation(?:\s+time)?)\s*:?\s*(\d+(?:\s*[-–]\s*\d+)?)\s*(min(?:utes?)?|hr?s?|hours?)"#,
            from: searchText)
        let cookTime = extractTimeField(
            pattern: #"(?:cook(?:ing)?(?:\s+time)?|bak(?:ing)?(?:\s+time)?|total(?:\s+time)?)\s*:?\s*(\d+(?:\s*[-–]\s*\d+)?)\s*(min(?:utes?)?|hr?s?|hours?)"#,
            from: searchText)
        let servings = extractServings(from: searchText)

        return OCRRecipeResult(title: titleLine, ingredients: ingredients, instructions: instructions,
                               prepTime: prepTime, cookTime: cookTime, servings: servings)
    }

    private static func isIngredientLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        guard line.count > 1 else { return false }

        // Bare numbers only (page numbers, footnote markers like "77")
        if lower.range(of: #"^\d+$"#, options: .regularExpression) != nil { return false }

        // Bullet sub-steps are instructions
        if line.hasPrefix("+") || line.hasPrefix("•") || line.hasPrefix("→") || line.hasPrefix("◆") { return false }

        // Circled number steps are instructions
        let r = NSRange(line.startIndex..., in: line)
        if (circledStepRegex?.numberOfMatches(in: line, range: r) ?? 0) > 0 { return false }

        // Sentence fragments: word immediately followed by comma or period at start of line
        // e.g. "sheet. Season..." / "paste, 1 tablespoon..." / "chicken, toss..."
        if lower.range(of: #"^[a-z]+[,\.]"#, options: .regularExpression) != nil { return false }

        // Lines starting with articles, prepositions, conjunctions — sentence context, not an ingredient
        let nonIngredientStarters = ["the ", "a ", "an ", "this ", "that ", "these ", "those ",
                                     "quite ", "one of", "each ", "while ", "when ", "after ",
                                     "and ", "but ", "for ", "with ", "in ", "no ", "not "]
        if nonIngredientStarters.contains(where: { lower.hasPrefix($0) }) { return false }

        // Ingredient category headers (PRODUCE, PANTRY, DAIRY, MEAT)
        let categoryHeaders = ["produce", "pantry", "dairy", "meat", "protein", "grocery"]
        if line.count < 20, categoryHeaders.contains(where: { lower == $0 || lower.hasPrefix($0) }) { return false }

        // Header-only lines
        let headerWords = ["ingredient", "instruction", "direction", "method", "preparation",
                           "step", "note", "tip", "equipment", "serve", "serving", "yield"]
        if headerWords.contains(where: { lower == $0 || lower == $0 + "s" }) { return false }

        // Numbered steps ("1. Preheat...", "2. Stir...") are instructions
        if lower.range(of: #"^\d+[\.\)]\s+[a-z]"#, options: .regularExpression) != nil { return false }

        // Long lines are instructions
        if line.count > 75 { return false }

        // Instruction signal words
        let instructionSignals = ["until", "degrees", "°f", "°c", "minutes", "seconds",
                                  "preheat", "set aside", "let cool", "let rest", "allow", "hours", " aside"]
        if instructionSignals.contains(where: { lower.contains($0) }) { return false }

        // Lines starting with a cooking action verb are instructions
        let actionPrefixes = ["stir", "mix", "fold", "pour", "heat", "cook", "bake", "roast",
                              "simmer", "boil", "whisk", "blend", "remove", "transfer", "place",
                              "combine", "drain", "cool", "serve", "season", "toss", "arrange",
                              "spread", "return", "reduce", "continue", "baste", "shake", "tilt",
                              "add ", "in a ", "using ", "once ", "meanwhile"]
        if actionPrefixes.contains(where: { lower.hasPrefix($0) }) { return false }

        // Strong signal: has a measurement unit near the START of the line (within first 20 chars)
        // This prevents matching "Season chicken with 4 teaspoons salt" as an ingredient
        let measurePattern = #"\b\d+\s*(\/\d+)?\s*(cup|tbsp|tsp|tablespoon|teaspoon|oz|ounce|lb|pound|g|gram|kg|ml|liter|litre|clove|pinch|dash|handful|bunch|slice|piece|can|package|bag|stick|sprig)s?\b"#
        if let regex = try? NSRegularExpression(pattern: measurePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: line, range: r) {
            return match.range.location < 20
        }

        // Starts with a number or fraction (e.g. "2 eggs", "½ cup")
        if lower.range(of: #"^[\d½⅓⅔¼¾⅛⅜⅝⅞]"#, options: .regularExpression) != nil { return true }

        // Named ingredient words — only on short lines AND word appears near the start
        if line.count <= 45 {
            let ingredientWords = ["egg", "flour", "sugar", "butter", "milk", "cream", "salt",
                                   "pepper", "oil", "water", "garlic", "onion", "lemon", "vanilla",
                                   "baking soda", "baking powder", "yeast", "honey", "vinegar",
                                   "stock", "broth", "tomato", "cheese", "chicken", "beef",
                                   "pork", "rice", "pasta"]
            if let word = ingredientWords.first(where: { lower.contains($0) }),
               let range = lower.range(of: word) {
                let position = lower.distance(from: lower.startIndex, to: range.lowerBound)
                // Word must be near the start, and not followed by "in", "on", "from", "no"
                // (which signals it's being used in a sentence about the ingredient, not listed)
                if position <= 12 {
                    let after = String(lower[range.upperBound...])
                    let sentencePrepositions = [" in ", " on ", " from ", " no ", " of the"]
                    return !sentencePrepositions.contains(where: { after.hasPrefix($0) })
                }
            }
        }

        return false
    }
}

// MARK: - Memory Population Helper

extension RecipeExtractor {
    
    /// Formats a RecipeResult into a clean memory text string.
    static func memoryText(from recipe: RecipeResult) -> String {
        var parts: [String] = []
        parts.append("🍽 \(recipe.title)")
        
        var meta: [String] = []
        if let prep = recipe.prepTime  { meta.append("Prep: \(prep)") }
        if let cook = recipe.cookTime  { meta.append("Cook: \(cook)") }
        if let srv  = recipe.servings  { meta.append("Serves: \(srv)") }
        if !meta.isEmpty { parts.append(meta.joined(separator: " · ")) }
        
        if !recipe.instructions.isEmpty {
            parts.append("\nInstructions:")
            for (i, step) in recipe.instructions.enumerated() {
                parts.append("\(i + 1). \(step)")
            }
        }
        
        return parts.joined(separator: "\n")
    }
}
