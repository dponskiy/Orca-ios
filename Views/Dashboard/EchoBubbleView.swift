//
//  EchoBubbleView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI

struct EchoBubbleView: View {
    let echo: Echo
    let count: Int
    var pendingCount: Int = 0
    var totalMemories: Int = 1
    
    @State private var floatOffset: CGFloat = 0
    
    private var bubbleSize: CGFloat {
        guard totalMemories > 0 else { return 64 }
        let proportion = Double(count) / Double(totalMemories)
        let minSize: CGFloat = 56
        let maxSize: CGFloat = 100
        let scaled = min(proportion * 3, 1.0)
        return minSize + (maxSize - minSize) * CGFloat(scaled)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color.oceanTeal.opacity(0.18))
                        .frame(width: bubbleSize, height: bubbleSize)
                    
                    Text(echo.emoji)
                        .font(.system(size: bubbleSize * 0.42))
                }
                
                Text(echo.name)
                    .font(.custom("DMSans-Medium", size: 13))
                    .foregroundColor(.deepNavy)
                
                Text("\(count)")
                    .font(.custom("DMMono-Regular", size: 11))
                    .foregroundColor(.gray)
            }
            .offset(y: floatOffset)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    floatOffset = -4
                }
            }
            
            if pendingCount > 0 {
                ZStack {
                    Circle()
                        .fill(Color.coral)
                        .frame(width: 20, height: 20)
                    Text("\(pendingCount)")
                        .font(.custom("DMSans-Medium", size: 11))
                        .foregroundColor(.white)
                }
                .offset(x: 4, y: -2)
            }
        }
    }
}

#Preview {
    HStack {
        EchoBubbleView(echo: Echo(name: "Dining", emoji: "🍜"), count: 3, pendingCount: 0, totalMemories: 10)
        EchoBubbleView(echo: Echo(name: "Work", emoji: "💼"), count: 8, pendingCount: 2, totalMemories: 10)
    }
}
