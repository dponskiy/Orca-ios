//
//  EchoDetailView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI
import SwiftData

struct EchoDetailView: View {
    let echo: Echo
    @Query private var memories: [Memory]
    @Query private var pings: [Ping]
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService

    enum ActiveSheet: Identifiable {
        case editMemory(Memory)
        case detailMemory(Memory)
        case groceryMode
        var id: String {
            switch self {
            case .editMemory(let m): return "edit-\(m.id)"
            case .detailMemory(let m): return "detail-\(m.id)"
            case .groceryMode: return "grocery"
            }
        }
    }
    @State private var activeSheet: ActiveSheet? = nil

    var filteredMemories: [Memory] {
        memories.filter { $0.echoId == echo.id }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func isExpired(_ memory: Memory) -> Bool {
        let expiryDate = memory.endDate ?? memory.detectedDate
        guard let date = expiryDate, date < Date() else { return false }
        let memoryPings = pings.filter { $0.memoryId == memory.id }
        if memoryPings.contains(where: { $0.recurrence != .none }) { return false }
        return !memoryPings.contains { $0.fireDate > Date() }
    }

    var body: some View {
        List {
            // Count + mode buttons
            Section {
                VStack(spacing: 10) {
                    HStack {
                        Text("\(filteredMemories.count) \(filteredMemories.count == 1 ? "memory" : "memories")")
                            .font(.custom("DMSans-Medium", size: 14)).foregroundColor(.gray)
                        Spacer()
                    }

                    if echo.name == "Cooking" {
                        Button {
                            activeSheet = .groceryMode
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle().fill(Color.oceanTeal).frame(width: 40, height: 40)
                                    Image(systemName: "cart.fill").font(.system(size: 16)).foregroundColor(.white)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Shopping Mode")
                                        .font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy)
                                    Text("Add recipes from URLs · shop by aisle")
                                        .font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium)).foregroundColor(.gray.opacity(0.4))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(Color.oceanTeal.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.oceanTeal.opacity(0.2), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            // Finance echo view
            if echo.name.lowercased().contains("finance") && !filteredMemories.isEmpty {
                Section {
                    FinanceEchoView(memories: filteredMemories)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            // Workout echo view
            if echo.name.lowercased().contains("workout") && !filteredMemories.isEmpty {
                Section {
                    WorkoutEchoView(memories: filteredMemories, detailMemory: Binding(
                        get: { nil },
                        set: { if let m = $0 { activeSheet = .detailMemory(m) } }
                    ))
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }

            // Empty state
            if filteredMemories.isEmpty {
                VStack(spacing: 12) {
                    Text(echo.emoji).font(.system(size: 44))
                    Text("No memories in \(echo.name)")
                        .font(.custom("DMSans-Medium", size: 18)).foregroundColor(.deepNavy)
                    Text("Drop a memory and say something about \(echo.name.lowercased()) — Sonar will sort it here automatically.")
                        .font(.custom("DMSans-Regular", size: 14)).foregroundColor(.gray)
                        .multilineTextAlignment(.center).padding(.horizontal, 20)
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 14)).foregroundColor(.oceanTeal)
                        Text("Tap the fin button to get started")
                            .font(.custom("DMSans-Medium", size: 14)).foregroundColor(.oceanTeal)
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 60)
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
            } else {
                ForEach(filteredMemories) { memory in
                    let expired = isExpired(memory)
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(memory.text)
                                .font(.custom("DMSans-Regular", size: 15))
                                .foregroundColor(expired ? .gray : .deepNavy)
                                .lineLimit(3)
                            HStack(spacing: 8) {
                                if let date = memory.detectedDate {
                                    if let endDate = memory.endDate {
                                        Text("\(date.formatted(.dateTime.month(.abbreviated).day().year())) – \(endDate.formatted(.dateTime.month(.abbreviated).day().year()))")
                                            .font(.custom("DMMono-Regular", size: 12))
                                            .foregroundColor(expired ? .gray.opacity(0.5) : .oceanTeal)
                                    } else {
                                        Text(date, format: .dateTime.month(.abbreviated).day().year())
                                            .font(.custom("DMMono-Regular", size: 12))
                                            .foregroundColor(expired ? .gray.opacity(0.5) : .oceanTeal)
                                    }
                                } else {
                                    Text(memory.createdAt, format: .dateTime.month(.abbreviated).day().year())
                                        .font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                                }
                                if memory.detectedDate != nil { Text("📅").font(.system(size: 11)) }
                                if memory.wasEdited {
                                    Text("edited").font(.custom("DMMono-Regular", size: 11)).foregroundColor(.seafoam)
                                }
                                if memory.locationName != nil {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 11)).foregroundColor(.coral)
                                }
                            }
                            if let url = memory.url, !url.isEmpty {
                                Button {
                                    if let link = URL(string: url) { UIApplication.shared.open(link) }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "link").font(.system(size: 10))
                                        Text("Open Link").font(.custom("DMSans-Medium", size: 11))
                                    }
                                    .foregroundColor(.oceanTeal)
                                }
                            }
                        }
                        Spacer()
                        Button { activeSheet = .editMemory(memory) } label: {
                            ZStack {
                                Circle().fill(Color.mist).frame(width: 40, height: 40)
                                Image(systemName: "pencil")
                                    .font(.system(size: 15, weight: .medium)).foregroundColor(.oceanTeal)
                            }
                        }
                    }
                    .padding(.vertical, 8).padding(.horizontal, 4)
                    .background(expired ? Color(red: 0.91, green: 0.94, blue: 0.97) : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .listRowBackground(expired ? Color(red: 0.91, green: 0.94, blue: 0.97) : Color.white)
                    .contentShape(Rectangle())
                    .onTapGesture { activeSheet = .detailMemory(memory) }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            let id = memory.id
                            let memoryPings = pings.filter { $0.memoryId == memory.id }
                            for ping in memoryPings {
                                NotificationService.shared.cancelPing(pingId: ping.id)
                                modelContext.delete(ping)
                                Task { await SupabaseSyncService.shared.deletePing(id: ping.id) }
                            }
                            modelContext.delete(memory)
                            SpotlightService.shared.removeMemory(id: id)
                            SupabaseSyncService.shared.scheduleDelete(id: id)
                        } label: { Label("Delete", systemImage: "trash") }
                        .tint(.red)
                        Button { activeSheet = .editMemory(memory) } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.oceanTeal)
                    }
                }

                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left").font(.system(size: 10))
                        Text("swipe to edit or delete").font(.custom("DMSans-Regular", size: 12))
                    }
                    .foregroundColor(.gray.opacity(0.5)).padding(.top, 8)
                    Spacer()
                }
                .listRowSeparator(.hidden).listRowBackground(Color.clear)
            }
        }
        .navigationTitle("\(echo.emoji) \(echo.name)")
        .listStyle(.plain)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .editMemory(let memory):
                MemoryEditView(memory: memory)
            case .detailMemory(let memory):
                MemoryDetailView(memory: memory)
            case .groceryMode:
                GroceryModeView(memories: filteredMemories)
            }
        }
    }
}

#Preview {
    NavigationStack { EchoDetailView(echo: Echo(name: "Workout", emoji: "💪")) }
        .modelContainer(for: [Memory.self, Echo.self, Ping.self], inMemory: true)
}
