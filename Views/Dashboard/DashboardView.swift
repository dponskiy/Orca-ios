//
//  DashboardView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var memories: [Memory]
    @Query private var echos: [Echo]
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Greeting
                    Text(greeting)
                        .font(.custom("InstrumentSerif-Regular", size: 28))
                        .foregroundColor(.deepNavy)
                    
                    Text("\(memories.count) memories across \(echos.count) Echos")
                        .font(.custom("DMSans-Regular", size: 14))
                        .foregroundColor(.gray)
                    
                    // Echo bubbles
                    if echos.isEmpty {
                        emptyState
                    } else {
                        echoBubbleGrid
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color.pearl)
            .onAppear {
                seedDefaultEchos()
            }
        }
    }
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
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
    
    private var echoBubbleGrid: some View {
            let activeEchos = echos.filter { echo in
                memories.contains { $0.echoId == echo.id }
            }
            
            return ZStack {
                ForEach(Array(activeEchos.enumerated()), id: \.element.id) { index, echo in
                    let count = memories.filter { $0.echoId == echo.id }.count
                    let position = bubblePosition(index: index, total: activeEchos.count)
                    
                    NavigationLink(destination: EchoDetailView(echo: echo)) {
                        EchoBubbleView(
                            echo: echo,
                            count: count
                        )
                    }
                    .offset(x: position.x, y: position.y)
                }
            }
            .frame(height: CGFloat(max(1, (activeEchos.count + 1) / 2)) * 130)
            .frame(maxWidth: .infinity)
        }
        
        private func bubblePosition(index: Int, total: Int) -> CGPoint {
            // Staggered positions that feel organic, not grid-like
            let offsets: [CGPoint] = [
                CGPoint(x: -60, y: 0),
                CGPoint(x: 70, y: 20),
                CGPoint(x: -20, y: 110),
                CGPoint(x: 90, y: 90),
                CGPoint(x: -80, y: 210),
                CGPoint(x: 40, y: 190),
                CGPoint(x: -30, y: 310),
                CGPoint(x: 80, y: 290),
                CGPoint(x: -70, y: 400),
                CGPoint(x: 50, y: 380),
                CGPoint(x: -10, y: 490),
                CGPoint(x: 90, y: 470),
                CGPoint(x: -60, y: 580),
                CGPoint(x: 60, y: 560),
            ]
            
            if index < offsets.count {
                return offsets[index]
            }
            return CGPoint(x: index % 2 == 0 ? -40 : 60, y: CGFloat(index) * 90)
        }
    
    private func seedDefaultEchos() {
        guard echos.isEmpty else { return }
        for (index, item) in Echo.defaults.enumerated() {
            let echo = Echo(name: item.0, emoji: item.1, isDefault: true)
            echo.sortOrder = index
            modelContext.insert(echo)
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Memory.self, Echo.self, Ping.self], inMemory: true)
}
