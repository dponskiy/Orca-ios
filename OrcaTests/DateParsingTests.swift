//
//  DateParsingTests.swift
//  OrcaTests
//
//  How people actually talk, and what Sonar should make of it.
//
//  Add a line to `cases` whenever you think of a new phrasing — no recording
//  needed. Expectations are written the way a person would read them:
//
//      "Sep 4 19:00"        an absolute date and time
//      "Sep 4"              a date with no particular time
//      "+1d 09:00"          9am tomorrow (relative to when the test runs)
//      nil                  nothing should be detected
//
//  Failures print the phrase, what was expected and what came out, so a broken
//  phrasing is readable at a glance rather than a date mismatch.
//

import Testing
import Foundation
@testable import Orca

struct DateParsingTests {

    // MARK: - The table

    /// One phrasing and what it should produce. A struct rather than a tuple so
    /// each case shows up as its own named test.
    struct Phrasing: Sendable, CustomStringConvertible {
        let phrase: String
        let event: String?
        let reminder: String?
        var description: String { phrase }
        init(_ phrase: String, _ event: String?, _ reminder: String?) {
            self.phrase = phrase; self.event = event; self.reminder = reminder
        }
    }

    static let cases: [Phrasing] = [

        // --- Date and time separated by other words (the LinkedIn bug) ---
        Phrasing("Remind me September 4 to post on LinkedIn at 7 PM remind me an hour before",
         "Sep 4 19:00", "Sep 4 18:00"),
        Phrasing("September 4 at 7 PM post on LinkedIn", "Sep 4 19:00", nil),

        // --- Ranges must still work, and must not fire on infinitives ---
        Phrasing("Trip December 14 to December 20", "Dec 14", nil),
        Phrasing("Vacation December 3 through December 9", "Dec 3", nil),
        Phrasing("Remind me Friday to call the vet", "Fri", nil),

        // --- Spoken times from voice transcription ---
        Phrasing("my doctor appointment at 1130 this thursday", "Thu 11:30", nil),
        Phrasing("my doctor appointment at 11 30 this thursday", "Thu 11:30", nil),
        Phrasing("my doctor appointment at eleven thirty this thursday", "Thu 11:30", nil),
        Phrasing("dentist at three o'clock friday", "Fri 15:00", nil),
        Phrasing("call mom at seven forty five tonight", "today 19:45", nil),

        // --- Relative offsets ---
        Phrasing("dentist April 5th at 2pm, remind me the day before", "Apr 5 14:00", "Apr 4 14:00"),
        Phrasing("meeting tomorrow at 9am remind me 30 minutes before", "+1d 09:00", "+1d 08:30"),

        // --- Recurring ---
        Phrasing("submit timesheet every Friday at 4pm", "Fri 16:00", "Fri 16:00"),

        // --- A month that has already gone by rolls to next year ---
        Phrasing("dentist March 3 at 2pm", "Mar 3 14:00", nil),
        Phrasing("remind me January 5 to renew the registration", "Jan 5", nil),
        // ...but not when the year was said outright
        Phrasing("dentist March 3 2026 at 2pm", "Mar 3 2026 14:00", nil),

        // --- Things that are not dates ---
        Phrasing("shoe size 11", nil, nil),
        Phrasing("bench press 225 for 5 reps", nil, nil),
        Phrasing("wifi password is 8675309", nil, nil),
    ]

    // MARK: - Runner

    @Test("Phrasing parses correctly", arguments: cases)
    func phrasing(_ c: Phrasing) {
        let reading = SonarEngine().readDates(c.phrase)

        #expect(Self.matches(expected: c.event, got: reading.eventDate),
                "event — expected \(c.event ?? "nil"), got \(Self.describe(reading.eventDate))")

