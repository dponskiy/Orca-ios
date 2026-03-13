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
    
    private var isEmpty: Bool { count == 0 }
    
    private var bubbleSize: CGFloat {
        if isEmpty { return 32 } // smaller than min active size
        guard totalMemories > 0 else { return 52 }
        let proportion = Double(count) / Double(totalMemories)
        let minSize: CGFloat = 44
        let maxSize: CGFloat = 80
        let scaled = min(proportion * 3, 1.0)
        return minSize + (maxSize - minSize) * CGFloat(scaled)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(isEmpty ? Color.gray.opacity(0.08) : Color.oceanTeal.opacity(0.18))
                        .frame(width: bubbleSize, height: bubbleSize)
                    
                    Text(echo.emoji)
                        .font(.system(size: bubbleSize * 0.42))
                        .opacity(isEmpty ? 0.4 : 1.0)
                }
                
                Text(echo.name)
                    .font(.custom("DMSans-Medium", size: isEmpty ? 11 : 13))
                    .foregroundColor(isEmpty ? .gray.opacity(0.5) : .deepNavy)
                
                if !isEmpty {
                    Text("\(count)")
                        .font(.custom("DMMono-Regular", size: 11))
                        .foregroundColor(.gray)
                }
            }
            .offset(y: floatOffset)
            .onAppear {
                guard !isEmpty else { return }
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
