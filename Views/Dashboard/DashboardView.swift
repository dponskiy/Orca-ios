//
//  DashboardView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI
import SwiftData
import WeatherKit
import Combine
import CoreLocation

struct DashboardView: View {
    @Binding var showSearch: Bool
    @Binding var resetTrigger: Bool
    @Query private var memories: [Memory]
    @Query private var echos: [Echo]
    @Query private var pings: [Ping]
    @Environment(\.modelContext) private var modelContext
    @State private var navigationPath = NavigationPath()
    // Routes every dashboard modal through a single presentation. The individual
    // flags stay so the rest of the view (and child bindings) are untouched.
    private enum DashboardSheet: String, Identifiable {
        case createEcho, editMemory, memoryDetail, grocery, media
        case collectibles, sharedSpaces, thoughts, gifts, weather
        var id: String { rawValue }
    }

    private var dashboardSheet: Binding<DashboardSheet?> {
        Binding(
            get: {
                if showCreateEcho       { return .createEcho }
                if editingMemory != nil { return .editMemory }
                if detailMemory  != nil { return .memoryDetail }
                if showGroceryMode      { return .grocery }
                if showMediaMode        { return .media }
                if showCollectibles     { return .collectibles }
                if showSharedSpaces     { return .sharedSpaces }
                if showThoughts         { return .thoughts }
                if showGiftMode         { return .gifts }
                if showWeatherDetail    { return .weather }
                return nil
            },
            set: { newValue in
                // Dismissal (nil) clears everything; the flags are only ever set
                // to true by the buttons that open each destination.
                showCreateEcho    = (newValue == .createEcho)
                showGroceryMode   = (newValue == .grocery)
                showMediaMode     = (newValue == .media)
                showCollectibles  = (newValue == .collectibles)
                showSharedSpaces  = (newValue == .sharedSpaces)
                showThoughts      = (newValue == .thoughts)
                showGiftMode      = (newValue == .gifts)
                showWeatherDetail = (newValue == .weather)
                if newValue != .editMemory   { editingMemory = nil }
                if newValue != .memoryDetail { detailMemory  = nil }
            }
        )
    }

    @State private var showCreateEcho = false
    @State private var showUpcoming = true
    @State private var showPinned = true
    @State private var editingMemory: Memory?
    @State private var detailMemory: Memory?
    @Query private var sharedSpaces: [SharedSpace]
    @Query private var sharedEvents: [SharedEvent]
    @Environment(AuthService.self) private var authService
    @State private var showCollectibles = false
    @State private var showSharedSpaces = false
    @State private var showThoughts = false
    @State private var showEditQuickActions = false
    @AppStorage("enabledQuickActions") private var enabledActionsRaw = "shopping,thoughts,shared,media,collectibles"
    @State private var showWeatherDetail = false
    @StateObject private var weatherService = WeatherService.shared
    @StateObject private var locationService = LocationService.shared
    @State private var showGroceryMode = false
    @State private var showMediaMode = false
    @State private var showGiftMode = false
    @State private var showSettings = false
    @AppStorage("cleanUpDismissedAtCount") private var cleanUpDismissedAtCount = 0

    // MARK: - Computed Properties

    // O(n) — build count map once, then sort once
    var displayedEchos: [Echo] {
        var countByEcho: [UUID: Int] = [:]
        for memory in memories { countByEcho[memory.echoId, default: 0] += 1 }
        return echos
            .filter { !$0.isSystemEcho && countByEcho[$0.id] != nil }
            .sorted { (countByEcho[$0.id] ?? 0) > (countByEcho[$1.id] ?? 0) }
    }

    var pinnedMemories: [Memory] { memories.filter { $0.isPinned } }

