//
//  NotificationService.swift
//  Orca
//
//  Created by David Piliponskiy on 2/24/26.
//

import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()

    // MARK: - Clean notification text
    private func cleanNotificationText(_ text: String) -> String {
        var result = text
        let replacements: [(String, String)] = [
            ("tomorrow", "today"),
            ("tonight", "today"),
            ("next week", "this week"),
            ("next month", "this month"),
            ("next year", "this year"),
            ("next monday", "this monday"),
            ("next tuesday", "this tuesday"),
            ("next wednesday", "this wednesday"),
            ("next thursday", "this thursday"),
            ("next friday", "this friday"),
            ("next saturday", "this saturday"),
            ("next sunday", "this sunday"),
        ]
        for (original, replacement) in replacements {
            result = result.replacingOccurrences(of: original, with: replacement, options: .caseInsensitive)
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    func schedulePing(ping: Ping, memoryText: String) {
        let content = UNMutableNotificationContent()
        content.title = "🐋 Orca Ping"
        content.body = cleanNotificationText(memoryText)
        content.sound = .default

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: ping.fireTime)

        var triggerComponents = calendar.dateComponents([.year, .month, .day], from: ping.fireDate)
        triggerComponents.hour = components.hour
        triggerComponents.minute = components.minute

        switch ping.recurrence {
        case .daily:
            var daily = DateComponents()
            daily.hour = components.hour
            daily.minute = components.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: daily, repeats: true)
            let request = UNNotificationRequest(identifier: ping.id.uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)

        case .weekly:
            var weekly = DateComponents()
            weekly.weekday = calendar.component(.weekday, from: ping.fireDate)
            weekly.hour = components.hour
            weekly.minute = components.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: weekly, repeats: true)
            let request = UNNotificationRequest(identifier: ping.id.uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)

        case .monthly:
            var monthly = DateComponents()
            monthly.day = calendar.component(.day, from: ping.fireDate)
            monthly.hour = components.hour
            monthly.minute = components.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: monthly, repeats: true)
            let request = UNNotificationRequest(identifier: ping.id.uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)

        case .yearly:
            var yearly = DateComponents()
            yearly.month = calendar.component(.month, from: ping.fireDate)
            yearly.day = calendar.component(.day, from: ping.fireDate)
            yearly.hour = components.hour
            yearly.minute = components.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: yearly, repeats: true)
            let request = UNNotificationRequest(identifier: ping.id.uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)

        case .none:
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
            let request = UNNotificationRequest(identifier: ping.id.uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }

        print("🔔 Scheduled notification for: \(memoryText) at \(triggerComponents)")
    }

    // MARK: - Follow-up for unresolved pings

    func checkAndScheduleFollowUps(pings: [Ping], memories: [Memory]) {
        let now = Date()
        let twoHoursAgo = Calendar.current.date(byAdding: .hour, value: -2, to: now) ?? now
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now

        // Pre-extract memory properties to avoid SwiftData detachment crash
        struct MemorySnapshot {
            let id: UUID
            let isActionable: Bool
            let isCompleted: Bool
            let text: String
        }
        let memorySnapshots = memories.map {
            MemorySnapshot(id: $0.id, isActionable: $0.isActionable, isCompleted: $0.isCompleted, text: $0.text)
        }

        // Pre-extract ping properties
        struct PingSnapshot {
            let ping: Ping
            let id: UUID
            let recurrence: Ping.Recurrence
            let followUpScheduled: Bool
            let lastFired: Date?
            let fireDate: Date
            let memoryId: UUID
        }
        let pingSnapshots = pings.map {
            PingSnapshot(ping: $0, id: $0.id, recurrence: $0.recurrence, followUpScheduled: $0.followUpScheduled, lastFired: $0.lastFired, fireDate: $0.fireDate, memoryId: $0.memoryId)
        }

        for snapshot in pingSnapshots {
            guard snapshot.recurrence == .none else { continue }
            guard snapshot.followUpScheduled == false else { continue }

            if snapshot.lastFired == nil && snapshot.fireDate < now {
                snapshot.ping.lastFired = snapshot.fireDate
            }

            guard let lastFired = snapshot.ping.lastFired else { continue }
            guard lastFired <= twoHoursAgo else { continue }
            guard lastFired >= twoDaysAgo else { continue }

            guard let memory = memorySnapshots.first(where: { $0.id == snapshot.memoryId }) else { continue }
            guard memory.isActionable && !memory.isCompleted else { continue }

            scheduleFollowUp(pingId: snapshot.id, memoryText: memory.text)
            snapshot.ping.followUpScheduled = true

            print("🔁 Follow-up scheduled for: \(memory.text)")
        }
    }

    private func scheduleFollowUp(pingId: UUID, memoryText: String) {
        let content = UNMutableNotificationContent()
        content.title = "Still need to do this?"
        content.body = cleanNotificationText(memoryText)
        content.sound = .default

        // Fire 2 minutes from now (the check already waited 2 hours)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 120, repeats: false)
        let identifier = "followup-\(pingId.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleInactivityReminder(afterDays days: Int = 5) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["inactivity_reminder"])

        let content = UNMutableNotificationContent()
        content.title = "Your memory is fading 🐬"
        content.body = "You haven't dropped anything in 5 days. Tap to capture something."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(days * 24 * 60 * 60),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: "inactivity_reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelInactivityReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["inactivity_reminder"])
    }

    func cancelPing(pingId: UUID) {
        let ids = [pingId.uuidString, "followup-\(pingId.uuidString)"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
        print("🔕 Cancelled notification + follow-up: \(pingId)")
    }

    func cancelOrphanedNotifications(validPingIds: [UUID]) {
        let validIds = Set(validPingIds.map { $0.uuidString })
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let orphaned = requests
                .map { $0.identifier }
                .filter { id in
                    id != "inactivity_reminder" &&
                    !id.hasPrefix("followup-") &&
                    !validIds.contains(id)
                }
            if !orphaned.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: orphaned)
                print("🔕 Cancelled \(orphaned.count) orphaned notifications")
            }
        }
    }

    func cancelAllPings() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
