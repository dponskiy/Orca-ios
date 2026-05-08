//
//  SonarAnimationView.swift
//  Orca
//
//  Created by David Piliponskiy on 4/30/26.
//

import SwiftUI
import SwiftUI
import Combine

struct SonarAnimationView: View {
    @State private var levels: [CGFloat] = Array(repeating: 0.3, count: 28)
    @State private var animating = false

    private let barCount = 28
    private let timer = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.deepNavy.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Waveform
                HStack(alignment: .center, spacing: 4) {
                    ForEach(0..<barCount, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor(for: i))
                            .frame(width: 5, height: barHeight(for: i))
                            .animation(
                                .easeInOut(duration: Double.random(in: 0.25...0.55)),
                                value: levels[i]
                            )
                    }
                }
                .frame(height: 80)
                .onReceive(timer) { _ in
                    guard animating else { return }
                    for i in 0..<barCount {
                        levels[i] = CGFloat.random(in: 0.15...1.0)
                    }
                }

                VStack(spacing: 6) {
                    Text("Sonar running")
                        .font(.custom("DMSans-Medium", size: 17))
                        .foregroundColor(.white)
                    Text("Routing your memory")
                        .font(.custom("DMSans-Regular", size: 14))
                        .foregroundColor(.oceanTeal)
                }

                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .onAppear { animating = true }
        .onDisappear { animating = false }
    }

    private func barColor(for index: Int) -> Color {
        // Mirror the recording overlay — coral in the middle, teal on the edges
        let center = barCount / 2
        let distance = abs(index - center)
        let ratio = Double(distance) / Double(center)
        return ratio < 0.4 ? Color.coral.opacity(0.85) : Color.oceanTeal.opacity(0.75 + Double(index % 3) * 0.08)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let base: CGFloat = 8
        let max: CGFloat = 72
        return base + (levels[index] * (max - base))
    }
}
