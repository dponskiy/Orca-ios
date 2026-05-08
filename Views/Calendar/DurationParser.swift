//
//  DurationParser.swift
//  Orca
//
//  Created by David Piliponskiy on 4/19/26.
//

import Foundation

/// Parses estimated task duration from natural language text.
/// Purely display metadata — never interacts with pings or notifications.
class DurationParser {
    static let shared = DurationParser()
    private init() {}

    // MARK: - Public

    /// Returns estimated duration in minutes, or nil if none detected.
    func parse(text: String) -> Int? {
        let lower = text.lowercased()

        // Normalize word numbers to digits before parsing
        let normalized = lower
            .replacingOccurrences(of: "two hours", with: "2 hours")
            .replacingOccurrences(of: "two hour", with: "2 hours")
            .replacingOccurrences(of: "three hours", with: "3 hours")
            .replacingOccurrences(of: "three hour", with: "3 hours")
            .replacingOccurrences(of: "four hours", with: "4 hours")
            .replacingOccurrences(of: "four hour", with: "4 hours")
            .replacingOccurrences(of: "five hours", with: "5 hours")
            .replacingOccurrences(of: "five hour", with: "5 hours")
            .replacingOccurrences(of: "six hours", with: "6 hours")
            .replacingOccurrences(of: "six hour", with: "6 hours")
            .replacingOccurrences(of: "thirty minutes", with: "30 minutes")
            .replacingOccurrences(of: "forty five minutes", with: "45 minutes")
            .replacingOccurrences(of: "forty-five minutes", with: "45 minutes")
            .replacingOccurrences(of: "fifteen minutes", with: "15 minutes")
            .replacingOccurrences(of: "twenty minutes", with: "20 minutes")
            .replacingOccurrences(of: "twenty five minutes", with: "25 minutes")
            .replacingOccurrences(of: "ten minutes", with: "10 minutes")
            .replacingOccurrences(of: "forty five mins", with: "45 minutes")
            .replacingOccurrences(of: "fifteen mins", with: "15 minutes")

        // Qualitative shortcuts
        if containsAny(normalized, ["quick ", "quickly", "briefly"])          { return 20 }
        if containsAny(normalized, ["all day", "full day"])                   { return 480 }
        if normalized.contains("all morning")                                 { return 180 }
        if normalized.contains("all afternoon")                               { return 240 }
        if normalized.contains("all evening")                                 { return 180 }
        if containsAny(normalized, ["half an hour", "half hour", "half-hour"]) { return 30 }
        if containsAny(normalized, ["an hour", "a hour", "one hour"])         { return 60 }

        if let m = extractCombined(normalized) { return m }
        if let m = extractHalfHours(normalized) { return m }
        if let m = extractHours(normalized) { return m }
        if let m = extractMinutes(normalized) { return m }

        return nil
    }

    /// Formats minutes into a compact readable string  →  "45m", "1h", "1h 30m"
    func format(_ minutes: Int) -> String {
        guard minutes > 0 else { return "0m" }
        if minutes < 60 { return "\(minutes)m" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    // MARK: - Private Extraction

    private func containsAny(_ text: String, _ terms: [String]) -> Bool {
        terms.contains { text.contains($0) }
    }

    private func firstMatch(pattern: String, in text: String) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
    }

    private func captureInt(_ match: NSTextCheckingResult, at index: Int, in text: String) -> Int? {
        guard match.numberOfRanges > index,
              let range = Range(match.range(at: index), in: text) else { return nil }
        return Int(text[range])
    }

    private func extractCombined(_ text: String) -> Int? {
        guard let match = firstMatch(
            pattern: #"(\d+)\s*h(?:ours?|r)?\s+(\d+)\s*m(?:in(?:utes?)?)?"#,
            in: text),
              let h = captureInt(match, at: 1, in: text),
              let m = captureInt(match, at: 2, in: text)
        else { return nil }
        return h * 60 + m
    }

    private func extractHalfHours(_ text: String) -> Int? {
        guard let match = firstMatch(pattern: #"(\d+)\.5\s*h(?:ours?|r)?"#, in: text),
              let h = captureInt(match, at: 1, in: text)
        else { return nil }
        return h * 60 + 30
    }

    private func extractHours(_ text: String) -> Int? {
        // Require explicit h/hr/hour suffix; avoid time-of-day matches like "at 3pm"
        guard let match = firstMatch(
            pattern: #"(?<!\d:)(\d+)\s*h(?:ours?|r)\b(?!\s*(?:\d{2}|:|\s*(?:am|pm)))"#,
            in: text),
              let h = captureInt(match, at: 1, in: text),
              h > 0, h <= 24
        else { return nil }

        // Double-check preceding context isn't a time indicator
        if let range = Range(match.range(at: 0), in: text) {
            let start = text.distance(from: text.startIndex, to: range.lowerBound)
            if start >= 3 {
                let lookback = String(text[
                    text.index(text.startIndex, offsetBy: max(0, start - 4))..<range.lowerBound
                ])
                if containsAny(lookback, ["at ", "by ", " at", " by"]) { return nil }
            }
        }
        return h * 60
    }

    private func extractMinutes(_ text: String) -> Int? {
        guard let match = firstMatch(
            pattern: #"(\d+)\s*m(?:in(?:utes?)?)?\b(?!\s*(?:am|pm|:))"#,
            in: text),
              let m = captureInt(match, at: 1, in: text),
              m > 0, m < 600
        else { return nil }
        return m
    }
}
