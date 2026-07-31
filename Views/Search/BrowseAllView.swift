//
//  BrowseAllView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI
import SwiftData

struct BrowseAllView: View {
    @Query(sort: \Memory.createdAt, order: .reverse) private var memories: [Memory]
    @Query private var echos: [Echo]
    @Query private var pings: [Ping]
    @Query(sort: \Person.name) private var persons: [Person]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService

    @State private var sortMode: SortMode = .mostRecent
    @State private var selectedEchoId: UUID?
    @State private var selectedPersonId: UUID?
    @State private var editingMemory: Memory?
    @State private var detailMemory: Memory?

    private let calendar = Calendar.current

    enum SortMode: String, CaseIterable {
        case mostRecent = "Most Recent"
        case byMonth = "By Month"
        case byEcho = "By Echo"
        case byPerson = "By Person"
    }

    var activeEchos: [Echo] {
        echos.filter { echo in !echo.isSystemEcho && memories.contains { $0.echoId == echo.id } }
    }

    var filteredMemories: [Memory] {
        var result = Array(memories)

        if let echoId = selectedEchoId {
            result = result.filter { $0.echoId == echoId }
        }

        if let personId = selectedPersonId,
           let person = persons.first(where: { $0.id == personId }) {
            let firstName = person.name.split(separator: " ").first.map(String.init) ?? person.name
            result = result.filter { $0.text.localizedCaseInsensitiveContains(firstName) }
        }

        return result.sorted { $0.createdAt > $1.createdAt }
    }

    private func isExpired(_ memory: Memory) -> Bool {
        let expiryDate = memory.endDate ?? memory.detectedDate
        guard let date = expiryDate, date < Date() else { return false }
        // Pre-extract ping properties to avoid SwiftData detachment crash
        let memoryPingData = pings
            .filter { $0.memoryId == memory.id }
            .map { (recurrence: $0.recurrence, fireDate: $0.fireDate) }
        if memoryPingData.contains(where: { $0.recurrence != .none }) { return false }
        return !memoryPingData.contains { $0.fireDate > Date() }
    }

