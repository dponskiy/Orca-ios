
//  OnboardingFlow.swift
//  Orca
//
//  Created by David Piliponskiy on 3/3/26.
//

import SwiftUI
import SwiftData
import AVFoundation
import UserNotifications

struct OnboardingFlow: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var step = 0
    @State private var firstMemoryText = ""
    
    var body: some View {
        ZStack(alignment: .bottom) {
            switch step {
            case 0: SplashScreen(onNext: {
                AnalyticsService.shared.trackOnboardingStepViewed(step: 1, name: "What Is Orca")
                step = 1
            })
            case 1: WhatIsOrcaScreen(onNext: {
                AnalyticsService.shared.trackOnboardingStepViewed(step: 2, name: "Thought Bubbles")
                step = 2
            })
            case 2: ThoughtBubblesScreen(onNext: {
                AnalyticsService.shared.trackOnboardingStepViewed(step: 3, name: "First Drop")
                step = 3
            })
            case 3: FirstDropScreen(
                onNext: {
                    AnalyticsService.shared.trackOnboardingStepViewed(step: 4, name: "Notifications")
                    step = 4
                },
                onMemorySaved: { text in firstMemoryText = text }
            )
            case 4: NotificationsScreen(onNext: {
                AnalyticsService.shared.trackOnboardingStepViewed(step: 5, name: "All Set")
                step = 5
            }, memoryText: firstMemoryText)
            case 5: AllSetScreen(onDone: {
                AnalyticsService.shared.trackOnboardingCompleted(droppedFirstMemory: !firstMemoryText.isEmpty)
                hasCompletedOnboarding = true
            })
            default: AllSetScreen(onDone: {
                hasCompletedOnboarding = true
            })
            }
            
            if step > 0 && step < 5 {
                            HStack {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.4)) {
                                        step -= 1
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 12, weight: .medium))
                                        Text("Back")
                                            .font(.custom("DMSans-Regular", size: 14))
                                    }
                                    .foregroundColor(.white.opacity(0.35))
                                }
                                
                                Spacer()
                                
                                Button {
                                    AnalyticsService.shared.trackOnboardingSkipped(atStep: step)
                                    hasCompletedOnboarding = true
                                } label: {
                                    Text("Skip")
                                        .font(.custom("DMSans-Regular", size: 14))
                                        .foregroundColor(.white.opacity(0.35))
                                }
                            }
                            .padding(.horizontal, 28)
                            .padding(.bottom, 16)
                        }
                    }
                    .animation(.easeInOut(duration: 0.4), value: step)
                    .onAppear {
                        AnalyticsService.shared.trackOnboardingStarted()
                        AnalyticsService.shared.trackOnboardingStepViewed(step: 0, name: "Splash")
                    }
                }
    
    // MARK: - Splash
    
    struct SplashScreen: View {
        let onNext: () -> Void
        @State private var logoScale: CGFloat = 0.6
        @State private var logoOpacity: CGFloat = 0
        @State private var textOpacity: CGFloat = 0
        @State private var buttonOpacity: CGFloat = 0
        
        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "0B1D33"), Color(hex: "1A3A5C")],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.oceanTeal, .seafoam],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 96, height: 96)
                                .shadow(color: .oceanTeal.opacity(0.4), radius: 24, y: 8)
                            FinIcon()
                                .fill(.white)
                                .frame(width: 48, height: 56)
                        }
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        
                        VStack(spacing: 6) {
                            Text("Orca")
                                .font(.custom("DMSans-Medium", size: 36))
                                .foregroundColor(.white)
                            Text("Everything you forget.")
                                .font(.custom("DMSans-Regular", size: 17))
                                .foregroundColor(.white.opacity(0.55))
                            Text("Finally remembered.")
                                .font(.custom("DMSans-Medium", size: 17))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .opacity(textOpacity)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 14) {
                        Button {
                            onNext()
                        } label: {
                            Text("Get Started")
                                .font(.custom("DMSans-Medium", size: 17))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [.oceanTeal, .seafoam],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .oceanTeal.opacity(0.4), radius: 12, y: 4)
                        }
                        Text("Takes less than 2 minutes")
                            .font(.custom("DMSans-Regular", size: 13))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 52)
                    .opacity(buttonOpacity)
                }
            }
            .onAppear {
                withAnimation(.spring(duration: 0.7, bounce: 0.4)) {
                    logoScale = 1.0
                    logoOpacity = 1.0
                }
                withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                    textOpacity = 1.0
                }
                withAnimation(.easeOut(duration: 0.5).delay(0.7)) {
                    buttonOpacity = 1.0
                }
            }
        }
    }
    
    // MARK: - What Is Orca
    
    struct WhatIsOrcaScreen: View {
        let onNext: () -> Void
        @State private var itemsVisible = false
        
        let features: [(String, String, String)] = [
            ("mic.fill", "Drop it in seconds", "Voice, text, or screenshot — Orca captures anything in under 5 seconds."),
            ("sparkles", "Sonar sorts it", "Orca reads what you said and files it in the right place automatically."),
            ("bell.fill", "Pings bring it back", "Set it and forget it. Orca reminds you exactly when it matters."),
        ]
        
        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "0B1D33"), Color(hex: "1A3A5C")],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer().frame(height: 72)
                    
                    VStack(spacing: 6) {
                        Text("The gap between thinking it")
                            .font(.custom("DMSans-Regular", size: 24))
                            .foregroundColor(.white)
                        Text("and remembering it.")
                            .font(.custom("DMSans-Regular", size: 24))
                            .foregroundColor(.white)
                        Text("That's where Orca lives.")
                            .font(.custom("DMSans-Medium", size: 24))
                            .foregroundColor(.oceanTeal)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 48)
                    
                    VStack(spacing: 28) {
                        ForEach(features.indices, id: \.self) { i in
                            let f = features[i]
                            HStack(alignment: .center, spacing: 18) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.white.opacity(0.1))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: f.0)
                                        .font(.system(size: 20))
                                        .foregroundColor(.oceanTeal)
                                }
                                .frame(width: 48, height: 48)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(f.1)
                                        .font(.custom("DMSans-Medium", size: 17))
                                        .foregroundColor(.white)
                                    Text(f.2)
                                        .font(.custom("DMSans-Regular", size: 14))
                                        .foregroundColor(.white.opacity(0.5))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 28)
                            .opacity(itemsVisible ? 1 : 0)
                            .offset(y: itemsVisible ? 0 : 20)
                            .animation(.easeOut(duration: 0.4).delay(Double(i) * 0.15), value: itemsVisible)
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        onNext()
                    } label: {
                        Text("See it in action")
                            .font(.custom("DMSans-Medium", size: 17))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.oceanTeal, .seafoam],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .oceanTeal.opacity(0.4), radius: 12, y: 4)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 52)
                }
            }
            .onAppear {
                withAnimation { itemsVisible = true }
            }
        }
    }
    
    // MARK: - Thought Bubbles
    
    struct ThoughtBubblesScreen: View {
        let onNext: () -> Void
        
        @State private var visibleCount = 0
        @State private var titleVisible = false
        
        let bubbles: [(String, String)] = [
            ("🎂", "Mom's birthday August 15"),
            ("📶", "WiFi: BlueMountain2024"),
            ("✈️", "London Arcade Bar: NQ64 Arcade Bar"),
            ("🍳", "NYT recipe — paste URL to import"),
            ("🐾", "Dog heartworm pill every 1st"),
            ("🍽️", "Carbone — try the lamb chops"),
            ("👕", "Tux Size 40R"),
            ("💼", "Submit Timesheet every Friday"),
            ("📸", "Screenshot a recipe → auto-imports ingredients"),
            ("📖", "Dungeon Crawler Carl was Great, 5 Stars"),
        ]
        
        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "0B1D33"), Color(hex: "0F2640")],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            Spacer().frame(height: 16)
                            
                            ForEach(bubbles.indices, id: \.self) { i in
                                let isLeft = i % 2 == 0
                                
                                HStack {
                                    if !isLeft { Spacer(minLength: 48) }
                                    
                                    HStack(spacing: 8) {
                                        Text(bubbles[i].0)
                                            .font(.system(size: 16))
                                        Text(bubbles[i].1)
                                            .font(.custom("DMSans-Regular", size: 13))
                                            .foregroundColor(.white.opacity(0.9))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(.white.opacity(0.09))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(.white.opacity(0.13), lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                    .opacity(visibleCount > i ? 1 : 0)
                                    .offset(x: visibleCount > i ? 0 : (isLeft ? -30 : 30))
                                    .animation(.spring(duration: 0.4, bounce: 0.3).delay(Double(i) * 0.12), value: visibleCount)
                                    
                                    if isLeft { Spacer(minLength: 48) }
                                }
                                .padding(.horizontal, 20)
                            }
                            
                            Spacer().frame(height: 160)
                        }
                    }
                    .mask(
                        LinearGradient(
                            colors: [.clear, .black, .black, .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, Color(hex: "0B1D33").opacity(0.85), Color(hex: "0B1D33")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 220)
                    .allowsHitTesting(false)
                }
                .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    VStack(spacing: 6) {
                        Text("Notes, reminders, and search.")
                            .font(.custom("DMSans-Regular", size: 20))
                            .foregroundColor(.white.opacity(0.5))
                        Text("Captured in one tap.")
                            .font(.custom("DMSans-Medium", size: 32))
                            .foregroundColor(.white)
                    }
                    .opacity(titleVisible ? 1 : 0)
                    .offset(y: titleVisible ? 0 : 12)
                    .animation(.easeOut(duration: 0.5).delay(0.6), value: titleVisible)
                    .padding(.bottom, 16)
                    
                    Button {
                        onNext()
                    } label: {
                        Text("Show me how")
                            .font(.custom("DMSans-Medium", size: 17))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.oceanTeal, .seafoam],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .oceanTeal.opacity(0.5), radius: 16, y: 6)
                    }
                    .opacity(titleVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.8), value: titleVisible)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 52)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    visibleCount = bubbles.count
                }
                titleVisible = true
            }
        }
    }
    
    // MARK: - First Real Drop
    
    struct FirstDropScreen: View {
        let onNext: () -> Void
        let onMemorySaved: (String) -> Void
        
        @Environment(\.modelContext) private var modelContext
        @Query private var echos: [Echo]
        
        @State private var audioService = AudioService()
        @State private var sonarEngine = SonarEngine()
        @State private var isRecording = false
        @State private var hasRecorded = false
        @State private var showResult = false
        @State private var sonarResult: SonarResult?
        @State private var permissionDenied = false
        @State private var savedTranscription = ""
        
        var echoForResult: Echo? {
            guard let result = sonarResult else { return nil }
            return echos.first { $0.id == result.echoId } ?? echos.first { $0.name == result.echoName }
        }
        
        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "0B1D33"), Color(hex: "1A3A5C")],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)
                    
                    VStack(spacing: 8) {
                        Text("Drop your first memory")
                            .font(.custom("DMSans-Medium", size: 28))
                            .foregroundColor(.white)
                        Text(hasRecorded ? "Sonar is working its magic..." : "Tap the mic and say anything")
                            .font(.custom("DMSans-Regular", size: 16))
                            .foregroundColor(.white.opacity(0.5))
                            .animation(.easeOut, value: hasRecorded)
                    }
                    
                    Spacer()
                    
                    if showResult, let result = sonarResult {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.oceanTeal)
                                    .font(.system(size: 18))
                                Text("Saved to \(result.echoName)")
                                    .font(.custom("DMSans-Medium", size: 15))
                                    .foregroundColor(.deepNavy)
                                Spacer()
                                Text(echoForResult?.emoji ?? "📝")
                                    .font(.system(size: 22))
                            }
                            
                            Text(savedTranscription)
                                .font(.custom("DMSans-Regular", size: 15))
                                .foregroundColor(.deepNavy)
                            
                            HStack(spacing: 8) {
                                if result.shouldCreatePing {
                                    Label(
                                        result.pingRecurrence == .none ? "Ping set" : result.pingRecurrence.rawValue.capitalized,
                                        systemImage: "bell.fill"
                                    )
                                    .font(.custom("DMSans-Medium", size: 12))
                                    .foregroundColor(.oceanTeal)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.oceanTeal.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                                
                                if let date = result.detectedDate {
                                    Text(date, format: .dateTime.month(.abbreviated).day())
                                        .font(.custom("DMMono-Regular", size: 12))
                                        .foregroundColor(.coral)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.coral.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(16)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.1), radius: 16, y: 4)
                        .padding(.horizontal, 28)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                        
                    } else {
                        VStack(spacing: 28) {
                            if !savedTranscription.isEmpty || !audioService.transcription.isEmpty {
                                Text(savedTranscription.isEmpty ? audioService.transcription : savedTranscription)
                                    .font(.custom("DMSans-Regular", size: 18))
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                    .animation(.easeOut, value: audioService.transcription)
                            }
                            
                            if isRecording {
                                HStack(spacing: 3) {
                                    ForEach(0..<24, id: \.self) { i in
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.coral.opacity(0.8))
                                            .frame(width: 4, height: barHeight(index: i))
                                            .animation(.linear(duration: 0.1), value: audioService.audioLevel)
                                    }
                                }
                                .frame(height: 40)
                            }
                            
                            if !hasRecorded {
                                Button {
                                    toggleRecording()
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(isRecording ? Color.coral : Color.oceanTeal)
                                            .frame(width: 80, height: 80)
                                            .shadow(color: (isRecording ? Color.coral : Color.oceanTeal).opacity(0.4), radius: 16, y: 4)
                                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(.white)
                                    }
                                    .scaleEffect(isRecording ? 1.1 : 1.0)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isRecording)
                                }
                            } else {
                                ProgressView()
                                    .tint(.oceanTeal)
                                    .scaleEffect(1.5)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    if showResult {
                        Button {
                            onNext()
                        } label: {
                            Text("That's the magic ✨")
                                .font(.custom("DMSans-Medium", size: 17))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [.oceanTeal, .seafoam],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .oceanTeal.opacity(0.4), radius: 12, y: 4)
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 52)
                        .transition(.opacity)
                    } else if permissionDenied {
                        VStack(spacing: 12) {
                            Text("Microphone access needed")
                                .font(.custom("DMSans-Regular", size: 14))
                                .foregroundColor(.white.opacity(0.5))
                            Button {
                                onNext()
                            } label: {
                                Text("Skip for now")
                                    .font(.custom("DMSans-Regular", size: 15))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                        .padding(.bottom, 52)
                    } else if !hasRecorded {
                        Text("Try: \"Dentist March 20 at 2pm, remind me a day before\"")
                            .font(.custom("DMSans-Regular", size: 13))
                            .foregroundColor(.white.opacity(0.3))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.bottom, 52)
                    }
                }
            }
        }
        
        private func barHeight(index: Int) -> CGFloat {
            let base: CGFloat = 4
            let level = CGFloat(audioService.audioLevel)
            let variation = sin(Double(index) * 0.8 + Date().timeIntervalSince1970 * 3) * 0.5 + 0.5
            return base + (level * 36 * CGFloat(variation))
        }
        
        private func toggleRecording() {
            let status = AVAudioApplication.shared.recordPermission
            if status == .denied {
                permissionDenied = true
                return
            }
            if status == .undetermined {
                audioService.requestPermissions { granted in
                    if granted { startRecording() }
                    else { permissionDenied = true }
                }
                return
            }
            if isRecording {
                stopAndSave()
            } else {
                startRecording()
            }
        }
        
        private func startRecording() {
            isRecording = true
            audioService.startRecording()
        }
        
        private func stopAndSave() {
            audioService.stopRecording()
            isRecording = false
            savedTranscription = audioService.transcription
            hasRecorded = true
            
            guard !savedTranscription.isEmpty else {
                hasRecorded = false
                return
            }
            
            sonarResult = sonarEngine.process(text: savedTranscription, echos: echos)
            onMemorySaved(savedTranscription)
            
            let echoId = sonarResult?.echoId ?? echos.first?.id ?? UUID()
            let memory = Memory(text: savedTranscription, echoId: echoId)
            memory.tags = sonarResult?.tags ?? []
            memory.detectedDate = sonarResult?.detectedDate
            memory.echoConfidence = sonarResult?.echoConfidence ?? 1.0
            memory.dateConfidence = sonarResult?.dateConfidence
            memory.sonarConfidence = sonarResult?.echoConfidence ?? 1.0
            memory.isActionable = sonarResult?.isActionable ?? false
            modelContext.insert(memory)
            
            if let detectedURL = sonarEngine.detectURL(text: savedTranscription) {
                memory.url = detectedURL
            }
            
            if let result = sonarResult {
                for suggestion in result.pingSuggestions {
                    let fireDate = suggestion.fireDate ?? result.detectedDate ?? Date()
                    let ping = Ping(memoryId: memory.id, fireDate: fireDate, recurrence: suggestion.recurrence)
                    if let fireTime = suggestion.fireTime {
                        ping.fireTime = fireTime
                    }
                    modelContext.insert(ping)
                    NotificationService.shared.schedulePing(ping: ping, memoryText: memory.text)
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
                    showResult = true
                }
            }
        }
    }
    
    // MARK: - Notifications
    
    struct NotificationsScreen: View {
        let onNext: () -> Void
        let memoryText: String
        
        @State private var granted = false
        @State private var contentVisible = false
        
        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "0B1D33"), Color(hex: "1A3A5C")],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    VStack(spacing: 28) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.08))
                                .frame(width: 96, height: 96)
                            Text("🔔")
                                .font(.system(size: 44))
                        }
                        .scaleEffect(contentVisible ? 1 : 0.6)
                        .opacity(contentVisible ? 1 : 0)
                        .animation(.spring(duration: 0.6, bounce: 0.4), value: contentVisible)
                        
                        VStack(spacing: 10) {
                            Text("Never miss a thing")
                                .font(.custom("DMSans-Medium", size: 28))
                                .foregroundColor(.white)
                            Text("Orca fires Pings at exactly the right moment — not a minute early, not a minute late.")
                                .font(.custom("DMSans-Regular", size: 15))
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .opacity(contentVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.2), value: contentVisible)
                        
                        // Real notification using their actual memory
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(
                                        LinearGradient(
                                            colors: [.oceanTeal, .seafoam],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 40, height: 40)
                                FinIcon()
                                    .fill(.white)
                                    .frame(width: 20, height: 24)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Orca · now")
                                    .font(.custom("DMMono-Regular", size: 11))
                                    .foregroundColor(.white.opacity(0.4))
                                Text(memoryText.isEmpty ? "🦷 Dentist tomorrow at 2pm" : memoryText)
                                    .font(.custom("DMSans-Medium", size: 14))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 28)
                        .opacity(contentVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.35), value: contentVisible)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 12) {
                        if granted {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.oceanTeal)
                                Text("Notifications enabled")
                                    .font(.custom("DMSans-Medium", size: 16))
                                    .foregroundColor(.white)
                            }
                            .transition(.scale.combined(with: .opacity))
                            
                            Button {
                                onNext()
                            } label: {
                                Text("Almost done")
                                    .font(.custom("DMSans-Medium", size: 17))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(
                                            colors: [.oceanTeal, .seafoam],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .transition(.opacity)
                        } else {
                            Button {
                                requestNotifications()
                            } label: {
                                Text("Turn on Pings")
                                    .font(.custom("DMSans-Medium", size: 17))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(
                                            colors: [.oceanTeal, .seafoam],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: .oceanTeal.opacity(0.4), radius: 12, y: 4)
                            }
                            
                            Button {
                                onNext()
                            } label: {
                                Text("Maybe later")
                                    .font(.custom("DMSans-Regular", size: 15))
                                    .foregroundColor(.white.opacity(0.35))
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 52)
                    .animation(.spring(duration: 0.4), value: granted)
                }
            }
            .onAppear {
                withAnimation { contentVisible = true }
            }
        }
        
        private func requestNotifications() {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async {
                    withAnimation { self.granted = granted }
                    if !granted { onNext() }
                }
            }
        }
    }
    
    // MARK: - All Set
    
    struct AllSetScreen: View {
        let onDone: () -> Void
        @State private var contentVisible = false
        
        let tips: [(String, String)] = [
            ("🎙️", "Tap the fin for instant voice capture"),
            ("↑",   "Swipe up on the fin for more options"),
            ("🔍", "Search with \"Dive into memories\""),
            ("⚙️", "Set Orca as your Action Button in Settings"),
        ]
        
        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "0B1D33"), Color(hex: "1A3A5C")],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.oceanTeal, .seafoam],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 88, height: 88)
                            .shadow(color: .oceanTeal.opacity(0.5), radius: 24, y: 8)
                        FinIcon()
                            .fill(.white)
                            .frame(width: 44, height: 52)
                    }
                    .scaleEffect(contentVisible ? 1 : 0.5)
                    .opacity(contentVisible ? 1 : 0)
                    .animation(.spring(duration: 0.7, bounce: 0.5), value: contentVisible)
                    .padding(.bottom, 24)
                    
                    VStack(spacing: 8) {
                        Text("You're all set")
                            .font(.custom("DMSans-Medium", size: 32))
                            .foregroundColor(.white)
                        Text("Your personal assistant is ready.")
                            .font(.custom("DMSans-Regular", size: 16))
                            .foregroundColor(.white.opacity(0.7))
                        Text("The more you Drop, the smarter it gets.")
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .opacity(contentVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.3), value: contentVisible)
                    
                    Spacer()
                    
                    VStack(spacing: 0) {
                        ForEach(tips.indices, id: \.self) { i in
                            HStack(spacing: 14) {
                                Text(tips[i].0)
                                    .font(.system(size: 18))
                                    .frame(width: 28)
                                Text(tips[i].1)
                                    .font(.custom("DMSans-Regular", size: 14))
                                    .foregroundColor(.white.opacity(0.65))
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .opacity(contentVisible ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.4 + Double(i) * 0.1), value: contentVisible)
                            
                            if i < tips.count - 1 {
                                Divider()
                                    .background(.white.opacity(0.08))
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                    
                    Spacer()
                    
                    Button {
                        AnalyticsService.shared.trackOnboardingCompleted(droppedFirstMemory: true)
                        onDone()
                    } label: {
                        Text("Start using Orca")
                            .font(.custom("DMSans-Medium", size: 17))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.oceanTeal, .seafoam],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .oceanTeal.opacity(0.4), radius: 12, y: 4)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 52)
                    .opacity(contentVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.8), value: contentVisible)
                }
            }
            .onAppear {
                withAnimation { contentVisible = true }
            }
        }
    }
}
