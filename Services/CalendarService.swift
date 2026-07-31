//
//  CalendarService.swift
//  Orca
//

import Foundation
import EventKit

@Observable
class CalendarService {
    static let shared = CalendarService()

    private let store = EKEventStore()

    // MARK: - Authorization

    var isAuthorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            print("❌ Calendar access denied: \(error)")
            return false
        }
    }

    // MARK: - Sync Settings

    var syncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "calendarSyncEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "calendarSyncEnabled") }
    }

    var singleEventsOnly: Bool {
        get { UserDefaults.standard.object(forKey: "calendarSyncSingleOnly") == nil
                ? true  // default: single events only
                : UserDefaults.standard.bool(forKey: "calendarSyncSingleOnly") }
        set { UserDefaults.standard.set(newValue, forKey: "calendarSyncSingleOnly") }
    }

    var promptShown: Bool {
        get { UserDefaults.standard.bool(forKey: "calendarSyncPromptShown") }
        set { UserDefaults.standard.set(newValue, forKey: "calendarSyncPromptShown") }
    }

    // MARK: - Should Sync Check

    /// Returns true if this memory should be auto-added based on current sync settings.
    /// pingSuggestions: the recurrence suggestions from SonarResult (checked before pings are persisted)
    func shouldAutoSync(memory: Memory, recurrence: Ping.Recurrence = .none) -> Bool {
        guard syncEnabled, isAuthorized, memory.detectedDate != nil else { return false }
        if singleEventsOnly {
            // Skip recurring pings
            return recurrence == .none
        }
        return true
    }

    // MARK: - Deduplication

    private func dedupKey(title: String, date: Date) -> String {
        let day = Calendar.current.startOfDay(for: date)
        return "calendarEvent_\(title.lowercased().hashValue)_\(Int(day.timeIntervalSince1970))"
    }

    func isAlreadyAdded(title: String, date: Date) -> Bool {
        UserDefaults.standard.string(forKey: dedupKey(title: title, date: date)) != nil
    }

    // MARK: - Add Event

    @discardableResult
    func addEvent(title: String, startDate: Date, endDate: Date? = nil, notes: String? = nil, isAllDay: Bool = false) -> String? {
        guard isAuthorized else { return nil }

        // Prevent duplicate calendar entries for the same title+day
        let key = dedupKey(title: title, date: startDate)
        if let existing = UserDefaults.standard.string(forKey: key) {
            print("📅 Already in calendar, skipping: \(title)")
            return existing
        }

        let event = EKEvent(eventStore: store)
        event.title = title
        event.notes = notes
        event.calendar = store.defaultCalendarForNewEvents

        if isAllDay {
            event.isAllDay = true
            let startDay = Calendar.current.startOfDay(for: startDate)
            event.startDate = startDay
            // All-day multi-day events use an exclusive end date (day after the last day)
            if let endDate = endDate {
                let endDay = Calendar.current.startOfDay(for: endDate)
                event.endDate = Calendar.current.date(byAdding: .day, value: 1, to: endDay) ?? endDay
            } else {
                event.endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDay) ?? startDay
            }
        } else {
            event.startDate = startDate
            event.endDate = endDate ?? Calendar.current.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
        }

        do {
            try store.save(event, span: .thisEvent)
            UserDefaults.standard.set(event.eventIdentifier, forKey: key)
            print("📅 Added to Apple Calendar: \(title)")
            return event.eventIdentifier
        } catch {
            print("❌ Failed to add calendar event: \(error)")
            return nil
        }
    }

    func removeEvent(identifier: String) {
        guard isAuthorized,
              let event = store.event(withIdentifier: identifier) else { return }
        do {
            try store.remove(event, span: .thisEvent)
            print("📅 Removed from Apple Calendar: \(identifier)")
        } catch {
            print("❌ Failed to remove calendar event: \(error)")
        }
    }

    // MARK: - Convenience: add a Memory

    func addMemory(_ memory: Memory) {
        guard let date = memory.detectedDate else { return }
        let title = memory.text.components(separatedBy: "\n").first ?? memory.text
        addEvent(title: title, startDate: date, endDate: memory.endDate)
    }
}
