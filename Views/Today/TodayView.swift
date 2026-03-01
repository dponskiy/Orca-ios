//
//  Untitled.swift
//  Orca
//
//  Created by David Piliponskiy on 2/27/26.
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: \Memory.createdAt, order: .reverse) private var allMemories: [Memory]
    @Query private var pings: [Ping]
    @Query private var echos: [Echo]
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedDate: Date = Date()
    @State private var showWeekView = false
    @State private var editingMemory: Memory?
    @State private var showCompleted = false
    @State private var snoozeMemory: Memory?
    @State private var showSnoozeSheet = false
    
    private let calendar = Calendar.current
    
    // MARK: - Filtered Data
    
    var todayTasks: [Memory] {
            allMemories.filter { memory in
                guard memory.isActionable && !memory.isCompleted else { return false }
                
                // Show on detected date
                if isTaskForDate(memory: memory) { return true }
                
                // Also show if there's a recurring ping for this day
                let memoryPings = pings.filter { $0.memoryId == memory.id && $0.isActive }
                for ping in memoryPings {
                    guard selectedDate >= calendar.startOfDay(for: ping.fireDate) else { continue }
                    switch ping.recurrence {
                    case .daily:
                        return true
                    case .weekly:
                        let fireWeekday = calendar.component(.weekday, from: ping.fireDate)
                        let selectedWeekday = calendar.component(.weekday, from: selectedDate)
                        if fireWeekday == selectedWeekday { return true }
                    case .monthly:
                        let fireDay = calendar.component(.day, from: ping.fireDate)
                        let selectedDay = calendar.component(.day, from: selectedDate)
                        if fireDay == selectedDay { return true }
                    case .yearly:
                        let fc = calendar.dateComponents([.month, .day], from: ping.fireDate)
                        let sc = calendar.dateComponents([.month, .day], from: selectedDate)
                        if fc.month == sc.month && fc.day == sc.day { return true }
                    case .none:
                        continue
                    }
                }
                return false
            }
            .sorted { m1, m2 in
                let d1 = m1.detectedDate ?? m1.createdAt
                let d2 = m2.detectedDate ?? m2.createdAt
                return d1 < d2
            }
        }
    
    var overdueTasks: [Memory] {
        guard calendar.isDateInToday(selectedDate) else { return [] }
        return allMemories.filter { memory in
            memory.isActionable && !memory.isCompleted &&
            memory.detectedDate != nil &&
            memory.detectedDate! < calendar.startOfDay(for: Date()) &&
            !calendar.isDate(memory.detectedDate!, inSameDayAs: Date())
        }
        .sorted { ($0.detectedDate ?? $0.createdAt) < ($1.detectedDate ?? $1.createdAt) }
    }
    
    var completedTasks: [Memory] {
        allMemories.filter { memory in
            memory.isActionable && memory.isCompleted &&
            memory.completedAt != nil &&
            calendar.isDate(memory.completedAt!, inSameDayAs: selectedDate)
        }
    }
    
    var todayPings: [Ping] {
        pings.filter { ping in
                    guard ping.isActive,
                          let memory = allMemories.first(where: { $0.id == ping.memoryId }) else { return false }
                    
                    // Hide pings for recurring actionable tasks (they show in TO DO)
                    if memory.isActionable && ping.recurrence != .none { return false }
            
            if calendar.isDate(ping.fireDate, inSameDayAs: selectedDate) {
                return true
            }
            
            guard selectedDate >= calendar.startOfDay(for: ping.fireDate) else { return false }
            
            if let eventDate = memory.detectedDate,
                           !calendar.isDate(ping.fireDate, inSameDayAs: eventDate),
                           selectedDate > calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: eventDate) ?? eventDate) {
                            return false
                        }
            
            switch ping.recurrence {
            case .daily:
                return true
            case .weekly:
                let fireWeekday = calendar.component(.weekday, from: ping.fireDate)
                let selectedWeekday = calendar.component(.weekday, from: selectedDate)
                return fireWeekday == selectedWeekday
            case .monthly:
                let fireDay = calendar.component(.day, from: ping.fireDate)
                let selectedDay = calendar.component(.day, from: selectedDate)
                return fireDay == selectedDay
            case .yearly:
                let fireComponents = calendar.dateComponents([.month, .day], from: ping.fireDate)
                let selectedComponents = calendar.dateComponents([.month, .day], from: selectedDate)
                return fireComponents.month == selectedComponents.month && fireComponents.day == selectedComponents.day
            case .none:
                return false
            }
        }
    }
    
    var todayEvents: [Memory] {
        allMemories.filter { memory in
            !memory.isActionable && !memory.isCompleted &&
            memory.detectedDate != nil &&
            calendar.isDate(memory.detectedDate!, inSameDayAs: selectedDate)
        }
        .sorted { m1, m2 in
            (m1.detectedDate ?? m1.createdAt) < (m2.detectedDate ?? m2.createdAt)
        }
    }
    
    var droppedToday: [Memory] {
        allMemories.filter { memory in
            !memory.isActionable &&
            memory.detectedDate == nil &&
            calendar.isDate(memory.createdAt, inSameDayAs: selectedDate)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                dateHeader
                
                if showWeekView {
                    weekStrip
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        statsBar
                        
                        if !overdueTasks.isEmpty {
                            overdueSection
                        }
                        
                        if !todayTasks.isEmpty {
                            todoSection
                        }
                        
                        if !todayPings.isEmpty {
                            pingsSection
                        }
                        
                        if !todayEvents.isEmpty {
                            eventsSection
                        }
                        
                        if !completedTasks.isEmpty {
                            completedSection
                        }
                        
                        if !droppedToday.isEmpty {
                            droppedSection
                        }
                        
                        if todayTasks.isEmpty && todayPings.isEmpty && todayEvents.isEmpty && droppedToday.isEmpty && completedTasks.isEmpty && overdueTasks.isEmpty {
                            emptyState
                        }
                        
                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .background(Color.pearl)
            .onAppear {
                selectedDate = Date()
            }
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
    
    // MARK: - Date Header
    private var dateHeader: some View {
        HStack {
            Button {
                selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.oceanTeal)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                if calendar.isDateInToday(selectedDate) {
                    Text("Today")
                        .font(.custom("DMSans-Medium", size: 18))
                        .foregroundColor(.deepNavy)
                } else if calendar.isDateInYesterday(selectedDate) {
                    Text("Yesterday")
                        .font(.custom("DMSans-Medium", size: 18))
                        .foregroundColor(.deepNavy)
                } else if calendar.isDateInTomorrow(selectedDate) {
                    Text("Tomorrow")
                        .font(.custom("DMSans-Medium", size: 18))
                        .foregroundColor(.deepNavy)
                } else {
                    Text(selectedDate, format: .dateTime.weekday(.wide))
                        .font(.custom("DMSans-Medium", size: 18))
                        .foregroundColor(.deepNavy)
                }
                
                Text(selectedDate, format: .dateTime.month(.wide).day().year())
                    .font(.custom("DMSans-Regular", size: 13))
                    .foregroundColor(.gray)
            }
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.2)) {
                    showWeekView.toggle()
                }
            }
            
            Spacer()
            
            Button {
                selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.oceanTeal)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white)
    }
    
    // MARK: - Week Strip
    private var weekStrip: some View {
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)) ?? selectedDate
        
        return HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { offset in
                let day = calendar.date(byAdding: .day, value: offset, to: startOfWeek) ?? selectedDate
                let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
                let isToday = calendar.isDateInToday(day)
                let hasTasks = allMemories.contains { $0.isActionable && !$0.isCompleted && isTaskForDate(memory: $0, for: day) }
                
                Button {
                    selectedDate = day
                } label: {
                    VStack(spacing: 4) {
                        Text(day, format: .dateTime.weekday(.narrow))
                            .font(.custom("DMSans-Medium", size: 11))
                            .foregroundColor(isSelected ? .white : .gray)
                        
                        Text(day, format: .dateTime.day())
                            .font(.custom("DMSans-Medium", size: 15))
                            .foregroundColor(isSelected ? .white : .deepNavy)
                        
                        Circle()
                            .fill(hasTasks ? (isSelected ? Color.white : Color.oceanTeal) : Color.clear)
                            .frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isSelected ? Color.oceanTeal : (isToday ? Color.mist : Color.clear))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(Color.white)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Stats Bar
    private var statsBar: some View {
        let total = todayTasks.count + completedTasks.count + overdueTasks.count
        let done = completedTasks.count
        
        return HStack(spacing: 16) {
            if total > 0 {
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .stroke(Color.mist, lineWidth: 3)
                            .frame(width: 32, height: 32)
                        Circle()
                            .trim(from: 0, to: total > 0 ? CGFloat(done) / CGFloat(total) : 0)
                            .stroke(Color.oceanTeal, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 32, height: 32)
                            .rotationEffect(.degrees(-90))
                    }
                    
                    Text("\(done)/\(total) done")
                        .font(.custom("DMSans-Medium", size: 14))
                        .foregroundColor(.deepNavy)
                }
            }
            
            if !overdueTasks.isEmpty {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.coral)
                        .frame(width: 8, height: 8)
                    Text("\(overdueTasks.count) overdue")
                        .font(.custom("DMSans-Medium", size: 13))
                        .foregroundColor(.coral)
                }
            }
            
            if !todayPings.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.oceanTeal)
                    Text("\(todayPings.count) \(todayPings.count == 1 ? "ping" : "pings")")
                        .font(.custom("DMSans-Medium", size: 13))
                        .foregroundColor(.oceanTeal)
                }
            }
            
            if !todayEvents.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.seafoam)
                    Text("\(todayEvents.count) \(todayEvents.count == 1 ? "event" : "events")")
                        .font(.custom("DMSans-Medium", size: 13))
                        .foregroundColor(.seafoam)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Overdue Section
    private var overdueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.coral)
                    .frame(width: 8, height: 8)
                Text("OVERDUE")
                    .font(.custom("DMSans-Medium", size: 13))
                    .foregroundColor(.coral)
                    .tracking(1)
            }
            
            ForEach(overdueTasks) { memory in
                taskRow(memory: memory, isOverdue: true)
            }
        }
    }
    
    // MARK: - To Do Section
    private var todoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TO DO")
                .font(.custom("DMSans-Medium", size: 13))
                .foregroundColor(.oceanTeal)
                .tracking(1)
            
            ForEach(todayTasks) { memory in
                taskRow(memory: memory, isOverdue: false)
            }
        }
    }
    
    // MARK: - Pings Section
    private var pingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PINGS")
                .font(.custom("DMSans-Medium", size: 13))
                .foregroundColor(.oceanTeal)
                .tracking(1)
            
            ForEach(todayPings) { ping in
                if let memory = allMemories.first(where: { $0.id == ping.memoryId }) {
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
            }
        }
    }
    
    // MARK: - Events Section
    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EVENTS")
                .font(.custom("DMSans-Medium", size: 13))
                .foregroundColor(.seafoam)
                .tracking(1)
            
            ForEach(todayEvents) { memory in
                HStack(spacing: 12) {
                    if let echo = echos.first(where: { $0.id == memory.echoId }) {
                        Text(echo.emoji)
                            .font(.system(size: 16))
                            .frame(width: 24)
                    } else {
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.seafoam)
                            .frame(width: 24)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(memory.text)
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(.deepNavy)
                            .lineLimit(2)
                        
                        HStack(spacing: 8) {
                            if let echo = echos.first(where: { $0.id == memory.echoId }) {
                                Text(echo.name)
                                    .font(.custom("DMSans-Medium", size: 12))
                                    .foregroundColor(.deepNavy)
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
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
            }
        }
    }
    
    // MARK: - Completed Section
    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    showCompleted.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text("COMPLETED")
                        .font(.custom("DMSans-Medium", size: 13))
                        .foregroundColor(.gray)
                        .tracking(1)
                    
                    Text("\(completedTasks.count)")
                        .font(.custom("DMMono-Regular", size: 12))
                        .foregroundColor(.gray)
                    
                    Image(systemName: showCompleted ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
            
            if showCompleted {
                ForEach(completedTasks) { memory in
                    completedRow(memory: memory)
                }
            }
        }
    }
    
    // MARK: - Dropped Section
    private var droppedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DROPPED TODAY")
                .font(.custom("DMSans-Medium", size: 13))
                .foregroundColor(.gray)
                .tracking(1)
            
            ForEach(droppedToday) { memory in
                HStack(spacing: 12) {
                    if let echo = echos.first(where: { $0.id == memory.echoId }) {
                        Text(echo.emoji)
                            .font(.system(size: 16))
                            .frame(width: 24)
                    }
                    
                    Text(memory.text)
                        .font(.custom("DMSans-Regular", size: 15))
                        .foregroundColor(.deepNavy)
                        .lineLimit(2)
                        .onTapGesture {
                            editingMemory = memory
                        }
                    
                    Spacer()
                }
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
            }
        }
    }
    
    // MARK: - Task Row
    private func taskRow(memory: Memory, isOverdue: Bool) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    memory.isCompleted = true
                    memory.completedAt = Date()
                    memory.updatedAt = Date()
                }
            } label: {
                Circle()
                    .stroke(isOverdue ? Color.coral : Color.oceanTeal, lineWidth: 2)
                    .frame(width: 24, height: 24)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(memory.text)
                    .font(.custom("DMSans-Regular", size: 15))
                    .foregroundColor(.deepNavy)
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
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(.custom("DMMono-Regular", size: 12))
                            .foregroundColor(isOverdue ? .coral : .gray)
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
    
    // MARK: - Completed Row
    private func completedRow(memory: Memory) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    memory.isCompleted = false
                    memory.completedAt = nil
                    memory.updatedAt = Date()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.oceanTeal)
                        .frame(width: 24, height: 24)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            Text(memory.text)
                .font(.custom("DMSans-Regular", size: 15))
                .foregroundColor(.gray)
                .strikethrough()
                .lineLimit(2)
            
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)
            
            Image(systemName: "checkmark.circle")
                .font(.system(size: 44))
                .foregroundColor(.seafoam.opacity(0.4))
            
            Text(calendar.isDateInToday(selectedDate) ? "All clear today" : "Nothing on this day")
                .font(.custom("DMSans-Medium", size: 18))
                .foregroundColor(.deepNavy)
            
            Text(calendar.isDateInToday(selectedDate) ? "Drop a memory with a task and it\u{2019}ll show up here" : "Tasks and memories for this day will appear here")
                .font(.custom("DMSans-Regular", size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Helpers
    
    private func isTaskForDate(memory: Memory, for date: Date? = nil) -> Bool {
        let targetDate = date ?? selectedDate
        
        if let detectedDate = memory.detectedDate {
            return calendar.isDate(detectedDate, inSameDayAs: targetDate)
        }
        
        return calendar.isDate(memory.createdAt, inSameDayAs: targetDate)
    }
}

// MARK: - Snooze Sheet
struct SnoozeSheet: View {
    let memory: Memory
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let calendar = Calendar.current
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(memory.text)
                    .font(.custom("DMSans-Regular", size: 15))
                    .foregroundColor(.deepNavy)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.pearl)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                Text("Snooze until...")
                    .font(.custom("DMSans-Medium", size: 16))
                    .foregroundColor(.deepNavy)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 8) {
                    snoozeOption(
                        icon: "sunrise",
                        label: "Tomorrow",
                        sublabel: formatDate(daysFromNow: 1),
                        date: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                    )
                    
                    snoozeOption(
                        icon: "calendar.badge.plus",
                        label: "In 2 days",
                        sublabel: formatDate(daysFromNow: 2),
                        date: calendar.date(byAdding: .day, value: 2, to: Date()) ?? Date()
                    )
                    
                    snoozeOption(
                        icon: "calendar",
                        label: "Next week",
                        sublabel: formatDate(daysFromNow: 7),
                        date: calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                    )
                    
                    snoozeOption(
                        icon: "calendar.badge.clock",
                        label: "Next month",
                        sublabel: formatDate(daysFromNow: 30),
                        date: calendar.date(byAdding: .month, value: 1, to: Date()) ?? Date()
                    )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Or pick a date")
                        .font(.custom("DMSans-Medium", size: 14))
                        .foregroundColor(.gray)
                    
                    DatePicker(
                        "Snooze date",
                        selection: Binding(
                            get: { memory.detectedDate ?? Date() },
                            set: { newDate in
                                memory.detectedDate = newDate
                                memory.updatedAt = Date()
                                onDone()
                            }
                        ),
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .tint(.oceanTeal)
                }
                
                Spacer()
            }
            .padding(20)
            .navigationTitle("Snooze")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func snoozeOption(icon: String, label: String, sublabel: String, date: Date) -> some View {
        Button {
            memory.detectedDate = date
            memory.updatedAt = Date()
            onDone()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.oceanTeal)
                    .frame(width: 24)
                
                Text(label)
                    .font(.custom("DMSans-Medium", size: 15))
                    .foregroundColor(.deepNavy)
                
                Spacer()
                
                Text(sublabel)
                    .font(.custom("DMMono-Regular", size: 13))
                    .foregroundColor(.gray)
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        }
    }
    
    private func formatDate(daysFromNow days: Int) -> String {
        let date = calendar.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}

#Preview {
    TodayView()
        .modelContainer(for: [Memory.self, Echo.self, Ping.self], inMemory: true)
}
