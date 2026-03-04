//
//  DropButton.swift
//  Orca
//
//  Created by David Piliponskiy on 2/24/26.
//

import SwiftUI

struct DropButton: View {
    var action: () -> Void
    var onLongPress: () -> Void
    @State private var isPulsing = true
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Pulse rings
            if isPulsing {
                Circle()
                    .stroke(Color.oceanTeal.opacity(0.3), lineWidth: 2)
                    .frame(width: 72, height: 72)
                    .scaleEffect(isPulsing ? 1.4 : 1.0)
                    .opacity(isPulsing ? 0 : 0.5)
                    .animation(
                        .easeOut(duration: 2.5).repeatForever(autoreverses: false),
                        value: isPulsing
                    )
            }
            
            // Main button
            Circle()
                .fill(Color.oceanTeal)
                .frame(width: 56, height: 56)
                .shadow(color: .oceanTeal.opacity(0.4), radius: 8, y: 4)
            
            // Fin icon
            FinIcon()
                .fill(.white)
                .frame(width: 24, height: 28)
        }
        .offset(y: dragOffset)
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    if value.translation.height < 0 {
                        // Only allow upward drag, with resistance
                        dragOffset = value.translation.height * 0.3
                    }
                }
                .onEnded { value in
                    withAnimation(.spring(duration: 0.4, bounce: 0.5)) {
                        dragOffset = 0
                    }
                    // Trigger if swiped up more than 30pts
                    if value.translation.height < -30 {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        onLongPress()
                    }
                }
        )
        .simultaneousGesture(
            TapGesture().onEnded {
                action()
            }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                onLongPress()
            }
        )
        .onAppear { isPulsing = true }
    }
}

#Preview {
    DropButton(action: { }, onLongPress: { })
}
