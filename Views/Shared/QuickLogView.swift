//
//  QuickLogView.swift
//  Orca
//
//  Created by David Piliponskiy on 3/28/26.
//

import SwiftUI
import SwiftData
import Speech
import AVFoundation
import Combine

// MARK: - Speech Manager

class SpeechRecognitionManager: ObservableObject {
    @Published var transcribedText = ""
    @Published var isListening = false

    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    func toggleListening(onResult: @escaping (String) -> Void) {
        if isListening { stopListening() } else { startListening(onResult: onResult) }
    }

    private func startListening(onResult: @escaping (String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized, let self = self else { return }
            DispatchQueue.main.async { self.startRecording(onResult: onResult) }
        }
    }

    private func startRecording(onResult: @escaping (String) -> Void) {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        recognitionTask = recognizer?.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            guard let self else { return }
            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                    onResult(result.bestTranscription.formattedString)
                }
            }
            if error != nil || result?.isFinal == true {
                DispatchQueue.main.async { self.stopListening() }
            }
        }

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()
        isListening = true
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        try? AVAudioSession.sharedInstance().setActive(false)
        isListening = false
    }
}

// MARK: - Logged Set Model

struct LoggedSet: Identifiable {
    let id = UUID()
    let text: String
    let exerciseName: String?
    let setSummary: String?
    let isCardio: Bool
    let isPR: Bool
}

// MARK: - View

struct QuickLogView: View {
    var onFinish: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var memories: [Memory]
    @Query private var echos: [Echo]
    @Query private var pings: [Ping]

    @StateObject private var speechManager = SpeechRecognitionManager()
    @State private var inputText = ""
    @FocusState private var textFieldFocused: Bool

    // Live session tracking
    @State private var loggedSets: [LoggedSet] = []
    @State private var sessionTitle: String = WorkoutSessionManager.sessionTitle()

    // Prior exercises (already logged today before opening Quick Log)
    @State private var priorExercises: [ParsedExercise] = []

    // Rest timer
    @State private var restSecondsRemaining = 0
    @State private var restTimer: Timer? = nil

    // Quick-add chips
    @State private var lastLoggedWeight: Double? = nil
    @State private var lastLoggedReps: Int? = nil
    @State private var lastLoggedExercise: String? = nil

    // Quick-add picker state
    @State private var quickAddWeightDelta: Double = 0
    @State private var quickAddSelectedReps: Int? = nil
    @State private var quickAddManualWeight: String = ""
    @State private var quickAddManualReps: String = ""

    // Session setup
    @State private var selectedDayTypes: [String] = []
    @State private var customDayType: String = ""
    @State private var selectedEquipment: String = "Free Weight"
    @State private var isSessionConfigured: Bool = false
    @State private var showEquipmentPicker: Bool = false

    // Tip card
    @State private var tipDismissed = false
    @AppStorage("quickLogTipDismissed") private var tipPermanentlyDismissed = false

    private let dayTypes = [
        "Chest", "Back", "Legs", "Shoulders", "Triceps", "Biceps",
        "Arms", "Core", "Glutes", "Push Day", "Pull Day", "Full Body", "Cardio"
    ]
    private let equipmentTypes = ["Free Weight", "Machine", "Bodyweight"]
    private let weightDeltas: [Double] = [0, 5, 10, 15, 20, 25]
    private let repOptions = [5, 6, 8, 10, 12]

    // Persistence keys
    private let kWorkoutDayDate = "workoutDayDate"
    private let kWorkoutDayTypes = "workoutDayTypes"

    // MARK: - Data

    private var workoutEcho: Echo? {
        echos.first { $0.name.lowercased().contains("workout") }
    }

    private var todayWorkoutMemory: Memory? {
        guard let id = workoutEcho?.id else { return nil }
        return memories.first {
            $0.echoId == id && Calendar.current.isDate($0.createdAt, inSameDayAs: Date())
        }
    }

    private var isFirstSession: Bool {
        guard let id = workoutEcho?.id else { return true }
        return !memories.contains { $0.echoId == id }
    }

