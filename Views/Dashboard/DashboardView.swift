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
    @State private var editingMemory: Memory?
    
    var activeEchos: [Echo] {
        echos.filter { echo in
            memories.contains { $0.echoId == echo.id }
        }
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
                            
                            Text("\(memories.count) memories across \(activeEchos.count) \(activeEchos.count == 1 ? "Echo" : "Echos")")
                                .font(.custom("DMSans-Regular", size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        NavigationLink(destination: SettingsView()) {
                            ZStack {
                                Circle()
                                    .fill(Color.mist)
                                    .frame(width: 36, height: 36)
                                Image(systemName: "person")
                                    .font(.system(size: 15))
                                    .foregroundColor(.oceanTeal)
                            }
                        }
                    }
                    
                    // Search bar
                    Button {
                        showSearch = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 15))
                                .foregroundColor(.gray)
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
                    
                    // Upcoming / Pinned card
                    if showUpcoming, let upcoming = upcomingMemory {
                        UpcomingCard(
                            memory: upcoming.memory,
                            echos: echos,
                            isPinned: upcoming.isPinned,
                            onTap: { editingMemory = upcoming.memory },
                            onDismiss: {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    showUpcoming = false
                                }
                            }
                        )
                    }
                    
                    // Your Echos header
                    HStack {
                        Text("YOUR ECHOS")
                            .font(.custom("DMSans-Medium", size: 13))
                            .foregroundColor(.oceanTeal)
                            .tracking(1)
                        
                        Spacer()
                        
                        Button {
                            showCreateEcho = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.mist)
                                    .frame(width: 28, height: 28)
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.oceanTeal)
                            }
                        }
                    }
                    .padding(.top, 4)
                    
                    // Echo bubbles or empty state
                    if activeEchos.isEmpty {
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
            }
            .sheet(isPresented: $showCreateEcho) {
                CreateEchoView()
            }
            .sheet(item: $editingMemory) { memory in
                MemoryEditView(memory: memory)
            }
        }
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
    
    // MARK: - Upcoming Memory
    
    private var upcomingMemory: (memory: Memory, isPinned: Bool)? {
        if let pinned = memories.first(where: { $0.isPinned }) {
            return (pinned, true)
        }
        
        let now = Date()
        let upcoming = memories
            .filter { $0.detectedDate != nil && $0.detectedDate! > now && !$0.isCompleted }
            .sorted { ($0.detectedDate ?? now) < ($1.detectedDate ?? now) }
            .first
        
        if let upcoming = upcoming {
            return (upcoming, false)
        }
        
        return nil
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
        let active = activeEchos
        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
        
        return LazyVGrid(columns: columns, spacing: 24) {
            ForEach(Array(active.enumerated()), id: \.element.id) { index, echo in
                let count = memories.filter { $0.echoId == echo.id }.count
                
                NavigationLink(destination: EchoDetailView(echo: echo)) {
                    EchoBubbleView(
                        echo: echo,
                        count: count,
                        pendingCount: pendingCountFor(echo: echo),
                        totalMemories: memories.count
                    )
                }
                .offset(
                    x: CGFloat([8, -6, 10, -8, 5, -10, 7, -5, 9, -7, 6, -9, 8, -6][index % 14]),
                    y: CGFloat([4, -8, 6, -4, 10, -6, 3, -9, 7, -3, 8, -5, 4, -7][index % 14])
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
