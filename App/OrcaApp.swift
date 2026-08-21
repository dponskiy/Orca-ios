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
import WidgetKit

// MARK: - Widget shared data (also defined in OrcaWidget.swift for the extension)

struct OrcaWidgetTask: Codable, Identifiable {
    let id: String
    let text: String
    let echoEmoji: String
    let isOverdue: Bool
    let dateLabel: String
}

struct OrcaWidgetData: Codable {
    let todayCount: Int
    let overdueCount: Int
    let tasks: [OrcaWidgetTask]
    let updatedAt: Date

    static let appGroupSuite = "group.com.dponskiy.Orca"
    static let defaultsKey   = "orcaWidgetData"

    static func write(_ data: OrcaWidgetData) {
        guard let defaults = UserDefaults(suiteName: appGroupSuite),
              let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: defaultsKey)
    }

    static func read() -> OrcaWidgetData {
        guard let defaults = UserDefaults(suiteName: appGroupSuite),
              let raw = defaults.data(forKey: defaultsKey),
              let data = try? JSONDecoder().decode(OrcaWidgetData.self, from: raw) else {
            return OrcaWidgetData(todayCount: 0, overdueCount: 0, tasks: [], updatedAt: .distantPast)
        }
        return data
    }
}

// MARK: - App Delegate (handles notification responses)

class OrcaAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationService.shared.registerCategories()
        return true
    }

    // Called when user taps a notification action (Mark Done / Snooze)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let memoryIdStr = userInfo["memoryId"] as? String
        let pingIdStr   = userInfo["pingId"] as? String
        let body        = response.notification.request.content.body

        switch response.actionIdentifier {
        case "MARK_DONE":
            if let str = memoryIdStr, let id = UUID(uuidString: str) {
                NotificationCenter.default.post(name: .markMemoryDoneFromNotification, object: id)
            }
        case "SNOOZE_1H":
            if let str = pingIdStr, let pingId = UUID(uuidString: str) {
                NotificationService.shared.snoozeFromNotification(
                    pingId: pingId,
                    memoryId: memoryIdStr.flatMap { UUID(uuidString: $0) },
                    memoryText: body,
                    hours: 1
                )
            }
        default:
            break
        }
        completionHandler()
    }

    // Show notification banner even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let markMemoryDoneFromNotification = Notification.Name("markMemoryDoneFromNotification")
    static let inviteAccepted = Notification.Name("inviteAccepted")
    static let calendarSyncCheck = Notification.Name("calendarSyncCheck")
    static let recipeImport = Notification.Name("recipeImport")
}

// MARK: - Invite token store (survives sign-in flow)

enum InviteTokenStore {
    private static let key = "orca_pending_invite_token"
    static func save(_ token: String) { UserDefaults.standard.set(token, forKey: key) }
    static func consume() -> String? {
        guard let token = UserDefaults.standard.string(forKey: key) else { return nil }
        UserDefaults.standard.removeObject(forKey: key)
        return token
    }
}

// MARK: - App