        if let expectedReminder = c.reminder {
            #expect(Self.matches(expected: expectedReminder, got: reading.reminderFiresAt),
                    "reminder — expected \(expectedReminder), got \(Self.describe(reading.reminderFiresAt))")
        }
    }

    /// Prints every phrase and what it produced. Handy while adding new ones —
    /// run this to see current behaviour before deciding what's correct.
    @Test("Show what every phrase currently produces")
    func showAll() {
        let engine = SonarEngine()
        for c in Self.cases {
            let r = engine.readDates(c.phrase)
            let recurrence = r.recurrence == .none ? "" : "  [\(r.recurrence.rawValue)]"
            print("• \(c.phrase)\n    event: \(Self.describe(r.eventDate))   reminder: \(Self.describe(r.reminderFiresAt))\(recurrence)")
        }
    }

    // MARK: - Comparison

    /// Compares loosely on purpose: an expectation of "Sep 4" only checks the day,
    /// while "Sep 4 19:00" also checks the time. That keeps cases where the time
    /// genuinely doesn't matter from failing on a default.
    private static func matches(expected: String?, got: Date?) -> Bool {
        guard let expected else { return got == nil }
        guard let got, let target = resolve(expected) else { return false }
        let cal = Calendar.current
        guard cal.isDate(got, inSameDayAs: target.date) else { return false }
        guard target.checkTime else { return true }
        let a = cal.dateComponents([.hour, .minute], from: got)
        let b = cal.dateComponents([.hour, .minute], from: target.date)
        return a.hour == b.hour && a.minute == b.minute
    }

    /// Turns "Sep 4 19:00" / "+1d 09:00" / "Thu 11:30" / "today 19:45" into a Date.
    private static func resolve(_ spec: String) -> (date: Date, checkTime: Bool)? {
        let cal = Calendar.current
        let now = Date()
        let parts = spec.split(separator: " ").map(String.init)
        guard let head = parts.first else { return nil }

        var time: (h: Int, m: Int)? = nil
        if parts.count > 1 {
            let hm = parts[1].split(separator: ":").compactMap { Int($0) }
            if hm.count == 2 { time = (hm[0], hm[1]) }
        }

        var base: Date?
        if head.hasPrefix("+"), head.hasSuffix("d"),
           let days = Int(head.dropFirst().dropLast()) {
            base = cal.date(byAdding: .day, value: days, to: now)
        } else if head.lowercased() == "today" {
            base = now
        } else if let weekday = weekdayNumber(head) {
            base = nextOccurrence(of: weekday, from: now)
        } else if parts.count >= 2, let month = monthNumber(head), let day = Int(parts[1]) {
            // "Mar 3 2026 14:00" — an explicit year pins it
            var explicitYear: Int? = nil
            var timeIndex = 2
            if parts.count > 2, let y = Int(parts[2]), y > 1900 {
                explicitYear = y
                timeIndex = 3
            }
            var comps = cal.dateComponents([.year], from: now)
            if let explicitYear { comps.year = explicitYear }
            comps.month = month; comps.day = day
            base = cal.date(from: comps)
            if explicitYear == nil, let b = base, b < cal.startOfDay(for: now) {
                base = cal.date(byAdding: .year, value: 1, to: b)
            }
            if parts.count > timeIndex {
                let hm = parts[timeIndex].split(separator: ":").compactMap { Int($0) }
                time = hm.count == 2 ? (hm[0], hm[1]) : nil
            } else {
                time = nil
            }
        }

        guard let day = base else { return nil }
        guard let t = time else { return (day, false) }
        var comps = cal.dateComponents([.year, .month, .day], from: day)
        comps.hour = t.h; comps.minute = t.m
        guard let exact = cal.date(from: comps) else { return (day, false) }
        return (exact, true)
    }

    private static func monthNumber(_ s: String) -> Int? {
        let months = ["jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
                      "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12]
        return months[String(s.lowercased().prefix(3))]
    }

    private static func weekdayNumber(_ s: String) -> Int? {
        let days = ["sun": 1, "mon": 2, "tue": 3, "wed": 4, "thu": 5, "fri": 6, "sat": 7]
        return days[String(s.lowercased().prefix(3))]
    }

    private static func nextOccurrence(of weekday: Int, from now: Date) -> Date {
        let cal = Calendar.current
        let today = cal.component(.weekday, from: now)
        var delta = (weekday - today + 7) % 7
        if delta == 0 { delta = 7 }
        return cal.date(byAdding: .day, value: delta, to: now) ?? now
    }

    private static func describe(_ date: Date?) -> String {
        guard let date else { return "nil" }
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d yyyy HH:mm"
        return f.string(from: date)
    }
}
