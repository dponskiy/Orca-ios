//
//  DashboardView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI
import SwiftData
import WeatherKit
import CoreLocation

struct DashboardView: View {
    @Binding var showSearch: Bool
    @Query private var memories: [Memory]
    @Query private var echos: [Echo]
    @Query private var pings: [Ping]
    @Environment(\.modelContext) private var modelContext
    @State private var showCreateEcho = false
    @State private var showUpcoming = true
    @State private var showPinned = true
    @State private var editingMemory: Memory?
    @State private var detailMemory: Memory?
    @State private var showQuickLog = false
    @State private var navigateToWorkoutEcho = false
    @State private var showWeatherDetail = false
    @StateObject private var weatherService = WeatherService.shared
    @StateObject private var locationService = LocationService.shared
    @State private var showGroceryMode = false
    @State private var showMediaMode = false

    // MARK: - Computed Properties

    var displayedEchos: [Echo] {
        let withMemories = echos.filter { echo in
            memories.contains { $0.echoId == echo.id }
        }.sorted { $0.sortOrder < $1.sortOrder }

        if withMemories.count >= 6 { return withMemories }

        let withMemoryIds = Set(withMemories.map { $0.id })
        let topEmpty = echos
            .filter { !withMemoryIds.contains($0.id) }
            .sorted { $0.sortOrder < $1.sortOrder }
            .prefix(6 - withMemories.count)

        return withMemories + Array(topEmpty)
    }

    var pinnedMemories: [Memory] { memories.filter { $0.isPinned } }