@main
struct OrcaApp: App {
    @UIApplicationDelegateAdaptor(OrcaAppDelegate.self) var appDelegate
    @State private var authService = AuthService()
    @AppStorage("hasSkippedAuth") private var hasSkippedAuth = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    let modelContainer: ModelContainer = {
        guard let container = try? ModelContainer(for: Memory.self, Echo.self, Ping.self, SubTask.self, GroceryList.self, Person.self, GiftItem.self, WatchlistItem.self, SharedSpace.self, SharedSpaceMember.self, SharedEvent.self, SharedChecklistItem.self, SharedRecipe.self, SharedGroceryItem.self, ThoughtTab.self, TCGCard.self, SmiskiItem.self, LegoSet.self, GameItem.self) else {
            fatalError("Failed to create ModelContainer")
        }
        return container
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCompletedOnboarding {
                    OnboardingFlow()
                        .environment(authService)
                } else if authService.isAuthenticated {
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
                    SharedSpaceSyncService.shared.configure(modelContext: modelContainer.mainContext)
                    SupabaseSyncService.shared.stopAutoSync()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        SupabaseSyncService.shared.startAutoSync(userId: userId)
                        Task {
                            await SharedSpaceSyncService.shared.syncAll(userId: userId)
                            SharedSpaceSyncService.shared.startRealtime(userId: userId)
                            // Process any invite token that arrived before sign-in
                            if let token = InviteTokenStore.consume() {
                                await acceptInvite(token: token, userId: userId)
                            }
                        }
                    }
                } else {
                    SupabaseSyncService.shared.stopAutoSync()
                    SharedSpaceSyncService.shared.stopRealtime()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                let context = modelContainer.mainContext
                Task { @MainActor in
                    let memories = (try? context.fetch(FetchDescriptor<Memory>())) ?? []
                    let pings    = (try? context.fetch(FetchDescriptor<Ping>())) ?? []

                    if newPhase == .active {
                        NotificationService.shared.checkAndScheduleFollowUps(pings: pings, memories: memories)
                        await FinanceService.shared.checkPriceAlerts(memories: memories)
                        // Refresh badge when app comes to foreground
                        NotificationService.shared.updateBadge(memories: memories, pings: pings)
                        // Reschedule morning briefing with fresh counts every foreground
                        scheduleMorningBriefing(memories: memories, pings: pings)
                    }

                    if newPhase == .background || newPhase == .inactive {
                        // Write widget snapshot so the widget can update without launching the app
                        writeWidgetData(memories: memories, pings: pings)
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
            }
            .preferredColorScheme(.light)
            .onAppear {
                AnalyticsService.shared.initialize()
                TMDBService.shared.loadPosterCache()
                requestNotificationPermission()
                LocationService.shared.requestLocation()
                let context = modelContainer.mainContext
                let validPingIds = (try? context.fetch(FetchDescriptor<Ping>()))?.map { $0.id } ?? []
                NotificationService.shared.cancelOrphanedNotifications(validPingIds: validPingIds)
                OrcaShortcuts.updateAppShortcutParameters()
                // Schedule morning briefing + seed initial widget data
                Task { @MainActor in
                    let memories = (try? context.fetch(FetchDescriptor<Memory>())) ?? []
                    let pings    = (try? context.fetch(FetchDescriptor<Ping>())) ?? []
                    scheduleMorningBriefing(memories: memories, pings: pings)
                    writeWidgetData(memories: memories, pings: pings)
                    NotificationService.shared.updateBadge(memories: memories, pings: pings)
                }
            }
            // Handle "Mark Done" tapped from a notification action button
            .onReceive(NotificationCenter.default.publisher(for: .markMemoryDoneFromNotification)) { notification in
                guard let memoryId = notification.object as? UUID else { return }
                let context = modelContainer.mainContext
                let memories = (try? context.fetch(FetchDescriptor<Memory>())) ?? []
                if let memory = memories.first(where: { $0.id == memoryId }), !memory.isCompleted {
                    memory.isCompleted = true
                    memory.completedAt = Date()
                    memory.updatedAt   = Date()
                    // Cancel associated pings
                    let pings = (try? context.fetch(FetchDescriptor<Ping>())) ?? []
                    for ping in pings where ping.memoryId == memoryId {
                        ping.isActive = false
                        NotificationService.shared.cancelPing(pingId: ping.id)
                    }
                    try? context.save()
                    // Re-fetch after mutations so badge reflects the completed state
                    let freshMemories = (try? context.fetch(FetchDescriptor<Memory>())) ?? []
                    let freshPings    = (try? context.fetch(FetchDescriptor<Ping>())) ?? []
                    NotificationService.shared.updateBadge(memories: freshMemories, pings: freshPings)
                    if let userId = authService.userId {
                        Task { await SupabaseSyncService.shared.pushMemory(memory, userId: userId) }
                    }
                    print("✅ Marked done from notification: \(memoryId)")
                }
            }
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                if let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                    print("✅ Spotlight deep link: \(identifier)")
                    NotificationCenter.default.post(name: .openDropOverlay, object: nil)
                }
            }
            // Handle orca://invite/TOKEN and https://links.orcadrop.app/invite/TOKEN
            .onOpenURL { url in
                handleIncomingURL(url)
            }
        }
        .modelContainer(modelContainer)
    }

    // MARK: - Invite Deep Link

    private func handleIncomingURL(_ url: URL) {
        // orca://recipe?url=<encoded-source-url>  OR  orca://recipe?data=<base64-json>
        // https://links.orcadrop.app/recipe?url=...  OR  https://links.orcadrop.app/recipe?data=...
        let isOrcaRecipe = url.scheme == "orca" && url.host == "recipe"
        let isUniversalRecipe = url.host == "links.orcadrop.app" &&
            url.pathComponents.count >= 2 && url.pathComponents[1] == "recipe"
        if isOrcaRecipe || isUniversalRecipe,
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            if let sourceURL = components.queryItems?.first(where: { $0.name == "url" })?.value,
               !sourceURL.isEmpty {
                NotificationCenter.default.post(name: .recipeImport, object: nil, userInfo: ["url": sourceURL])
            } else if let data = components.queryItems?.first(where: { $0.name == "data" })?.value,
                      !data.isEmpty {
                NotificationCenter.default.post(name: .recipeImport, object: nil, userInfo: ["data": data])
            }
            return
        }

        // Handles both:
        //   orca://invite/TOKEN
        //   https://links.orcadrop.app/invite/TOKEN
        let token: String?
        if url.scheme == "orca", url.host == "invite" {
            token = url.pathComponents.dropFirst().first ?? String(url.path.dropFirst())
        } else if url.host == "links.orcadrop.app", url.pathComponents.count >= 3,
                  url.pathComponents[1] == "invite" {
            token = url.pathComponents[2]
        } else {
            token = nil
        }

        guard let token, !token.isEmpty else { return }

        if let userId = authService.userId {
            // Already signed in — accept immediately
            Task { await acceptInvite(token: token, userId: userId) }
        } else {
            // Not signed in yet — stash the token, process after auth
            InviteTokenStore.save(token)
            print("📬 Invite token saved for post-auth: \(token)")
        }
    }

    private func acceptInvite(token: String, userId: UUID) async {
        do {
            try await SharedSpaceSyncService.shared.acceptInvite(token: token, userId: userId)
            NotificationCenter.default.post(name: .inviteAccepted, object: nil)
            print("✅ Invite accepted: \(token)")
        } catch {
            print("❌ Invite accept failed: \(error)")
        }
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

    // MARK: - Morning Briefing

    private func scheduleMorningBriefing(memories: [Memory], pings: [Ping]) {
        let cal = Calendar.current
        let now = Date()

        let taskCount = memories.filter { m in
            guard m.isActionable && !m.isCompleted else { return false }
            guard let date = m.detectedDate else { return false }
            return cal.isDateInToday(date)
        }.count

        let overdueCount = memories.filter { m in
            guard m.isActionable && !m.isCompleted else { return false }
            guard let date = m.detectedDate else { return false }
            return date < cal.startOfDay(for: now) && !cal.isDateInToday(date)
        }.count

        // Find birthdays in next 7 days from People models (stored in Memory tags)
        let soonBirthdays = memories.compactMap { m -> String? in
            guard m.tags.contains("birthday"), let date = m.detectedDate else { return nil }
            let daysAway = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day ?? 999
            guard daysAway >= 0 && daysAway <= 7 else { return nil }
            return m.text.components(separatedBy: " ").prefix(2).joined(separator: " ")
        }

        // Shared events happening today
        let sharedEvents = (try? modelContainer.mainContext.fetch(FetchDescriptor<SharedEvent>())) ?? []
        let todaySharedTitles = sharedEvents
            .filter { $0.date != nil && cal.isDateInToday($0.date!) }
            .map { $0.title }

        NotificationService.shared.scheduleMorningBriefing(
            taskCount: taskCount,
            overdueCount: overdueCount,
            upcomingBirthdays: soonBirthdays,
            sharedEventTitles: todaySharedTitles
        )
    }

    // MARK: - Widget Data

    private func writeWidgetData(memories: [Memory], pings: [Ping]) {
        let cal = Calendar.current
        let now = Date()
        let echos = (try? modelContainer.mainContext.fetch(FetchDescriptor<Echo>())) ?? []
        var echoEmojiMap: [UUID: String] = [:]
        for echo in echos { echoEmojiMap[echo.id] = echo.emoji }

        let overdueMems = memories.filter { m in
            guard m.isActionable && !m.isCompleted, let date = m.detectedDate else { return false }
            return date < cal.startOfDay(for: now) && !cal.isDateInToday(date)
        }.sorted { ($0.detectedDate ?? $0.createdAt) < ($1.detectedDate ?? $1.createdAt) }

        let todayMems = memories.filter { m in
            guard m.isActionable && !m.isCompleted, let date = m.detectedDate else { return false }
            return cal.isDateInToday(date)
        }.sorted { ($0.detectedDate ?? $0.createdAt) < ($1.detectedDate ?? $1.createdAt) }

        let overdueIds = Set(overdueMems.map { $0.id })
        var widgetTasks: [OrcaWidgetTask] = []
        for m in (overdueMems + todayMems).prefix(4) {
            let isOverdue = overdueIds.contains(m.id)
            let dateLabel = isOverdue ? (m.detectedDate?.formatted(.dateTime.month(.abbreviated).day()) ?? "Overdue") : "Today"
            widgetTasks.append(OrcaWidgetTask(
                id: m.id.uuidString,
                text: m.text.components(separatedBy: "\n").first ?? m.text,
                echoEmoji: echoEmojiMap[m.echoId] ?? "📋",
                isOverdue: isOverdue,
                dateLabel: dateLabel
            ))
        }

        OrcaWidgetData.write(OrcaWidgetData(
            todayCount: todayMems.count,
            overdueCount: overdueMems.count,
            tasks: widgetTasks,
            updatedAt: now
        ))
    }
}
