//
//  TodayView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/27/26.
//

import SwiftUI
import SwiftData
import WeatherKit
import CoreLocation

struct TodayView: View {
    @Query(sort: \Memory.createdAt, order: .reverse) private var allMemories: [Memory]
    @Query private var pings: [Ping]
    @Query private var echos: [Echo]
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService

    @State private var selectedDate: Date = Date()
    @State private var showWeekView = false
    @State private var editingMemory: Memory?
    @State private var detailMemory: Memory?
    @State private var showCompleted = false
    @State private var snoozeMemory: Memory?
    @State private var expandedMemoryIds: Set<UUID> = []
    @State private var taskMode: TaskMode = .today
    @State private var quickAddText: String = ""
    @State private var showBanner = false
    @State private var bannerSonarResult: SonarResult?
    @State private var bannerMemory: Memory?
    @State private var showWeatherDetail = false
    @FocusState private var quickAddFocused: Bool

    @StateObject private var weatherService = WeatherService.shared
    @StateObject private var locationService = LocationService.shared

    private let calendar = Calendar.current
    private let sonarEngine = SonarEngine()

    enum TaskMode {
        case today, all
    }

    // MARK: - Recurring Completion Helpers

    private func isoDateKey(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }

    private func isCompletedOn(_ memory: Memory, date: Date) -> Bool {
        memory.recurringCompletedDates.contains(isoDateKey(date))
    }

    private func setCompleted(_ memory: Memory, date: Date) {
        let key = isoDateKey(date)
        if !memory.recurringCompletedDates.contains(key) {
            memory.recurringCompletedDates.append(key)
        }
        memory.completedAt = date
        memory.updatedAt = Date()
    }

    private func setUncompleted(_ memory: Memory, date: Date) {
        let key = isoDateKey(date)
        memory.recurringCompletedDates.removeAll { $0 == key }
        if memory.recurringCompletedDates.isEmpty {
            memory.completedAt = nil
        } else {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            memory.completedAt = memory.recurringCompletedDates
                .compactMap { formatter.date(from: $0) }
                .max()
        }
        memory.updatedAt = Date()
    }

    // MARK: - Load Awareness

    private var totalEstimatedMinutes: Int {
        (todayTasks + overdueTasks + completedTasks)
            .compactMap { $0.estimatedMinutes }
            .reduce(0, +)
    }

    private var remainingLoadLabel: String {
        let remaining = max((8 * 60) - totalEstimatedMinutes, 0)
        return DurationParser.shared.format(remaining)
    }

    private var loadFraction: Double {
        min(Double(totalEstimatedMinutes) / (8.0 * 60.0), 1.0)
    }

    private var loadLabel: String {
        DurationParser.shared.format(totalEstimatedMinutes)
    }

    private var hasAnyDuration: Bool {
        (todayTasks + overdueTasks + completedTasks).contains { $0.estimatedMinutes != nil }
    }

    // MARK: - Computed Data

    var todayTasks: [Memory] {
        allMemories.filter { memory in
            guard memory.isActionable else { return false }
            let memoryPings = pings.filter { $0.memoryId == memory.id }
            let isRecurring = memoryPings.contains { $0.recurrence != .none }
            if isRecurring {
                if isCompletedOn(memory, date: selectedDate) { return false }
            } else {
                if memory.isCompleted { return false }
            }
            if isTaskForDate(memory: memory) { return true }
            for ping in memoryPings {
                guard ping.recurrence != .none else { continue }
                guard ping.isActive else { continue }
                guard selectedDate >= calendar.startOfDay(for: ping.fireDate) else { continue }
                switch ping.recurrence {
                case .daily: return true
                case .weekly:
                    let fireWeekday = calendar.component(.weekday, from: ping.fireDate)
                    let selectedWeekday = calendar.component(.weekday, from: selectedDate)
                    if fireWeekday == selectedWeekday { return true }
                case .monthly:
                    let fireDay = calendar.component(.day, from: ping.fireDate)
                    let selectedDay = calendar.component(.day, from: selectedDate)
                    if fireDay == selectedDay { return true }
                case .yearly:
                    let fc = calendar.dateComponents([.month, .day], from: ping.fireDate)
                    let sc = calendar.dateComponents([.month, .day], from: selectedDate)
                    if fc.month == sc.month && fc.day == sc.day { return true }
                case .none: continue
                }
            }
            return false
        }
        .sorted { ($0.detectedDate ?? $0.createdAt) < ($1.detectedDate ?? $1.createdAt) }
    }

    var overdueTasks: [Memory] {
        guard calendar.isDateInToday(selectedDate) else { return [] }
        return allMemories.filter { memory in
            guard memory.isActionable && !memory.isCompleted else { return false }
            guard let detectedDate = memory.detectedDate else { return false }
            let memoryPings = pings.filter { $0.memoryId == memory.id }
            let isRecurring = memoryPings.contains { $0.recurrence != .none }
            if isRecurring { return false }
            if todayTasks.contains(where: { $0.id == memory.id }) { return false }
            if let endDate = memory.endDate,
               selectedDate >= calendar.startOfDay(for: detectedDate) &&
               selectedDate <= calendar.startOfDay(for: endDate) { return false }
            return detectedDate < calendar.startOfDay(for: Date()) &&
                   !calendar.isDate(detectedDate, inSameDayAs: Date())
        }
        .sorted { ($0.detectedDate ?? $0.createdAt) < ($1.detectedDate ?? $1.createdAt) }
    }

