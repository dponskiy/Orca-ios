//
//  AnalyticsService.swift
//  Orca
//
//  Created by David Piliponskiy on 3/3/26.
//

import Foundation
import Mixpanel

final class AnalyticsService {
    static let shared = AnalyticsService()
    
    private init() {}
    
    func initialize() {
        Mixpanel.initialize(token: Config.mixpanelToken, trackAutomaticEvents: true)
    }
    
    // MARK: - Identity
    
    func identify(userId: String, email: String? = nil, name: String? = nil) {
        Mixpanel.mainInstance().identify(distinctId: userId)
        if let email = email {
            Mixpanel.mainInstance().people.set(property: "$email", to: email)
        }
        if let name = name {
            Mixpanel.mainInstance().people.set(property: "$name", to: name)
        }
    }
    
    func reset() {
        Mixpanel.mainInstance().reset()
    }
    
    // MARK: - Onboarding
    
    func trackOnboardingStarted() {
        track("Onboarding Started")
    }
    
    func trackOnboardingStepViewed(step: Int, name: String) {
        track("Onboarding Step Viewed", properties: [
            "step": step,
            "step_name": name,
        ])
    }
    
    func trackOnboardingCompleted(droppedFirstMemory: Bool) {
        track("Onboarding Completed", properties: [
            "dropped_first_memory": droppedFirstMemory,
        ])
    }
    
    func trackOnboardingSkipped(atStep: Int) {
        track("Onboarding Skipped", properties: [
            "at_step": atStep,
        ])
    }
    
    // MARK: - Memory Capture
    
    func trackMemoryDropped(captureType: String, echoName: String, hasPing: Bool, hasDate: Bool, hasURL: Bool, hasChecklist: Bool, wordCount: Int) {
        track("Memory Dropped", properties: [
            "capture_type": captureType,
            "echo_name": echoName,
            "has_ping": hasPing,
            "has_date": hasDate,
            "has_url": hasURL,
            "has_checklist": hasChecklist,
            "word_count": wordCount,
        ])
        Mixpanel.mainInstance().people.increment(property: "total_memories", by: 1)
    }
    
    func trackMemoryEdited(echoName: String) {
        track("Memory Edited", properties: [
            "echo_name": echoName,
        ])
    }
    
    func trackMemoryDeleted(echoName: String) {
        track("Memory Deleted", properties: [
            "echo_name": echoName,
        ])
    }
    
    func trackRecipeFetched(success: Bool, source: String) {
        track("Recipe Fetched", properties: [
            "success": success,
            "source": source, // "url" or "screenshot"
        ])
    }
    
    // MARK: - Search
    
    func trackSearchOpened() {
        track("Search Opened")
    }
    
    func trackSearchPerformed(query: String, resultCount: Int, usedVoice: Bool) {
        track("Search Performed", properties: [
            "query_length": query.count,
            "result_count": resultCount,
            "used_voice": usedVoice,
        ])
    }
    
    func trackBrowseAllOpened(sortMode: String) {
        track("Browse All Opened", properties: [
            "sort_mode": sortMode,
        ])
    }
    
    // MARK: - Pings
    
    func trackPingCreated(recurrence: String, echoName: String) {
        track("Ping Created", properties: [
            "recurrence": recurrence,
            "echo_name": echoName,
        ])
    }
    
    func trackPingTapped(echoName: String) {
        track("Ping Tapped", properties: [
            "echo_name": echoName,
        ])
    }
    
    // MARK: - Echos
    
    func trackEchoCreated(name: String) {
        track("Echo Created", properties: ["name": name])
    }
    
    func trackEchoDeleted(name: String) {
        track("Echo Deleted", properties: ["name": name])
    }
    
    // MARK: - Settings
    
    func trackNotificationsEnabled() {
        track("Notifications Enabled")
        Mixpanel.mainInstance().people.set(property: "notifications_enabled", to: true)
    }
    
    func trackNotificationsDenied() {
        track("Notifications Denied")
        Mixpanel.mainInstance().people.set(property: "notifications_enabled", to: false)
    }
    
    func trackOnboardingReplayed() {
        track("Onboarding Replayed")
    }
    
    func trackAppRated() {
        track("App Rated")
    }
    
    func trackFeedbackSent() {
        track("Feedback Sent")
    }
    
    func trackAllMemoriesCleared(count: Int) {
        track("All Memories Cleared", properties: ["count": count])
    }
    
    // MARK: - Private
    
    private func track(_ event: String, properties: [String: MixpanelType]? = nil) {
        Mixpanel.mainInstance().track(event: event, properties: properties)
    }
}
