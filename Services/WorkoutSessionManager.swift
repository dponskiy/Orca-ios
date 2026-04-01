//
//  WorkoutSessionManager.swift
//  Orca
//
//  Created by David Piliponskiy on 3/28/26.
//

import Foundation
import SwiftData

class WorkoutSessionManager {
    static let shared = WorkoutSessionManager()
    private init() {}

    // MARK: - Session Title

    static func sessionTitle(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "Workout · \(formatter.string(from: date))"
    }

    // MARK: - Today's Session

    func todayWorkoutMemory(echos: [Echo], context: ModelContext) -> Memory? {
        guard let workoutEchoId = echos.first(where: { $0.name.lowercased().contains("workout") })?.id else { return nil }
        let descriptor = FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        guard let memories = try? context.fetch(descriptor) else { return nil }
        return memories.first {
            $0.echoId == workoutEchoId &&
            Calendar.current.isDate($0.createdAt, inSameDayAs: Date())
        }
    }

    // MARK: - Merge or Create

    /// Called from voice/typed capture when Sonar routes to Workout.
    /// If a session exists today, appends the new text to it and returns the existing memory.
    /// If no session exists today, returns nil (caller should create a new memory normally).
    func mergeIntoTodaySession(text: String, echos: [Echo], context: ModelContext) -> Memory? {
        guard let existing = todayWorkoutMemory(echos: echos, context: context) else { return nil }

        // Don't re-append a header line
        let newLine = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newLine.isEmpty else { return existing }

        // Check if text is already in the memory to avoid duplicates
        guard !existing.text.contains(newLine) else { return existing }

        existing.text += "\n\(newLine)"
        existing.updatedAt = Date()
        return existing
    }

    // MARK: - Format Quick Log Memory Text

    /// Builds structured memory text from a list of logged lines
    static func formatSessionText(title: String, lines: [String]) -> String {
        ([title] + lines).joined(separator: "\n")
    }
}