    var completedTasks: [Memory] {
        allMemories.filter { memory in
            guard memory.isActionable else { return false }
            let memoryPings = pings.filter { $0.memoryId == memory.id }
            let isRecurring = memoryPings.contains { $0.recurrence != .none }
            if isRecurring {
                return isCompletedOn(memory, date: selectedDate)
            }
            return memory.isCompleted &&
                   memory.completedAt != nil &&
                   calendar.isDate(memory.completedAt!, inSameDayAs: selectedDate)
        }
    }

    var todayPings: [Ping] {
        pings.filter { ping in
            guard ping.isActive,
                  let memory = allMemories.first(where: { $0.id == ping.memoryId }) else { return false }
            let alreadyShownAsTask = todayTasks.contains { $0.id == memory.id }
            let alreadyShownAsEvent = todayEvents.contains { $0.id == memory.id }
            if alreadyShownAsTask || alreadyShownAsEvent { return false }
            if memory.isActionable && ping.recurrence != .none { return false }
            if calendar.isDate(ping.fireDate, inSameDayAs: selectedDate) { return true }
            guard selectedDate >= calendar.startOfDay(for: ping.fireDate) else { return false }
            if let eventDate = memory.detectedDate,
               !calendar.isDate(ping.fireDate, inSameDayAs: eventDate),
               selectedDate > calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: eventDate) ?? eventDate) {
                return false
            }
            switch ping.recurrence {
            case .daily: return true
            case .weekly:
                return calendar.component(.weekday, from: ping.fireDate) == calendar.component(.weekday, from: selectedDate)
            case .monthly:
                return calendar.component(.day, from: ping.fireDate) == calendar.component(.day, from: selectedDate)
            case .yearly:
                let fc = calendar.dateComponents([.month, .day], from: ping.fireDate)
                let sc = calendar.dateComponents([.month, .day], from: selectedDate)
                return fc.month == sc.month && fc.day == sc.day
            case .none: return false
            }
        }
    }

    var todayEvents: [Memory] {
        allMemories.filter { memory in
            !memory.isActionable && !memory.isCompleted &&
            memory.detectedDate != nil &&
            calendar.isDate(memory.detectedDate!, inSameDayAs: selectedDate)
        }
        .sorted { ($0.detectedDate ?? $0.createdAt) < ($1.detectedDate ?? $1.createdAt) }
    }

    var droppedToday: [Memory] {
        allMemories.filter { memory in
            !memory.isActionable &&
            memory.detectedDate == nil &&
            calendar.isDate(memory.createdAt, inSameDayAs: selectedDate)
        }
    }

    var allIncompleteTasks: [Memory] {
        allMemories.filter { memory in
            guard memory.isActionable else { return false }
            let memoryPings = pings.filter { $0.memoryId == memory.id }
            let isRecurring = memoryPings.contains { $0.recurrence != .none }
            if isRecurring {
                if isCompletedOn(memory, date: Date()) { return false }
                return true
            }
            return !memory.isCompleted
        }
        .sorted { ($0.detectedDate ?? $0.createdAt) < ($1.detectedDate ?? $1.createdAt) }
    }

    var overdueAllTasks: [Memory] {
        allIncompleteTasks.filter { memory in
            guard let date = memory.detectedDate else { return false }
            return date < calendar.startOfDay(for: Date()) &&
                   !calendar.isDate(date, inSameDayAs: Date())
        }
    }

    var todayAllTasks: [Memory] {
        allIncompleteTasks.filter { memory in
            guard let date = memory.detectedDate else { return false }
            return calendar.isDate(date, inSameDayAs: Date())
        }
    }

    var thisWeekAllTasks: [Memory] {
        let now = Date()
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        return allIncompleteTasks.filter { memory in
            guard let date = memory.detectedDate else { return false }
            return date > calendar.startOfDay(for: now) &&
                   !calendar.isDate(date, inSameDayAs: now) &&
                   date <= endOfWeek
        }
    }

    var laterAllTasks: [Memory] {
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return allIncompleteTasks.filter { memory in
            guard let date = memory.detectedDate else { return true }
            return date > endOfWeek
        }
    }

    // MARK: - Helpers

    private func hasPingToday(_ memory: Memory) -> Bool {
        pings.contains { ping in
            ping.memoryId == memory.id &&
            ping.isActive &&
            calendar.isDate(ping.fireDate, inSameDayAs: selectedDate)
        }
    }

    private func updateBannerMemoryDuration(_ minutes: Int) {
        guard let memory = bannerMemory, minutes > 0 else { return }
        memory.estimatedMinutes = minutes
        if let userId = authService.userId {
            Task { await SupabaseSyncService.shared.pushMemory(memory, userId: userId) }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    dateHeader
                    if showWeekView { weekStrip }
                    if calendar.isDateInToday(selectedDate) { modePicker }

                    List {
                        if calendar.isDateInToday(selectedDate) {
                            quickAddBar
                                .listRowBackground(Color.pearl)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 4, trailing: 20))
                        }

                        if taskMode == .today || !calendar.isDateInToday(selectedDate) {
                            statsBar
                                .listRowBackground(Color.pearl)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))

                            if !overdueTasks.isEmpty { overdueSection }
                            if !todayTasks.isEmpty { todoSection }
                            if !todayPings.isEmpty { pingsSection }
                            if !todayEvents.isEmpty { eventsSection }
                            if !completedTasks.isEmpty { completedSection }
                            if !droppedToday.isEmpty { droppedSection }

                            if todayTasks.isEmpty && todayPings.isEmpty && todayEvents.isEmpty &&
                               droppedToday.isEmpty && completedTasks.isEmpty && overdueTasks.isEmpty {
                                emptyState
                                    .listRowBackground(Color.pearl)
                                    .listRowSeparator(.hidden)
                            }
                        } else {
                            allTasksView
                        }

                        Color.clear.frame(height: 100)
                            .listRowBackground(Color.pearl)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .background(Color.pearl)
                    .scrollContentBackground(.hidden)
                }

                if showBanner, let sonarResult = bannerSonarResult {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture { showBanner = false }
                    VStack {
                        Spacer()
                        ConfirmBannerView(
                            transcription: quickAddText,
                            sonarResult: sonarResult,
                            echos: echos,
                            onDone: { isTask, duration in
                                if let memory = bannerMemory {
                                    memory.isActionable = isTask
                                    if let duration = duration, duration > 0 {
                                        updateBannerMemoryDuration(duration)
                                    }
                                }
                                showBanner = false
                                quickAddText = ""
                                bannerMemory = nil
                            },
                            onUndo: {
                                if let memory = bannerMemory {
                                    let id = memory.id
                                    let memoryPings = pings.filter { $0.memoryId == id }
                                    for ping in memoryPings {
                                        NotificationService.shared.cancelPing(pingId: ping.id)
                                        modelContext.delete(ping)
                                        Task { await SupabaseSyncService.shared.deletePing(id: ping.id) }
                                    }
                                    modelContext.delete(memory)
                                    Task { await SupabaseSyncService.shared.deleteMemory(id: id) }
                                }
                                showBanner = false
                                quickAddText = ""
                                bannerMemory = nil
                            },
                            onEchoChanged: { newEchoId in bannerMemory?.echoId = newEchoId },
                            onEdit: {
                                editingMemory = bannerMemory
                                showBanner = false
                            },
                            onAddToWatchlist: { title, type, service in
                                let item = WatchlistItem(title: title, itemType: type, streamingService: service)
                                modelContext.insert(item)
                            }
                        )
                    }
                }
            }
            .background(Color.pearl)
            .onAppear {
                selectedDate = Date()
                if let location = locationService.location {
                    Task { await weatherService.fetchWeather(for: location) }
                }
                locationService.requestLocation()
            }
            .onReceive(NotificationCenter.default.publisher(for: .resetToToday)) { _ in
                selectedDate = Date()
                taskMode = .today
            }
            .onChange(of: locationService.location) { _, location in
                if let location = location {
                    Task { await weatherService.fetchWeather(for: location) }
                }
            }
            .sheet(item: $editingMemory) { memory in MemoryEditView(memory: memory) }
            .sheet(item: $detailMemory) { memory in MemoryDetailView(memory: memory) }
            .sheet(isPresented: $showWeatherDetail) { WeatherDetailView() }
            .sheet(item: $snoozeMemory) { memory in
                SnoozeSheet(memory: memory) { snoozeMemory = nil }
            }
        }
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { taskMode = .today }
            } label: {
                Text("Today")
                    .font(.custom("DMSans-Medium", size: 14))
                    .foregroundColor(taskMode == .today ? .white : .deepNavy)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(taskMode == .today ? Color.oceanTeal : Color.clear)
                    .clipShape(Capsule())
            }

            Button {
                withAnimation(.easeOut(duration: 0.2)) { taskMode = .all }
            } label: {
                HStack(spacing: 4) {
                    Text("All Tasks")
                        .font(.custom("DMSans-Medium", size: 14))
                        .foregroundColor(taskMode == .all ? .white : .deepNavy)
                    if !allIncompleteTasks.isEmpty {
                        Text("\(allIncompleteTasks.count)")
                            .font(.custom("DMMono-Regular", size: 11))
                            .foregroundColor(taskMode == .all ? .white.opacity(0.8) : .gray)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(taskMode == .all ? Color.white.opacity(0.2) : Color.mist)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(taskMode == .all ? Color.oceanTeal : Color.clear)
                .clipShape(Capsule())
            }
        }
        .padding(3)
        .background(Color.mist)
        .clipShape(Capsule())
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.white)
    }

    // MARK: - Quick Add Bar

    private var quickAddBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.oceanTeal)

            TextField("Add a task...", text: $quickAddText)
                .font(.custom("DMSans-Regular", size: 15))
                .foregroundColor(.deepNavy)
                .focused($quickAddFocused)
                .onSubmit { submitQuickAdd() }

            if !quickAddText.isEmpty {
                Button { submitQuickAdd() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.oceanTeal)
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    private func submitQuickAdd() {
        guard !quickAddText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        quickAddFocused = false

        let text = quickAddText
        let result = sonarEngine.process(text: text, echos: echos)
        let echoId = result.echoId ?? echos.first { $0.name == "To-Do" }?.id ?? echos.first?.id ?? UUID()

        let memory = Memory(text: text, echoId: echoId, captureType: .typed)
        memory.tags = result.tags
        memory.detectedDate = result.detectedDate
        memory.endDate = result.endDate
        memory.echoConfidence = result.echoConfidence
        memory.dateConfidence = result.dateConfidence
        memory.sonarConfidence = result.echoConfidence
        memory.isActionable = true
        memory.estimatedMinutes = result.estimatedMinutes
        modelContext.insert(memory)
        SpotlightService.shared.indexMemory(
            memory,
            echoName: result.echoName,
            echoEmoji: echos.first { $0.id == memory.echoId }?.emoji ?? "📋"
        )

        if let userId = authService.userId {
            Task {
                await SupabaseSyncService.shared.pushMemory(memory, userId: userId)
                for suggestion in result.pingSuggestions {
                    let fireDate = suggestion.fireDate ?? result.detectedDate ?? Date()
                    let ping = Ping(memoryId: memory.id, fireDate: fireDate, recurrence: suggestion.recurrence)
                    if let fireTime = suggestion.fireTime { ping.fireTime = fireTime }
                    modelContext.insert(ping)
                    await SupabaseSyncService.shared.pushPing(ping, userId: userId)
                    NotificationService.shared.schedulePing(ping: ping, memoryText: memory.text)
                }
            }
        }

        bannerMemory = memory
        bannerSonarResult = result
        withAnimation(.spring(duration: 0.4)) { showBanner = true }
    }

    // MARK: - All Tasks View

    private var allTasksView: some View {
        Group {
            if allIncompleteTasks.isEmpty {
                VStack(spacing: 16) {
                    Spacer().frame(height: 40)
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 44)).foregroundColor(.seafoam.opacity(0.4))
                    Text("All caught up!")
                        .font(.custom("DMSans-Medium", size: 18)).foregroundColor(.deepNavy)
                    Text("No pending tasks. Drop a memory to get started.")
                        .font(.custom("DMSans-Regular", size: 14)).foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.pearl)
                .listRowSeparator(.hidden)
            } else {
                if !overdueAllTasks.isEmpty {
                    allTasksSection(title: "OVERDUE", color: .coral, tasks: overdueAllTasks, isOverdue: true)
                }
                if !todayAllTasks.isEmpty {
                    allTasksSection(title: "TODAY", color: .oceanTeal, tasks: todayAllTasks, isOverdue: false)
                }
                if !thisWeekAllTasks.isEmpty {
                    allTasksSection(title: "THIS WEEK", color: .oceanTeal, tasks: thisWeekAllTasks, isOverdue: false)
                }
                if !laterAllTasks.isEmpty {
                    allTasksSection(title: "LATER", color: .gray, tasks: laterAllTasks, isOverdue: false)
                }
            }
        }
    }

    private func allTasksSection(title: String, color: Color, tasks: [Memory], isOverdue: Bool) -> some View {
        Group {
            Text(title)
                .font(.custom("DMSans-Medium", size: 13))
                .foregroundColor(color)
                .tracking(1)
                .listRowBackground(Color.pearl)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 4, trailing: 20))

            ForEach(tasks) { memory in
                taskRow(memory: memory, isOverdue: isOverdue)
            }
        }
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        HStack {
            Button {
                selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.oceanTeal)
            }

            Spacer()

            VStack(spacing: 2) {
                if calendar.isDateInToday(selectedDate) {
                    Text("Today").font(.custom("DMSans-Medium", size: 18)).foregroundColor(.deepNavy)
                } else if calendar.isDateInYesterday(selectedDate) {
                    Text("Yesterday").font(.custom("DMSans-Medium", size: 18)).foregroundColor(.deepNavy)
                } else if calendar.isDateInTomorrow(selectedDate) {
                    Text("Tomorrow").font(.custom("DMSans-Medium", size: 18)).foregroundColor(.deepNavy)
                } else {
                    Text(selectedDate, format: .dateTime.weekday(.wide))
                        .font(.custom("DMSans-Medium", size: 18)).foregroundColor(.deepNavy)
                }
                Text(selectedDate, format: .dateTime.month(.wide).day().year())
                    .font(.custom("DMSans-Regular", size: 13)).foregroundColor(.gray)
            }
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.2)) { showWeekView.toggle() }
            }

            Spacer()

            HStack(spacing: 12) {
                if calendar.isDateInToday(selectedDate) && !weatherService.temperature.isEmpty {
                    Button { showWeatherDetail = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: weatherService.symbolName)
                                .font(.system(size: 13)).foregroundColor(.oceanTeal)
                            Text(weatherService.temperature)
                                .font(.custom("DMMono-Regular", size: 13)).foregroundColor(.deepNavy)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium)).foregroundColor(.oceanTeal)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white)
    }

    // MARK: - Week Strip

    private var weekStrip: some View {
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)) ?? selectedDate

        return HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { offset in
                let day = calendar.date(byAdding: .day, value: offset, to: startOfWeek) ?? selectedDate
                let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
                let isToday = calendar.isDateInToday(day)
                let hasTasks = allMemories.contains { $0.isActionable && !$0.isCompleted && isTaskForDate(memory: $0, for: day) }

                Button { selectedDate = day } label: {
                    VStack(spacing: 4) {
                        Text(day, format: .dateTime.weekday(.narrow))
                            .font(.custom("DMSans-Medium", size: 11))
                            .foregroundColor(isSelected ? .white : .gray)
                        Text(day, format: .dateTime.day())
                            .font(.custom("DMSans-Medium", size: 15))
                            .foregroundColor(isSelected ? .white : .deepNavy)
                        Circle()
                            .fill(hasTasks ? (isSelected ? Color.white : Color.oceanTeal) : Color.clear)
                            .frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isSelected ? Color.oceanTeal : (isToday ? Color.mist : Color.clear))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(Color.white)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        let total = todayTasks.count + completedTasks.count + overdueTasks.count
        let done = completedTasks.count

        return VStack(spacing: 8) {
            HStack(spacing: 16) {
                if total > 0 {
                    HStack(spacing: 6) {
                        ZStack {
                            Circle().stroke(Color.mist, lineWidth: 3).frame(width: 32, height: 32)
                            Circle()
                                .trim(from: 0, to: total > 0 ? CGFloat(done) / CGFloat(total) : 0)
                                .stroke(Color.oceanTeal, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 32, height: 32)
                                .rotationEffect(.degrees(-90))
                        }
                        Text("\(done)/\(total) done")
                            .font(.custom("DMSans-Medium", size: 14)).foregroundColor(.deepNavy)
                    }
                }
                if !overdueTasks.isEmpty {
                    HStack(spacing: 4) {
                        Circle().fill(Color.coral).frame(width: 8, height: 8)
                        Text("\(overdueTasks.count) overdue")
                            .font(.custom("DMSans-Medium", size: 13)).foregroundColor(.coral)
                    }
                }
                if !todayPings.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.fill").font(.system(size: 11)).foregroundColor(.oceanTeal)
                        Text("\(todayPings.count) \(todayPings.count == 1 ? "ping" : "pings")")
                            .font(.custom("DMSans-Medium", size: 13)).foregroundColor(.oceanTeal)
                    }
                }
                if !todayEvents.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill").font(.system(size: 11)).foregroundColor(.seafoam)
                        Text("\(todayEvents.count) \(todayEvents.count == 1 ? "event" : "events")")
                            .font(.custom("DMSans-Medium", size: 13)).foregroundColor(.seafoam)
                    }
                }

                if hasAnyDuration && totalEstimatedMinutes > 0 {
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "clock").font(.system(size: 10)).foregroundColor(.gray)
                        Text("~\(loadLabel)")
                            .font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.mist)
                    .clipShape(Capsule())
                }

                if !hasAnyDuration || totalEstimatedMinutes == 0 {
                    Spacer()
                }
            }

            if calendar.isDateInToday(selectedDate) && hasAnyDuration && totalEstimatedMinutes > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Daily load")
                            .font(.custom("DMSans-Medium", size: 11))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("~\(remainingLoadLabel) available")
                            .font(.custom("DMMono-Regular", size: 11))
                            .foregroundColor(.gray)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 100)
                                .fill(Color.mist)
                                .frame(height: 5)
                            RoundedRectangle(cornerRadius: 100)
                                .fill(loadFraction > 0.8 ? Color.coral : Color.oceanTeal)
                                .frame(width: geo.size.width * loadFraction, height: 5)
                        }
                    }
                    .frame(height: 5)
                }
            }
        }
    }

    // MARK: - Overdue Section

    private var overdueSection: some View {
        Group {
            HStack(spacing: 6) {
                Circle().fill(Color.coral).frame(width: 8, height: 8)
                Text("OVERDUE")
                    .font(.custom("DMSans-Medium", size: 13)).foregroundColor(.coral).tracking(1)
            }
            .listRowBackground(Color.pearl)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 4, trailing: 20))

            ForEach(overdueTasks) { memory in
                taskRow(memory: memory, isOverdue: true)
            }
        }
    }

    // MARK: - To Do Section

    private var todoSection: some View {
        Group {
            Text("TO DO")
                .font(.custom("DMSans-Medium", size: 13)).foregroundColor(.oceanTeal).tracking(1)
                .listRowBackground(Color.pearl)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 4, trailing: 20))

            ForEach(todayTasks) { memory in
                taskRow(memory: memory, isOverdue: false)
            }
        }
    }

    // MARK: - Fetch SubTasks

    private func fetchSubTasks(for memory: Memory) -> [SubTask] {
        let descriptor = FetchDescriptor<SubTask>(sortBy: [SortDescriptor(\.sortOrder)])
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { $0.memoryId == memory.id }
    }

    // MARK: - Pings Section

    private var pingsSection: some View {
        Group {
            Text("PINGS")
                .font(.custom("DMSans-Medium", size: 13)).foregroundColor(.oceanTeal).tracking(1)
                .listRowBackground(Color.pearl)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 4, trailing: 20))

            ForEach(todayPings) { ping in
                if let memory = allMemories.first(where: { $0.id == ping.memoryId }) {
                    let memoryText = memory.text
                    let hasChecklist = memory.hasChecklist
                    let fireTime = ping.fireTime
                    let recurrence = ping.recurrence

                    Button { detailMemory = memory } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 14)).foregroundColor(.oceanTeal).frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(memoryText)
                                    .font(.custom("DMSans-Regular", size: 15))
                                    .foregroundColor(.deepNavy)
                                    .lineLimit(hasChecklist ? 1 : 2)
                                if hasChecklist {
                                    let subTasks = fetchSubTasks(for: memory)
                                    if !subTasks.isEmpty {
                                        let completed = subTasks.filter { $0.isCompleted }.count
                                        HStack(spacing: 4) {
                                            Image(systemName: "list.bullet").font(.system(size: 10)).foregroundColor(.oceanTeal)
                                            Text("\(completed)/\(subTasks.count) items")
                                                .font(.custom("DMMono-Regular", size: 11)).foregroundColor(.oceanTeal)
                                        }
                                    }
                                }
                                HStack(spacing: 8) {
                                    Text(fireTime, format: .dateTime.hour().minute())
                                        .font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                                    if recurrence != .none {
                                        Text(recurrence.rawValue.capitalized)
                                            .font(.custom("DMMono-Regular", size: 11)).foregroundColor(.oceanTeal)
                                    }
                                }
                            }
                            Spacer()
                            Button { snoozeMemory = memory } label: {
                                ZStack {
                                    Circle().fill(Color.mist).frame(width: 32, height: 32)
                                    Image(systemName: "moon.zzz").font(.system(size: 12, weight: .medium)).foregroundColor(.oceanTeal)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.pearl)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button { editingMemory = memory } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.oceanTeal)
                    }
                }
            }
        }
    }

    // MARK: - Events Section

    private var eventsSection: some View {
        Group {
            Text("EVENTS")
                .font(.custom("DMSans-Medium", size: 13)).foregroundColor(.seafoam).tracking(1)
                .listRowBackground(Color.pearl)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 4, trailing: 20))

            ForEach(todayEvents) { memory in
                let memoryText = memory.text
                let memoryEchoId = memory.echoId
                let detectedDate = memory.detectedDate
                let estimatedMinutes = memory.estimatedMinutes

                Button { detailMemory = memory } label: {
                    HStack(spacing: 12) {
                        if let echo = echos.first(where: { $0.id == memoryEchoId }) {
                            Text(echo.emoji).font(.system(size: 16)).frame(width: 24)
                        } else {
                            Image(systemName: "star.fill").font(.system(size: 14)).foregroundColor(.seafoam).frame(width: 24)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(memoryText)
                                .font(.custom("DMSans-Regular", size: 15)).foregroundColor(.deepNavy).lineLimit(2)
                            HStack(spacing: 8) {
                                if let echo = echos.first(where: { $0.id == memoryEchoId }) {
                                    Text(echo.name)
                                        .font(.custom("DMSans-Medium", size: 12)).foregroundColor(.deepNavy)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.mist).clipShape(Capsule())
                                }
                                if let date = detectedDate {
                                    Text(date, format: .dateTime.hour().minute())
                                        .font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                                }
                                if let mins = estimatedMinutes {
                                    Text(DurationParser.shared.format(mins))
                                        .font(.custom("DMMono-Regular", size: 11))
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 5).padding(.vertical, 2)
                                        .background(Color.mist).clipShape(Capsule())
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.pearl)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button { editingMemory = memory } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.oceanTeal)
                }
            }
        }
    }

    // MARK: - Completed Section

    private var completedSection: some View {
        Group {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { showCompleted.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text("COMPLETED")
                        .font(.custom("DMSans-Medium", size: 13)).foregroundColor(.gray).tracking(1)
                    Text("\(completedTasks.count)")
                        .font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                    Image(systemName: showCompleted ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11)).foregroundColor(.gray)
                }
            }
            .listRowBackground(Color.pearl)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 4, trailing: 20))

            if showCompleted {
                ForEach(completedTasks) { memory in
                    completedRow(memory: memory)
                        .listRowBackground(Color.pearl)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                }
            }
        }
    }

    // MARK: - Dropped Section

    private var droppedSection: some View {
        Group {
            Text("DROPPED TODAY")
                .font(.custom("DMSans-Medium", size: 13)).foregroundColor(.gray).tracking(1)
                .listRowBackground(Color.pearl)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 4, trailing: 20))

            ForEach(droppedToday) { memory in
                let memoryText = memory.text
                let memoryEchoId = memory.echoId

                Button { detailMemory = memory } label: {
                    HStack(spacing: 12) {
                        if let echo = echos.first(where: { $0.id == memoryEchoId }) {
                            Text(echo.emoji).font(.system(size: 16)).frame(width: 24)
                        }
                        Text(memoryText)
                            .font(.custom("DMSans-Regular", size: 15)).foregroundColor(.deepNavy).lineLimit(2)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.pearl)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
            }
        }
    }

    // MARK: - Task Row

    private func taskRow(memory: Memory, isOverdue: Bool) -> some View {
        let subTasks = memory.hasChecklist ? fetchSubTasks(for: memory) : []
        let isExpanded = expandedMemoryIds.contains(memory.id)

        return Button { detailMemory = memory } label: {
            VStack(spacing: 0) {
                taskRowHeader(memory: memory, isOverdue: isOverdue, subTasks: subTasks, isExpanded: isExpanded)
                if isExpanded && !subTasks.isEmpty {
                    taskRowChecklist(memory: memory, subTasks: subTasks)
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.pearl)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                let id = memory.id
                let memoryPings = pings.filter { $0.memoryId == memory.id }
                for ping in memoryPings {
                    NotificationService.shared.cancelPing(pingId: ping.id)
                    modelContext.delete(ping)
                }
                modelContext.delete(memory)
                Task { await SupabaseSyncService.shared.deleteMemory(id: id) }
            } label: { Label("Delete", systemImage: "trash") }
                .tint(.red)

            Button { editingMemory = memory } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.oceanTeal)

            Button { snoozeMemory = memory } label: {
                Label("Snooze", systemImage: "moon.zzz")
            }
            .tint(Color(red: 0.059, green: 0.431, blue: 0.337))
        }
    }

    private func taskRowHeader(memory: Memory, isOverdue: Bool, subTasks: [SubTask], isExpanded: Bool) -> some View {
        let memoryText = memory.text
        let memoryEchoId = memory.echoId
        let detectedDate = memory.detectedDate
        let estimatedMinutes = memory.estimatedMinutes
        let memoryId = memory.id
        let memoryPings = pings.filter { $0.memoryId == memory.id }
        let isRecurring = memoryPings.contains { $0.recurrence != .none }
        let displayDate: Date? = isRecurring ? selectedDate : detectedDate
        let hasPing = hasPingToday(memory)

        return HStack(spacing: 12) {
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    if isRecurring {
                        setCompleted(memory, date: selectedDate)
                    } else {
                        memory.isCompleted = true
                        memory.completedAt = Date()
                        memory.updatedAt = Date()
                        for ping in memoryPings {
                            ping.isActive = false
                            NotificationService.shared.cancelPing(pingId: ping.id)
                        }
                    }
                }
            } label: {
                Circle()
                    .stroke(isOverdue ? Color.coral : Color.oceanTeal, lineWidth: 2)
                    .frame(width: 24, height: 24)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(memoryText)
                    .font(.custom("DMSans-Regular", size: 15)).foregroundColor(.deepNavy).lineLimit(2)
                HStack(spacing: 6) {
                    if let echo = echos.first(where: { $0.id == memoryEchoId }) {
                        HStack(spacing: 3) {
                            Text(echo.emoji).font(.system(size: 11))
                            Text(echo.name)
                                .font(.custom("DMSans-Medium", size: 12)).foregroundColor(.deepNavy).lineLimit(1).fixedSize()
                        }
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.mist).clipShape(Capsule())
                    }
                    if let date = displayDate {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(.custom("DMMono-Regular", size: 12))
                            .foregroundColor(isOverdue ? .coral : .gray).fixedSize()
                    }
                    if let mins = estimatedMinutes {
                        Text(DurationParser.shared.format(mins))
                            .font(.custom("DMMono-Regular", size: 11))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.mist).clipShape(Capsule())
                            .fixedSize()
                    }
                    if hasPing {
                        HStack(spacing: 3) {
                            Image(systemName: "bell.fill").font(.system(size: 10)).foregroundColor(.oceanTeal)
                            Text("Ping").font(.custom("DMMono-Regular", size: 11)).foregroundColor(.oceanTeal).fixedSize()
                        }
                    }
                }
                if !subTasks.isEmpty {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            if isExpanded {
                                expandedMemoryIds.remove(memoryId)
                            } else {
                                expandedMemoryIds.insert(memoryId)
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "list.bullet").font(.system(size: 10))
                            Text("\(subTasks.filter { $0.isCompleted }.count)/\(subTasks.count)")
                                .font(.custom("DMMono-Regular", size: 11))
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9))
                        }
                        .fixedSize()
                        .foregroundColor(.oceanTeal)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.oceanTeal.opacity(0.1)).clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .padding(12)
    }

    private func taskRowChecklist(memory: Memory, subTasks: [SubTask]) -> some View {
        VStack(spacing: 0) {
            Divider().padding(.horizontal, 12)
            ForEach(subTasks) { subTask in
                Button {
                    withAnimation(.spring(duration: 0.2)) {
                        subTask.isCompleted.toggle()
                        let allDone = subTasks.allSatisfy { $0.isCompleted }
                        if allDone {
                            let memoryPings = pings.filter { $0.memoryId == memory.id }
                            let isRecurring = memoryPings.contains { $0.recurrence != .none }
                            if isRecurring {
                                setCompleted(memory, date: selectedDate)
                            } else {
                                memory.isCompleted = true
                                memory.completedAt = Date()
                                for ping in memoryPings {
                                    ping.isActive = false
                                    NotificationService.shared.cancelPing(pingId: ping.id)
                                }
                            }
                            expandedMemoryIds.remove(memory.id)
                        }
                        memory.updatedAt = Date()
                    }
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .stroke(Color.oceanTeal.opacity(0.4), lineWidth: 1.5)
                                .frame(width: 18, height: 18)
                            if subTask.isCompleted {
                                Circle().fill(Color.oceanTeal).frame(width: 18, height: 18)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                            }
                        }
                        Text(subTask.text)
                            .font(.custom("DMSans-Regular", size: 14))
                            .foregroundColor(subTask.isCompleted ? .gray : .deepNavy)
                            .strikethrough(subTask.isCompleted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                if subTask.id != subTasks.last?.id {
                    Divider().padding(.leading, 40)
                }
            }
        }
    }

    // MARK: - Completed Row

    private func completedRow(memory: Memory) -> some View {
        let memoryText = memory.text
        let memoryPings = pings.filter { $0.memoryId == memory.id }
        let isRecurring = memoryPings.contains { $0.recurrence != .none }

        return HStack(spacing: 12) {
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    if isRecurring {
                        setUncompleted(memory, date: selectedDate)
                    } else {
                        memory.isCompleted = false
                        memory.completedAt = nil
                        memory.updatedAt = Date()
                        for ping in memoryPings {
                            ping.isActive = true
                            NotificationService.shared.schedulePing(ping: ping, memoryText: memoryText)
                        }
                    }
                }
            } label: {
                ZStack {
                    Circle().fill(Color.oceanTeal).frame(width: 24, height: 24)
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)

            Text(memoryText)
                .font(.custom("DMSans-Regular", size: 15)).foregroundColor(.gray).strikethrough().lineLimit(2)
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        .contentShape(Rectangle())
        .onTapGesture { detailMemory = memory }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)
            Image(systemName: "checkmark.circle")
                .font(.system(size: 44)).foregroundColor(.seafoam.opacity(0.4))
            Text(calendar.isDateInToday(selectedDate) ? "All clear today" : "No memories today")
                .font(.custom("DMSans-Medium", size: 18)).foregroundColor(.deepNavy)
            Text(calendar.isDateInToday(selectedDate) ? "Drop a memory with a task and it'll show up here" : "Tasks and memories for this day will appear here")
                .font(.custom("DMSans-Regular", size: 14)).foregroundColor(.gray).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func isTaskForDate(memory: Memory, for date: Date? = nil) -> Bool {
        let targetDate = date ?? selectedDate
        if let detectedDate = memory.detectedDate {
            return calendar.isDate(detectedDate, inSameDayAs: targetDate)
        }
        return calendar.isDate(memory.createdAt, inSameDayAs: targetDate)
    }
}

