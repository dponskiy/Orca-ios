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
            // Pulse ring
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

            // Sonar ping + mic
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
                    .frame(width: 46, height: 46)
                    .offset(y: -2)

                // Mid ring
                Circle()
                    .stroke(Color.white.opacity(0.55), lineWidth: 1.5)
                    .frame(width: 30, height: 30)
                    .offset(y: -2)

                // Inner ring
                Circle()
                    .stroke(Color.white.opacity(0.95), lineWidth: 2.2)
                    .frame(width: 14, height: 14)
                    .offset(y: -2)

                // Center dot
                Circle()
                    .fill(Color.white)
                    .frame(width: 7, height: 7)
                    .offset(y: -2)

                // Mic stem vertical line
                Rectangle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 2, height: 10)
                    .clipShape(Capsule())
                    .offset(y: 12)

                // Mic base horizontal line
                Rectangle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 14, height: 2)
                    .clipShape(Capsule())
                    .offset(y: 17)
            }
        }
        .offset(y: dragOffset)
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    if value.translation.height < 0 {
                        dragOffset = value.translation.height * 0.3
                    }
                }
                .onEnded { value in
                    withAnimation(.spring(duration: 0.4, bounce: 0.5)) {
                        dragOffset = 0
                    }
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
