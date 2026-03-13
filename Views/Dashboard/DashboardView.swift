//
//  DashboardView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI
import SwiftData

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

    // MARK: - Computed Properties

    var displayedEchos: [Echo] {
        let withMemories = echos.filter { echo in
            memories.contains { $0.echoId == echo.id }
        }.sorted { $0.sortOrder < $1.sortOrder }

        if withMemories.count >= 6 {
            return withMemories
        }

        let withMemoryIds = Set(withMemories.map { $0.id })
        let topEmpty = echos
            .filter { !withMemoryIds.contains($0.id) }
            .sorted { $0.sortOrder < $1.sortOrder }
            .prefix(6 - withMemories.count)

        return withMemories + Array(topEmpty)
    }

    var pinnedMemories: [Memory] {
        memories.filter { $0.isPinned }
    }

    var upcomingTasks: [Memory] {
        let now = Date()
        let window = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        return memories
            .filter {
                $0.isActionable &&
                !$0.isCompleted &&
                $0.detectedDate != nil &&
                $0.detectedDate! > now &&
                $0.detectedDate! <= window
            }
            .sorted { $0.detectedDate! < $1.detectedDate! }
    }

    private var cleanUpCount: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return memories.filter { memory in
            guard memory.isActionable else { return false }
            guard !memory.isPinned else { return false }
            guard !memory.hasChecklist else { return false }
            guard memory.url == nil || memory.url?.isEmpty == true else { return false }
            let hasRecurringPing = pings.contains { $0.memoryId == memory.id && $0.recurrence != .none }
            guard !hasRecurringPing else { return false }
            if memory.isCompleted, let completedAt = memory.completedAt {
                return completedAt < cutoff
            }
            if let detectedDate = memory.detectedDate {
                return detectedDate < cutoff
            }
            return false
        }.count
    }

    // MARK: - Expired helper
    private func isExpired(_ memory: Memory) -> Bool {
        guard let date = memory.detectedDate, date < Date() else { return false }
        let memoryPings = pings.filter { $0.memoryId == memory.id }
        // If any ping is recurring, never tint it
        if memoryPings.contains(where: { $0.recurrence != .none }) { return false }
        // If any one-time ping fires in the future, not expired
        let hasFuturePing = memoryPings.contains { $0.fireDate > Date() }
        return !hasFuturePing
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(greeting)
                                .font(.custom("InstrumentSerif-Regular", size: 28))
                                .foregroundColor(.deepNavy)
                            let activeCount = displayedEchos.filter { echo in
                                memories.contains { $0.echoId == echo.id }
                            }.count

                            Text("\(memories.count) memories across \(activeCount) \(activeCount == 1 ? "Echo" : "Echos")")
                                .font(.custom("DMSans-Regular", size: 14))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        NavigationLink(destination: SettingsView()) {
                            ZStack {
                                Circle().fill(Color.mist).frame(width: 36, height: 36)
                                Image(systemName: "person").font(.system(size: 15)).foregroundColor(.oceanTeal)
                            }
                        }
                    }

                    // Search bar
                    Button { showSearch = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").font(.system(size: 15)).foregroundColor(.gray)
                            Text("Dive into memories...")
                                .font(.custom("DMSans-Regular", size: 15))
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                    }

                    // Clean up hint
                    if cleanUpCount > 0 {
                        NavigationLink(destination: SettingsView()) {
                            HStack(spacing: 10) {
                                Image(systemName: "sparkles.rectangle.stack")
                                    .font(.system(size: 14))
                                    .foregroundColor(.oceanTeal)
                                Text("\(cleanUpCount) old \(cleanUpCount == 1 ? "task" : "tasks") can be cleaned up")
                                    .font(.custom("DMSans-Regular", size: 14))
                                    .foregroundColor(.deepNavy)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.oceanTeal.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // Pinned memories
                    if showPinned && !pinnedMemories.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "pin.fill").font(.system(size: 11)).foregroundColor(.coral)
                                    Text("PINNED")
                                        .font(.custom("DMSans-Medium", size: 13))
                                        .foregroundColor(.coral)
                                        .tracking(1)
                                }
                                Spacer()
                                Button {
                                    withAnimation(.easeOut(duration: 0.3)) { showPinned = false }
                                } label: {
                                    Image(systemName: "xmark").font(.system(size: 11, weight: .medium)).foregroundColor(.gray.opacity(0.5))
                                }
                            }
                            ForEach(pinnedMemories) { memory in
                                pinnedRow(memory: memory)
                            }
                        }
                    }

                    // Upcoming tasks
                    if showUpcoming && !upcomingTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock.fill").font(.system(size: 11)).foregroundColor(.oceanTeal)
                                    Text("UPCOMING")
                                        .font(.custom("DMSans-Medium", size: 13))
                                        .foregroundColor(.oceanTeal)
                                        .tracking(1)
                                }
                                Spacer()
                                Button {
                                    withAnimation(.easeOut(duration: 0.3)) { showUpcoming = false }
                                } label: {
                                    Image(systemName: "xmark").font(.system(size: 11, weight: .medium)).foregroundColor(.gray.opacity(0.5))
                                }
                            }
                            ForEach(upcomingTasks) { memory in
                                upcomingRow(memory: memory)
                            }
                        }
                    }

                    // Your Echos header
                    HStack {
                        Text("YOUR ECHOS")
                            .font(.custom("DMSans-Medium", size: 13))
                            .foregroundColor(.oceanTeal)
                            .tracking(1)
                        Spacer()
                        Button { showCreateEcho = true } label: {
                            ZStack {
                                Circle().fill(Color.mist).frame(width: 28, height: 28)
                                Image(systemName: "plus").font(.system(size: 13, weight: .medium)).foregroundColor(.oceanTeal)
                            }
                        }
                    }
                    .padding(.top, 4)

                    if displayedEchos.isEmpty {
                        emptyState
                    } else {
                        echoBubbleGrid
                    }

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color.pearl)
            .onAppear {
                seedDefaultEchos()
                showUpcoming = true
                showPinned = true
            }
            .sheet(isPresented: $showCreateEcho) { CreateEchoView() }
            .sheet(item: $editingMemory) { memory in MemoryEditView(memory: memory) }
        }
    }

    // MARK: - Pinned Row
    private func pinnedRow(memory: Memory) -> some View {
        let expired = isExpired(memory)
        return HStack(spacing: 12) {
            Image(systemName: "pin.fill")
                .font(.system(size: 13))
                .foregroundColor(expired ? .gray.opacity(0.4) : .coral)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(memory.text)
                    .font(.custom("DMSans-Regular", size: 15))
                    .foregroundColor(expired ? .gray : .deepNavy)
                    .lineLimit(2)

                if let echo = echos.first(where: { $0.id == memory.echoId }) {
                    HStack(spacing: 3) {
                        Text(echo.emoji).font(.system(size: 11))
                        Text(echo.name)
                            .font(.custom("DMSans-Medium", size: 12))
                            .foregroundColor(expired ? .gray : .deepNavy)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.mist)
                    .clipShape(Capsule())
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
        .onTapGesture { editingMemory = memory }
    }

    // MARK: - Upcoming Row
    private func upcomingRow(memory: Memory) -> some View {
        let expired = isExpired(memory)
        return HStack(spacing: 12) {
            if let echo = echos.first(where: { $0.id == memory.echoId }) {
                Text(echo.emoji).font(.system(size: 16)).frame(width: 24)
                    .opacity(expired ? 0.4 : 1.0)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(memory.text)
                    .font(.custom("DMSans-Regular", size: 15))
                    .foregroundColor(expired ? .gray : .deepNavy)
                    .lineLimit(2)

                if let date = memory.detectedDate {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundColor(expired ? .gray.opacity(0.5) : .oceanTeal)
                        Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                            .font(.custom("DMMono-Regular", size: 12))
                            .foregroundColor(expired ? .gray.opacity(0.5) : .oceanTeal)
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
        .onTapGesture { editingMemory = memory }
    }

    // MARK: - Greeting
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)
            FinIcon()
                .fill(Color.seafoam.opacity(0.3))
                .frame(width: 60, height: 72)
            Text("Drop your first memory")
                .font(.custom("DMSans-Medium", size: 18))
                .foregroundColor(.deepNavy)
            Text("Tap the fin button below to get started")
                .font(.custom("DMSans-Regular", size: 14))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Pending Count
    private func pendingCountFor(echo: Echo) -> Int {
        let echoMemories = memories.filter { $0.echoId == echo.id }
        var count = 0
        for memory in echoMemories {
            if memory.isActionable && !memory.isCompleted {
                if let date = memory.detectedDate,
                   date <= Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()) {
                    count += 1
                    continue
                }
            }
            let memoryPings = pings.filter { $0.memoryId == memory.id && $0.isActive }
            for ping in memoryPings {
                if Calendar.current.isDate(ping.fireDate, inSameDayAs: Date()) {
                    count += 1
                }
            }
        }
        return count
    }

    // MARK: - Echo Bubble Grid
    private var echoBubbleGrid: some View {
        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ]

        return LazyVGrid(columns: columns, spacing: 24) {
            ForEach(Array(displayedEchos.enumerated()), id: \.element.id) { index, echo in
                let count = memories.filter { $0.echoId == echo.id }.count
                let isEmpty = count == 0

                NavigationLink(destination: EchoDetailView(echo: echo)) {
                    EchoBubbleView(
                        echo: echo,
                        count: count,
                        pendingCount: isEmpty ? 0 : pendingCountFor(echo: echo),
                        totalMemories: memories.count
                    )
                    .opacity(isEmpty ? 0.5 : 1.0)
                }
                .offset(
                    x: isEmpty ? 0 : CGFloat([8, -6, 10, -8, 5, -10, 7, -5, 9, -7, 6, -9, 8, -6][index % 14]),
                    y: isEmpty ? 0 : CGFloat([4, -8, 6, -4, 10, -6, 3, -9, 7, -3, 8, -5, 4, -7][index % 14])
                )
            }
        }
    }

    // MARK: - Seed Defaults
    private func seedDefaultEchos() {
        guard echos.isEmpty else { return }
        Echo.seedDefaults(context: modelContext)
    }
}

#Preview {
    DashboardView(showSearch: .constant(false))
        .modelContainer(for: [Memory.self, Echo.self, Ping.self], inMemory: true)
}
