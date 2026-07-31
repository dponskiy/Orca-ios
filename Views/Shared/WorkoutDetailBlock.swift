//
//  WorkoutDetailBlock.swift
//  Orca
//
//  Created by David Piliponskiy on 3/28/26.
//

import SwiftUI

struct WorkoutDetailBlock: View {
    let memory: Memory

    private var parsed: WorkoutParseResult {
        WorkoutParser.shared.parse(text: memory.text)
    }

    var body: some View {
        if !parsed.exercises.isEmpty {
            VStack(spacing: 10) {
                ForEach(Array(parsed.exercises.enumerated()), id: \.offset) { _, exercise in
                    if exercise.isCardio {
                        cardioCard(exercise)
                    } else {
                        liftingCard(exercise)
                    }
                }
            }
        }
    }

    // MARK: - Lifting Card

    private func splitNameAndEquipment(_ name: String) -> (baseName: String, equipment: String?) {
        if name.hasSuffix(")"), let range = name.range(of: " (") {
            return (String(name[..<range.lowerBound]), String(name[range.upperBound...].dropLast()))
        }
        return (name, nil)
    }

    @ViewBuilder
    private func liftingCard(_ exercise: ParsedExercise) -> some View {
        let (baseName, equipmentBadge) = splitNameAndEquipment(exercise.name)
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.oceanTeal.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 14))
                        .foregroundColor(.oceanTeal)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(baseName)
                        .font(.custom("DMSans-Medium", size: 16))
                        .foregroundColor(.deepNavy)
                    HStack(spacing: 6) {
                        Text(exercise.setSummary)
                            .font(.custom("DMMono-Regular", size: 12))
                            .foregroundColor(.gray)
                        Text("·")
                            .font(.custom("DMMono-Regular", size: 12))
                            .foregroundColor(.gray)
                        Text(exercise.muscleGroup)
                            .font(.custom("DMMono-Regular", size: 12))
                            .foregroundColor(.gray)
                        if let badge = equipmentBadge {
                            Text("·")
                                .font(.custom("DMMono-Regular", size: 12))
                                .foregroundColor(.gray)
                            Text(badge)
                                .font(.custom("DMMono-Regular", size: 11))
                                .foregroundColor(.oceanTeal)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.oceanTeal.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
                Spacer()
                if exercise.isPR {
                    Text("NEW PR")
                        .font(.custom("DMSans-Medium", size: 11))
                        .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.0))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.85, green: 0.55, blue: 0.0).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else if !exercise.setSummary.isEmpty {
                    Text(exercise.setSummary)
                        .font(.custom("DMSans-Medium", size: 12))
                        .foregroundColor(.oceanTeal)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.oceanTeal.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(16)

            if !exercise.sets.isEmpty {
                Divider().padding(.horizontal, 16)

                // Column headers
                HStack {
                    Text("SET")
                        .frame(width: 36, alignment: .leading)
                    Spacer()
                    Text("WEIGHT")
                        .frame(width: 80, alignment: .trailing)
                    Text("REPS")
                        .frame(width: 48, alignment: .trailing)
                }
                .font(.custom("DMSans-Medium", size: 11))
                .foregroundColor(.gray)
                .tracking(0.5)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 4)

                // Set rows
                ForEach(exercise.sets, id: \.setNumber) { set in
                    HStack {
                        Text("\(set.setNumber)")
                            .font(.custom("DMMono-Regular", size: 14))
                            .foregroundColor(.gray)
                            .frame(width: 36, alignment: .leading)
                        Spacer()
                        if let w = set.weight {
                            HStack(spacing: 3) {
                                Text(w.truncatingRemainder(dividingBy: 1) == 0
                                     ? "\(Int(w))" : String(format: "%.1f", w))
                                    .font(.custom("DMMono-Regular", size: 15))
                                    .foregroundColor(.deepNavy)
                                Text(set.unit)
                                    .font(.custom("DMMono-Regular", size: 12))
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 80, alignment: .trailing)
                        } else {
                            Text("—")
                                .font(.custom("DMMono-Regular", size: 15))
                                .foregroundColor(.gray)
                                .frame(width: 80, alignment: .trailing)
                        }
                        if let r = set.reps {
                            Text("\(r)")
                                .font(.custom("DMMono-Regular", size: 15))
                                .foregroundColor(.deepNavy)
                                .frame(width: 48, alignment: .trailing)
                        } else {
                            Text("—")
                                .font(.custom("DMMono-Regular", size: 15))
                                .foregroundColor(.gray)
                                .frame(width: 48, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    if set.setNumber != exercise.sets.last?.setNumber {
                        Divider().padding(.horizontal, 16)
                    }
                }

                // Total volume footer
                if let vol = exercise.totalVolume {
                    Divider().padding(.horizontal, 16)
                    HStack {
                        Text("TOTAL VOLUME")
                            .font(.custom("DMSans-Medium", size: 11))
                            .foregroundColor(.gray)
                            .tracking(0.5)
                        Spacer()
                        let unit = exercise.sets.first?.unit ?? "lb"
                        let volInt = Int(vol)
                        Text("\(volInt.formatted()) \(unit)")
                            .font(.custom("DMSans-Medium", size: 15))
                            .foregroundColor(.deepNavy)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - Cardio Card

    @ViewBuilder
    private func cardioCard(_ exercise: ParsedExercise) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.oceanTeal.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: cardioIcon(exercise.name))
                        .font(.system(size: 14))
                        .foregroundColor(.oceanTeal)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.custom("DMSans-Medium", size: 16))
                        .foregroundColor(.deepNavy)
                    Text("cardio")
                        .font(.custom("DMMono-Regular", size: 12))
                        .foregroundColor(.gray)
                }
                Spacer()
                if exercise.isPR {
                    Text("NEW PR")
                        .font(.custom("DMSans-Medium", size: 11))
                        .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.0))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.85, green: 0.55, blue: 0.0).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(16)

            Divider().padding(.horizontal, 16)

            // Stats row
            HStack(spacing: 0) {
                if let dur = exercise.durationMinutes {
                    statCell(label: "DURATION", value: formatDuration(dur))
                }
                if let dist = exercise.distanceValue, let unit = exercise.distanceUnit {
                    Divider().frame(height: 40)
                    statCell(label: "DISTANCE", value: "\(formatDistance(dist)) \(unit)")
                }
                if let pace = exercise.pace {
                    Divider().frame(height: 40)
                    statCell(label: "PACE", value: pace)
                }
                if let cal = exercise.calories {
                    Divider().frame(height: 40)
                    statCell(label: "CALORIES", value: "\(cal)")
                }
            }
            .padding(.vertical, 12)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.custom("DMSans-Medium", size: 10))
                .foregroundColor(.gray)
                .tracking(0.5)
            Text(value)
                .font(.custom("DMSans-Medium", size: 15))
                .foregroundColor(.deepNavy)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func cardioIcon(_ name: String) -> String {
        switch name {
        case "Run", "Treadmill": return "figure.run"
        case "Swim": return "figure.pool.swim"
        case "Cycling": return "figure.outdoor.cycle"
        case "Rowing": return "figure.rowing"
        case "Walk": return "figure.walk"
        default: return "stopwatch"
        }
    }

    private func formatDuration(_ minutes: Double) -> String {
        let m = Int(minutes)
        if m >= 60 {
            let h = m / 60; let rem = m % 60
            return rem == 0 ? "\(h)h" : "\(h)h \(rem)m"
        }
        return "\(m) min"
    }

    private func formatDistance(_ val: Double) -> String {
        val.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(val))" : String(format: "%.1f", val)
    }
}
