//
//  CalendarView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI
import SwiftData

struct CalendarTabView: View {
    @Query(sort: \Memory.createdAt, order: .reverse) private var memories: [Memory]
    @Query private var pings: [Ping]
    @Query private var echos: [Echo]
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedDate: Date = Date()
    @State private var displayedMonth: Date = Date()
    @State private var editingMemory: Memory?
    @State private var snoozeMemory: Memory?
    @State private var showSnoozeSheet = false
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]
    
    // MARK: - Filtered Data
    
    private var selectedDateMemories: [Memory] {
        memories.filter { memory in
            guard let detected = memory.detectedDate else { return false }
            return calendar.isDate(detected, inSameDayAs: selectedDate)
        }
        .sorted {
            let d1 = $0.detectedDate ?? $0.createdAt
            let d2 = $1.detectedDate ?? $1.createdAt
            return d1 < d2
        }
    }
    
    private var selectedDatePings: [Ping] {
        pings.filter { ping in
            guard ping.isActive,
                  let _ = memories.first(where: { $0.id == ping.memoryId }) else { return false }
            
            if calendar.isDate(ping.fireDate, inSameDayAs: selectedDate) {
                return true
            }
            
            guard ping.recurrence != .none else { return false }
            guard selectedDate >= calendar.startOfDay(for: ping.fireDate) else { return false }
            
            switch ping.recurrence {
            case .daily:
                return true
            case .weekly:
                return calendar.component(.weekday, from: ping.fireDate) == calendar.component(.weekday, from: selectedDate)
            case .monthly:
                return calendar.component(.day, from: ping.fireDate) == calendar.component(.day, from: selectedDate)
            case .yearly:
                let fc = calendar.dateComponents([.month, .day], from: ping.fireDate)
                let sc = calendar.dateComponents([.month, .day], from: selectedDate)
                return fc.month == sc.month && fc.day == sc.day
            case .none:
                return false
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                monthHeader
                dayOfWeekHeader
                calendarGrid
                
                Divider()
                    .padding(.top, 4)
                
                selectedDateContent
            }
            .background(Color.pearl)
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editingMemory) { memory in
                MemoryEditView(memory: memory)
            }
            .sheet(isPresented: $showSnoozeSheet) {
                if let memory = snoozeMemory {
                    SnoozeSheet(memory: memory) {
                        showSnoozeSheet = false
                        snoozeMemory = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Month Header
    
    private var monthHeader: some View {
            HStack {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                        selectedDate = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.oceanTeal)
                }
                
                Spacer()
                
                Text(displayedMonth, format: .dateTime.month(.wide).year())
                    .font(.custom("DMSans-Medium", size: 18))
                    .foregroundColor(.deepNavy)
                
                Spacer()
                
                HStack(spacing: 24) {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            displayedMonth = Date()
                            selectedDate = Date()
                        }
                    } label: {
                        Text("Today")
                            .font(.custom("DMSans-Medium", size: 13))
                            .foregroundColor(.oceanTeal)
                    }
                    
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                            selectedDate = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.oceanTeal)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white)
        }
    // MARK: - Day of Week Header
    
    private var dayOfWeekHeader: some View {
        HStack(spacing: 0) {
            ForEach(daysOfWeek, id: \.self) { day in
                Text(day)
                    .font(.custom("DMSans-Medium", size: 12))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white)
    }
    
    // MARK: - Calendar Grid
    
    private var calendarGrid: some View {
        let days = daysInMonth()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                if let date = date {
                    dayCell(for: date)
                } else {
                    Color.clear
                        .frame(height: 44)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .background(Color.white)
    }
    
    // MARK: - Day Cell
    
    private func dayCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let isCurrentMonth = calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
        
        let hasMemories = memories.contains { memory in
            guard let detected = memory.detectedDate else { return false }
            return calendar.isDate(detected, inSameDayAs: date)
        }
        
        let hasPings = pings.contains { ping in
            guard ping.isActive else { return false }
            guard let _ = memories.first(where: { $0.id == ping.memoryId }) else { return false }
            guard ping.recurrence != .none || calendar.isDate(ping.fireDate, inSameDayAs: date) else { return false }
            
            if calendar.isDate(ping.fireDate, inSameDayAs: date) { return true }
            guard date >= calendar.startOfDay(for: ping.fireDate) else { return false }
            
            switch ping.recurrence {
            case .daily: return true
            case .weekly:
                return calendar.component(.weekday, from: ping.fireDate) == calendar.component(.weekday, from: date)
            case .monthly:
                return calendar.component(.day, from: ping.fireDate) == calendar.component(.day, from: date)
            case .yearly:
                let fc = calendar.dateComponents([.month, .day], from: ping.fireDate)
                let dc = calendar.dateComponents([.month, .day], from: date)
                return fc.month == dc.month && fc.day == dc.day
            case .none: return false
            }
        }
        
        let hasActionable = memories.contains { memory in
            memory.isActionable && !memory.isCompleted &&
            memory.detectedDate != nil &&
            calendar.isDate(memory.detectedDate!, inSameDayAs: date)
        }
        
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                selectedDate = date
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.custom("DMSans-Medium", size: 15))
                    .foregroundColor(
                        isSelected ? .white :
                            !isCurrentMonth ? .gray.opacity(0.4) :
                            isToday ? .oceanTeal :
                                .deepNavy
                    )
                
                HStack(spacing: 2) {
                    if hasActionable {
                        Circle()
                            .fill(isSelected ? Color.white : Color.oceanTeal)
                            .frame(width: 4, height: 4)
                    }
                    if hasPings {
                        Circle()
                            .fill(isSelected ? Color.white.opacity(0.7) : Color.coral)
                            .frame(width: 4, height: 4)
                    }
                    if hasMemories && !hasActionable && !hasPings {
                        Circle()
                            .fill(isSelected ? Color.white.opacity(0.5) : Color.seafoam)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.oceanTeal)
                            .frame(width: 38, height: 38)
                    } else if isToday {
                        Circle()
                            .stroke(Color.oceanTeal, lineWidth: 1.5)
                            .frame(width: 38, height: 38)
                    }
                }
            )
        }
    }
    
    // MARK: - Selected Date Content
    
    private var selectedDateContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if calendar.isDateInToday(selectedDate) {
                    Text("Today")
                        .font(.custom("DMSans-Medium", size: 16))
                        .foregroundColor(.deepNavy)
                } else {
                    Text(selectedDate, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.custom("DMSans-Medium", size: 16))
                        .foregroundColor(.deepNavy)
                }
                
                Spacer()
                
                let total = selectedDateMemories.count + selectedDatePings.count
                if total > 0 {
                    Text("\(total) \(total == 1 ? "item" : "items")")
                        .font(.custom("DMMono-Regular", size: 13))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            if selectedDateMemories.isEmpty && selectedDatePings.isEmpty {
                VStack(spacing: 12) {
                    Spacer().frame(height: 20)
                    Image(systemName: "calendar")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("Nothing on this day")
                        .font(.custom("DMSans-Regular", size: 15))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(selectedDatePings) { ping in
                        if let memory = memories.first(where: { $0.id == ping.memoryId }) {
                            calendarPingRow(ping: ping, memory: memory)
                                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        modelContext.delete(memory)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .tint(.red)
                                }
                        }
                    }
                    
                    ForEach(selectedDateMemories) { memory in
                        calendarMemoryRow(memory: memory)
                            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(memory)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                    }
                }
                .listStyle(.plain)
                .background(Color.pearl)
            }
        }
    }
    
    // MARK: - Calendar Memory Row
    
    private func calendarMemoryRow(memory: Memory) -> some View {
        HStack(spacing: 12) {
            if memory.isActionable {
                Button {
                                    withAnimation(.spring(duration: 0.3)) {
                                        memory.isCompleted.toggle()
                                        memory.completedAt = memory.isCompleted ? Date() : nil
                                        memory.updatedAt = Date()
                                        
                                        let memoryPings = pings.filter { $0.memoryId == memory.id }
                                        for ping in memoryPings {
                                            ping.isActive = !memory.isCompleted
                                            if memory.isCompleted {
                                                NotificationService.shared.cancelPing(pingId: ping.id)
                                            } else {
                                                NotificationService.shared.schedulePing(ping: ping, memoryText: memory.text)
                                            }
                                        }
                                    }
                                } label: {
                            if memory.isCompleted {
                                ZStack {
                                    Circle()
                                        .fill(Color.oceanTeal)
                                        .frame(width: 24, height: 24)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            } else {
                                Circle()
                                    .stroke(Color.oceanTeal, lineWidth: 2)
                                    .frame(width: 24, height: 24)
                            }
                        }
                    } else if let echo = echos.first(where: { $0.id == memory.echoId }) {
                        Text(echo.emoji)
                            .font(.system(size: 16))
                            .frame(width: 24)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(memory.text)
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(memory.isCompleted ? .gray : .deepNavy)
                            .strikethrough(memory.isCompleted)
                            .lineLimit(2)
                        
                        HStack(spacing: 8) {
                            if let echo = echos.first(where: { $0.id == memory.echoId }) {
                                HStack(spacing: 3) {
                                    Text(echo.emoji)
                                        .font(.system(size: 11))
                                    Text(echo.name)
                                        .font(.custom("DMSans-Medium", size: 12))
                                        .foregroundColor(.deepNavy)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.mist)
                                .clipShape(Capsule())
                            }
                            
                            if let date = memory.detectedDate {
                                Text(date, format: .dateTime.hour().minute())
                                    .font(.custom("DMMono-Regular", size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .onTapGesture {
                        editingMemory = memory
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Button {
                            snoozeMemory = memory
                            showSnoozeSheet = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.mist)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "moon.zzz")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.oceanTeal)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            editingMemory = memory
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.mist)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "pencil")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.oceanTeal)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
            }
            
            // MARK: - Calendar Ping Row
            
            private func calendarPingRow(ping: Ping, memory: Memory) -> some View {
                HStack(spacing: 12) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.oceanTeal)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(memory.text)
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(.deepNavy)
                            .lineLimit(2)
                        
                        HStack(spacing: 8) {
                            Text(ping.fireTime, format: .dateTime.hour().minute())
                                .font(.custom("DMMono-Regular", size: 12))
                                .foregroundColor(.gray)
                            
                            if ping.recurrence != .none {
                                Text(ping.recurrence.rawValue.capitalized)
                                    .font(.custom("DMMono-Regular", size: 11))
                                    .foregroundColor(.oceanTeal)
                            }
                        }
                    }
                    .onTapGesture {
                        editingMemory = memory
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Button {
                            snoozeMemory = memory
                            showSnoozeSheet = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.mist)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "moon.zzz")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.oceanTeal)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            editingMemory = memory
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.mist)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "pencil")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.oceanTeal)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
            }
            
            // MARK: - Days in Month
            
            private func daysInMonth() -> [Date?] {
                let range = calendar.range(of: .day, in: .month, for: displayedMonth)!
                let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))!
                let firstWeekday = calendar.component(.weekday, from: firstDay)
                
                var days: [Date?] = []
                
                for _ in 0..<(firstWeekday - 1) {
                    days.append(nil)
                }
                
                for day in range {
                    if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                        days.append(date)
                    }
                }
                
                while days.count % 7 != 0 {
                    days.append(nil)
                }
                
                return days
            }
        }
        
        #Preview {
            CalendarTabView()
                .modelContainer(for: [Memory.self, Echo.self, Ping.self], inMemory: true)
        }
