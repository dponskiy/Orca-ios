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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var sortMode: SortMode = .byMonth
    @State private var selectedEchoId: UUID?
    @State private var editingMemory: Memory?
    
    enum SortMode: String, CaseIterable {
        case byMonth = "By Month"
        case byEcho = "By Echo"
        case mostRecent = "Most Recent"
    }
    
    var activeEchos: [Echo] {
        echos.filter { echo in
            memories.contains { $0.echoId == echo.id }
        }
    }
    
    var filteredMemories: [Memory] {
        if let echoId = selectedEchoId {
            return memories.filter { $0.echoId == echoId }
        }
        return Array(memories)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 14, weight: .medium))
                        Text("Search")
                            .font(.custom("DMSans-Regular", size: 15))
                    }
                    .foregroundColor(.oceanTeal)
                }
                
                Spacer()
                
                Text("All Memories")
                    .font(.custom("DMSans-Medium", size: 17))
                    .foregroundColor(.deepNavy)
                
                Spacer()
                
                Text("\(filteredMemories.count)")
                    .font(.custom("DMMono-Regular", size: 15))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Sort mode pills
            HStack(spacing: 8) {
                ForEach(SortMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            sortMode = mode
                        }
                    } label: {
                        Text(mode.rawValue)
                            .font(.custom("DMSans-Medium", size: 14))
                            .foregroundColor(sortMode == mode ? .white : .deepNavy)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(sortMode == mode ? Color.deepNavy : Color.white)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(sortMode == mode ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            // Echo filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        selectedEchoId = nil
                    } label: {
                        Text("All")
                            .font(.custom("DMSans-Medium", size: 13))
                            .foregroundColor(selectedEchoId == nil ? .white : .deepNavy)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedEchoId == nil ? Color.oceanTeal : Color.white)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(selectedEchoId == nil ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    ForEach(activeEchos) { echo in
                        Button {
                            selectedEchoId = echo.id
                        } label: {
                            HStack(spacing: 4) {
                                Text(echo.emoji)
                                    .font(.system(size: 12))
                                Text(echo.name)
                                    .font(.custom("DMSans-Medium", size: 13))
                                    .foregroundColor(selectedEchoId == echo.id ? .white : .deepNavy)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedEchoId == echo.id ? Color.oceanTeal : Color.white)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(selectedEchoId == echo.id ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                            )
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
                case .byMonth:
                    ForEach(groupedByMonth, id: \.key) { month, monthMemories in
                        Section {
                            ForEach(monthMemories) { memory in
                                memoryRow(memory: memory)
                            }
                        } header: {
                            HStack {
                                Text(month)
                                    .font(.custom("DMSans-Medium", size: 15))
                                    .foregroundColor(.deepNavy)
                                Spacer()
                                Text("\(monthMemories.count)")
                                    .font(.custom("DMMono-Regular", size: 13))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                case .byEcho:
                    ForEach(groupedByEcho, id: \.key) { echoName, echoMemories in
                        Section {
                            ForEach(echoMemories) { memory in
                                memoryRow(memory: memory)
                            }
                        } header: {
                            let echo = echos.first { $0.name == echoName }
                            HStack {
                                Text("\(echo?.emoji ?? "📝") \(echoName)")
                                    .font(.custom("DMSans-Medium", size: 15))
                                    .foregroundColor(.deepNavy)
                                Spacer()
                                Text("\(echoMemories.count)")
                                    .font(.custom("DMMono-Regular", size: 13))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                case .mostRecent:
                    ForEach(filteredMemories) { memory in
                        memoryRow(memory: memory)
                    }
                }
            }
            .listStyle(.plain)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .sheet(item: $editingMemory) { memory in
            MemoryEditView(memory: memory)
        }
    }
    
    // MARK: - Memory Row
    private func memoryRow(memory: Memory) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if let echo = echos.first(where: { $0.id == memory.echoId }) {
                Text(echo.emoji)
                    .font(.system(size: 18))
                    .frame(width: 28)
                    .padding(.top, 2)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(memory.text)
                    .font(.custom("DMSans-Regular", size: 15))
                    .foregroundColor(.deepNavy)
                    .lineLimit(3)
                
                HStack(spacing: 8) {
                    Text(memory.createdAt, format: .dateTime.month(.abbreviated).day().year())
                        .font(.custom("DMMono-Regular", size: 12))
                        .foregroundColor(.gray)
                    
                    if let date = memory.detectedDate {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(.custom("DMMono-Regular", size: 12))
                            .foregroundColor(.coral)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                modelContext.delete(memory)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            
            Button {
                editingMemory = memory
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.oceanTeal)
        }
    }
    
    // MARK: - Grouping
    private var groupedByMonth: [(key: String, value: [Memory])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        
        let grouped = Dictionary(grouping: filteredMemories) { memory in
            formatter.string(from: memory.createdAt)
        }
        
        return grouped.sorted { pair1, pair2 in
            guard let d1 = pair1.value.first?.createdAt, let d2 = pair2.value.first?.createdAt else { return false }
            return d1 > d2
        }
    }
    
    private var groupedByEcho: [(key: String, value: [Memory])] {
        let grouped = Dictionary(grouping: filteredMemories) { memory in
            echos.first { $0.id == memory.echoId }?.name ?? "Unknown"
        }
        
        return grouped.sorted { $0.value.count > $1.value.count }
    }
}
