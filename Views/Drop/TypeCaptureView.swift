//
//  Untitled.swift
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
                        onDone: { isPresented = false },
                        onUndo: {
                            undoMemory()
                            isPresented = false
                        }
                    )
                }
            } else {
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
        
        if let result = sonarResult {
                    for suggestion in result.pingSuggestions {
                        let fireDate = suggestion.fireDate ?? result.detectedDate ?? Date()
                        let ping = Ping(memoryId: memory.id, fireDate: fireDate, recurrence: suggestion.recurrence)
                        if let fireTime = suggestion.fireTime {
                            ping.fireTime = fireTime
                        }
                        modelContext.insert(ping)
                    }
                }
        
        withAnimation(.spring(duration: 0.4)) {
            showBanner = true
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
