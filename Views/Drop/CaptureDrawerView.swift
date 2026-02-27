//
//  CaptureDrawerView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI

enum CaptureMode {
    case voice, screenshot, typed
}

struct CaptureDrawerView: View {
    let onSelect: (CaptureMode) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
            
            Text("Capture a memory")
                .font(.custom("DMSans-Medium", size: 16))
                .foregroundColor(.deepNavy)
                .padding(.top, 16)
            
            HStack(spacing: 32) {
                captureOption(icon: "mic.fill", label: "Voice", mode: .voice)
                captureOption(icon: "camera.fill", label: "Screenshot", mode: .screenshot)
                captureOption(icon: "keyboard", label: "Type", mode: .typed)
            }
            .padding(.vertical, 24)
            
            Button("Cancel") {
                onCancel()
            }
            .font(.custom("DMSans-Regular", size: 14))
            .foregroundColor(.gray)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 16, y: -4)
        .padding(.horizontal, 8)
    }
    
    private func captureOption(icon: String, label: String, mode: CaptureMode) -> some View {
        Button {
            onSelect(mode)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.mist)
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(.oceanTeal)
                }
                Text(label)
                    .font(.custom("DMSans-Regular", size: 13))
                    .foregroundColor(.deepNavy)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.3).ignoresSafeArea()
        VStack {
            Spacer()
            CaptureDrawerView(onSelect: { _ in }, onCancel: { })
        }
    }
}
