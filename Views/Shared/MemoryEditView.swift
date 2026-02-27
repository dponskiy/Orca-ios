//
//  MemoryEditView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI
import SwiftData

struct MemoryEditView: View {
    @Bindable var memory: Memory
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var echos: [Echo]
    @Query private var pings: [Ping]
    
    @State private var editedText: String = ""
    @State private var selectedEchoId: UUID = UUID()
    @State private var selectedDate: Date?
    @State private var hasDate: Bool = false
    @State private var showDeleteConfirm = false
    
    // Ping states
    @State private var hasPing: Bool = false
    @State private var pingRecurrence: Ping.Recurrence = Ping.Recurrence.none
    @State private var pingLeadTime: PingLeadTime = .dayOf
    @State private var pingTime: Date = Calendar.current.date(
        bySettingHour: 9, minute: 0, second: 0, of: Date()
    ) ?? Date()
    
    enum PingLeadTime: String, CaseIterable {
        case dayOf = "Day of"
        case dayBefore = "1 day before"
        case threeDays = "3 days before"
        case weekBefore = "1 week before"
        case twoWeeks = "2 weeks before"
        case monthBefore = "1 month before"
        
        var days: Int {
            switch self {
            case .dayOf: return 0
            case .dayBefore: return 1
            case .threeDays: return 3
            case .weekBefore: return 7
            case .twoWeeks: return 14
            case .monthBefore: return 30
            }
        }
    }
    
