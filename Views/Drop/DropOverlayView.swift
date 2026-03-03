//
//  DropOverlayView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI
import SwiftData
import AVFoundation

struct DropOverlayView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Query private var echos: [Echo]
    
    @State private var audioService = AudioService()
    @State private var showBanner = false
    @State private var sonarResult: SonarResult?
    @State private var permissionDenied = false
    @State private var editMemory: Memory? = nil
    
    private func updateLastMemoryEcho(_ echoId: UUID) {
        let descriptor = FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        if let last = try? modelContext.fetch(descriptor).first {
            last.echoId = echoId
        }
    }
    private func handleRecipeFetch(_ recipe: RecipeResult) {
        let descriptor = FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        guard let memory = try? modelContext.fetch(descriptor).first else { return }
        
        // Update memory text with instructions
        var parts: [String] = ["🍽 \(recipe.title)"]
        var meta: [String] = []
        if let prep = recipe.prepTime { meta.append("Prep: \(prep)") }
        if let cook = recipe.cookTime { meta.append("Cook: \(cook)") }
        if let srv  = recipe.servings { meta.append("Serves: \(srv)") }
        if !meta.isEmpty { parts.append(meta.joined(separator: " · ")) }
        if !recipe.instructions.isEmpty {
            parts.append("\nInstructions:")
            for (i, step) in recipe.instructions.enumerated() {
                parts.append("\(i + 1). \(step)")
            }
        }
        memory.text = parts.joined(separator: "\n")
        
        // Add ingredients as subtasks
        if !recipe.ingredients.isEmpty {
            memory.hasChecklist = true
            for (index, ingredient) in recipe.ingredients.enumerated() {
                let subTask = SubTask(memoryId: memory.id, text: ingredient, sortOrder: index)
                modelContext.insert(subTask)
            }
        }
    }
    private let sonarEngine = SonarEngine()
    
    var body: some View {
        ZStack {
            if showBanner {
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
                        onDone: { isTask in
                            updateLastMemoryTask(isTask: isTask)
                            dismissAndClose()
                        },
                        onUndo: { undoAndClose() },
                        onEchoChanged: { newEchoId in
                            updateLastMemoryEcho(newEchoId)
                        },
                        onRecipeFetched: { recipe in
                            handleRecipeFetch(recipe)
                        },
                        onEdit: {
                            let descriptor = FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
                            editMemory = try? modelContext.fetch(descriptor).first
                        }
                    )
                }
            } else if permissionDenied {
                permissionDeniedView
            } else {
                recordingView
            }
        }
        .onAppear {
            checkAndStartRecording()
        }
                .sheet(item: $editMemory) { memory in
                    MemoryEditView(memory: memory)
        }
    }
    
    // MARK: - Permission Check
    
    private func checkAndStartRecording() {
        let micStatus = AVAudioApplication.shared.recordPermission
        if micStatus == .undetermined {
            audioService.requestPermissions { granted in
                if granted {
                    audioService.startRecording()
                } else {
                    permissionDenied = true
                }
            }
        } else if micStatus == .denied {
            permissionDenied = true
        } else {
            audioService.startRecording()
        }
    }
    
    // MARK: - Recording View
    
    private var recordingView: some View {
        ZStack {
            LinearGradient(
                colors: [.deepNavy, Color(hex: "1A2A44")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                if !audioService.transcription.isEmpty {
                    Text(audioService.transcription)
                        .font(.custom("DMSans-Regular", size: 18))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .animation(.easeOut(duration: 0.2), value: audioService.transcription)
                }
                
                HStack(spacing: 3) {
                    ForEach(0..<24, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.coral.opacity(0.8))
                            .frame(width: 4, height: barHeight(index: i))
                            .animation(.linear(duration: 0.1), value: audioService.audioLevel)
                    }
                }
                .frame(height: 40)
                
                Text(formatTime(audioService.recordingDuration))
                    .font(.custom("DMMono-Regular", size: 16))
                    .foregroundColor(.white.opacity(0.5))
                
                Spacer()
                
                FinIcon()
                    .fill(Color.coral.opacity(0.6))
                    .frame(width: 40, height: 48)
                    .scaleEffect(audioService.isRecording ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: audioService.isRecording)
                
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
    
    // MARK: - Permission Denied View
    
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

    // MARK: - Update Last Memory

    private func updateLastMemoryTask(isTask: Bool) {
        let recent = try? modelContext.fetch(
            FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )
        if let last = recent?.first {
            last.isActionable = isTask
        }
    }
    
    // MARK: - Helpers
    
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
        
        sonarResult = sonarEngine.process(text: audioService.transcription, echos: echos)
        
        let echoId = sonarResult?.echoId ?? echos.first?.id ?? UUID()
        let memory = Memory(text: audioService.transcription, echoId: echoId)
        memory.tags = sonarResult?.tags ?? []
        memory.detectedDate = sonarResult?.detectedDate
        memory.echoConfidence = sonarResult?.echoConfidence ?? 1.0
        memory.dateConfidence = sonarResult?.dateConfidence
        memory.sonarConfidence = sonarResult?.echoConfidence ?? 1.0
        memory.isActionable = sonarResult?.isActionable ?? false
        modelContext.insert(memory)

        // Detect URL
        if let detectedURL = sonarEngine.detectURL(text: audioService.transcription) {
            memory.url = detectedURL
        }
        
        // Detect checklist
        if let checklistItems = sonarEngine.detectChecklist(text: audioService.transcription) {
            memory.hasChecklist = true
            for (index, item) in checklistItems.enumerated() {
                let subTask = SubTask(memoryId: memory.id, text: item, sortOrder: index)
                modelContext.insert(subTask)
            }
        }

        // Create Pings from suggestions
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
        
        withAnimation(.spring(duration: 0.4)) {
            showBanner = true
        }
    }
    
    private func dismissAndClose() {
        isPresented = false
    }
    
    private func undoAndClose() {
        let recent = try? modelContext.fetch(
            FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )
        if let last = recent?.first {
            modelContext.delete(last)
        }
        isPresented = false
    }
}
