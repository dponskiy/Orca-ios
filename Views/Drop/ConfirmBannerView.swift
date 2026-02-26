//
//  ConfirmBannerView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI

struct ConfirmBannerView: View {
    let transcription: String
    let sonarResult: SonarResult?
    let echos: [Echo]
    let onDone: () -> Void
    let onUndo: () -> Void
    
    @State private var countdown: CGFloat = 1.0
    @State private var isPaused = false
    @State private var isEditing = false
    @State private var timerActive = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Countdown bar
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.oceanTeal)
                    .frame(width: geo.size.width * countdown, height: 3)
            }
            .frame(height: 3)
            
            VStack(spacing: 16) {
                // Header
                HStack {
                    HStack(spacing: 4) {
                        Text("Saved")
                            .font(.custom("DMSans-Medium", size: 16))
                            .foregroundColor(.deepNavy)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.oceanTeal)
                        
                        if isPaused {
                            Text("· editing")
                                .font(.custom("DMSans-Regular", size: 13))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: onUndo) {
                        Text("Undo")
                            .font(.custom("DMSans-Medium", size: 14))
                            .foregroundColor(.deepNavy)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    Button(action: onDone) {
                        Text("Done")
                            .font(.custom("DMSans-Medium", size: 14))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.oceanTeal)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                
                // Transcription
                VStack(alignment: .leading, spacing: 4) {
                    Text(transcription)
                        .font(.custom("DMSans-Regular", size: 15))
                        .foregroundColor(.deepNavy)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if !isEditing {
                        Text("Tap to edit")
                            .font(.custom("DMSans-Regular", size: 12))
                            .foregroundColor(.gray)
                    }
                }
                .padding(12)
                .background(Color.pearl)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onTapGesture {
                    isPaused = true
                    isEditing = true
                }
                
                // Echo chip + Date chip
                HStack(spacing: 8) {
                    // Echo chip
                    if let result = sonarResult {
                        HStack(spacing: 4) {
                            let echo = echos.first { $0.name == result.echoName }
                            Text(echo?.emoji ?? "📝")
                                .font(.system(size: 14))
                            Text(result.echoName)
                                .font(.custom("DMSans-Medium", size: 13))
                                .foregroundColor(.deepNavy)
                            
                            if result.echoConfidence < 0.7 {
                                Text("?")
                                    .font(.custom("DMSans-Bold", size: 11))
                                    .foregroundColor(.white)
                                    .frame(width: 16, height: 16)
                                    .background(Color.coral)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.mist)
                        .clipShape(Capsule())
                        .onTapGesture { isPaused = true }
                        
                        // Date chip
                        if let date = result.detectedDate {
                            HStack(spacing: 4) {
                                Text("📅")
                                    .font(.system(size: 14))
                                Text(date, format: .dateTime.month(.abbreviated).day())
                                    .font(.custom("DMSans-Medium", size: 13))
                                    .foregroundColor(.deepNavy)
                                
                                if (result.dateConfidence ?? 0) < 0.7 {
                                    Text("?")
                                        .font(.custom("DMSans-Bold", size: 11))
                                        .foregroundColor(.white)
                                        .frame(width: 16, height: 16)
                                        .background(Color.coral)
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.mist)
                            .clipShape(Capsule())
                            .onTapGesture { isPaused = true }
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding(16)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 16, y: -4)
        .padding(.horizontal, 8)
        .transition(.move(edge: .bottom))
        .onAppear {
            startCountdown()
        }
    }
    
    private func startCountdown() {
        withAnimation(.linear(duration: 5)) {
            countdown = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if !isPaused {
                onDone()
            }
        }
    }
}