    var upcomingTasks: [Memory] {
        let now = Date()
        let window = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        let sportsEchoId = echos.first { $0.name.lowercased() == "sports" }?.id
        let hideSports = !UserDefaults.standard.showSportsInUpcoming

        let withDate = memories.filter {
            $0.isActionable && !$0.isCompleted && $0.detectedDate != nil &&
            $0.detectedDate! > now && $0.detectedDate! <= window &&
            !(hideSports && $0.echoId == sportsEchoId)
        }

        let withPing = memories.filter { memory in
            guard !memory.isCompleted else { return false }
            guard !(hideSports && memory.echoId == sportsEchoId) else { return false }
            guard !withDate.contains(where: { $0.id == memory.id }) else { return false }
            return pings.contains { ping in
                guard ping.memoryId == memory.id && ping.isActive else { return false }
                if ping.recurrence != .none {
                    let completedToday = memory.completedAt.map {
                        Calendar.current.isDate($0, inSameDayAs: Date())
                    } ?? false
                    if completedToday { return false }
                    if ping.recurrence == .yearly {
                        let cal = Calendar.current
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
            let pingDate = pings
                .filter { $0.memoryId == memory.id && $0.isActive && $0.fireDate > now }
                .map { $0.fireDate }.min()
            return [memory.detectedDate, pingDate].compactMap { $0 }.min() ?? memory.createdAt
        }

        return Array((withDate + withPing)
            .sorted { soonestDate(for: $0) < soonestDate(for: $1) }
            .prefix(3))
    }

    // MARK: - Shortcuts Logic

    private var hasWorkoutMemories: Bool {
        guard let id = echos.first(where: { $0.name.lowercased().contains("workout") })?.id else { return false }
        return memories.contains { $0.echoId == id }
    }

    private var hasCookingWithChecklist: Bool {
        guard let id = echos.first(where: { $0.name.lowercased() == "cooking" })?.id else { return false }
        return memories.contains { $0.echoId == id && $0.hasChecklist }
    }

    private var showShortcutsStrip: Bool { true }

    private var workoutEcho: Echo? { echos.first { $0.name.lowercased().contains("workout") } }
    private var cookingEcho: Echo? { echos.first { $0.name.lowercased() == "cooking" } }

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

    private func pendingCountFor(echo: Echo) -> Int {
        let echoMemories = memories.filter { $0.echoId == echo.id }
        let now = Date()
        var count = 0
        for memory in echoMemories {
            guard memory.isActionable && !memory.isCompleted else { continue }
            let memoryPings = pings.filter { $0.memoryId == memory.id && $0.isActive }
            for ping in memoryPings {
                if Calendar.current.isDate(ping.fireDate, inSameDayAs: now) { count += 1; break }
            }
        }
        return count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
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

                                NavigationLink(destination: SettingsView()) {
                                    ZStack {
                                        Circle().fill(Color.mist).frame(width: 36, height: 36)
                                        Image(systemName: "person").font(.system(size: 15)).foregroundColor(.oceanTeal)
                                    }
                                }
                            }
                            let activeCount = displayedEchos.filter { echo in
                                memories.contains { $0.echoId == echo.id }
                            }.count
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
                    if cleanUpCount > 0 {
                        NavigationLink(destination: SettingsView()) {
                            HStack(spacing: 10) {
                                Image(systemName: "sparkles.rectangle.stack")
                                    .font(.system(size: 14)).foregroundColor(.oceanTeal)
                                Text("\(cleanUpCount) old \(cleanUpCount == 1 ? "task" : "tasks") can be cleaned up")
                                    .font(.custom("DMSans-Regular", size: 14)).foregroundColor(.deepNavy)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .medium)).foregroundColor(.gray.opacity(0.5))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(Color.oceanTeal.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
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
            .background(
                NavigationLink(
                    destination: Group {
                        if let echo = echos.first(where: { $0.name.lowercased().contains("workout") }) {
                            EchoDetailView(echo: echo)
                        }
                    },
                    isActive: $navigateToWorkoutEcho
                ) { EmptyView() }
            )
            .onAppear {
                showUpcoming = true
                showPinned = true
                if let location = locationService.location {
                    Task { await weatherService.fetchWeather(for: location) }
                }
                locationService.requestLocation()
            }
            .onChange(of: locationService.location) { _, location in
                if let location = location { Task { await weatherService.fetchWeather(for: location) } }
            }
            .sheet(isPresented: $showCreateEcho) { EchoEditSheet(echo: nil) }
            .sheet(item: $editingMemory) { MemoryEditView(memory: $0) }
            .sheet(isPresented: $showGroceryMode) {
                GroceryModeView(memories: memories.filter { $0.echoId == cookingEcho?.id })
            }
            .sheet(item: $detailMemory) { MemoryDetailView(memory: $0) }
            .sheet(isPresented: $showMediaMode) {
                WatchModeView()
            }
            .sheet(isPresented: $showQuickLog) {
                QuickLogView(onFinish: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        navigateToWorkoutEcho = true
                    }
                })
            }
            // NEW: Weather detail sheet
            .sheet(isPresented: $showWeatherDetail) {
                WeatherDetailView()
            }
        }
    }

    // MARK: - Quick Actions Strip

    private var quickActionsStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QUICK ACTIONS")
                .font(.custom("DMSans-Medium", size: 11))
                .foregroundColor(.gray)
                .tracking(0.5)

            HStack(spacing: 10) {
                Button { showGroceryMode = true } label: {
                    shortcutCard(icon: "cart.fill", iconColor: Color.oceanTeal, title: "Shopping\nmode", subtitle: hasCookingWithChecklist ? "From recipes" : "Build your list", accentBorder: false)
                }

                Button { showQuickLog = true } label: {
                    shortcutCard(icon: "figure.strengthtraining.traditional", iconColor: Color.oceanTeal, title: "Workout\nmode", subtitle: hasWorkoutMemories ? "Log a set" : "Start first session", accentBorder: true)
                }

                Button { showMediaMode = true } label: {
                    shortcutCard(icon: "popcorn.fill", iconColor: Color.oceanTeal, title: "Media\nmode", subtitle: "Shows, movies & books", accentBorder: false)
                }
            }
        }
    }

    private func shortcutCard(icon: String, iconColor: Color, title: String, subtitle: String, accentBorder: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.system(size: 18)).foregroundColor(iconColor).frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.custom("DMSans-Medium", size: 13)).foregroundColor(.deepNavy).multilineTextAlignment(.leading).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Text(subtitle).font(.custom("DMSans-Regular", size: 11)).foregroundColor(.gray).lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(accentBorder ? Color.oceanTeal.opacity(0.35) : Color.black.opacity(0.08), lineWidth: accentBorder ? 1.0 : 0.5))
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
            FinIcon().fill(Color.seafoam.opacity(0.3)).frame(width: 60, height: 72)
            Text("Drop your first memory").font(.custom("DMSans-Medium", size: 18)).foregroundColor(.deepNavy)
            Text("Tap the fin button below to get started").font(.custom("DMSans-Regular", size: 14)).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Echo Bubble Grid

    private var echoBubbleGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 24) {
            ForEach(Array(displayedEchos.enumerated()), id: \.element.id) { index, echo in
                let count = memories.filter { $0.echoId == echo.id }.count
                let isEmpty = count == 0
                NavigationLink(destination: EchoDetailView(echo: echo)) {
                    EchoBubbleView(echo: echo, count: count, pendingCount: isEmpty ? 0 : pendingCountFor(echo: echo), totalMemories: memories.count)
                        .opacity(isEmpty ? 0.5 : 1.0)
                }
                .offset(
                    x: isEmpty ? 0 : CGFloat([8, -6, 10, -8, 5, -10, 7, -5, 9, -7, 6, -9, 8, -6][index % 14]),
                    y: isEmpty ? 0 : CGFloat([4, -8, 6, -4, 10, -6, 3, -9, 7, -3, 8, -5, 4, -7][index % 14])
                )
            }
        }
    }
}

#Preview {
    DashboardView(showSearch: .constant(false))
        .modelContainer(for: [Memory.self, Echo.self, Ping.self], inMemory: true)
}