    var existingPing: Ping? {
        pings.first { $0.memoryId == memory.id }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    textSection
                    echoSection
                    dateSection
                    
                    if hasDate {
                        pingSection
                    }
                    
                    // Delete button
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                            Text("Delete Memory")
                                .font(.custom("DMSans-Medium", size: 15))
                            Spacer()
                        }
                        .foregroundColor(.coral)
                        .padding(.vertical, 14)
                        .background(Color.coral.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .background(Color.white)
            .navigationTitle("Edit Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEdits()
                        dismiss()
                    }
                    .font(.custom("DMSans-Medium", size: 16))
                    .foregroundColor(.oceanTeal)
                }
            }
            .onAppear {
                loadState()
            }
            .alert("Delete Memory", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    modelContext.delete(memory)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete this memory and any associated Pings.")
            }
        }
    }
    
    // MARK: - Text Section
    private var textSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Memory")
                .font(.custom("DMSans-Medium", size: 14))
                .foregroundColor(.gray)
            
            TextEditor(text: $editedText)
                .font(.custom("DMSans-Regular", size: 16))
                .foregroundColor(.deepNavy)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100, maxHeight: 200)
                .padding(12)
                .background(Color.pearl)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.oceanTeal.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Echo Section
    private var echoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Echo")
                .font(.custom("DMSans-Medium", size: 14))
                .foregroundColor(.gray)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(echos) { echo in
                        Button {
                            selectedEchoId = echo.id
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
        }
    }
    
    // MARK: - Date Section
    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date")
                .font(.custom("DMSans-Medium", size: 14))
                .foregroundColor(.gray)
            
            Toggle(isOn: $hasDate) {
                Text("Associated date")
                    .font(.custom("DMSans-Regular", size: 15))
                    .foregroundColor(.deepNavy)
            }
            .tint(.oceanTeal)
            .onChange(of: hasDate) { _, newValue in
                if !newValue {
                    hasPing = false
                }
            }
            
            if hasDate {
                DatePicker(
                    "Date",
                    selection: Binding(
                        get: { selectedDate ?? Date() },
                        set: { selectedDate = $0 }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(.oceanTeal)
            }
        }
    }
    
    // MARK: - Ping Section
    private var pingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ping (Reminder)")
                .font(.custom("DMSans-Medium", size: 14))
                .foregroundColor(.gray)
            
            Toggle(isOn: $hasPing) {
                HStack(spacing: 6) {
                    Text("🔔")
                        .font(.system(size: 16))
                    Text("Remind me")
                        .font(.custom("DMSans-Regular", size: 15))
                        .foregroundColor(.deepNavy)
                }
            }
            .tint(.oceanTeal)
            
            if hasPing {
                VStack(alignment: .leading, spacing: 6) {
                    Text("When")
                        .font(.custom("DMSans-Medium", size: 13))
                        .foregroundColor(.gray)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(PingLeadTime.allCases, id: \.self) { lead in
                                Button {
                                    pingLeadTime = lead
                                } label: {
                                    Text(lead.rawValue)
                                        .font(.custom("DMSans-Medium", size: 13))
                                        .foregroundColor(pingLeadTime == lead ? .white : .deepNavy)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(pingLeadTime == lead ? Color.oceanTeal : Color.mist)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                
                DatePicker(
                    "Time",
                    selection: $pingTime,
                    displayedComponents: .hourAndMinute
                )
                .font(.custom("DMSans-Regular", size: 15))
                .tint(.oceanTeal)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Repeat")
                        .font(.custom("DMSans-Medium", size: 13))
                        .foregroundColor(.gray)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([
                                (Ping.Recurrence.none, "One time"),
                                (Ping.Recurrence.daily, "Daily"),
                                (Ping.Recurrence.weekly, "Weekly"),
                                (Ping.Recurrence.monthly, "Monthly"),
                                (Ping.Recurrence.yearly, "Yearly"),
                            ], id: \.0) { recurrence, label in
                                Button {
                                    pingRecurrence = recurrence
                                } label: {
                                    Text(label)
                                        .font(.custom("DMSans-Medium", size: 13))
                                        .foregroundColor(pingRecurrence == recurrence ? .white : .deepNavy)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(pingRecurrence == recurrence ? Color.oceanTeal : Color.mist)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                
                if let date = selectedDate {
                    let fireDate = Calendar.current.date(byAdding: .day, value: -pingLeadTime.days, to: date) ?? date
                    HStack(spacing: 6) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.oceanTeal)
                        Text("Will fire: \(fireDate, format: .dateTime.month(.abbreviated).day()) at \(pingTime, format: .dateTime.hour().minute())")
                            .font(.custom("DMMono-Regular", size: 13))
                            .foregroundColor(.deepNavy)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.mist)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(16)
        .background(Color.pearl)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Load / Save
    private func loadState() {
        editedText = memory.text
        selectedEchoId = memory.echoId
        selectedDate = memory.detectedDate
        hasDate = memory.detectedDate != nil
        
        if let ping = existingPing {
            hasPing = true
            pingRecurrence = ping.recurrence
            pingTime = ping.fireTime
            
            if let memDate = memory.detectedDate {
                let daysDiff = Calendar.current.dateComponents([.day], from: ping.fireDate, to: memDate).day ?? 0
                pingLeadTime = PingLeadTime.allCases.first { $0.days == daysDiff } ?? .dayOf
            }
        }
    }
    
    private func saveEdits() {
        memory.text = editedText
        memory.echoId = selectedEchoId
        memory.detectedDate = hasDate ? selectedDate : nil
        memory.wasEdited = true
        memory.updatedAt = Date()
        
        if hasPing, let date = selectedDate {
            let fireDate = Calendar.current.date(byAdding: .day, value: -pingLeadTime.days, to: date) ?? date
            
            let calendar = Calendar.current
            let timeComponents = calendar.dateComponents([.hour, .minute], from: pingTime)
            let finalFireDate = calendar.date(bySettingHour: timeComponents.hour ?? 9, minute: timeComponents.minute ?? 0, second: 0, of: fireDate) ?? fireDate
            
            if let existing = existingPing {
                existing.fireDate = finalFireDate
                existing.fireTime = pingTime
                existing.recurrence = pingRecurrence
                existing.isActive = true
            } else {
                let ping = Ping(memoryId: memory.id, fireDate: finalFireDate, recurrence: pingRecurrence)
                ping.fireTime = pingTime
                modelContext.insert(ping)
            }
        } else {
            if let existing = existingPing {
                modelContext.delete(existing)
            }
        }
    }
}
