//
//  SearchView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @Binding var isPresented: Bool
    @Query(sort: \Memory.createdAt, order: .reverse) private var memories: [Memory]
    @Query private var echos: [Echo]
    @Query private var thoughtTabs: [ThoughtTab]
    
    @State private var editingMemory: Memory?
    @State private var detailMemory: Memory?
    @State private var searchText = ""
    @State private var showBrowseAll = false
    @FocusState private var isFocused: Bool
    @State private var audioService = AudioService()
    @State private var isListening = false
    
    var results: [Memory] {
        guard !searchText.isEmpty else { return [] }
        let lower = searchText.lowercased()
        return memories.filter { memory in
            memory.text.lowercased().contains(lower) ||
            memory.tags.contains { $0.lowercased().contains(lower) } ||
            echos.first { $0.id == memory.echoId }?.name.lowercased().contains(lower) ?? false
        }
    }
    
    var recentMemories: [Memory] {
        Array(memories.prefix(5))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.deepNavy)
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15))
                            .foregroundColor(.gray)
                        
                        TextField("Ask about your memories...", text: $searchText)
                            .font(.custom("DMSans-Regular", size: 16))
                            .focused($isFocused)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.pearl)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Button {
                        if isListening {
                            audioService.stopRecording()
                            searchText = audioService.transcription
                            isListening = false
                        } else {
                            isListening = true
                            audioService.startRecording()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                if isListening {
                                    audioService.stopRecording()
                                    searchText = audioService.transcription
                                    isListening = false
                                }
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(isListening ? Color.coral : Color.deepNavy)
                                .frame(width: 36, height: 36)
                            Image(systemName: isListening ? "stop.fill" : "mic.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                        .animation(.easeInOut(duration: 0.2), value: isListening)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                if !searchText.isEmpty {
                    searchResultsList
                } else {
                    defaultView
                }
                
                Spacer()
            }
            .background(Color.white)
            .sheet(item: $editingMemory) { memory in
                MemoryEditView(memory: memory)
            }
            .sheet(item: $detailMemory) { memory in
                MemoryDetailView(memory: memory)
            }
            .onAppear {
                isFocused = true
                AnalyticsService.shared.trackSearchOpened()
            }
            .onChange(of: searchText) { _, newValue in
                if !newValue.isEmpty {
                    AnalyticsService.shared.trackSearchPerformed(
                        query: newValue,
                        resultCount: results.count,
                        usedVoice: false
                    )
                }
            }
            .navigationDestination(isPresented: $showBrowseAll) {
                BrowseAllView()
            }
        }
    }
    
    // MARK: - Default View

    private var defaultView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Surface all memories card
                Button {
                    showBrowseAll = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.mist)
                                .frame(width: 44, height: 44)
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.oceanTeal)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Surface all memories")
                                .font(.custom("DMSans-Medium", size: 16))
                                .foregroundColor(.deepNavy)
                            Text("\(memories.count) memories · Browse by date or Echo")
                                .font(.custom("DMSans-Regular", size: 13))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(14)
                    .background(Color.pearl)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Recent
                if !recentMemories.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("RECENT")
                            .font(.custom("DMSans-Medium", size: 13))
                            .foregroundColor(.oceanTeal)
                            .tracking(1)
                            .padding(.horizontal, 16)
                        
                        VStack(spacing: 0) {
                            ForEach(recentMemories) { memory in
                                HStack(spacing: 12) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                    
                                    Text(memory.text)
                                        .font(.custom("DMSans-Regular", size: 15))
                                        .foregroundColor(.deepNavy)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                                .onTapGesture { detailMemory = memory }
                                
                                if memory.id != recentMemories.last?.id {
                                    Divider()
                                        .padding(.leading, 44)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Search Results

    private var searchResultsList: some View {
        Group {
            if results.isEmpty {
                VStack(spacing: 12) {
                    Spacer().frame(height: 60)
                    Text("No results for \"\(searchText)\"")
                        .font(.custom("DMSans-Medium", size: 16))
                        .foregroundColor(.deepNavy)
                    Text("Try a different search term")
                        .font(.custom("DMSans-Regular", size: 14))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Text("\(results.count) \(results.count == 1 ? "result" : "results")")
                        .font(.custom("DMSans-Medium", size: 13))
                        .foregroundColor(.gray)
                        .listRowSeparator(.hidden)
                    
                    ForEach(results) { memory in
                        searchResultRow(memory: memory)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    private func searchResultRow(memory: Memory) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(memory.text)
                    .font(.custom("DMSans-Regular", size: 15))
                    .foregroundColor(.deepNavy)
                    .lineLimit(3)
                
                HStack(spacing: 8) {
                    if let echo = echos.first(where: { $0.id == memory.echoId }) {
                        // Thoughts entries show tab name
                        if echo.name == "Thoughts", let tabId = memory.thoughtTabId,
                           let tab = thoughtTabs.first(where: { $0.id == tabId }) {
                            HStack(spacing: 3) {
                                Text("💭")
                                    .font(.system(size: 11))
                                Text("Thoughts · \(tab.name)")
                                    .font(.custom("DMSans-Medium", size: 12))
                                    .foregroundColor(.deepNavy)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.oceanTeal.opacity(0.08))
                            .clipShape(Capsule())
                        } else {
                            HStack(spacing: 3) {
                                Text(echo.emoji)
                                    .font(.system(size: 11))
                                Text(echo.name)
                                    .font(.custom("DMSans-Medium", size: 12))
                                    .foregroundColor(.deepNavy)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.mist)
                            .clipShape(Capsule())
                        }
                    }
                    
                    Text(memory.createdAt, format: .dateTime.month(.abbreviated).day().year())
                        .font(.custom("DMMono-Regular", size: 11))
                        .foregroundColor(.gray)
                    
                    if let date = memory.detectedDate {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(.custom("DMMono-Regular", size: 11))
                            .foregroundColor(.coral)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { detailMemory = memory }
    }
}

#Preview {
    SearchView(isPresented: .constant(true))
        .modelContainer(for: [Memory.self, Echo.self, Ping.self], inMemory: true)
}