// MARK: - Snooze Sheet

struct SnoozeSheet: View {
    let memory: Memory
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(memory.text)
                    .font(.custom("DMSans-Regular", size: 15)).foregroundColor(.deepNavy).lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12).background(Color.pearl).clipShape(RoundedRectangle(cornerRadius: 10))

                Text("Snooze until...")
                    .font(.custom("DMSans-Medium", size: 16)).foregroundColor(.deepNavy)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 8) {
                    snoozeOption(icon: "sunrise", label: "Tomorrow", sublabel: formatDate(daysFromNow: 1), date: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())
                    snoozeOption(icon: "calendar.badge.plus", label: "In 2 days", sublabel: formatDate(daysFromNow: 2), date: calendar.date(byAdding: .day, value: 2, to: Date()) ?? Date())
                    snoozeOption(icon: "calendar", label: "Next week", sublabel: formatDate(daysFromNow: 7), date: calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date())
                    snoozeOption(icon: "calendar.badge.clock", label: "Next month", sublabel: formatDate(daysFromNow: 30), date: calendar.date(byAdding: .month, value: 1, to: Date()) ?? Date())
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Or pick a date")
                        .font(.custom("DMSans-Medium", size: 14)).foregroundColor(.gray)
                    DatePicker(
                        "Snooze date",
                        selection: Binding(
                            get: { memory.detectedDate ?? Date() },
                            set: { newDate in
                                memory.detectedDate = newDate
                                memory.updatedAt = Date()
                                onDone()
                            }
                        ),
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact).tint(.oceanTeal)
                }
                Spacer()
            }
            .padding(20)
            .navigationTitle("Snooze")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.gray)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func snoozeOption(icon: String, label: String, sublabel: String, date: Date) -> some View {
        Button {
            memory.detectedDate = date
            memory.updatedAt = Date()
            onDone()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16)).foregroundColor(.oceanTeal).frame(width: 24)
                Text(label).font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy)
                Spacer()
                Text(sublabel).font(.custom("DMMono-Regular", size: 13)).foregroundColor(.gray)
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        }
    }

    private func formatDate(daysFromNow days: Int) -> String {
        let date = calendar.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}

#Preview {
    TodayView()
        .modelContainer(for: [Memory.self, Echo.self, Ping.self, SubTask.self], inMemory: true)
        .environment(AuthService())
}
