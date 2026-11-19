//
//  CookTimerStore.swift
//  Orca
//
//  The timers running while you cook.
//
//  Two things keep time, and they have to agree. On screen a ticker redraws the
//  countdown every second, but it only runs while the app is in front. The timer that
//  actually matters is a local notification scheduled for the moment it ends, so a timer
//  still goes off when you put the phone down — which is the normal way to use one.
//
//  So nothing counts down in memory. Each timer stores the date it ends, and what's left
//  is worked out from the clock. A timer is therefore still correct after the app has
//  been backgrounded for twenty minutes, which a decrementing counter would not be.
//

import Foundation
import SwiftUI
import UserNotifications

@Observable
final class CookTimerStore {
    static let shared = CookTimerStore()

    struct Timer: Identifiable, Equatable {
        let id: UUID
        /// What it's for, taken from the step: "Simmer 20 minutes".
        let label: String
        let total: Int
        let endsAt: Date

        var remaining: Int { max(0, Int(endsAt.timeIntervalSinceNow.rounded())) }
        var isDone: Bool { remaining == 0 }

        /// 0 at the start, 1 when it goes off.
        var progress: Double {
            guard total > 0 else { return 1 }
            return min(1, max(0, Double(total - remaining) / Double(total)))
        }

        var clock: String {
            let r = remaining
            return r >= 3600
                ? String(format: "%d:%02d:%02d", r / 3600, (r % 3600) / 60, r % 60)
                : String(format: "%d:%02d", r / 60, r % 60)
        }
    }

    private(set) var timers: [Timer] = []

    /// Bumped every second so views redraw; the timers themselves don't change.
    private(set) var tick = 0
    private var ticker: Foundation.Timer?

    /// Timers already announced, so a finished one left on screen buzzes once rather
    /// than once a second until it's cleared.
    private var announced: Set<UUID> = []

    private init() {}

    // MARK: - Starting and stopping

    @discardableResult
    func start(label: String, seconds: Int) -> Timer {
        let timer = Timer(id: UUID(),
                          label: label,
                          total: seconds,
                          endsAt: Date().addingTimeInterval(TimeInterval(seconds)))
        timers.append(timer)
        schedule(timer)
        startTicking()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        return timer
    }

    func cancel(_ id: UUID) {
        timers.removeAll { $0.id == id }
        announced.remove(id)
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier(id)])
        if timers.isEmpty { stopTicking() }
    }

    /// Clears the ones that have gone off. Called when you acknowledge them, not
    /// automatically — a timer that finished while you were elsewhere should still be
    /// on screen when you come back, so you know it did.
    func clearFinished() {
        for timer in timers where timer.isDone { announced.remove(timer.id) }
        timers.removeAll { $0.isDone }
        if timers.isEmpty { stopTicking() }
    }

    func cancelAll() {
        let ids = timers.map { identifier($0.id) }
        timers.removeAll()
        announced.removeAll()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        stopTicking()
    }

    // MARK: - Notifications

    /// Asked for the first time a timer is started, rather than on the way into cooking
    /// mode — a permission sheet makes sense once you've pressed something.
    func ensurePermission() async -> Bool {
        let centre = UNUserNotificationCenter.current()
        let settings = await centre.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await centre.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false   // refused: the on-screen countdown still works
        }
    }

    private func schedule(_ timer: Timer) {
        let content = UNMutableNotificationContent()
        content.title = "Timer finished"
        content.body = timer.label
        content.sound = .default

        // Scheduled against the end date rather than a duration, so it survives the app
        // being closed and reopened.
        let seconds = max(1, timer.endsAt.timeIntervalSinceNow)
        let request = UNNotificationRequest(
            identifier: identifier(timer.id),
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false))

        UNUserNotificationCenter.current().add(request)
    }

    private func identifier(_ id: UUID) -> String { "cook-timer-\(id.uuidString)" }

    // MARK: - Ticking

    private func startTicking() {
        guard ticker == nil else { return }
        ticker = Foundation.Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.tick &+= 1
            // A timer that reaches zero while you're watching should say so itself —
            // once, as it lands, not every second it sits there finished.
            for timer in self.timers where timer.isDone && !self.announced.contains(timer.id) {
                self.announced.insert(timer.id)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    private func stopTicking() {
        ticker?.invalidate()
        ticker = nil
    }
}
