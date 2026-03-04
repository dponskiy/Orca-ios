//
//  TypeCaptureView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI
import SwiftData

struct TypeCaptureView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Query private var echos: [Echo]
    
    @State private var text = ""
    @State private var showBanner = false
    @State private var sonarResult: SonarResult?
    @FocusState private var isFocused: Bool
    @State private var editMemory: Memory? = nil
    
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
    private func updateLastMemoryEcho(_ echoId: UUID) {
        let descriptor = FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        if let last = try? modelContext.fetch(descriptor).first {
            last.echoId = echoId
        }
    }

    private let sonarEngine = SonarEngine()
    
    var body: some View {
        ZStack {
            if showBanner {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { isPresented = false }
                
                VStack {
                    Spacer()
                    ConfirmBannerView(
                        transcription: text,
                        sonarResult: sonarResult,
                        echos: echos,
                        onDone: { isTask in
                            updateLastMemoryTask(isTask: isTask)
                            isPresented = false
                        },
                            onUndo: { undoMemory() },
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
            }
            else {
                ZStack {
                    Color.deepNavy.ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        // Header
                        HStack {
                            Button("Cancel") {
                                isPresented = false
                            }
                            .font(.custom("DMSans-Regular", size: 16))
                            .foregroundColor(.white.opacity(0.6))
                            
                            Spacer()
                            
                            Button("Save") {
                                saveMemory()
                            }
                            .font(.custom("DMSans-Medium", size: 16))
                            .foregroundColor(text.isEmpty ? .white.opacity(0.3) : .oceanTeal)
                            .disabled(text.isEmpty)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        
                        // Text input
                        TextEditor(text: $text)
                            .font(.custom("DMSans-Regular", size: 18))
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 16)
                            .focused($isFocused)
                        
                        // Placeholder
                        if text.isEmpty {
                            Text("Type a memory...")
                                .font(.custom("DMSans-Regular", size: 18))
                                .foregroundColor(.white.opacity(0.3))
                                .padding(.horizontal, 20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .allowsHitTesting(false)
                                .offset(y: -60)
                        }
                    }
                }
                .onAppear {
                    isFocused = true
                }
            }
                }
        .sheet(item: $editMemory) { memory in
                    MemoryEditView(memory: memory)
        }
    }
    
    private func saveMemory() {
        guard !text.isEmpty else { return }
        
        sonarResult = sonarEngine.process(text: text, echos: echos)
        
        let echoId = sonarResult?.echoId ?? echos.first?.id ?? UUID()
        let memory = Memory(text: text, echoId: echoId, captureType: Memory.CaptureType.typed)
        memory.tags = sonarResult?.tags ?? []
        memory.detectedDate = sonarResult?.detectedDate
        memory.echoConfidence = sonarResult?.echoConfidence ?? 1.0
        memory.dateConfidence = sonarResult?.dateConfidence
        memory.sonarConfidence = sonarResult?.echoConfidence ?? 1.0
        memory.isActionable = sonarResult?.isActionable ?? false
        modelContext.insert(memory)
        AnalyticsService.shared.trackMemoryDropped(
            captureType: "typed",
            echoName: sonarResult?.echoName ?? "Unknown",
            hasPing: sonarResult?.shouldCreatePing ?? false,
            hasDate: sonarResult?.detectedDate != nil,
            hasURL: memory.url != nil,
            hasChecklist: memory.hasChecklist,
            wordCount: text.split(separator: " ").count
        )
        // Detect URL
        if let detectedURL = sonarEngine.detectURL(text: text) {
            memory.url = detectedURL
        }
        
        // Detect checklist
        if let checklistItems = sonarEngine.detectChecklist(text: text) {
            memory.hasChecklist = true
            for (index, item) in checklistItems.enumerated() {
                let subTask = SubTask(memoryId: memory.id, text: item, sortOrder: index)
                modelContext.insert(subTask)
            }
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
        
        withAnimation(.spring(duration: 0.4)) {
            showBanner = true
        }
    }

    private func updateLastMemoryTask(isTask: Bool) {
        let recent = try? modelContext.fetch(
            FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )
        if let last = recent?.first {
            last.isActionable = isTask
        }
    }

    private func undoMemory() {
        let recent = try? modelContext.fetch(
            FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )
        if let last = recent?.first {
            modelContext.delete(last)
        }
    }
}

#Preview {
    TypeCaptureView(isPresented: .constant(true))
        .modelContainer(for: [Memory.self, Echo.self, Ping.self], inMemory: true)
}
