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
            switch count {
            case 1...3: return 68
            case 4...8: return 76
            case 9...15: return 88
            case 16...30: return 96
            default: return 104
            }
        }
    }

#Preview {
    EchoBubbleView(
        echo: Echo(name: "Dining", emoji: "🍜"),
        count: 5
    )
}
