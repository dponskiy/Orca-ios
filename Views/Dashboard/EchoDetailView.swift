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
    @State private var editingMemory: Memory?
    @Environment(\.modelContext) private var modelContext
    
    var filteredMemories: [Memory] {
        memories.filter { $0.echoId == echo.id }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        List {
            // Count header
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
                    Text("No memories yet")
                        .font(.custom("DMSans-Medium", size: 16))
                        .foregroundColor(.deepNavy)
                    Text("Drop a memory and Sonar will sort it here")
                        .font(.custom("DMSans-Regular", size: 14))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredMemories) { memory in
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(memory.text)
                                .font(.custom("DMSans-Regular", size: 15))
                                .foregroundColor(.deepNavy)
                                .lineLimit(3)
                            
                            HStack(spacing: 8) {
                                Text(memory.createdAt, format: .dateTime.month(.abbreviated).day().year())
                                    .font(.custom("DMMono-Regular", size: 12))
                                    .foregroundColor(.gray)
                                
                                if memory.detectedDate != nil {
                                    Text("📅")
                                        .font(.system(size: 11))
                                }
                                
                                if memory.wasEdited {
                                    Text("edited")
                                        .font(.custom("DMMono-Regular", size: 11))
                                        .foregroundColor(.seafoam)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            editingMemory = memory
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.mist)
                                    .frame(width: 40, height: 40)
                                Image(systemName: "pencil")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.oceanTeal)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        modelContext.delete(filteredMemories[index])
                    }
                }
            }
        }
        .navigationTitle("\(echo.emoji) \(echo.name)")
        .listStyle(.plain)
        .sheet(item: $editingMemory) { memory in
            MemoryEditView(memory: memory)
        }
    }
}

#Preview {
    NavigationStack {
        EchoDetailView(echo: Echo(name: "Dining", emoji: "🍜"))
    }
    .modelContainer(for: [Memory.self, Echo.self, Ping.self], inMemory: true)
}
