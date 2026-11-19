//
//  RecipeDocument.swift
//  Orca
//
//  A recipe is a Memory: its ingredients are SubTasks, and its steps live in the text
//  under an "Instructions:" line, numbered as they were written.
//
//      🍽 Sunday Sauce
//      45 min · 6 servings
//
//      Instructions:
//      1. Brown the sausage
//      2. Simmer 20 minutes
//
//  Reading that back was written out twice in MemoryDetailView before cooking mode needed
//  it a third time. It lives here now, with the writing half beside it, since adding a
//  step means editing text that also holds the title and the notes above it.
//

import Foundation

enum RecipeDocument {

    /// The marker the steps live under. Written by RecipeImportService and read here.
    static let marker = "Instructions:"

    // MARK: - Reading

    /// The recipe's name: the first line that says something, without the 🍽 it's filed
    /// under.
    ///
    /// Dropping a fixed two characters was wrong three ways. The plate is saved bare by
    /// some capture screens and with a variation selector by others, and `hasPrefix`
    /// doesn't treat those as the same character — so one form kept its emoji inside the
    /// name. It isn't always followed by a space either, so "🍽Sunday Sauce" came back as
    /// "unday Sauce". And a text that opened with a blank line gave up altogether, with
    /// the name sitting right there on the next one.
    ///
    /// Only the preamble is searched, so a recipe with nothing above its steps is called
    /// "Recipe" rather than "1. Brown the sausage".
    static func title(in text: String) -> String {
        for line in preamble(in: text).components(separatedBy: "\n") {
            var name = Substring(line)
            for plate in plates where name.hasPrefix(plate) {
                name = name.dropFirst(plate.count)
                break
            }
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { return trimmed }
        }
        return "Recipe"
    }

    /// One plate, as the two different characters it gets saved as.
    private static let plates = ["🍽️", "🍽"]

    /// The steps, in order, with the numbering they were saved with removed — a step
    /// should read as a step, not as "3. 3." once it's drawn in a numbered list.
    static func steps(in text: String) -> [String] {
        guard let start = markerRange(in: text) else { return [] }
        return text[start.upperBound...]
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { $0.replacingOccurrences(of: #"^\d+[.)]\s*"#, with: "", options: .regularExpression) }
            .filter { !$0.isEmpty }
    }

    /// Everything above the steps — title, timings, notes. What writing must not disturb.
    static func preamble(in text: String) -> String {
        guard let start = markerRange(in: text) else { return text }
        return String(text[..<start.lowerBound])
    }

    // MARK: - Writing

    /// The memory text with these steps in place of whatever was there.
    ///
    /// The block runs to the end of the text, because that's where it's written: the
    /// importer appends it last. So anything a person typed *after* the steps would be
    /// taken for a step and renumbered rather than lost — which is the behaviour the
    /// tests pin down, and the reason this is one function instead of three call sites.
    static func settingSteps(_ steps: [String], in text: String) -> String {
        let kept = steps
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var head = preamble(in: text)
        while head.hasSuffix("\n") { head.removeLast() }

        guard !kept.isEmpty else { return head }

        let numbered = kept.enumerated().map { "\($0.offset + 1). \($0.element)" }
        return head + "\n\n" + marker + "\n" + numbered.joined(separator: "\n")
    }

    // MARK: - Private

    private static func markerRange(in text: String) -> Range<String.Index>? {
        // Matched on its own line so an ingredient that happens to mention the word
        // doesn't start the block early.
        text.range(of: #"(?m)^\s*"# + marker + #"\s*$"#, options: .regularExpression)
    }
}
