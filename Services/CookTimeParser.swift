//
//  CookTimeParser.swift
//  Orca
//
//  Finds the times inside a recipe step, so each one can be tapped to start a timer.
//
//  Not to be confused with DurationParser, which answers a different question: how long a
//  whole task will take, as one number, with shortcuts like "quick" → 20 minutes. Those
//  shortcuts are wrong here — "quickly sauté the garlic" is not a 20 minute timer — and a
//  step routinely holds more than one time: "simmer 20 minutes, then bake 35-40".
//
//  What it must not find matters as much as what it does. A recipe is full of numbers
//  that aren't times: "bake at 350", "a 9x13 pan", "2 cups of flour". Each of those is in
//  the tests as a line that has to produce nothing.
//

import Foundation

/// A time written in a step, and where it sits, so it can be drawn in place.
struct CookTime: Equatable, Identifiable {
    /// Exactly what was written: "35-40 minutes".
    let text: String
    /// What the timer runs for. A range starts at its lower bound — better to check early
    /// than to find out late.
    let seconds: Int
    /// Where `text` sits in the step it came from.
    let range: Range<String.Index>

    let id = UUID()

    var minutes: Int { seconds / 60 }

    static func == (a: CookTime, b: CookTime) -> Bool {
        a.text == b.text && a.seconds == b.seconds && a.range == b.range
    }
}

enum CookTimeParser {

    // MARK: - Public

    /// Every time in a step, in the order they were written.
    static func times(in step: String) -> [CookTime] {
        var found: [CookTime] = []
        var claimed: [Range<String.Index>] = []

        // Order matters. "1 hour 20 minutes" is one timer of 80 minutes, so the compound
        // form has to be taken before the plain form can read "1 hour" and then wander off
        // with "20 minutes" as a second timer. Each pattern skips text already claimed.
        for pattern in patterns {
            for match in matches(of: pattern.regex, in: step) {
                guard !claimed.contains(where: { $0.overlaps(match.range) }) else { continue }
                guard let seconds = pattern.seconds(match.groups), seconds > 0 else { continue }
                claimed.append(match.range)
                found.append(CookTime(text: String(step[match.range]),
                                      seconds: seconds,
                                      range: match.range))
            }
        }

        return found.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    // MARK: - Patterns

    private struct Pattern {
        let regex: NSRegularExpression
        /// Captured groups → seconds, or nil when they don't describe a time after all.
        let seconds: ([String?]) -> Int?
    }

    private static let unit = #"(seconds?|secs?|minutes?|mins?|hours?|hrs?)"#

    private static let patterns: [Pattern] = {
        func re(_ pattern: String) -> NSRegularExpression {
            // These are all written by hand below, so a bad one is a programming error
            // rather than anything a recipe could cause.
            try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        }

        return [
            // "1 hour 20 minutes", "2 hrs and 5 min"
            Pattern(regex: re(#"\b(\d+)\s*(?:hours?|hrs?)\s*(?:and\s+)?(\d+)\s*(?:minutes?|mins?)\b"#)) { groups in
                guard let hours = groups[1].flatMap(Double.init),
                      let mins = groups[2].flatMap(Double.init) else { return nil }
                return Int(hours * 3600 + mins * 60)
            },

            // "35-40 minutes", "2 to 3 min" — the lower bound starts the timer
            Pattern(regex: re(#"\b(\d+)\s*(?:–|—|-|to)\s*(\d+)\s*"# + unit + #"\b"#)) { groups in
                guard let low = groups[1].flatMap(Double.init), let unit = groups[3] else { return nil }
                return seconds(low, unit: unit)
            },

            // "1½ hours", "1 1/2 hours", "½ hour"
            Pattern(regex: re(#"\b(\d+)?\s*(?:½|1/2)\s*"# + unit + #"\b"#)) { groups in
                guard let unit = groups[2] else { return nil }
                return seconds((groups[1].flatMap(Double.init) ?? 0) + 0.5, unit: unit)
            },

            // "half an hour", "an hour" — written out, with no digits to find
            Pattern(regex: re(#"\b(half\s+an\s+hour|an\s+hour)\b"#)) { groups in
                guard let phrase = groups[1]?.lowercased() else { return nil }
                return phrase.hasPrefix("half") ? 1800 : 3600
            },

            // "20 minutes", "90 seconds", "a 30-minute rest"
            Pattern(regex: re(#"\b(\d+(?:\.\d+)?)[\s-]{0,3}"# + unit + #"\b"#)) { groups in
                guard let value = groups[1].flatMap(Double.init), let unit = groups[2] else { return nil }
                return seconds(value, unit: unit)
            },
        ]
    }()

    private static func seconds(_ value: Double, unit: String) -> Int? {
        let unit = unit.lowercased()
        if unit.hasPrefix("sec") { return Int(value) }
        if unit.hasPrefix("min") { return Int(value * 60) }
        if unit.hasPrefix("hour") || unit.hasPrefix("hr") { return Int(value * 3600) }
        return nil
    }

    // MARK: - Regex plumbing

    private struct Match {
        let range: Range<String.Index>
        let groups: [String?]
    }

    private static func matches(of regex: NSRegularExpression, in text: String) -> [Match] {
        let whole = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, options: [], range: whole).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            let groups = (0..<match.numberOfRanges).map { index -> String? in
                guard let r = Range(match.range(at: index), in: text) else { return nil }
                return String(text[r])
            }
            return Match(range: range, groups: groups)
        }
    }
}
