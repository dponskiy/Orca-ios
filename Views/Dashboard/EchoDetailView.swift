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
    @State private var editingMemory: Memory?
    @State private var detailMemory: Memory?
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService

    var filteredMemories: [Memory] {
        memories.filter { $0.echoId == echo.id }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Expired Helper
    private func isExpired(_ memory: Memory) -> Bool {
        let expiryDate = memory.endDate ?? memory.detectedDate
        guard let date = expiryDate, date < Date() else { return false }
        let memoryPings = pings.filter { $0.memoryId == memory.id }
        if memoryPings.contains(where: { $0.recurrence != .none }) { return false }
        let hasFuturePing = memoryPings.contains { $0.fireDate > Date() }
        return !hasFuturePing
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("\(filteredMemories.count) \(filteredMemories.count == 1 ? "memory" : "memories")")
                        .font(.custom("DMSans-Medium", size: 14))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if filteredMemories.isEmpty {
                VStack(spacing: 12) {
                    Text(echo.emoji).font(.system(size: 44))
                    Text("No memories in \(echo.name)")
                        .font(.custom("DMSans-Medium", size: 18))
                        .foregroundColor(.deepNavy)
                    Text("Drop a memory and say something about \(echo.name.lowercased()) — Sonar will sort it here automatically.")
                        .font(.custom("DMSans-Regular", size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.oceanTeal)
                        Text("Tap the fin button to get started")
                            .font(.custom("DMSans-Medium", size: 14))
                            .foregroundColor(.oceanTeal)
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
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
                                        .font(.custom("DMMono-Regular", size: 12))
                                        .foregroundColor(.gray)
                                }

                                if memory.detectedDate != nil {
                                    Text("📅").font(.system(size: 11))
                                }

                                if memory.wasEdited {
                                    Text("edited")
                                        .font(.custom("DMMono-Regular", size: 11))
                                        .foregroundColor(.seafoam)
                                }
                            }

                            if let url = memory.url, !url.isEmpty {
                                Button {
                                    if let link = URL(string: url) {
                                        UIApplication.shared.open(link)
                                    }
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

                        Button { editingMemory = memory } label: {
                            ZStack {
                                Circle().fill(Color.mist).frame(width: 40, height: 40)
                                Image(systemName: "pencil")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.oceanTeal)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .background(expired ? Color(red: 0.91, green: 0.94, blue: 0.97) : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .listRowBackground(expired ? Color(red: 0.91, green: 0.94, blue: 0.97) : Color.white)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if memory.hasChecklist || memory.text.count > 100 {
                            detailMemory = memory
                        } else {
                            editingMemory = memory
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            let id = memory.id
                            modelContext.delete(memory)
                            SpotlightService.shared.removeMemory(id: memory.id)
                            Task { await SupabaseSyncService.shared.deleteMemory(id: id) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                        Button { editingMemory = memory } label: {
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
                    .foregroundColor(.gray.opacity(0.5))
                    .padding(.top, 8)
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("\(echo.emoji) \(echo.name)")
        .listStyle(.plain)
        .sheet(item: $editingMemory) { memory in
            MemoryEditView(memory: memory)
        }
        .sheet(item: $detailMemory) { memory in
            MemoryDetailView(memory: memory)
        }
    }
}

#Preview {
    NavigationStack {
        EchoDetailView(echo: Echo(name: "Dining", emoji: "🍜"))
    }
    .modelContainer(for: [Memory.self, Echo.self, Ping.self], inMemory: true)
}