    private var showTipCard: Bool {
        !tipDismissed && !tipPermanentlyDismissed && loggedSets.isEmpty
    }

    private var sessionSubtitle: String {
        if loggedSets.isEmpty && todayWorkoutMemory == nil {
            return "Start logging — it all stays together"
        }
        if !selectedDayTypes.isEmpty {
            let label = selectedDayTypes.map { $0.replacingOccurrences(of: " Day", with: "") }.joined(separator: " + ")
            return "\(label) · tap Done when finished"
        }
        return "Today's session · tap Done when finished"
    }

    private var restTimerDisplay: String {
        let m = restSecondsRemaining / 60
        let s = restSecondsRemaining % 60
        return "\(m):\(String(format: "%02d", s))"
    }

    private let examplePhrases = [
        "Bench press 185 for 3 sets of 8",
        "Squat 225 six times",
        "Ran 3 miles in 28 minutes",
        "Deadlift 315 — new PR",
    ]

    private let exampleChips = [
        ("Bench press", "bench press 135x8"),
        ("Squat", "squat 185x5"),
        ("Run", "ran 3 miles in 30 minutes"),
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    if showTipCard { tipCard }

                    if isSessionConfigured {
                        sessionHeaderCard
                    } else {
                        workoutTypePickerCard
                    }

                    if !priorExercises.isEmpty { todaySoFarCard }
                    if !loggedSets.isEmpty { liveSessionCard }
                    logASetCard
                    if restSecondsRemaining > 0 { restTimerCard }
                    if lastLoggedExercise != nil { quickAddSection }

                    Spacer().frame(height: 40)
                }
                .padding(20)
            }
            .background(Color.pearl)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Quick Log")
                            .font(.custom("DMSans-Medium", size: 17))
                            .foregroundColor(.deepNavy)
                        Text(sessionSubtitle)
                            .font(.custom("DMSans-Regular", size: 12))
                            .foregroundColor(.gray)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        speechManager.stopListening()
                        finishSession()
                        dismiss()
                        onFinish?()
                    }
                    .foregroundColor(.oceanTeal)
                }
            }
            .onAppear {
                loadTodaySession()
                if let existing = todayWorkoutMemory {
                    let parsed = WorkoutParser.shared.parse(text: existing.text)
                    priorExercises = parsed.exercises
                }
            }
        }
        .onDisappear { restTimer?.invalidate() }
    }

    // MARK: - Tip Card

    private var tipCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("How Quick Log works")
                        .font(.custom("DMSans-Medium", size: 15))
                        .foregroundColor(.deepNavy)
                    Text("Speak or type naturally after each set")
                        .font(.custom("DMSans-Regular", size: 13))
                        .foregroundColor(.gray)
                }
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        tipDismissed = true
                        tipPermanentlyDismissed = true
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray.opacity(0.35))
                }
            }
            .padding(16)

            Divider().padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(examplePhrases, id: \.self) { phrase in
                    HStack(spacing: 10) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.oceanTeal.opacity(0.6))
                            .frame(width: 16)
                        Text("\"\(phrase)\"")
                            .font(.custom("DMSans-Regular", size: 13))
                            .foregroundColor(.deepNavy)
                            .italic()
                    }
                }
            }
            .padding(16)

            Divider().padding(.horizontal, 16)

            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.merge")
                    .font(.system(size: 13))
                    .foregroundColor(.oceanTeal)
                    .frame(width: 20)
                Text("Closed the app mid-session? Come back and keep logging — everything merges into one session for the day automatically.")
                    .font(.custom("DMSans-Regular", size: 13))
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)

            if isFirstSession {
                Divider().padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 8) {
                    Text("QUICK START")
                        .font(.custom("DMSans-Medium", size: 11))
                        .foregroundColor(.gray)
                        .tracking(0.5)

                    HStack(spacing: 8) {
                        ForEach(exampleChips, id: \.0) { label, phrase in
                            Button {
                                inputText = phrase
                                withAnimation(.easeOut(duration: 0.2)) { tipDismissed = true }
                            } label: {
                                Text(label)
                                    .font(.custom("DMSans-Regular", size: 13))
                                    .foregroundColor(.oceanTeal)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Color.oceanTeal.opacity(0.08))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.oceanTeal.opacity(0.2), lineWidth: 0.5))
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.oceanTeal.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Workout Type Picker (shown once per day)

    private var workoutTypePickerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("WHAT'S TODAY'S WORKOUT?")
                .font(.custom("DMSans-Medium", size: 11))
                .foregroundColor(.gray)
                .tracking(0.5)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                ForEach(dayTypes, id: \.self) { dayType in
                    let isSelected = selectedDayTypes.contains(dayType)
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            if isSelected {
                                selectedDayTypes.removeAll { $0 == dayType }
                            } else {
                                selectedDayTypes.append(dayType)
                            }
                        }
                    } label: {
                        Text(dayType)
                            .font(.custom("DMSans-Regular", size: 13))
                            .foregroundColor(isSelected ? .white : .deepNavy)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(isSelected ? Color.oceanTeal : Color.mist)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                                isSelected ? Color.clear : Color.black.opacity(0.06),
                                lineWidth: 0.5
                            ))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Custom
            HStack(spacing: 8) {
                TextField("Custom (e.g. Upper Body)", text: $customDayType)
                    .font(.custom("DMSans-Regular", size: 13))
                    .foregroundColor(.deepNavy)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(!customDayType.isEmpty ? Color.oceanTeal.opacity(0.08) : Color.mist)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                        !customDayType.isEmpty ? Color.oceanTeal.opacity(0.35) : Color.clear,
                        lineWidth: 1
                    ))
                if !customDayType.isEmpty {
                    Button { customDayType = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.gray.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button(action: startSession) {
                Text(selectedDayTypes.isEmpty && customDayType.isEmpty ? "Skip & Start" : "Start Session")
                    .font(.custom("DMSans-Medium", size: 15))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.oceanTeal)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - Session Header (shown after type is set)

    private var sessionHeaderCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("TODAY'S SESSION")
                    .font(.custom("DMSans-Medium", size: 11))
                    .foregroundColor(.gray)
                    .tracking(0.5)
                Text(
                    selectedDayTypes.isEmpty
                        ? "Workout"
                        : selectedDayTypes.map { $0.replacingOccurrences(of: " Day", with: "") }.joined(separator: " · ")
                )
                .font(.custom("DMSans-Medium", size: 16))
                .foregroundColor(.deepNavy)
            }
            Spacer()
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    isSessionConfigured = false
                }
            } label: {
                Text("Edit")
                    .font(.custom("DMSans-Regular", size: 14))
                    .foregroundColor(.oceanTeal)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Color.oceanTeal.opacity(0.08))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - Today So Far Card

    private var todaySoFarCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TODAY SO FAR")
                .font(.custom("DMSans-Medium", size: 11))
                .foregroundColor(.gray)
                .tracking(0.5)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            ForEach(0..<priorExercises.count, id: \.self) { index in
                let exercise = priorExercises[index]
                if index > 0 { Divider().padding(.horizontal, 16) }
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.oceanTeal.opacity(0.1))
                            .frame(width: 28, height: 28)
                        Image(systemName: exercise.isCardio ? cardioIcon(exercise.name) : "figure.strengthtraining.traditional")
                            .font(.system(size: 12))
                            .foregroundColor(.oceanTeal)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                            .font(.custom("DMSans-Medium", size: 14))
                            .foregroundColor(.deepNavy)
                        if exercise.isCardio {
                            let parts = [
                                exercise.durationMinutes.map { "\(Int($0)) min" },
                                exercise.distanceValue.flatMap { d in exercise.distanceUnit.map { "\(Int(d)) \($0)" } },
                                exercise.pace
                            ].compactMap { $0 }
                            if !parts.isEmpty {
                                Text(parts.joined(separator: " · "))
                                    .font(.custom("DMMono-Regular", size: 12))
                                    .foregroundColor(.gray)
                            }
                        } else {
                            let unit = exercise.sets.first?.unit ?? "lb"
                            if let w = exercise.sets.first?.weight, let r = exercise.sets.first?.reps {
                                Text("\(exercise.sets.count)×\(r) · \(Int(w)) \(unit)")
                                    .font(.custom("DMMono-Regular", size: 12))
                                    .foregroundColor(.gray)
                            } else {
                                Text(exercise.setSummary)
                                    .font(.custom("DMMono-Regular", size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    Spacer()
                    if exercise.isPR {
                        Text("PR")
                            .font(.custom("DMSans-Medium", size: 11))
                            .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.0))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color(red: 0.85, green: 0.55, blue: 0.0).opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
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
    }

    // MARK: - Live Session Card

    private var liveSessionCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("LOGGED THIS SESSION")
                .font(.custom("DMSans-Medium", size: 11))
                .foregroundColor(.gray)
                .tracking(0.5)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            ForEach(Array(loggedSets.enumerated()), id: \.element.id) { index, set in
                if index > 0 { Divider().padding(.horizontal, 16) }
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.oceanTeal.opacity(0.1))
                            .frame(width: 28, height: 28)
                        Image(systemName: set.isCardio ? "figure.run" : "figure.strengthtraining.traditional")
                            .font(.system(size: 12))
                            .foregroundColor(.oceanTeal)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(set.exerciseName ?? set.text)
                            .font(.custom("DMSans-Medium", size: 14))
                            .foregroundColor(.deepNavy)
                        if let summary = set.setSummary {
                            Text(summary)
                                .font(.custom("DMMono-Regular", size: 12))
                                .foregroundColor(.gray)
                        }
                    }

                    Spacer()

                    if set.isPR {
                        Text("PR")
                            .font(.custom("DMSans-Medium", size: 11))
                            .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.0))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color(red: 0.85, green: 0.55, blue: 0.0).opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.oceanTeal.opacity(0.5))
                    }

                    Button {
                        deleteLoggedSet(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.gray.opacity(0.4))
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
    }

    // MARK: - Log a Set Card

    private var logASetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LOG A SET")
                .font(.custom("DMSans-Medium", size: 11))
                .foregroundColor(.gray)
                .tracking(0.5)

            HStack(spacing: 12) {
                Button {
                    speechManager.toggleListening { text in inputText = text }
                } label: {
                    ZStack {
                        Circle()
                            .fill(speechManager.isListening ? Color.coral : Color.oceanTeal)
                            .frame(width: 52, height: 52)
                            .shadow(
                                color: (speechManager.isListening ? Color.coral : Color.oceanTeal).opacity(0.3),
                                radius: 6, y: 3
                            )
                        Image(systemName: speechManager.isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                }

                TextField("or type it...", text: $inputText, axis: .vertical)
                    .font(.custom("DMSans-Regular", size: 15))
                    .foregroundColor(.deepNavy)
                    .focused($textFieldFocused)
                    .padding(12)
                    .background(Color.mist)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .frame(minHeight: 52)
                    .onSubmit { logEntry() }
            }

            if !inputText.isEmpty {
                Button(action: logEntry) {
                    Text("Log set")
                        .font(.custom("DMSans-Medium", size: 14))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.oceanTeal)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            // Equipment — collapsed by default
            Divider()

            VStack(spacing: 8) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showEquipmentPicker.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Text("Equipment")
                            .font(.custom("DMSans-Regular", size: 13))
                            .foregroundColor(.gray)
                        if !showEquipmentPicker {
                            Text("· \(selectedEquipment)")
                                .font(.custom("DMSans-Regular", size: 13))
                                .foregroundColor(.oceanTeal)
                        }
                        Spacer()
                        Image(systemName: showEquipmentPicker ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)

                if showEquipmentPicker {
                    HStack(spacing: 8) {
                        ForEach(equipmentTypes, id: \.self) { type in
                            Button {
                                selectedEquipment = type
                                withAnimation(.easeOut(duration: 0.2)) { showEquipmentPicker = false }
                            } label: {
                                Text(type)
                                    .font(.custom("DMSans-Regular", size: 13))
                                    .foregroundColor(selectedEquipment == type ? .white : .deepNavy)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(selectedEquipment == type ? Color.oceanTeal : Color.mist)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - Rest Timer Card

    private var restTimerCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.system(size: 16)).foregroundColor(.oceanTeal)
            VStack(alignment: .leading, spacing: 1) {
                Text("Rest timer")
                    .font(.custom("DMSans-Medium", size: 14)).foregroundColor(.deepNavy)
                Text("\(restTimerDisplay) remaining")
                    .font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
            }
            Spacer()
            Text(restTimerDisplay)
                .font(.custom("DMSans-Medium", size: 22))
                .foregroundColor(.oceanTeal)
                .monospacedDigit()
            Button {
                restTimer?.invalidate()
                restSecondsRemaining = 0
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20)).foregroundColor(.gray.opacity(0.4))
            }
        }
        .padding(14)
        .background(Color.oceanTeal.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.oceanTeal.opacity(0.15), lineWidth: 0.5))
    }

    // MARK: - Quick Add

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("QUICK ADD")
                    .font(.custom("DMSans-Medium", size: 11))
                    .foregroundColor(.gray).tracking(0.5)
                if let ex = lastLoggedExercise {
                    Text("· \(ex)")
                        .font(.custom("DMSans-Regular", size: 11))
                        .foregroundColor(.gray.opacity(0.7))
                }
                Spacer()
            }

            HStack(alignment: .top, spacing: 12) {

                // Weight column
                VStack(spacing: 6) {
                    Text("Weight")
                        .font(.custom("DMSans-Medium", size: 12))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(weightDeltas, id: \.self) { delta in
                        Button {
                            quickAddWeightDelta = delta
                            quickAddManualWeight = ""
                        } label: {
                            Text(delta == 0 ? "Same" : "+\(Int(delta)) lb")
                                .font(.custom("DMSans-Regular", size: 13))
                                .foregroundColor(quickAddWeightDelta == delta && quickAddManualWeight.isEmpty ? .white : .deepNavy)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(quickAddWeightDelta == delta && quickAddManualWeight.isEmpty ? Color.oceanTeal : Color.mist)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }

                    TextField("Custom lb", text: $quickAddManualWeight)
                        .font(.custom("DMSans-Regular", size: 13))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 9).padding(.horizontal, 8)
                        .background(!quickAddManualWeight.isEmpty ? Color.oceanTeal.opacity(0.12) : Color.mist)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                            !quickAddManualWeight.isEmpty ? Color.oceanTeal.opacity(0.4) : Color.clear,
                            lineWidth: 1
                        ))
                        .onChange(of: quickAddManualWeight) { _, _ in
                            if !quickAddManualWeight.isEmpty { quickAddWeightDelta = 0 }
                        }
                }

                // Reps column
                VStack(spacing: 6) {
                    Text("Reps")
                        .font(.custom("DMSans-Medium", size: 12))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(repOptions, id: \.self) { rep in
                        Button {
                            quickAddSelectedReps = rep
                            quickAddManualReps = ""
                        } label: {
                            Text("\(rep) reps")
                                .font(.custom("DMSans-Regular", size: 13))
                                .foregroundColor(quickAddSelectedReps == rep && quickAddManualReps.isEmpty ? .white : .deepNavy)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(quickAddSelectedReps == rep && quickAddManualReps.isEmpty ? Color.oceanTeal : Color.mist)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }

                    TextField("Custom reps", text: $quickAddManualReps)
                        .font(.custom("DMSans-Regular", size: 13))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 9).padding(.horizontal, 8)
                        .background(!quickAddManualReps.isEmpty ? Color.oceanTeal.opacity(0.12) : Color.mist)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                            !quickAddManualReps.isEmpty ? Color.oceanTeal.opacity(0.4) : Color.clear,
                            lineWidth: 1
                        ))
                        .onChange(of: quickAddManualReps) { _, _ in
                            if !quickAddManualReps.isEmpty { quickAddSelectedReps = nil }
                        }
                }
            }

            Button(action: quickLogSet) {
                Text("Log Set")
                    .font(.custom("DMSans-Medium", size: 15))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.oceanTeal)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    private func quickLogSet() {
        guard let exercise = lastLoggedExercise else { return }

        let finalWeight: Double
        if !quickAddManualWeight.isEmpty, let mw = Double(quickAddManualWeight) {
            finalWeight = mw
        } else if let lw = lastLoggedWeight {
            finalWeight = lw + quickAddWeightDelta
        } else {
            return
        }

        let finalReps: Int
        if !quickAddManualReps.isEmpty, let mr = Int(quickAddManualReps) {
            finalReps = mr
        } else if let sr = quickAddSelectedReps {
            finalReps = sr
        } else if let lr = lastLoggedReps {
            finalReps = lr
        } else {
            return
        }

        let rawText = "\(exercise) \(Int(finalWeight))x\(finalReps)"
        let text = selectedEquipment == "Machine" ? "[Machine] \(rawText)" : rawText
        logRawText(text)
        updateLastSet(exercise: exercise, weight: finalWeight, reps: finalReps)

        quickAddWeightDelta = 0
        quickAddSelectedReps = nil
        quickAddManualWeight = ""
        quickAddManualReps = ""
    }

    // MARK: - Helpers

    private func cardioIcon(_ name: String) -> String {
        switch name {
        case "Run", "Treadmill": return "figure.run"
        case "Swim": return "figure.pool.swim"
        case "Cycling": return "figure.outdoor.cycle"
        case "Rowing": return "figure.rowing"
        case "Walk": return "figure.walk"
        case "Hike": return "figure.hiking"
        default: return "stopwatch"
        }
    }

    // MARK: - Session Persistence

    private func todayDateString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    private func loadTodaySession() {
        let storedDate = UserDefaults.standard.string(forKey: kWorkoutDayDate)
        guard storedDate == todayDateString(),
              let types = UserDefaults.standard.array(forKey: kWorkoutDayTypes) as? [String],
              !types.isEmpty else {
            return
        }
        selectedDayTypes = types
        isSessionConfigured = true
        rebuildSessionTitle()
    }

    private func saveTodaySession() {
        UserDefaults.standard.set(todayDateString(), forKey: kWorkoutDayDate)
        UserDefaults.standard.set(selectedDayTypes, forKey: kWorkoutDayTypes)
    }

    private func startSession() {
        if !customDayType.isEmpty && !selectedDayTypes.contains(customDayType) {
            selectedDayTypes.append(customDayType)
            customDayType = ""
        }
        saveTodaySession()
        rebuildSessionTitle()
        withAnimation(.easeOut(duration: 0.2)) {
            isSessionConfigured = true
        }
    }

    private func rebuildSessionTitle() {
        let dateStr = Date().formatted(.dateTime.month(.abbreviated).day())
        if !selectedDayTypes.isEmpty {
            let label = selectedDayTypes.map { $0.replacingOccurrences(of: " Day", with: "") }.joined(separator: " + ")
            sessionTitle = "\(label) · \(dateStr)"
        } else {
            sessionTitle = WorkoutSessionManager.sessionTitle()
        }
        if let memory = todayWorkoutMemory {
            var lines = memory.text.components(separatedBy: "\n")
            if !lines.isEmpty {
                lines[0] = sessionTitle
                memory.text = lines.joined(separator: "\n")
                memory.updatedAt = Date()
            }
        }
    }

    // MARK: - Log Entry

    private func logEntry() {
        speechManager.stopListening()
        let raw = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        let text = selectedEquipment == "Machine" ? "[Machine] \(raw)" : raw
        logRawText(text)
        inputText = ""
        speechManager.transcribedText = ""
        textFieldFocused = false
        withAnimation(.easeOut(duration: 0.2)) { tipDismissed = true }
    }

    private func logRawText(_ text: String) {
        let parsed = WorkoutParser.shared.parse(text: text)
        let exercise = parsed.exercises.first

        let loggedSet = LoggedSet(
            text: text,
            exerciseName: exercise?.name,
            setSummary: buildSetSummary(exercise: exercise, rawText: text),
            isCardio: exercise?.isCardio ?? false,
            isPR: exercise?.isPR ?? false
        )
        loggedSets.append(loggedSet)
        appendToMemory(text: text)

        if let existing = todayWorkoutMemory {
            let parsed = WorkoutParser.shared.parse(text: existing.text)
            priorExercises = parsed.exercises
        }

        if let ex = exercise, !ex.isCardio, let set = ex.sets.first {
            updateLastSet(exercise: ex.name, weight: set.weight ?? 0, reps: set.reps ?? 0)
        }

        startRestTimer(seconds: 90)
    }

    private func buildSetSummary(exercise: ParsedExercise?, rawText: String) -> String? {
        guard let ex = exercise else { return nil }
        if ex.isCardio {
            var parts: [String] = []
            if let dur = ex.durationMinutes { parts.append("\(Int(dur)) min") }
            if let dist = ex.distanceValue, let u = ex.distanceUnit { parts.append("\(Int(dist)) \(u)") }
            if let pace = ex.pace { parts.append(pace) }
            return parts.joined(separator: " · ")
        } else {
            guard !ex.sets.isEmpty else { return nil }
            let unit = ex.sets.first?.unit ?? "lb"
            if let w = ex.sets.first?.weight, let r = ex.sets.first?.reps {
                return "\(ex.sets.count)×\(r) · \(Int(w)) \(unit)"
            }
            return ex.setSummary
        }
    }

    // MARK: - Delete Logged Set

    private func deleteLoggedSet(at index: Int) {
        guard index < loggedSets.count else { return }
        let removedText = loggedSets[index].text
        loggedSets.remove(at: index)

        guard let memory = todayWorkoutMemory else { return }
        let lines = memory.text
            .components(separatedBy: "\n")
            .filter { $0 != removedText }
            .joined(separator: "\n")
        memory.text = lines
        memory.updatedAt = Date()

        let remaining = memory.text
            .components(separatedBy: "\n")
            .filter { !$0.hasPrefix("Workout ·") && !$0.isEmpty }
        if remaining.isEmpty {
            let memoryPings = pings.filter { $0.memoryId == memory.id }
            for ping in memoryPings {
                NotificationService.shared.cancelPing(pingId: ping.id)
                modelContext.delete(ping)
                Task { await SupabaseSyncService.shared.deletePing(id: ping.id) }
            }
            let memoryId = memory.id
            modelContext.delete(memory)
            SupabaseSyncService.shared.scheduleDelete(id: memoryId)
            loggedSets = []
            priorExercises = []
        } else {
            let parsed = WorkoutParser.shared.parse(text: memory.text)
            priorExercises = parsed.exercises
        }
    }

    // MARK: - Memory Management

    private func appendToMemory(text: String) {
        if let existing = todayWorkoutMemory {
            existing.text += "\n\(text)"
            existing.updatedAt = Date()
        } else {
            guard let echo = workoutEcho else { return }
            let newMemory = Memory(text: sessionTitle, echoId: echo.id)
            modelContext.insert(newMemory)
            newMemory.text += "\n\(text)"
            newMemory.updatedAt = Date()
        }
    }

    private func finishSession() {
        guard let memory = todayWorkoutMemory else { return }
        memory.updatedAt = Date()
    }

    private func updateLastSet(exercise: String, weight: Double, reps: Int) {
        lastLoggedExercise = exercise
        lastLoggedWeight = weight
        lastLoggedReps = reps
    }

    private func startRestTimer(seconds: Int = 90) {
        restTimer?.invalidate()
        restSecondsRemaining = seconds
        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                if self.restSecondsRemaining > 0 {
                    self.restSecondsRemaining -= 1
                } else {
                    self.restTimer?.invalidate()
                    self.restTimer = nil
                }
            }
        }
    }
}
