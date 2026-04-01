//
//  OrcaApp.swift
//  Orca
//
//  Created by David Piliponskiy on 2/24/26.
//

import SwiftUI
import SwiftData
import UserNotifications
import CoreSpotlight
import AppIntents

@main
struct OrcaApp: App {
    @State private var authService = AuthService()
    @AppStorage("hasSkippedAuth") private var hasSkippedAuth = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    let modelContainer: ModelContainer = {
        guard let container = try? ModelContainer(for: Memory.self, Echo.self, Ping.self, SubTask.self, GroceryList.self, Person.self, GiftItem.self) else {
            fatalError("Failed to create ModelContainer")
        }
        return container
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCompletedOnboarding {
                    OnboardingFlow()
                } else if authService.isAuthenticated || hasSkippedAuth {
                    ContentView()
                        .environment(authService)
                } else {
                    AuthView(authService: authService) {
                        hasSkippedAuth = true
                    }
                }
            }
            .onChange(of: authService.userId) { _, newUserId in
                if let userId = newUserId {
                    SupabaseSyncService.shared.configure(modelContext: modelContainer.mainContext)
                    SupabaseSyncService.shared.stopAutoSync()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        SupabaseSyncService.shared.startAutoSync(userId: userId)
                    }
                } else {
                    SupabaseSyncService.shared.stopAutoSync()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                let context = modelContainer.mainContext
                Task {
                    let memories = (try? context.fetch(FetchDescriptor<Memory>())) ?? []
                    await FinanceService.shared.checkPriceAlerts(memories: memories)
                    await SportsMemoryService.shared.refreshGamePings(
                        memories: memories,
                        modelContext: modelContainer.mainContext
                    )
                }
            }
            .preferredColorScheme(.light)
            .onAppear {
                AnalyticsService.shared.initialize()
                requestNotificationPermission()
                LocationService.shared.requestLocation()
                let validPingIds = (try? modelContainer.mainContext.fetch(FetchDescriptor<Ping>()))?.map { $0.id } ?? []
                NotificationService.shared.cancelOrphanedNotifications(validPingIds: validPingIds)
                OrcaShortcuts.updateAppShortcutParameters()
            }
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                if let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                    print("✅ Spotlight deep link: \(identifier)")
                    NotificationCenter.default.post(name: .openDropOverlay, object: nil)
                }
            }
        }
        .modelContainer(modelContainer)
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notifications granted")
            } else {
                print("❌ Notifications denied: \(String(describing: error))")
            }
        }
    }
}