    var upcomingTasks: [Memory] {
        let now = Date()
        let cal = Calendar.current
        let window = cal.date(byAdding: .day, value: 7, to: now) ?? now

        // Build ping lookup once — O(n) instead of O(n*m) nested scan
        var pingsByMemory: [UUID: [Ping]] = [:]
        for ping in pings { pingsByMemory[ping.memoryId, default: []].append(ping) }

        let withDate = memories.filter {
            $0.isActionable && !$0.isCompleted && $0.detectedDate != nil &&
            $0.detectedDate! > now && $0.detectedDate! <= window
        }
        let withDateIds = Set(withDate.map { $0.id })

        let withPing = memories.filter { memory in
            guard !memory.isCompleted, !withDateIds.contains(memory.id) else { return false }
            guard let memPings = pingsByMemory[memory.id] else { return false }
            return memPings.contains { ping in
                guard ping.isActive else { return false }
                if ping.recurrence != .none {
                    let completedToday = memory.completedAt.map { cal.isDate($0, inSameDayAs: now) } ?? false
                    if completedToday { return false }
                    if ping.recurrence == .yearly {
                        var components = cal.dateComponents([.month, .day], from: ping.fireDate)
                        components.year = cal.component(.year, from: now)
                        var nextFire = cal.date(from: components) ?? ping.fireDate
                        if nextFire < now { nextFire = cal.date(byAdding: .year, value: 1, to: nextFire) ?? nextFire }
                        return nextFire <= window
                    }
                    return true
                }
                return ping.fireDate > now && ping.fireDate <= window
            }
        }

        func soonestDate(for memory: Memory) -> Date {
            let pingDate = pingsByMemory[memory.id]?
                .filter { $0.isActive && $0.fireDate > now }
                .map { $0.fireDate }.min()
            return [memory.detectedDate, pingDate].compactMap { $0 }.min() ?? memory.createdAt
        }

        return Array((withDate + withPing)
            .sorted { soonestDate(for: $0) < soonestDate(for: $1) }
            .prefix(3))
    }

    // MARK: - Shortcuts Logic


    private var hasCookingWithChecklist: Bool {
        guard let id = echos.first(where: { $0.name.lowercased() == "cooking" })?.id else { return false }
        return memories.contains { $0.echoId == id && $0.hasChecklist }
    }

    private var showShortcutsStrip: Bool { true }

    private var cookingEcho: Echo? { echos.first { $0.name.lowercased() == "cooking" } }

    private var hasSharedSpaces: Bool {
        let userId = authService.userId?.uuidString ?? ""
        return sharedSpaces.contains { $0.createdByUserId == userId || $0.invitedUserId == userId }
    }

    private var upcomingSharedEvents: [SharedEvent] {
        let userId = authService.userId?.uuidString ?? ""
        let mySpaceIds = Set(sharedSpaces.filter {
            $0.createdByUserId == userId || $0.invitedUserId == userId
        }.map { $0.id })
        let now = Date()
        let cal = Calendar.current
        let window = cal.date(byAdding: .day, value: 7, to: now) ?? now
        let today = cal.startOfDay(for: now)
        return sharedEvents.filter { event in
            guard mySpaceIds.contains(event.spaceId), let start = event.date else { return false }
            let end = event.endDate ?? start
            // Show if event starts within window OR is currently spanning today
            return start <= window && cal.startOfDay(for: end) >= today
        }.sorted { ($0.date ?? $0.createdAt) < ($1.date ?? $1.createdAt) }
    }

    // MARK: - Helpers

