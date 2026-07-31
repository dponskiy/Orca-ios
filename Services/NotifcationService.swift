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

    // MARK: - Notification Categories (actionable)

    func registerCategories() {
        let markDoneAction = UNNotificationAction(
            identifier: "MARK_DONE",
            title: "✓ Mark Done",
            options: [.authenticationRequired]
        )
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_1H",
            title: "Snooze 1 hr",
            options: []
        )
        let pingCategory = UNNotificationCategory(
            identifier: "PING",
            actions: [markDoneAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([pingCategory])
    }

    // MARK: - Schedule Ping

    func schedulePing(ping: Ping, memoryText: String) {
        let content = UNMutableNotificationContent()
        content.title = "🐋 Orca Ping"
        content.body = cleanNotificationText(memoryText)
        content.sound = .default
        content.categoryIdentifier = "PING"
        content.userInfo = [
            "memoryId": ping.memoryId.uuidString,
            "pingId": ping.id.uuidString
        ]

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

    // Returns an advance ping 2 weeks before a Birthday or Gifts memory's detected date.
    // Returns nil if the echo doesn't warrant it, the date is too soon, or no date exists.
    func makeAdvancePing(for memory: Memory, echoName: String?) -> Ping? {
        guard let name = echoName, name == "Birthday",
              let targetDate = memory.detectedDate else { return nil }
        let now = Date()
        guard let twoWeeksBefore = Calendar.current.date(byAdding: .day, value: -14, to: targetDate),
              twoWeeksBefore > now else { return nil }
        let ping = Ping(memoryId: memory.id, fireDate: twoWeeksBefore, recurrence: .none)
        ping.fireTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: twoWeeksBefore) ?? twoWeeksBefore
        return ping
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
                    id != "morning_briefing" &&
                    !id.hasPrefix("followup-") &&
                    !id.hasPrefix("snooze-") &&
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

    // MARK: - Badge Count

    func updateBadge(memories: [Memory], pings: [Ping]) {
        let now = Date()
        let cal = Calendar.current

        // Count tasks due today or overdue and not completed
        // For recurring tasks, check recurringCompletedDates for today instead of isCompleted
        let todayFormatter = ISO8601DateFormatter()
        todayFormatter.formatOptions = [.withFullDate]
        let todayKey = todayFormatter.string(from: now)
        let taskCount = memories.filter { memory in
            guard memory.isActionable && !memory.isCompleted else { return false }
            // If completed today via recurring mechanism, don't count it
            if memory.recurringCompletedDates.contains(todayKey) { return false }
            if let date = memory.detectedDate {
                return cal.isDateInToday(date)
            }
            // Undated tasks have no urgency signal — don't inflate the badge
            return false
        }.count

        // Count pings firing today that aren't already covered by a task's detectedDate
        let taskMemoryIds = Set(memories.filter { memory in
            guard memory.isActionable && !memory.isCompleted else { return false }
            guard let date = memory.detectedDate else { return false }
            return cal.isDateInToday(date)
        }.map { $0.id })
        let pingCount = pings.filter { ping in
            ping.isActive &&
            cal.isDate(ping.fireDate, inSameDayAs: now) &&
            !taskMemoryIds.contains(ping.memoryId)
        }.count

        let total = max(taskCount + pingCount, 0)
        UNUserNotificationCenter.current().setBadgeCount(total) { error in
            if let error { print("❌ Badge update failed: \(error)") }
        }
    }

    // MARK: - Morning Briefing

    func scheduleMorningBriefing(taskCount: Int, overdueCount: Int, upcomingBirthdays: [String], sharedEventTitles: [String] = []) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["morning_briefing"])

        // Build message — keep today/overdue distinct so counts aren't confusing
        var parts: [String] = []
        if taskCount > 0 && overdueCount > 0 {
            parts.append("\(taskCount) \(taskCount == 1 ? "task" : "tasks") today, \(overdueCount) overdue.")
        } else if taskCount > 0 {
            parts.append("\(taskCount) \(taskCount == 1 ? "task" : "tasks") on your list today.")
        } else if overdueCount > 0 {
            parts.append("\(overdueCount) overdue \(overdueCount == 1 ? "task" : "tasks") need attention.")
        } else {
            parts.append("You're all caught up today! 🎉")
        }
        if !upcomingBirthdays.isEmpty {
            let names = upcomingBirthdays.prefix(2).joined(separator: " & ")
            parts.append("🎂 \(names)'s birthday is coming up.")
        }
        if !sharedEventTitles.isEmpty {
            if sharedEventTitles.count == 1 {
                parts.append("🤝 \(sharedEventTitles[0]) today.")
            } else {
                parts.append("🤝 \(sharedEventTitles.count) shared events today.")
            }
        }

        let content = UNMutableNotificationContent()
        content.title = "Good morning 🐋"
        content.body = parts.joined(separator: " ")
        content.sound = .default

        // One-shot for the next 8am so content is always fresh on reschedule
        // (app reschedules on every foreground via scenePhase .active)
        let cal = Calendar.current
        let now = Date()
        var next8am = cal.date(bySettingHour: 8, minute: 0, second: 0, of: now) ?? now
        if next8am <= now {
            next8am = cal.date(byAdding: .day, value: 1, to: next8am) ?? next8am
        }
        let components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: next8am)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "morning_briefing", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("❌ Morning briefing failed: \(error)") }
            else { print("🌅 Morning briefing scheduled for \(next8am)") }
        }
    }

    // MARK: - Snooze from notification

    func snoozeFromNotification(pingId: UUID, memoryId: UUID?, memoryText: String, hours: Int = 1) {
        let snoozeDate = Date().addingTimeInterval(TimeInterval(hours * 3600))
        let content = UNMutableNotificationContent()
        content.title = "🐋 Orca Ping"
        content.body = cleanNotificationText(memoryText)
        content.sound = .default
        content.categoryIdentifier = "PING"
        var userInfo: [String: String] = ["pingId": pingId.uuidString]
        if let memoryId { userInfo["memoryId"] = memoryId.uuidString }
        content.userInfo = userInfo

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(hours * 3600), repeats: false)
        let id = "snooze-\(pingId.uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
        print("😴 Snoozed ping \(pingId) for \(hours)h — fires at \(snoozeDate)")
    }
}
