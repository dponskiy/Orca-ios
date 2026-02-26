//
//  DropOverlayView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI
import SwiftData

struct DropOverlayView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Query private var echos: [Echo]
    
    @State private var audioService = AudioService()
    @State private var showBanner = false
    @State private var sonarResult: SonarResult?
    @State private var permissionDenied = false
    
    private let sonarEngine = SonarEngine()
    
    var body: some View {
        ZStack {
            if showBanner {
                // Dimmed dashboard with banner
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissAndClose()
                    }
                
                VStack {
                    Spacer()
                    ConfirmBannerView(
                        transcription: audioService.transcription,
                        sonarResult: sonarResult,
                        echos: echos,
                        onDone: { dismissAndClose() },
                        onUndo: { undoAndClose() }
                    )
                }
            } else if permissionDenied {
                permissionDeniedView
            } else {
                recordingView
            }
        }
        .onAppear {
            audioService.requestPermissions { granted in
                if granted {
                    audioService.startRecording()
                } else {
                    permissionDenied = true
                }
            }
        }
    }
    
    private var recordingView: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.deepNavy, Color(hex: "1A2A44")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Live transcription
                if !audioService.transcription.isEmpty {
                    Text(audioService.transcription)
                        .font(.custom("DMSans-Regular", size: 18))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .animation(.easeOut(duration: 0.2), value: audioService.transcription)
                }
                
                // Waveform bars
                HStack(spacing: 3) {
                    ForEach(0..<24, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.coral.opacity(0.8))
                            .frame(width: 4, height: barHeight(index: i))
                            .animation(.linear(duration: 0.1), value: audioService.audioLevel)
                    }
                }
                .frame(height: 40)
                
                // Timer
                Text(formatTime(audioService.recordingDuration))
                    .font(.custom("DMMono-Regular", size: 16))
                    .foregroundColor(.white.opacity(0.5))
                
                Spacer()
                
                // Fin icon pulsing
                FinIcon()
                    .fill(Color.coral.opacity(0.6))
                    .frame(width: 40, height: 48)
                    .scaleEffect(audioService.isRecording ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: audioService.isRecording)
                
                // Stop button
                Button {
                    stopAndProcess()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.coral)
                            .frame(width: 72, height: 72)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white)
                            .frame(width: 24, height: 24)
                    }
                }
                .padding(.bottom, 60)
            }
        }
    }
    
    private var permissionDeniedView: some View {
        ZStack {
            Color.deepNavy.ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.coral)
                
                Text("Microphone Access Needed")
                    .font(.custom("DMSans-Medium", size: 18))
                    .foregroundColor(.white)
                
                Text("Orca needs your microphone to capture voice memories. Open Settings to enable it.")
                    .font(.custom("DMSans-Regular", size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.custom("DMSans-Medium", size: 16))
                .foregroundColor(.oceanTeal)
                .padding(.top, 8)
                
                Button("Cancel") {
                    isPresented = false
                }
                .font(.custom("DMSans-Regular", size: 14))
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 4)
            }
        }
    }
    
    private func barHeight(index: Int) -> CGFloat {
        let base: CGFloat = 4
        let level = CGFloat(audioService.audioLevel)
        let variation = sin(Double(index) * 0.8 + Date().timeIntervalSince1970 * 3) * 0.5 + 0.5
        return base + (level * 36 * CGFloat(variation))
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func stopAndProcess() {
        audioService.stopRecording()
        
        guard !audioService.transcription.isEmpty else {
            isPresented = false
            return
        }
        
        // Run Sonar
        sonarResult = sonarEngine.process(text: audioService.transcription, echos: echos)
        
        // Save memory
        let echoId = sonarResult?.echoId ?? echos.first?.id ?? UUID()
        let memory = Memory(text: audioService.transcription, echoId: echoId)
        memory.tags = sonarResult?.tags ?? []
        memory.detectedDate = sonarResult?.detectedDate
        memory.echoConfidence = sonarResult?.echoConfidence ?? 1.0
        memory.dateConfidence = sonarResult?.dateConfidence
        memory.sonarConfidence = sonarResult?.echoConfidence ?? 1.0
        modelContext.insert(memory)
        
        // Create Ping if needed
        if let result = sonarResult, result.shouldCreatePing, let date = result.detectedDate {
            let ping = Ping(memoryId: memory.id, fireDate: date, recurrence: result.pingRecurrence)
            modelContext.insert(ping)
        }
        
        withAnimation(.spring(duration: 0.4)) {
            showBanner = true
        }
    }
    
    private func dismissAndClose() {
        isPresented = false
    }
    
    private func undoAndClose() {
        // Delete the most recent memory
        let recent = try? modelContext.fetch(
            FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )
        if let last = recent?.first {
            modelContext.delete(last)
        }
        isPresented = false
    }
}