    private var cleanUpCount: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return memories.filter { memory in
            guard memory.isActionable, !memory.isPinned, !memory.hasChecklist else { return false }
            guard memory.url == nil || memory.url?.isEmpty == true else { return false }
            let hasRecurring = pings.contains { $0.memoryId == memory.id && $0.recurrence != .none }
            guard !hasRecurring else { return false }
            if memory.isCompleted, let completedAt = memory.completedAt { return completedAt < cutoff }
            if let detectedDate = memory.detectedDate { return detectedDate < cutoff }
            return false
        }.count
    }

    private func isExpired(_ memory: Memory) -> Bool {
        let expiryDate = memory.endDate ?? memory.detectedDate
        guard let date = expiryDate, date < Date() else { return false }
        let memoryPings = pings.filter { $0.memoryId == memory.id }
        if memoryPings.contains(where: { $0.recurrence != .none }) { return false }
        return !memoryPings.contains { $0.fireDate > Date() }
    }

    // Pre-computed once — O(n) — used by echoBubbleGrid per echo
    private var pendingCountByEcho: [UUID: Int] {
        let now = Date()
        var pingsByMemory: [UUID: [Ping]] = [:]
        for ping in pings where ping.isActive {
            pingsByMemory[ping.memoryId, default: []].append(ping)
        }
        var result: [UUID: Int] = [:]
        for memory in memories {
            guard memory.isActionable && !memory.isCompleted else { continue }
            guard let memPings = pingsByMemory[memory.id] else { continue }
            let hasTodayPing = memPings.contains { Calendar.current.isDate($0.fireDate, inSameDayAs: now) }
            if hasTodayPing { result[memory.echoId, default: 0] += 1 }
        }
        return result
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(greeting)
                                    .font(.custom("InstrumentSerif-Regular", size: 28))
                                    .foregroundColor(.deepNavy)
                                Spacer()

                                // UPDATED: Weather chip is now tappable
                                if !weatherService.temperature.isEmpty {
                                    Button {
                                        showWeatherDetail = true
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: weatherService.symbolName)
                                                .font(.system(size: 14))
                                                .foregroundColor(.oceanTeal)
                                            Text(weatherService.temperature)
                                                .font(.custom("DMMono-Regular", size: 14))
                                                .foregroundColor(.deepNavy)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }

                                Button { showSettings = true } label: {
                                    ZStack {
                                        Circle().fill(Color.mist).frame(width: 36, height: 36)
                                        Image(systemName: "person").font(.system(size: 15)).foregroundColor(.oceanTeal)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            let activeCount = displayedEchos.count
                            Text("\(memories.count) \(memories.count == 1 ? "memory" : "memories") across \(activeCount) \(activeCount == 1 ? "Echo" : "Echos")")
                                .font(.custom("DMSans-Regular", size: 14)).foregroundColor(.gray)
                        }
                    }

                    // Search bar
                    Button { showSearch = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").font(.system(size: 15)).foregroundColor(.gray)
                            Text("Dive into memories...")
                                .font(.custom("DMSans-Regular", size: 15)).foregroundColor(.gray)
                            Spacer()
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                    }

                    // Clean up hint
                    if cleanUpCount > 0 && cleanUpCount > cleanUpDismissedAtCount {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles.rectangle.stack")
                                .font(.system(size: 14)).foregroundColor(.oceanTeal)
                            Button { showSettings = true } label: {
                                Text("\(cleanUpCount) old \(cleanUpCount == 1 ? "task" : "tasks") can be cleaned up")
                                    .font(.custom("DMSans-Regular", size: 14)).foregroundColor(.deepNavy)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Button {
                                cleanUpDismissedAtCount = cleanUpCount
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color.oceanTeal.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    // Pinned
                    if showPinned && !pinnedMemories.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "pin.fill").font(.system(size: 11)).foregroundColor(.coral)
                                    Text("PINNED").font(.custom("DMSans-Medium", size: 13)).foregroundColor(.coral).tracking(1)
                                }
                                Spacer()
                                Button {
                                    withAnimation(.easeOut(duration: 0.3)) { showPinned = false }
                                } label: {
                                    Image(systemName: "xmark").font(.system(size: 11, weight: .medium)).foregroundColor(.gray.opacity(0.5))
                                }
                            }
                            ForEach(pinnedMemories) { memory in pinnedRow(memory: memory) }
                        }
                    }

                    // Upcoming
                    if showUpcoming && !upcomingTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock.fill").font(.system(size: 11)).foregroundColor(.oceanTeal)
                                    Text("UPCOMING").font(.custom("DMSans-Medium", size: 13)).foregroundColor(.oceanTeal).tracking(1)
                                }
                                Spacer()
                                Button {
                                    withAnimation(.easeOut(duration: 0.3)) { showUpcoming = false }
                                } label: {
                                    Image(systemName: "xmark").font(.system(size: 11, weight: .medium)).foregroundColor(.gray.opacity(0.5))
                                }
                            }
                            ForEach(upcomingTasks) { memory in upcomingRow(memory: memory) }
                        }
                    }

                    // Shared upcoming
                    if !upcomingSharedEvents.isEmpty {
                        sharedUpcomingSection
                    }

                    // Quick Actions Strip
                    if showShortcutsStrip { quickActionsStrip }

                    // Your Echos header
                    HStack {
                        Text("YOUR ECHOS")
                            .font(.custom("DMSans-Medium", size: 13)).foregroundColor(.oceanTeal).tracking(1)
                        Spacer()
                        Button { showCreateEcho = true } label: {
                            ZStack {
                                Circle().fill(Color.mist).frame(width: 28, height: 28)
                                Image(systemName: "plus").font(.system(size: 13, weight: .medium)).foregroundColor(.oceanTeal)
                            }
                        }
                    }
                    .padding(.top, 4)

                    if displayedEchos.isEmpty { emptyState } else { echoBubbleGrid }

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color.pearl)
            .navigationDestination(for: Echo.self) { echo in
                EchoDetailView(echo: echo)
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
            }
            .onAppear {
                showUpcoming = true
                showPinned = true
                if let location = locationService.location {
                    Task { await weatherService.fetchWeather(for: location) }
                }
                locationService.requestLocation()
                // Migrate quick actions: add new, remove retired
                var ids = enabledActionsRaw.split(separator: ",").map(String.init)
                var changed = false
                for newAction in ["gifts", "collectibles"] where !ids.contains(newAction) {
                    ids.append(newAction)
                    changed = true
                }
                if ids.contains("workout") {
                    ids.removeAll { $0 == "workout" }
                    changed = true
                }
                if changed {
                    enabledActionsRaw = QuickActionItem.allCases
                        .filter { ids.contains($0.rawValue) }
                        .map { $0.rawValue }
                        .joined(separator: ",")
                }
            }
            .onChange(of: locationService.location) { _, location in
                if let location = location { Task { await weatherService.fetchWeather(for: location) } }
            }
            // One sheet, not eleven siblings. Stacked presentation modifiers on a
            // single view destabilise each other, and anything presented two levels
            // deeper (Collectibles → Gallery → card detail) got torn down on open.
            .sheet(item: dashboardSheet) { which in
                switch which {
                case .createEcho:    EchoEditSheet(echo: nil)
                case .editMemory:    if let m = editingMemory { MemoryEditView(memory: m) }
                case .memoryDetail:  if let m = detailMemory  { MemoryDetailView(memory: m) }
                case .grocery:       GroceryModeView(memories: memories.filter { $0.echoId == cookingEcho?.id })
                case .media:         WatchModeView()
                case .collectibles:  CollectiblesView()
                case .sharedSpaces:  SharedSpacesHubView()
                case .thoughts:      ThoughtsView()
                case .gifts:         GiftQuickActionView()
                case .weather:       WeatherDetailView()
                }
            }
        }
        .onChange(of: resetTrigger) { _, _ in
            withAnimation {
                navigationPath = NavigationPath()
                showSettings = false
            }
        }
    }

    // MARK: - Shared Upcoming Section

    private var sharedUpcomingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill").font(.system(size: 11)).foregroundColor(.oceanTeal)
                Text("SHARED").font(.custom("DMSans-Medium", size: 13)).foregroundColor(.oceanTeal).tracking(1)
            }
            ForEach(upcomingSharedEvents.prefix(3)) { event in
                sharedEventRow(event: event)
            }
        }
    }

    private func sharedEventRow(event: SharedEvent) -> some View {
        let space = sharedSpaces.first { $0.id == event.spaceId }
        let partnerName = space?.invitedUserEmail.components(separatedBy: "@").first?.capitalized ?? "Shared"

        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.oceanTeal.opacity(0.1)).frame(width: 32, height: 32)
                Image(systemName: "person.2.fill").font(.system(size: 12)).foregroundColor(.oceanTeal)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.custom("DMSans-Regular", size: 15))
                    .foregroundColor(.deepNavy)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if let date = event.date {
                        Image(systemName: "clock").font(.system(size: 10)).foregroundColor(.oceanTeal)
                        Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                            .font(.custom("DMMono-Regular", size: 12)).foregroundColor(.oceanTeal)
                    }
                    Text("· \(partnerName)")
                        .font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        .onTapGesture { showSharedSpaces = true }
    }

    // MARK: - Quick Actions Strip

    // MARK: - Quick Actions Data

    enum QuickActionItem: String, CaseIterable {
        case shopping, thoughts, shared, media, gifts, collectibles

        var icon: String {
            switch self {
            case .shopping:     return "cart.fill"
            case .collectibles: return "square.stack.3d.up.fill"
            case .media:        return "popcorn.fill"
            case .shared:       return "person.2.fill"
            case .thoughts:     return "bubble.left.fill"
            case .gifts:        return "gift.fill"
            }
        }
        var title: String {
            switch self {
            case .shopping:     return "Shopping"
            case .collectibles: return "Collectibles"
            case .media:        return "Media"
            case .shared:       return "Shared Space"
            case .thoughts:     return "Thoughts"
            case .gifts:        return "Gifts"
            }
        }
        var displayName: String {
            switch self {
            case .shopping:     return "Shopping Mode"
            case .collectibles: return "Collectibles"
            case .media:        return "Media Mode"
            case .shared:       return "Shared Space"
            case .thoughts:     return "Thoughts"
            case .gifts:        return "Gifts"
            }
        }
    }

    private var enabledActions: [QuickActionItem] {
        let ids = enabledActionsRaw.split(separator: ",").map(String.init)
        return QuickActionItem.allCases.filter { ids.contains($0.rawValue) }
    }

    private func isEnabled(_ action: QuickActionItem) -> Bool {
        enabledActionsRaw.split(separator: ",").map(String.init).contains(action.rawValue)
    }

    private func toggleAction(_ action: QuickActionItem) {
        var ids = enabledActionsRaw.split(separator: ",").map(String.init)
        if ids.contains(action.rawValue) {
            guard ids.count > 1 else { return } // keep at least 1
            ids.removeAll { $0 == action.rawValue }
        } else {
            ids.append(action.rawValue)
        }
        // Preserve original order
        enabledActionsRaw = QuickActionItem.allCases
            .filter { ids.contains($0.rawValue) }
            .map { $0.rawValue }
            .joined(separator: ",")
    }

    private func subtitle(for action: QuickActionItem) -> String {
        switch action {
        case .shopping:     return hasCookingWithChecklist ? "Build your grocery list" : "Recipes & grocery lists"
        case .collectibles: return "Pokémon, Legos & more"
        case .media:        return "Movies, shows & books"
        case .shared:       return hasSharedSpaces ? "View shared spaces" : "Invite someone"
        case .thoughts:     return "Notes & journal"
        case .gifts:        return "Track gift ideas"
        }
    }

    private func triggerAction(_ action: QuickActionItem) {
        switch action {
        case .shopping:     showGroceryMode = true
        case .collectibles: showCollectibles = true
        case .media:        showMediaMode = true
        case .shared:       showSharedSpaces = true
        case .thoughts:     showThoughts = true
        case .gifts:        showGiftMode = true
        }
    }

    // MARK: - Quick Actions Strip

    private var quickActionsStrip: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Section header — matches Upcoming / Your Echos style
            HStack {
                Text("QUICK ACTIONS")
                    .font(.custom("DMSans-Medium", size: 13))
                    .foregroundColor(.oceanTeal)
                    .tracking(1)
                Spacer()
                Button {
                    showEditQuickActions = true
                } label: {
                    Text("Edit")
                        .font(.custom("DMSans-Medium", size: 13))
                        .foregroundColor(.oceanTeal)
                }
            }

            // Dynamic grid — 3 per row, wraps automatically
            let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(enabledActions, id: \.rawValue) { action in
                    Button { triggerAction(action) } label: {
                        shortcutCard(
                            icon: action.icon,
                            iconColor: .oceanTeal,
                            title: action.title,
                            subtitle: subtitle(for: action),
                            accentBorder: true
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showEditQuickActions) { editQuickActionsSheet }
    }

    // MARK: - Edit Quick Actions Sheet

    private var editQuickActionsSheet: some View {
        NavigationStack {
            List {
                Section {
                    Text("Choose which quick actions appear on your dashboard. At least one must be selected.")
                        .font(.custom("DMSans-Regular", size: 13))
                        .foregroundColor(.gray)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section {
                    ForEach(QuickActionItem.allCases, id: \.rawValue) { action in
                        let enabled = isEnabled(action)
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) { toggleAction(action) }
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(enabled ? Color.oceanTeal : Color.mist)
                                        .frame(width: 36, height: 36)
                                    Image(systemName: action.icon)
                                        .font(.system(size: 15))
                                        .foregroundColor(enabled ? .white : .gray)
                                }
                                Text(action.displayName)
                                    .font(.custom("DMSans-Regular", size: 16))
                                    .foregroundColor(.deepNavy)
                                Spacer()
                                Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundColor(enabled ? .oceanTeal : .gray.opacity(0.3))
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Quick Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showEditQuickActions = false }
                        .foregroundColor(.oceanTeal)
                        .font(.custom("DMSans-Medium", size: 16))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func shortcutCard(icon: String, iconColor: Color, title: String, subtitle: String, accentBorder: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundColor(iconColor)
                .frame(height: 32)
            VStack(spacing: 2) {
                Text(title)
                    .font(.custom("DMSans-Medium", size: 13))
                    .foregroundColor(.deepNavy)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.custom("DMSans-Regular", size: 11))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 96)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.oceanTeal.opacity(0.3), lineWidth: 1.0))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
    }

    // MARK: - Pinned Row

    private func pinnedRow(memory: Memory) -> some View {
        let expired = isExpired(memory)
        return HStack(spacing: 12) {
            Image(systemName: "pin.fill").font(.system(size: 13)).foregroundColor(expired ? .gray.opacity(0.4) : .coral).frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(memory.text).font(.custom("DMSans-Regular", size: 15)).foregroundColor(expired ? .gray : .deepNavy).lineLimit(2)
                if let echo = echos.first(where: { $0.id == memory.echoId }) {
                    HStack(spacing: 3) {
                        Text(echo.emoji).font(.system(size: 11))
                        Text(echo.name).font(.custom("DMSans-Medium", size: 12)).foregroundColor(expired ? .gray : .deepNavy)
                    }
                    .padding(.horizontal, 6).padding(.vertical, 2).background(Color.mist).clipShape(Capsule())
                }
            }
            Spacer()
            Button { editingMemory = memory } label: {
                ZStack {
                    Circle().fill(Color.mist).frame(width: 32, height: 32)
                    Image(systemName: "pencil").font(.system(size: 12, weight: .medium)).foregroundColor(.oceanTeal)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(expired ? Color(red: 0.91, green: 0.94, blue: 0.97) : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        .onTapGesture { detailMemory = memory }
    }

    // MARK: - Upcoming Row

    private func upcomingRow(memory: Memory) -> some View {
        let expired = isExpired(memory)
        return HStack(spacing: 12) {
            if let echo = echos.first(where: { $0.id == memory.echoId }) {
                Text(echo.emoji).font(.system(size: 16)).frame(width: 24).opacity(expired ? 0.4 : 1.0)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(memory.text).font(.custom("DMSans-Regular", size: 15)).foregroundColor(expired ? .gray : .deepNavy).lineLimit(2)
                let activePing = pings
                    .filter { $0.memoryId == memory.id && $0.isActive }
                    .sorted { p1, p2 in
                        if p1.recurrence != .none && p2.recurrence == .none { return true }
                        if p1.recurrence == .none && p2.recurrence != .none { return false }
                        return p1.fireDate < p2.fireDate
                    }.first
                let displayDate: Date? = {
                    if let ping = activePing {
                        if ping.recurrence == .daily {
                            let completedToday = memory.completedAt.map {
                                Calendar.current.isDate($0, inSameDayAs: Date())
                            } ?? false
                            let baseDay = completedToday ?
                                (Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()) : Date()
                            let fireComponents = Calendar.current.dateComponents([.hour, .minute], from: ping.fireTime)
                            return Calendar.current.date(bySettingHour: fireComponents.hour ?? 9,
                                                         minute: fireComponents.minute ?? 0,
                                                         second: 0, of: baseDay) ?? baseDay
                        }
                        return ping.fireDate
                    }
                    return memory.detectedDate
                }()
                if let date = displayDate {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock").font(.system(size: 10)).foregroundColor(expired ? .gray.opacity(0.5) : .oceanTeal)
                            Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                                .font(.custom("DMMono-Regular", size: 12)).foregroundColor(expired ? .gray.opacity(0.5) : .oceanTeal)
                        }
                        let daysUntil = Calendar.current.dateComponents([.day],
                            from: Calendar.current.startOfDay(for: Date()),
                            to: Calendar.current.startOfDay(for: date)).day ?? 0
                        if daysUntil == 0 {
                            Text("Today").font(.custom("DMSans-Medium", size: 11)).foregroundColor(.coral)
                        } else if daysUntil > 0 {
                            Text("in \(daysUntil) \(daysUntil == 1 ? "day" : "days")")
                                .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.oceanTeal.opacity(0.7))
                        }
                    }
                }
            }
            Spacer()
            Button { editingMemory = memory } label: {
                ZStack {
                    Circle().fill(Color.mist).frame(width: 32, height: 32)
                    Image(systemName: "pencil").font(.system(size: 12, weight: .medium)).foregroundColor(.oceanTeal)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(expired ? Color(red: 0.91, green: 0.94, blue: 0.97) : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        .onTapGesture { detailMemory = memory }
    }

    // MARK: - Greeting

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)
            Image("OrcaLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .opacity(0.5)
            Text("Drop your first memory").font(.custom("DMSans-Medium", size: 18)).foregroundColor(.deepNavy)
            Text("Tap the fin button below to get started").font(.custom("DMSans-Regular", size: 14)).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Echo Bubble Grid

    private var echoBubbleGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        let countMap = { () -> [UUID: Int] in
            var m: [UUID: Int] = [:]
            for memory in memories { m[memory.echoId, default: 0] += 1 }
            return m
        }()
        let pendingMap = pendingCountByEcho
        let total = memories.count
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(displayedEchos, id: \.id) { echo in
                NavigationLink(value: echo) {
                    EchoBubbleView(echo: echo, count: countMap[echo.id] ?? 0, pendingCount: pendingMap[echo.id] ?? 0, totalMemories: total)
                }
            }
        }
    }
}

#Preview {
    DashboardView(showSearch: .constant(false), resetTrigger: .constant(false))
        .modelContainer(for: [Memory.self, Echo.self, Ping.self], inMemory: true)
}
