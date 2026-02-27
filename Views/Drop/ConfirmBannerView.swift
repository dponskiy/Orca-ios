//
//  ConfirmBannerView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI
import SwiftData

struct ConfirmBannerView: View {
    let transcription: String
    let sonarResult: SonarResult?
    let echos: [Echo]
    let onDone: () -> Void
    let onUndo: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @State private var editedText: String = ""
    @State private var selectedEchoId: UUID?
    @State private var selectedDate: Date?
    @State private var countdown: CGFloat = 1.0
    @State private var isPaused = false
    @State private var isEditingText = false
    @State private var showEchoPicker = false
    @State private var showDatePicker = false
    @State private var countdownTimer: Timer?
    @FocusState private var textFocused: Bool
    @State private var hasPing: Bool = false
    
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
                header
                
                // Transcription
                transcriptionSection
                
                // Echo picker
                if showEchoPicker {
                    echoPickerSection
                }
                
                // Date picker
                if showDatePicker {
                    datePickerSection
                }
                
                // Chips row
                chipsRow
            }
            .padding(16)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 16, y: -4)
        .padding(.horizontal, 8)
        .transition(.move(edge: .bottom))
        .onAppear {
            editedText = transcription
            selectedEchoId = sonarResult?.echoId
            selectedDate = sonarResult?.detectedDate
            hasPing = sonarResult?.shouldCreatePing ?? false
            startCountdown()
        }
    }
    
    // MARK: - Header
    private var header: some View {
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
            
            Button(action: {
                countdownTimer?.invalidate()
                onUndo()
            }) {
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
            
            Button(action: {
                countdownTimer?.invalidate()
                saveEdits()
                onDone()
            }) {
                Text("Done")
                    .font(.custom("DMSans-Medium", size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.oceanTeal)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
    
    // MARK: - Transcription
    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isEditingText {
                TextEditor(text: $editedText)
                    .font(.custom("DMSans-Regular", size: 15))
                    .foregroundColor(.deepNavy)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 60, maxHeight: 120)
                    .focused($textFocused)
            } else {
                Text(editedText)
                    .font(.custom("DMSans-Regular", size: 15))
                    .foregroundColor(.deepNavy)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Tap to edit")
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .background(Color.pearl)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isEditingText ? Color.oceanTeal : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            pauseCountdown()
            isEditingText = true
            textFocused = true
        }
    }
    
    // MARK: - Echo Picker
    private var echoPickerSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(echos) { echo in
                    Button {
                        selectedEchoId = echo.id
                        showEchoPicker = false
                    } label: {
                        HStack(spacing: 4) {
                            Text(echo.emoji)
                                .font(.system(size: 14))
                            Text(echo.name)
                                .font(.custom("DMSans-Medium", size: 13))
                                .foregroundColor(selectedEchoId == echo.id ? .white : .deepNavy)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedEchoId == echo.id ? Color.oceanTeal : Color.mist)
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    // MARK: - Date Picker
    private var datePickerSection: some View {
        VStack(spacing: 8) {
            DatePicker(
                "Memory date",
                selection: Binding(
                    get: { selectedDate ?? Date() },
                    set: { selectedDate = $0 }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .font(.custom("DMSans-Regular", size: 14))
            
            if selectedDate != nil {
                Button("Remove date") {
                    selectedDate = nil
                    showDatePicker = false
                }
                .font(.custom("DMSans-Regular", size: 13))
                .foregroundColor(.coral)
            }
        }
        .padding(12)
        .background(Color.pearl)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    // MARK: - Chips Row
    private var chipsRow: some View {
        HStack(spacing: 8) {
            // Echo chip
            Button {
                pauseCountdown()
                withAnimation(.easeOut(duration: 0.2)) {
                    showEchoPicker.toggle()
                    showDatePicker = false
                }
            } label: {
                HStack(spacing: 4) {
                    let echo = echos.first { $0.id == selectedEchoId }
                    Text(echo?.emoji ?? "📝")
                        .font(.system(size: 14))
                    Text(echo?.name ?? "Notes")
                        .font(.custom("DMSans-Medium", size: 13))
                        .foregroundColor(.deepNavy)
                    
                    if (sonarResult?.echoConfidence ?? 1.0) < 0.7 && selectedEchoId == sonarResult?.echoId {
                        Text("?")
                            .font(.custom("DMSans-Bold", size: 11))
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                            .background(Color.coral)
                            .clipShape(Circle())
                    }
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.mist)
                .clipShape(Capsule())
            }
            
            // Date chip
            Button {
                pauseCountdown()
                withAnimation(.easeOut(duration: 0.2)) {
                    showDatePicker.toggle()
                    showEchoPicker = false
                }
            } label: {
                HStack(spacing: 4) {
                    Text("📅")
                        .font(.system(size: 14))
                    
                    if let date = selectedDate {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(.custom("DMSans-Medium", size: 13))
                            .foregroundColor(.deepNavy)
                    } else {
                        Text("+ Date")
                            .font(.custom("DMSans-Medium", size: 13))
                            .foregroundColor(.gray)
                    }
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.mist)
                .clipShape(Capsule())
            }
            
            // Ping chip
            if selectedDate != nil {
                Button {
                    pauseCountdown()
                    withAnimation(.easeOut(duration: 0.2)) {
                        hasPing.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: hasPing ? "bell.fill" : "bell")
                            .font(.system(size: 12))
                            .foregroundColor(hasPing ? .white : .oceanTeal)
                        Text(hasPing ? "Ping on" : "Ping")
                            .font(.custom("DMSans-Medium", size: 13))
                            .foregroundColor(hasPing ? .white : .deepNavy)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(hasPing ? Color.oceanTeal : Color.mist)
                    .clipShape(Capsule())
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Countdown
    private func startCountdown() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if !isPaused {
                countdown -= 0.01
                if countdown <= 0 {
                    timer.invalidate()
                    saveEdits()
                    onDone()
                }
            }
        }
    }
    
    private func pauseCountdown() {
        isPaused = true
    }
    
    // MARK: - Save
    private func saveEdits() {
        let recent = try? modelContext.fetch(
            FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )
        guard let memory = recent?.first else { return }
        
        // Update text if changed
        if editedText != transcription {
            memory.text = editedText
            memory.wasEdited = true
        }
        
        // Update Echo if changed
        if let newEchoId = selectedEchoId, newEchoId != sonarResult?.echoId {
            memory.echoId = newEchoId
            memory.wasEdited = true
        }
        
        // Update date
        if selectedDate != sonarResult?.detectedDate {
            memory.detectedDate = selectedDate
            memory.wasEdited = true
        }
        
        // Handle Ping
        let memoryId = memory.id
        let existingPings = try? modelContext.fetch(
            FetchDescriptor<Ping>(predicate: #Predicate<Ping> { ping in
                ping.memoryId == memoryId
            })
        )
        
        if hasPing, let date = selectedDate {
            if existingPings?.isEmpty ?? true {
                let ping = Ping(memoryId: memory.id, fireDate: date, recurrence: sonarResult?.pingRecurrence ?? Ping.Recurrence.none)
                modelContext.insert(ping)
            }
        } else {
            // Remove Ping if toggled off
            if let pings = existingPings {
                for ping in pings {
                    modelContext.delete(ping)
                }
            }
        }
    }
}
