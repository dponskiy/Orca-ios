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

    // Tip card
    @State private var tipDismissed = false
    @AppStorage("quickLogTipDismissed") private var tipPermanentlyDismissed = false

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
        if let result = todayWorkoutMemory.map({ WorkoutParser.shared.parse(text: $0.text) }),
           let type = result.sessionType {
            return "\(type) · tap Done when finished"
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

    // MARK: - Quick Add Chips

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QUICK ADD")
                .font(.custom("DMSans-Medium", size: 11))
                .foregroundColor(.gray).tracking(0.5)

            HStack(spacing: 8) {
                chipButton("Same weight +1 rep") {
                    guard let ex = lastLoggedExercise,
                          let reps = lastLoggedReps,
                          let w = lastLoggedWeight else { return }
                    let text = "\(ex) \(Int(w))x\(reps + 1)"
                    logRawText(text)
                    updateLastSet(exercise: ex, weight: w, reps: reps + 1)
                }
                chipButton("+5 lb same reps") {
                    guard let ex = lastLoggedExercise,
                          let reps = lastLoggedReps,
                          let w = lastLoggedWeight else { return }
                    let text = "\(ex) \(Int(w + 5))x\(reps)"
                    logRawText(text)
                    updateLastSet(exercise: ex, weight: w + 5, reps: reps)
                }
                chipButton("Finish session") {
                    speechManager.stopListening()
                    finishSession()
                    dismiss()
                    onFinish?()
                }
            }
        }
    }

    private func chipButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.custom("DMSans-Regular", size: 13))
                .foregroundColor(.deepNavy)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.black.opacity(0.08), lineWidth: 0.5))
        }
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
    // MARK: - Log Entry

    private func logEntry() {
        speechManager.stopListening()
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
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

        // Update priorExercises to reflect the newly added set
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
            modelContext.delete(memory)
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
