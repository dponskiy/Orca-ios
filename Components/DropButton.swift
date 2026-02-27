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
        .onTapGesture {
            action()
        }
        .onLongPressGesture(minimumDuration: 0.4) {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            onLongPress()
        }
    }
}

#Preview {
    DropButton(action: { }, onLongPress: { })
}
