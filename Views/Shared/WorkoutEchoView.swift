//
//  WorkoutEchoView.swift
//  Orca
//
//  Created by David Piliponskiy on 3/28/26.
//

import SwiftUI

struct WorkoutPR {
    let exerciseName: String
    let weight: Double
    let unit: String
    let date: Date
}

struct WorkoutEchoView: View {
    let memories: [Memory]
    @State private var showQuickLog = false
    @Binding var detailMemory: Memory?
    @State private var summaries: [UUID: String] = [:]

    // MARK: - Computed Data

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

    private var todaysWorkout: Memory? {
        let cal = Calendar.current
        return memories.first { cal.isDateInToday($0.createdAt) }
    }

    private var recentSessions: [(memory: Memory, result: WorkoutParseResult)] {
        memories
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(5)
            .map { ($0, WorkoutParser.shared.parse(text: $0.text)) }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Subtitle + Quick Log button
            HStack {
                Text("\(memories.count) \(memories.count == 1 ? "session" : "sessions") · updated just now")
                    .font(.custom("DMSans-Regular", size: 13))
                    .foregroundColor(.gray)
                Spacer()

                if let today = todaysWorkout {
                    Button {
                        detailMemory = today
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 12))
                            Text("Today's Workout")
                                .font(.custom("DMSans-Medium", size: 13))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.oceanTeal)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    showQuickLog = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: todaysWorkout != nil ? "arrow.right.circle.fill" : "plus")
                            .font(.system(size: 12, weight: .medium))
                        Text(todaysWorkout != nil ? "Continue Workout" : "Start Workout")
                            .font(.custom("DMSans-Medium", size: 13))
                    }
                    .foregroundColor(todaysWorkout != nil ? .oceanTeal : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(todaysWorkout != nil ? Color.oceanTeal.opacity(0.1) : Color.oceanTeal)
                    .clipShape(Capsule())
                    .overlay(todaysWorkout != nil ? Capsule().stroke(Color.oceanTeal.opacity(0.3), lineWidth: 1) : nil)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)

            weekStripCard

            if !allTimePRs.isEmpty { prCard }

            if !recentSessions.isEmpty { recentSessionsCard }

            Text("Tap a day or session to see your full breakdown")
                .font(.custom("DMSans-Regular", size: 12))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
                .padding(.bottom, 8)
        }
        .padding(.bottom, 8)
        .sheet(isPresented: $showQuickLog) {
            QuickLogView()
        }
    }

    // MARK: - Week Strip

    private var weekStripCard: some View {
        let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
        let activeColor = Color.oceanTeal
        let inactiveColor = Color.gray.opacity(0.15)

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
                        if let memory = day.memory {
                            detailMemory = memory
                        }
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                if day.hasWorkout {
                                    Circle()
                                        .fill(day.isToday ? activeColor.opacity(0.7) : activeColor)
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                } else {
                                    Circle()
                                        .fill(day.isToday ? activeColor.opacity(0.15) : inactiveColor)
                                        .frame(width: 32, height: 32)
                                    if day.isToday {
                                        Circle()
                                            .stroke(activeColor.opacity(0.4), lineWidth: 1.5)
                                            .frame(width: 32, height: 32)
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

    // MARK: - PR Card

    private var prCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PERSONAL RECORDS")
                .font(.custom("DMSans-Medium", size: 11))
                .foregroundColor(.gray)
                .tracking(0.5)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            ForEach(Array(allTimePRs.prefix(5).enumerated()), id: \.offset) { index, pr in
                if index > 0 { Divider().padding(.horizontal, 16) }
                HStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 13))
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
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
        .padding(.horizontal, 20)
    }

    // MARK: - Recent Sessions Card

    private var recentSessionsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("RECENT SESSIONS")
                .font(.custom("DMSans-Medium", size: 11))
                .foregroundColor(.gray)
                .tracking(0.5)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            ForEach(Array(recentSessions.enumerated()), id: \.offset) { index, item in
                if index > 0 { Divider().padding(.horizontal, 16) }
                Button {
                    detailMemory = item.memory
                } label: {
                    sessionRow(memory: item.memory, result: item.result)
                }
                .buttonStyle(.plain)
            }
            Spacer().frame(height: 8)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
        .padding(.horizontal, 20)
        // Fetch AI summaries for all recent sessions in the background
        .task {
            for (memory, _) in recentSessions {
                guard summaries[memory.id] == nil else { continue }
                let text = memory.text
                let id = memory.id
                if let summary = await AppleIntelligenceService.shared.summarizeWorkout(from: text) {
                    await MainActor.run { summaries[id] = summary }
                }
            }
        }
    }

    @ViewBuilder
    private func sessionRow(memory: Memory, result: WorkoutParseResult) -> some View {
        let isCardio = result.exercises.allSatisfy { $0.isCardio }
        let isLift = !isCardio && result.exercises.contains { !$0.isCardio }
        let icon: String = isCardio ? "figure.run" : "figure.strengthtraining.traditional"

        // Use AI summary if available, fall back to deterministic title
        let title: String = summaries[memory.id] ?? {
            if let type = result.sessionType { return type }
            let names = result.exercises.map { $0.name }.prefix(2).joined(separator: " + ")
            return names.isEmpty ? "Workout session" : names
        }()

        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.oceanTeal.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(.oceanTeal)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.custom("DMSans-Medium", size: 14))
                    .foregroundColor(.deepNavy)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(relativeDate(memory.createdAt))
                        .font(.custom("DMMono-Regular", size: 12))
                        .foregroundColor(.gray)

                    // Only show the extra detail line when AI summary is not yet loaded
                    if summaries[memory.id] == nil {
                        if isLift {
                            let liftExercises = result.exercises.filter { !$0.isCardio }
                            Text("· \(liftExercises.count) exercises")
                                .font(.custom("DMMono-Regular", size: 12))
                                .foregroundColor(.gray)
                        } else if let cardio = result.exercises.first(where: { $0.isCardio }) {
                            if let dur = cardio.durationMinutes {
                                Text("· \(Int(dur)) min")
                                    .font(.custom("DMMono-Regular", size: 12))
                                    .foregroundColor(.gray)
                            }
                            if let pace = cardio.pace {
                                Text("· \(pace)")
                                    .font(.custom("DMMono-Regular", size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }

            Spacer()

            if result.hasPR {
                Text("PR")
                    .font(.custom("DMSans-Medium", size: 11))
                    .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.0))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
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

    // MARK: - Helpers

    private func relativeDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: Date())).day ?? 0
        if days < 7 { return date.formatted(.dateTime.weekday(.abbreviated)) }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}
