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
    
    var filteredMemories: [Memory] {
        memories.filter { $0.echoId == echo.id }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        List {
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
                    MemoryRow(memory: memory)
                }
            }
        }
        .navigationTitle("\(echo.emoji) \(echo.name)")
        .listStyle(.plain)
    }
}

struct MemoryRow: View {
    let memory: Memory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(memory.text)
                .font(.custom("DMSans-Regular", size: 15))
                .foregroundColor(.deepNavy)
                .lineLimit(3)
            
            Text(memory.createdAt, style: .relative)
                .font(.custom("DMMono-Regular", size: 12))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        EchoDetailView(echo: Echo(name: "Dining", emoji: "🍜"))
    }
    .modelContainer(for: [Memory.self, Echo.self, Ping.self], inMemory: true)
}