    private func memoriesFor(person: Person) -> [Memory] {
        let firstName = person.name.split(separator: " ").first.map(String.init) ?? person.name
        return filteredMemories.filter { $0.text.localizedCaseInsensitiveContains(firstName) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left").font(.system(size: 14, weight: .medium))
                        Text("Search").font(.custom("DMSans-Regular", size: 15))
                    }
                    .foregroundColor(.oceanTeal)
                }
                Spacer()
                Text("All Memories")
                    .font(.custom("DMSans-Medium", size: 17)).foregroundColor(.deepNavy)
                Spacer()
                Text("\(filteredMemories.count)")
                    .font(.custom("DMMono-Regular", size: 15)).foregroundColor(.gray)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)

            // Sort mode pills — Most Recent first
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SortMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) { sortMode = mode }
                        } label: {
                            Text(mode.rawValue)
                                .font(.custom("DMSans-Medium", size: 14))
                                .foregroundColor(sortMode == mode ? .white : .deepNavy)
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .background(sortMode == mode ? Color.deepNavy : Color.white)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(sortMode == mode ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 8)

            // Filter pills — Echos + People
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        selectedEchoId = nil
                        selectedPersonId = nil
                    } label: {
                        Text("All")
                            .font(.custom("DMSans-Medium", size: 13))
                            .foregroundColor(selectedEchoId == nil && selectedPersonId == nil ? .white : .deepNavy)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(selectedEchoId == nil && selectedPersonId == nil ? Color.oceanTeal : Color.white)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    }

                    ForEach(activeEchos) { echo in
                        Button { selectedEchoId = echo.id; selectedPersonId = nil } label: {
                            HStack(spacing: 4) {
                                Text(echo.emoji).font(.system(size: 12))
                                Text(echo.name)
                                    .font(.custom("DMSans-Medium", size: 13))
                                    .foregroundColor(selectedEchoId == echo.id ? .white : .deepNavy)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(selectedEchoId == echo.id ? Color.oceanTeal : Color.white)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        }
                    }

                    ForEach(persons.filter { person in
                        let firstName = person.name.split(separator: " ").first.map(String.init) ?? person.name
                        return memories.contains { $0.text.localizedCaseInsensitiveContains(firstName) }
                    }) { person in
                        Button { selectedPersonId = person.id; selectedEchoId = nil } label: {
                            HStack(spacing: 4) {
                                let colors = personColors(for: person.colorIndex)
                                ZStack {
                                    Circle().fill(colors.0).frame(width: 16, height: 16)
                                    Text(String(person.name.prefix(1)))
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(colors.1)
                                }
                                Text(person.name.split(separator: " ").first.map(String.init) ?? person.name)
                                    .font(.custom("DMSans-Medium", size: 13))
                                    .foregroundColor(selectedPersonId == person.id ? .white : .deepNavy)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(selectedPersonId == person.id ? Color.oceanTeal : Color.white)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 8)

            Divider()

            // Memory list
            List {
                switch sortMode {
                case .mostRecent:
                    ForEach(filteredMemories) { memory in memoryRow(memory: memory) }

                case .byMonth:
                    ForEach(groupedByMonth, id: \.key) { month, monthMemories in
                        Section {
                            ForEach(monthMemories) { memory in memoryRow(memory: memory) }
                        } header: {
                            HStack {
                                Text(month).font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy)
                                Spacer()
                                Text("\(monthMemories.count)").font(.custom("DMMono-Regular", size: 13)).foregroundColor(.gray)
                            }
                        }
                    }

                case .byEcho:
                    ForEach(groupedByEcho, id: \.key) { echoName, echoMemories in
                        Section {
                            ForEach(echoMemories) { memory in memoryRow(memory: memory) }
                        } header: {
                            let echo = echos.first { $0.name == echoName }
                            HStack {
                                Text("\(echo?.emoji ?? "📝") \(echoName)").font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy)
                                Spacer()
                                Text("\(echoMemories.count)").font(.custom("DMMono-Regular", size: 13)).foregroundColor(.gray)
                            }
                        }
                    }

                case .byPerson:
                    ForEach(groupedByPerson, id: \.key) { personName, personMemories in
                        Section {
                            ForEach(personMemories) { memory in memoryRow(memory: memory) }
                        } header: {
                            HStack {
                                Text("👤 \(personName)").font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy)
                                Spacer()
                                Text("\(personMemories.count)").font(.custom("DMMono-Regular", size: 13)).foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .sheet(item: $editingMemory) { MemoryEditView(memory: $0) }
        .sheet(item: $detailMemory) { MemoryDetailView(memory: $0) }
    }

    // MARK: - Memory Row

    private func memoryRow(memory: Memory) -> some View {
        let expired = isExpired(memory)
        let expiredBg = Color(red: 0.91, green: 0.94, blue: 0.97)

        return HStack(alignment: .top, spacing: 12) {
            if let echo = echos.first(where: { $0.id == memory.echoId }) {
                Text(echo.emoji).font(.system(size: 18)).frame(width: 28).padding(.top, 2).opacity(expired ? 0.4 : 1.0)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(memory.text)
                    .font(.custom("DMSans-Regular", size: 15))
                    .foregroundColor(expired ? .gray : .deepNavy).lineLimit(3)
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
                    if memory.wasEdited {
                        Text("edited").font(.custom("DMMono-Regular", size: 11)).foregroundColor(.gray)
                    }
                    if memory.locationName != nil {
                        Image(systemName: "mappin.circle.fill").font(.system(size: 11)).foregroundColor(.coral)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 8).padding(.horizontal, 8)
        .background(expired ? expiredBg : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .listRowBackground(expired ? expiredBg : Color.white)
        .contentShape(Rectangle())
        .onTapGesture { detailMemory = memory }
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
            Button { editingMemory = memory } label: { Label("Edit", systemImage: "pencil") }
                .tint(.oceanTeal)
        }
    }

    // MARK: - Grouping

    private var groupedByMonth: [(key: String, value: [Memory])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        let grouped = Dictionary(grouping: filteredMemories) { memory in
            formatter.string(from: memory.detectedDate ?? memory.updatedAt)
        }
        return grouped.sorted { pair1, pair2 in
            let d1 = pair1.value.first.flatMap { $0.detectedDate ?? $0.updatedAt } ?? Date.distantPast
            let d2 = pair2.value.first.flatMap { $0.detectedDate ?? $0.updatedAt } ?? Date.distantPast
            return d1 > d2
        }
    }

    private var groupedByEcho: [(key: String, value: [Memory])] {
        let grouped = Dictionary(grouping: filteredMemories) { memory in
            echos.first { $0.id == memory.echoId }?.name ?? "Unknown"
        }
        return grouped.sorted { $0.value.count > $1.value.count }
    }

    private var groupedByPerson: [(key: String, value: [Memory])] {
        var seen = Set<String>()
        var result: [(key: String, value: [Memory])] = []
        for person in persons {
            let firstName = person.name.split(separator: " ").first.map(String.init) ?? person.name
            guard !seen.contains(firstName.lowercased()) else { continue }
            seen.insert(firstName.lowercased())
            let personMemories = filteredMemories.filter {
                $0.text.localizedCaseInsensitiveContains(firstName)
            }
            if !personMemories.isEmpty {
                result.append((key: person.name, value: personMemories))
            }
        }
        return result.sorted { $0.value.count > $1.value.count }
    }

    // MARK: - Color Helper

    private func personColors(for index: Int) -> (Color, Color) {
        let palette: [(Color, Color)] = [
            (Color(red: 0.878, green: 0.961, blue: 0.933), Color(red: 0.059, green: 0.431, blue: 0.337)),
            (Color(red: 0.980, green: 0.933, blue: 0.851), Color(red: 0.522, green: 0.310, blue: 0.043)),
            (Color(red: 0.902, green: 0.945, blue: 0.984), Color(red: 0.094, green: 0.373, blue: 0.647)),
            (Color(red: 0.980, green: 0.925, blue: 0.906), Color(red: 0.600, green: 0.235, blue: 0.110)),
            (Color(red: 0.933, green: 0.929, blue: 0.996), Color(red: 0.325, green: 0.290, blue: 0.718)),
        ]
        return palette[index % palette.count]
    }
}
