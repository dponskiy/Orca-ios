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
    var totalMemories: Int = 1
    @State private var floating = false
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.mist)
                    .frame(width: bubbleSize, height: bubbleSize)
                
                Text(echo.emoji)
                    .font(.system(size: bubbleSize * 0.4))
            }
            .offset(y: floating ? -3 : 3)
            .animation(
                .easeInOut(duration: 3)
                .repeatForever(autoreverses: true)
                .delay(Double.random(in: 0...1)),
                value: floating
            )
            .onAppear { floating = true }
            
            Text(echo.name)
                .font(.custom("DMSans-Medium", size: 13))
                .foregroundColor(.deepNavy)
            
            Text("\(count)")
                .font(.custom("DMMono-Regular", size: 11))
                .foregroundColor(.gray)
        }
    }
    
    private var bubbleSize: CGFloat {
        let minSize: CGFloat = 56
        let maxSize: CGFloat = 100
        
        guard totalMemories > 0 else { return minSize }
        
        let proportion = Double(count) / Double(totalMemories)
        
        return minSize + (maxSize - minSize) * CGFloat(min(proportion * 3, 1.0))
    }
}

#Preview {
    HStack {
        EchoBubbleView(echo: Echo(name: "Gifts", emoji: "🎁"), count: 2, totalMemories: 20)
        EchoBubbleView(echo: Echo(name: "Work", emoji: "💼"), count: 10, totalMemories: 20)
        EchoBubbleView(echo: Echo(name: "Dining", emoji: "🍜"), count: 18, totalMemories: 20)
    }
}
