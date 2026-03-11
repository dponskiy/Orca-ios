//
//  NotifcationService.swift
//  Orca
//
//  Created by David Piliponskiy on 2/24/26.
//

import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    
    func schedulePing(ping: Ping, memoryText: String) {
        let content = UNMutableNotificationContent()
        content.title = "🐋 Orca Ping"
        content.body = memoryText
        content.sound = .default
        
        // Use fire time components
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: ping.fireTime)
        
        // Combine fire date's day with fire time's hour/minute
        var triggerComponents = calendar.dateComponents([.year, .month, .day], from: ping.fireDate)
        triggerComponents.hour = components.hour
        triggerComponents.minute = components.minute
        
        switch ping.recurrence {
        case .daily:
            // Only hour and minute for daily
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
    func scheduleInactivityReminder(afterDays days: Int = 5 ) {
        // Cancel any existing inactivity reminder first
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["inactivity_reminder"])
        
        let content = UNMutableNotificationContent()
        content.title = "Your memory is fading 🐬"
        content.body = "You haven't dropped anything in 5 days. Tap to capture something."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(days * 24 * 60 * 60),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "inactivity_reminder",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }

    func cancelInactivityReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["inactivity_reminder"]
        )
    }
    func cancelPing(pingId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [pingId.uuidString])
        print("🔕 Cancelled notification: \(pingId)")
    }
    func cancelOrphanedNotifications(validPingIds: [UUID]) {
        let validIds = Set(validPingIds.map { $0.uuidString })
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let orphaned = requests
                .map { $0.identifier }
                .filter { id in
                    id != "inactivity_reminder" && !validIds.contains(id)
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
