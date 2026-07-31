//
//  WorkoutModeView.swift
//  Orca
//

import SwiftUI
import SwiftData

struct WorkoutModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Memory.createdAt, order: .reverse) private var allMemories: [Memory]
    @Query private var allEchos: [Echo]
    @State private var showQuickLog = false
    @State private var detailMemory: Memory?
    @State private var showPRs = false

    // MARK: - Data

    private var workoutEcho: Echo? {
        allEchos.first { $0.name.lowercased().contains("workout") }
    }

    private var memories: [Memory] {
        guard let id = workoutEcho?.id else { return [] }
        return allMemories.filter { $0.echoId == id }
    }

    private var allTimePRs: [WorkoutPR] {
        var prMap: [String: WorkoutPR] = [:]
        for memory in memories.sorted(by: { $0.createdAt < $1.createdAt }) {
            let result = WorkoutParser.shared.parse(text: memory.text)
            for exercise in result.exercises where !exercise.isCardio {
                let maxWeight = exercise.sets.compactMap { $0.weight }.max() ?? 0
                let unit = exercise.sets.first?.unit ?? "lb"
                if maxWeight > 0 {
                    if let existing = prMap[exercise.name] {
                        if maxWeight > existing.weight {
                            prMap[exercise.name] = WorkoutPR(exerciseName: exercise.name, weight: maxWeight, unit: unit, date: memory.createdAt)
                        }
                    } else {
                        prMap[exercise.name] = WorkoutPR(exerciseName: exercise.name, weight: maxWeight, unit: unit, date: memory.createdAt)
                    }
                }
            }
        }
        return Array(prMap.values).sorted { $0.date > $1.date }
    }

    private var weekDays: [(date: Date, hasWorkout: Bool, isToday: Bool, memory: Memory?)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysFromMon = (weekday + 5) % 7
        guard let monday = cal.date(byAdding: .day, value: -daysFromMon, to: today) else { return [] }
        return (0..<7).map { i in
            let day = cal.date(byAdding: .day, value: i, to: monday) ?? today
            let isToday = cal.isDate(day, inSameDayAs: Date())
            let memory = memories.first { cal.isDate($0.createdAt, inSameDayAs: day) }
            return (day, memory != nil, isToday, memory)
        }
    }

    private var workoutDaysThisWeek: Int { weekDays.filter { $0.hasWorkout }.count }

    private var recentSessions: [Memory] {
        Array(memories.prefix(6))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // MARK: Big Quick Log CTA
                    Button { showQuickLog = true } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Start Quick Log")
                                    .font(.custom("DMSans-Medium", size: 17))
                                    .foregroundColor(.white)
                                Text("Log sets by voice or tap")
                                    .font(.custom("DMSans-Regular", size: 13))
                                    .foregroundColor(.white.opacity(0.75))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(18)
                        .background(Color.oceanTeal)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.oceanTeal.opacity(0.4), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // MARK: Week Strip
                    weekStripCard

                    // MARK: Personal Records (collapsible)
                    if !allTimePRs.isEmpty {
                        prSection
                    }

                    // MARK: Recent Sessions
                    if !recentSessions.isEmpty {
                        recentSessionsCard
                    }

                    if memories.isEmpty {
                        emptyState
                    }

                    Spacer().frame(height: 40)
                }
            }
            .background(Color.pearl)
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.oceanTeal)
                }
            }
        }
        .sheet(isPresented: $showQuickLog) {
            QuickLogView()
        }
        .sheet(item: $detailMemory) {
            MemoryDetailView(memory: $0)
        }
    }

    // MARK: - Week Strip

    private var weekStripCard: some View {
        let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("THIS WEEK")
                    .font(.custom("DMSans-Medium", size: 11))
                    .foregroundColor(.gray)
                    .tracking(0.5)
                Spacer()
                Text("\(workoutDaysThisWeek) of 7 days")
                    .font(.custom("DMMono-Regular", size: 12))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            HStack(spacing: 0) {
                ForEach(Array(weekDays.enumerated()), id: \.offset) { i, day in
                    Button {
                        if let memory = day.memory { detailMemory = memory }
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                if day.hasWorkout {
                                    Circle().fill(day.isToday ? Color.oceanTeal.opacity(0.7) : Color.oceanTeal).frame(width: 32, height: 32)
                                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                                } else {
                                    Circle().fill(day.isToday ? Color.oceanTeal.opacity(0.15) : Color.gray.opacity(0.12)).frame(width: 32, height: 32)
                                    if day.isToday {
                                        Circle().stroke(Color.oceanTeal.opacity(0.4), lineWidth: 1.5).frame(width: 32, height: 32)
                                    }
                                }
                            }
                            Text(dayLabels[i])
                                .font(.custom("DMMono-Regular", size: 11))
                                .foregroundColor(day.isToday ? .oceanTeal : .gray)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .disabled(!day.hasWorkout)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
        .padding(.horizontal, 20)
    }

    // MARK: - PR Section (collapsible)

    private var prSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.3)) { showPRs.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.0))
                    Text("Personal Records")
                        .font(.custom("DMSans-Medium", size: 15))
                        .foregroundColor(.deepNavy)
                    Text("· \(allTimePRs.count)")
                        .font(.custom("DMMono-Regular", size: 13))
                        .foregroundColor(.gray)
                    Spacer()
                    Image(systemName: showPRs ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            if showPRs {
                Divider().padding(.horizontal, 16)
                ForEach(Array(allTimePRs.prefix(8).enumerated()), id: \.offset) { index, pr in
                    if index > 0 { Divider().padding(.horizontal, 16) }
                    HStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.0))
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pr.exerciseName)
                                .font(.custom("DMSans-Medium", size: 14))
                                .foregroundColor(.deepNavy)
                            Text(relativeDate(pr.date))
                                .font(.custom("DMMono-Regular", size: 12))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        HStack(spacing: 3) {
                            Text(pr.weight.truncatingRemainder(dividingBy: 1) == 0
                                 ? "\(Int(pr.weight))" : String(format: "%.1f", pr.weight))
                                .font(.custom("DMSans-Medium", size: 17))
                                .foregroundColor(.deepNavy)
                            Text(pr.unit)
                                .font(.custom("DMMono-Regular", size: 13))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                Spacer().frame(height: 8)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
        .padding(.horizontal, 20)
    }

    // MARK: - Recent Sessions

    private var recentSessionsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("RECENT SESSIONS")
                .font(.custom("DMSans-Medium", size: 11))
                .foregroundColor(.gray)
                .tracking(0.5)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            ForEach(Array(recentSessions.enumerated()), id: \.offset) { index, memory in
                if index > 0 { Divider().padding(.horizontal, 16) }
                let result = WorkoutParser.shared.parse(text: memory.text)
                Button { detailMemory = memory } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.oceanTeal.opacity(0.1))
                                .frame(width: 32, height: 32)
                            Image(systemName: result.exercises.allSatisfy { $0.isCardio } ? "figure.run" : "figure.strengthtraining.traditional")
                                .font(.system(size: 13))
                                .foregroundColor(.oceanTeal)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            // Show day type from first line if present
                            let title = sessionDisplayTitle(memory: memory, result: result)
                            Text(title)
                                .font(.custom("DMSans-Medium", size: 14))
                                .foregroundColor(.deepNavy)
                                .lineLimit(1)
                            Text(relativeDate(memory.createdAt))
                                .font(.custom("DMMono-Regular", size: 12))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        if result.hasPR {
                            Text("PR")
                                .font(.custom("DMSans-Medium", size: 11))
                                .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.0))
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Color(red: 0.85, green: 0.55, blue: 0.0).opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                            .foregroundColor(.gray.opacity(0.3))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
            Spacer().frame(height: 8)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
        .padding(.horizontal, 20)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 44))
                .foregroundColor(.oceanTeal.opacity(0.3))
            Text("No sessions yet")
                .font(.custom("DMSans-Medium", size: 18))
                .foregroundColor(.deepNavy)
            Text("Tap Quick Log to start your first session")
                .font(.custom("DMSans-Regular", size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Helpers

    private func sessionDisplayTitle(memory: Memory, result: WorkoutParseResult) -> String {
        let firstLine = memory.text.components(separatedBy: "\n").first ?? ""
        // If first line has a day type (e.g. "Chest Day · May 22"), show it
        let dayTypes = ["Chest Day", "Back Day", "Leg Day", "Shoulder Day", "Push Day", "Pull Day", "Full Body", "Cardio Day"]
        for dayType in dayTypes {
            if firstLine.contains(dayType) { return firstLine }
        }
        if let type = result.sessionType { return type }
        let names = result.exercises.map { $0.name }.prefix(2).joined(separator: " + ")
        return names.isEmpty ? firstLine : names
    }

    private func relativeDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: Date())).day ?? 0
        if days < 7 { return date.formatted(.dateTime.weekday(.abbreviated)) }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}
