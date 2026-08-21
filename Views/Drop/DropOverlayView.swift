//
//  DropOverlayView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI
import SwiftData
import AVFoundation
import CoreSpotlight

struct DropOverlayView: View {
    @Binding var isPresented: Bool
    var onComplete: ((String) -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Query private var echos: [Echo]

    @State private var audioService = AudioService()
    @State private var showBanner = false
    @State private var sonarResult: SonarResult?
    @State private var permissionDenied = false
    @State private var editMemory: Memory? = nil
    @State private var savedTranscription = ""
    @State private var visibleTipIndices: [Int] = []
    @State private var tipTimer: Timer? = nil
    @State private var silenceTimer: Timer? = nil
    @State private var showSonarAnimation = false
    @State private var tipsActive = false
    @State private var isProcessing = false

    private let sonarEngine = SonarEngine()

    private let tips: [(String, String)] = [
        ("🎂", "\"Cara's birthday is December 8th\""),
        ("✈️", "\"Screenshot a flight or hotel — auto-saved\""),
        ("📋", "\"Say 'and' between items to make a checklist\""),
        ("🍳", "\"Paste a recipe URL to import ingredients\""),
        ("🔔", "\"Dentist April 5th at 2pm, remind me the day before\""),
        ("🏋️", "\"Bench press 185 pounds 3 sets of 8\""),
        ("🎁", "\"Get Miles AirPods for Christmas\""),
        ("🍽️", "\"Carbone — try the lamb chops, skip the pasta\""),
        ("📈", "\"Alert me when AAPL drops below 180\""),
        ("💊", "\"Dog heartworm pill every 1st of the month\""),
        ("💼", "\"Submit timesheet every Friday at 4pm\""),
    ]

    private func updateLastMemoryEcho(_ echoId: UUID) {
        let descriptor = FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        if let last = try? modelContext.fetch(descriptor).first {
            last.echoId = echoId
        }
    }

    private func updateLastMemoryTask(isTask: Bool) {
        let recent = try? modelContext.fetch(
            FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )
        if let last = recent?.first {
            last.isActionable = isTask
        }
    }

    private func updateLastMemoryDuration(_ minutes: Int) {
        let descriptor = FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        if let last = try? modelContext.fetch(descriptor).first {
            last.estimatedMinutes = minutes
        }
    }

    // Applies an inline banner edit: saves the new text and re-applies the fresh
    // SonarResult so dates and pings track the edit (e.g. "4pm" → "3pm" moves the ping).
    private func applyEditedText(_ newText: String, result: SonarResult) {
        let descriptor = FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        guard let last = try? modelContext.fetch(descriptor).first else { return }
        last.text = newText
        last.updatedAt = Date()
        last.tags = result.tags
        last.detectedDate = result.detectedDate
        last.endDate = result.endDate
        last.dateConfidence = result.dateConfidence
        last.estimatedMinutes = result.estimatedMinutes
        last.isActionable = result.isActionable
        if let detectedURL = sonarEngine.detectURL(text: newText) { last.url = detectedURL }

        // Replace pings — the old ones may point at a time the edit just changed
        let pings = (try? modelContext.fetch(FetchDescriptor<Ping>())) ?? []
        for ping in pings where ping.memoryId == last.id {
            let pingId = ping.id
            NotificationService.shared.cancelPing(pingId: pingId)
            modelContext.delete(ping)
            Task { await SupabaseSyncService.shared.deletePing(id: pingId) }
        }
        var newPings: [Ping] = []
        for suggestion in result.pingSuggestions {
            let fireDate = suggestion.fireDate ?? result.detectedDate ?? Date()
            let ping = Ping(memoryId: last.id, fireDate: fireDate, recurrence: suggestion.recurrence)
            if let fireTime = suggestion.fireTime { ping.fireTime = fireTime }
            modelContext.insert(ping)
            NotificationService.shared.schedulePing(ping: ping, memoryText: last.text)
            newPings.append(ping)
        }
        if let advancePing = NotificationService.shared.makeAdvancePing(for: last, echoName: result.echoName) {
            modelContext.insert(advancePing)
            NotificationService.shared.schedulePing(ping: advancePing, memoryText: "2 weeks out: \(last.text)")
            newPings.append(advancePing)
        }

        // Refresh sonar checklist items; when the new text has none, leave existing
        // subtasks alone (protects recipe-ingredient checklists).
        if !result.checklistItems.isEmpty {
            let subTasks = (try? modelContext.fetch(FetchDescriptor<SubTask>())) ?? []
            for subTask in subTasks where subTask.memoryId == last.id {
                let subTaskId = subTask.id
                modelContext.delete(subTask)
                Task { await SupabaseSyncService.shared.deleteSubTask(id: subTaskId) }
            }
            last.hasChecklist = true
            for (i, item) in result.checklistItems.enumerated() {
                modelContext.insert(SubTask(memoryId: last.id, text: item, sortOrder: i))
            }
        }

        try? modelContext.save()
        SpotlightService.shared.indexMemory(
            last,
            echoName: echos.first { $0.id == last.echoId }?.name ?? "Notes",
            echoEmoji: echos.first { $0.id == last.echoId }?.emoji ?? "📝"
        )
        sonarResult = result  // banner chips refresh from this
        if let userId = authService.userId {
            Task { @MainActor in
                await SupabaseSyncService.shared.pushMemory(last, userId: userId)
                for ping in newPings {
                    await SupabaseSyncService.shared.pushPing(ping, userId: userId)
                }
            }
        }
    }

    private func updateLastMemoryLocation(name: String, address: String?, lat: Double, lng: Double) {
        let descriptor = FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        if let last = try? modelContext.fetch(descriptor).first {
            last.locationName = name
            last.locationAddress = address
            last.latitude = lat
            last.longitude = lng
            try? modelContext.save()
            if let userId = authService.userId {
                Task { await SupabaseSyncService.shared.pushMemory(last, userId: userId) }
            }
        }
    }

    private func handleRecipeFetch(_ recipe: RecipeResult) {
        let descriptor = FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        guard let memory = try? modelContext.fetch(descriptor).first else { return }

        var parts: [String] = ["🍽 \(recipe.title)"]
        var meta: [String] = []
        if let prep = recipe.prepTime { meta.append("Prep: \(prep)") }
        if let cook = recipe.cookTime { meta.append("Cook: \(cook)") }
        if let srv  = recipe.servings { meta.append("Serves: \(srv)") }
        if !meta.isEmpty { parts.append(meta.joined(separator: " · ")) }
        if !recipe.instructions.isEmpty {
            parts.append("\nInstructions:")
            for (i, step) in recipe.instructions.enumerated() {
                parts.append("\(i + 1). \(step)")
            }
        }
        memory.text = parts.joined(separator: "\n")

        if !recipe.ingredients.isEmpty {
            memory.hasChecklist = true
            for (index, ingredient) in recipe.ingredients.enumerated() {
                let subTask = SubTask(memoryId: memory.id, text: ingredient, sortOrder: index)
                modelContext.insert(subTask)
            }
        }
    }

    // MARK: - Extract Gift Name

    private func extractGiftName(from text: String, personName: String) -> String {
        let lower = text.lowercased()
        let firstName = personName.split(separator: " ").first.map(String.init)?.lowercased() ?? ""

        var cleaned = lower
        let removals = [
            "buy \(firstName)", "get \(firstName)", "got \(firstName)", "getting \(firstName)",
            "buying \(firstName)", "for \(firstName)", "for her", "for him", "for them",
            "buy", "get", "got", "getting", "buying", "picked up", "ordered", "order",
            "found", "grabbed", "give", "giving",
            "for his birthday", "for her birthday", "for their birthday",
            "for christmas", "for the holidays", "for mothers day", "for mother's day",
            "for fathers day", "for father's day", "for valentine's day", "for valentines day",
            "for graduation", "for anniversary", "for thanksgiving", "for hanukkah",
            "for his", "for her", "for their", "for the",
            "birthday", "christmas", "anniversary", "graduation", "holiday",
            "mother's day", "mothers day", "father's day", "fathers day",
            "valentine's day", "valentines day", "hanukkah", "thanksgiving",
            "as a gift", "as a present", "as a surprise",
            firstName
        ]

        for phrase in removals {
            cleaned = cleaned.replacingOccurrences(of: phrase, with: " ")
        }

        let result = cleaned
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        return result.count > 2 ? result.capitalized : text
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            if showSonarAnimation {
                SonarAnimationView()
                    .ignoresSafeArea()
                    .transition(.opacity)
            } else if permissionDenied {
                permissionDeniedView
            } else if showBanner {
                recordingView
                    .allowsHitTesting(false)

                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture { dismissAndClose() }

                VStack {
                    Spacer()
                    ConfirmBannerView(
                        transcription: savedTranscription,
                        sonarResult: sonarResult,
                        echos: echos,
                        onDone: { isTask, duration in
                            updateLastMemoryTask(isTask: isTask)
                            if let duration = duration, duration > 0 {
                                updateLastMemoryDuration(duration)
                            }
                            dismissAndClose()
                        },
                        onUndo: { undoAndClose() },
                        onEchoChanged: { newEchoId in
                            updateLastMemoryEcho(newEchoId)
                        },
                        onRecipeFetched: { recipe in
                            handleRecipeFetch(recipe)
                        },
                        onEdit: {
                            let descriptor = FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
                            editMemory = try? modelContext.fetch(descriptor).first
                        },
                        onTextEdited: { newText, newResult in
                            applyEditedText(newText, result: newResult)
                        },
                        onLocationSet: { name, address, lat, lng in
                            updateLastMemoryLocation(name: name, address: address, lat: lat, lng: lng)
                        },
                        onGroceryHint: {
                            NotificationCenter.default.post(name: .groceryModeHint, object: nil)
                        },
                        onAddToWatchlist: { title, type, service in
                            let item = WatchlistItem(title: title, itemType: type, streamingService: service)
                            modelContext.insert(item)
                        }
                    )
                }
            } else {
                recordingView
            }
        }
        .onAppear {
            checkAndStartRecording()
        }
        .sheet(item: $editMemory, onDismiss: {
            let descriptor = FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            if let last = try? modelContext.fetch(descriptor).first {
                savedTranscription = last.text
            }
        }) { memory in
            MemoryEditView(memory: memory)
        }
    }

    // MARK: - Permission Check

    private func checkAndStartRecording() {
        let micStatus = AVAudioApplication.shared.recordPermission
        if micStatus == .undetermined {
            audioService.requestPermissions { granted in
                if granted {
                    audioService.startRecording()
                    startSilenceTimer()
                } else {
                    permissionDenied = true
                }
            }
        } else if micStatus == .denied {
            permissionDenied = true
        } else {
            audioService.startRecording()
            startSilenceTimer()
        }
    }

    // MARK: - Silence Timer

    private func startSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { _ in
            DispatchQueue.main.async {
                guard audioService.transcription.isEmpty else { return }
                stopTipRotation()
                audioService.stopRecording()
                isPresented = false
            }
        }
    }

    private func cancelSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = nil
    }

    // MARK: - Tip Rotation

    private func startTipRotation() {
        guard !showBanner && !showSonarAnimation else { return }
        let initialCount = min(3, tips.count)
        for i in 0..<initialCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
                    if !visibleTipIndices.contains(i) {
                        visibleTipIndices.append(i)
                    }
                }
            }
        }
        var nextTipIndex = initialCount
        tipTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            guard nextTipIndex < tips.count else {
                tipTimer?.invalidate()
                return
            }
            withAnimation(.easeOut(duration: 0.3)) {
                if !visibleTipIndices.isEmpty { visibleTipIndices.removeFirst() }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                    visibleTipIndices.append(nextTipIndex)
                    nextTipIndex += 1
                }
            }
        }
    }

    private func stopTipRotation() {
        tipTimer?.invalidate()
        tipTimer = nil
    }

    // MARK: - Recording View

    private var recordingView: some View {
        ZStack {
            LinearGradient(
                colors: [.deepNavy, Color(hex: "1A2A44")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("WHAT CAN I SAY?")
                        .font(.custom("DMSans-Medium", size: 11))
                        .foregroundColor(.white.opacity(0.3))
                        .tracking(1)
                        .padding(.horizontal, 28)
                        .padding(.top, 64)
                        .padding(.bottom, 16)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(visibleTipIndices, id: \.self) { index in
                            HStack(spacing: 12) {
                                Text(tips[index].0)
                                    .font(.system(size: 18))
                                    .frame(width: 28)
                                Text(tips[index].1)
                                    .font(.custom("DMSans-Regular", size: 14))
                                    .foregroundColor(.white.opacity(0.75))
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 20)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                        }
                    }
                    Spacer()
                }
                .frame(maxHeight: .infinity)

                Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 28)

                VStack(spacing: 16) {
                    if !audioService.transcription.isEmpty {
                        Text(audioService.transcription)
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .lineLimit(3)
                            .animation(.easeOut(duration: 0.2), value: audioService.transcription)
                    } else {
                        Text("Listening...")
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(.white.opacity(0.25))
                    }

                    HStack(spacing: 3) {
                        ForEach(0..<28, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.coral.opacity(0.7))
                                .frame(width: 4, height: barHeight(index: i))
                                .animation(.linear(duration: 0.1), value: audioService.audioLevel)
                        }
                    }
                    .frame(height: 56)

                    Text(formatTime(audioService.recordingDuration))
                        .font(.custom("DMMono-Regular", size: 14))
                        .foregroundColor(.white.opacity(0.4))

                    Button {
                        cancelSilenceTimer()
                        stopTipRotation()
                        stopAndProcess()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.coral)
                                .frame(width: 68, height: 68)
                                .shadow(color: Color.coral.opacity(0.4), radius: 16, y: 4)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.white)
                                .frame(width: 22, height: 22)
                        }
                    }
                }
                .padding(.vertical, 24)
                .padding(.bottom, 32)
                .frame(maxHeight: .infinity)
            }
        }
        .onAppear {
            guard !showBanner && !showSonarAnimation else { return }
            startTipRotation()
            tipsActive = true
        }
        .onDisappear {
            stopTipRotation()
            tipsActive = false
        }
        .onChange(of: audioService.transcription) { _, newValue in
            if !newValue.isEmpty { cancelSilenceTimer() }
        }
        // AudioService hard-stops at the 60s cap — without this the UI keeps
        // "listening" while nothing is recorded. Process what was captured.
        .onChange(of: audioService.isRecording) { wasRecording, isRec in
            if wasRecording && !isRec && !isProcessing && !showBanner && !showSonarAnimation {
                stopTipRotation()
                stopAndProcess()
            }
        }
    }

    // MARK: - Permission Denied View

    private var permissionDeniedView: some View {
        ZStack {
            Color.deepNavy.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.coral)
                Text("Microphone Access Needed")
                    .font(.custom("DMSans-Medium", size: 18))
                    .foregroundColor(.white)
                Text("Orca needs your microphone to capture voice memories. Open Settings to enable it.")
                    .font(.custom("DMSans-Regular", size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.custom("DMSans-Medium", size: 16))
                .foregroundColor(.oceanTeal)
                .padding(.top, 8)
                Button("Cancel") { isPresented = false }
                    .font(.custom("DMSans-Regular", size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Helpers

    private func barHeight(index: Int) -> CGFloat {
        let base: CGFloat = 6
        let level = CGFloat(max(audioService.audioLevel, 0.15))
        let time = Date().timeIntervalSince1970
        let wave1 = sin(Double(index) * 0.6 + time * 4.0) * 0.5 + 0.5
        let wave2 = sin(Double(index) * 1.2 + time * 2.5 + 1.0) * 0.3 + 0.3
        let variation = CGFloat((wave1 + wave2) / 1.3)
        return base + (level * 56 * variation)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Stop and Process
    // Sonar runs first (sync, instant), then AI enhances while the
    // sonar animation is still showing — no extra perceived latency.

    private func stopAndProcess() {
        guard !isProcessing else { return }
        isProcessing = true
        cancelSilenceTimer()
        audioService.stopRecording()
        savedTranscription = audioService.transcription

        guard !savedTranscription.isEmpty else {
            isPresented = false
            return
        }

        withAnimation(.easeOut(duration: 0.2)) { visibleTipIndices = [] }
        withAnimation(.easeIn(duration: 0.2)) { showSonarAnimation = true }

        let echoSnapshot = Array(echos)

        Task {
            // Minimum animation duration
            try? await Task.sleep(nanoseconds: 900_000_000)

            // Re-read after the delay: stopRecording() finishes recognition rather than
            // cancelling it, so the final segment (the last words) lands during this window.
            let latest = audioService.transcription
            if !latest.isEmpty { savedTranscription = latest }
            let text = savedTranscription

            // Sonar — synchronous, runs off main actor is fine since SonarEngine is a plain class
            let rawResult = SonarEngine().process(text: text, echos: echoSnapshot)

            // AI enhance — runs while animation is still visible, adds no perceived latency
            let finalResult = await AppleIntelligenceService.shared.enhance(
                text: text,
                sonarResult: rawResult,
                echos: echoSnapshot
            )

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) { showSonarAnimation = false }
                processSonarResult(with: finalResult)
            }
        }
    }

    // MARK: - Process Sonar Result
    // Now accepts a pre-computed (and AI-enhanced) SonarResult.

    private func processSonarResult(with result: SonarResult) {
        sonarResult = result

        let isWorkout = result.echoName.lowercased().contains("workout")
        if isWorkout,
           let existing = WorkoutSessionManager.shared.mergeIntoTodaySession(
               text: savedTranscription, echos: Array(echos), context: modelContext) {
            if let userId = authService.userId {
                Task { await SupabaseSyncService.shared.pushMemory(existing, userId: userId) }
            }
            withAnimation(.spring(duration: 0.4)) { showBanner = true }
            return
        }

        let echoId = result.echoId
            ?? echos.first { $0.name == "Notes" }?.id
            ?? echos.first?.id
            ?? UUID()
        let memory = Memory(text: savedTranscription, echoId: echoId)
        memory.tags = result.tags
        memory.detectedDate = result.detectedDate
        memory.endDate = result.endDate
        memory.echoConfidence = result.echoConfidence
        memory.dateConfidence = result.dateConfidence
        memory.sonarConfidence = result.echoConfidence
        memory.isActionable = result.isActionable
        memory.estimatedMinutes = result.estimatedMinutes
        if !result.checklistItems.isEmpty {
            memory.hasChecklist = true
            for (i, item) in result.checklistItems.enumerated() {
                modelContext.insert(SubTask(memoryId: memory.id, text: item, sortOrder: i))
            }
        }
        modelContext.insert(memory)
        SpotlightService.shared.indexMemory(
            memory,
            echoName: result.echoName,
            echoEmoji: echos.first { $0.id == memory.echoId }?.emoji ?? "📝"
        )
        NotificationService.shared.scheduleInactivityReminder(afterDays: 5)

        if memory.detectedDate != nil {
            let recurrence = result.pingRecurrence
            NotificationCenter.default.post(
                name: .calendarSyncCheck,
                object: memory,
                userInfo: ["recurrence": recurrence.rawValue]
            )
        }

        // Create pings locally first so reminders always work
        if !result.pingSuggestions.isEmpty {
            var createdPings: [Ping] = []
            for suggestion in result.pingSuggestions {
                let fireDate = suggestion.fireDate ?? result.detectedDate ?? Date()
                let ping = Ping(memoryId: memory.id, fireDate: fireDate, recurrence: suggestion.recurrence)
                if let fireTime = suggestion.fireTime { ping.fireTime = fireTime }
                modelContext.insert(ping)
                NotificationService.shared.schedulePing(ping: ping, memoryText: memory.text)
                createdPings.append(ping)
            }
            if let advancePing = NotificationService.shared.makeAdvancePing(for: memory, echoName: result.echoName) {
                modelContext.insert(advancePing)
                NotificationService.shared.schedulePing(ping: advancePing, memoryText: "2 weeks out: \(memory.text)")
                createdPings.append(advancePing)
            }
            try? modelContext.save()

            if let userId = authService.userId {
                Task { @MainActor in
                    await SupabaseSyncService.shared.pushMemory(memory, userId: userId)
                    for ping in createdPings {
                        await SupabaseSyncService.shared.pushPing(ping, userId: userId)
                    }
                }
            }
        } else if let userId = authService.userId {
            Task { @MainActor in
                await SupabaseSyncService.shared.pushMemory(memory, userId: userId)
            }
        }

        if let detectedURL = sonarEngine.detectURL(text: savedTranscription) {
            memory.url = detectedURL
        }
        // Checklist already handled via result.checklistItems above; only fall back to legacy detection if nothing was found
        if result.checklistItems.isEmpty, let checklistItems = sonarEngine.detectChecklist(text: savedTranscription) {
            memory.hasChecklist = true
            for (index, item) in checklistItems.enumerated() {
                let subTask = SubTask(memoryId: memory.id, text: item, sortOrder: index)
                modelContext.insert(subTask)
            }
        }

        AnalyticsService.shared.trackMemoryDropped(
            captureType: "voice",
            echoName: result.echoName,
            hasPing: result.shouldCreatePing,
            hasDate: result.detectedDate != nil,
            hasURL: memory.url != nil,
            hasChecklist: memory.hasChecklist,
            wordCount: savedTranscription.split(separator: " ").count
        )

        // Auto-create GiftItem
        let isGiftsEcho = result.echoName == "Gifts"
        let lowerText = savedTranscription.lowercased()

        let hasGiftKeyword = ["gift", "present", "got", "get", "getting", "bought", "buy",
                              "buying", "picked up", "ordered", "order", "found", "grabbed",
                              "headphones", "beats", "computer", "laptop", "phone", "jewelry",
                              "flowers", "perfume", "watch", "book", "clothes", "shoes", "bag",
                              "purse", "wallet", "airpods", "ipad", "iphone", "camera", "speaker",
                              "earbuds", "surprise", "wish list", "registry",
                              "waterbottle", "water bottle", "sunglasses", "bracelet",
                              "necklace", "ring", "scarf", "hat", "sweater", "hoodie",
                              "sneakers", "boots", "backpack", "wants", "wants for",
                              "getting for", "buying for"].contains { lowerText.contains($0) }

        let hasOccasionKeyword = ["birthday", "christmas", "anniversary", "holiday",
                                   "graduation", "wedding", "valentine", "mother's day",
                                   "mothers day", "father's day", "fathers day",
                                   "new year", "hanukkah", "thanksgiving"].contains { lowerText.contains($0) }

        if isGiftsEcho || (hasGiftKeyword && hasOccasionKeyword) {
            let personDescriptor = FetchDescriptor<Person>()
            let allPersons = (try? modelContext.fetch(personDescriptor)) ?? []
            let detectedPeople = result.detectedPeople
            let matchingPersons: [Person] = allPersons.filter { person in
                let firstName = person.name.split(separator: " ").first.map(String.init) ?? person.name
                guard firstName.count > 2 else { return false }
                return detectedPeople.contains { $0.lowercased() == firstName.lowercased() }
                    || lowerText.contains(firstName.lowercased())
            }

            var giftCreatedForPersonIds = Set<UUID>()
            for matchedPerson in matchingPersons {
                guard !giftCreatedForPersonIds.contains(matchedPerson.id) else { continue }
                let alreadyExists = (try? modelContext.fetch(FetchDescriptor<GiftItem>()))?.contains {
                    $0.linkedMemoryId == memory.id && $0.personId == matchedPerson.id
                } ?? false

                if !alreadyExists {
                    let occasion: String
                    if lowerText.contains("christmas") || lowerText.contains("xmas") { occasion = "Christmas" }
                    else if lowerText.contains("birthday") || lowerText.contains("bday") { occasion = "Birthday" }
                    else if lowerText.contains("anniversary") {
                        let customMatch = matchedPerson.customOccasions.first { occ in
                            let normalized = occ.lowercased().replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\u{2019}", with: "")
                            return normalized.contains("anniversary")
                        }
                        occasion = customMatch ?? "Anniversary"
                    } else if lowerText.contains("graduation") {
                        let customMatch = matchedPerson.customOccasions.first { occ in
                            let normalized = occ.lowercased().replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\u{2019}", with: "")
                            return normalized.contains("graduation")
                        }
                        occasion = customMatch ?? "Graduation"
                    } else if lowerText.contains("valentine") {
                        let customMatch = matchedPerson.customOccasions.first { occ in
                            let normalized = occ.lowercased().replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\u{2019}", with: "")
                            return normalized.contains("valentine")
                        }
                        occasion = customMatch ?? "Valentine's Day"
                    } else if lowerText.contains("mother's day") || lowerText.contains("mothers day") {
                        let customMatch = matchedPerson.customOccasions.first { occ in
                            let normalized = occ.lowercased().replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\u{2019}", with: "")
                            return normalized.contains("mothers day") || normalized.contains("mother")
                        }
                        occasion = customMatch ?? "Mother's Day"
                    } else if lowerText.contains("father's day") || lowerText.contains("fathers day") {
                        let customMatch = matchedPerson.customOccasions.first { occ in
                            let normalized = occ.lowercased().replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\u{2019}", with: "")
                            return normalized.contains("fathers day") || normalized.contains("father")
                        }
                        occasion = customMatch ?? "Father's Day"
                    } else if lowerText.contains("new year") {
                        let customMatch = matchedPerson.customOccasions.first { occ in
                            let normalized = occ.lowercased().replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\u{2019}", with: "")
                            return normalized.contains("new year")
                        }
                        occasion = customMatch ?? "New Year's"
                    } else if lowerText.contains("hanukkah") {
                        let customMatch = matchedPerson.customOccasions.first { occ in
                            let normalized = occ.lowercased().replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\u{2019}", with: "")
                            return normalized.contains("hanukkah")
                        }
                        occasion = customMatch ?? "Hanukkah"
                    } else if lowerText.contains("thanksgiving") {
                        let customMatch = matchedPerson.customOccasions.first { occ in
                            let normalized = occ.lowercased().replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\u{2019}", with: "")
                            return normalized.contains("thanksgiving")
                        }
                        occasion = customMatch ?? "Thanksgiving"
                    } else if lowerText.contains("holiday") {
                        occasion = "Holiday"
                    } else {
                        let matchedCustom = matchedPerson.customOccasions.first { occ in
                            let normalized = occ.lowercased().replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\u{2019}", with: "")
                            let normalizedText = lowerText.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\u{2019}", with: "")
                            return normalizedText.contains(normalized)
                        }
                        occasion = matchedCustom ?? "Birthday"
                    }

                    let giftName = extractGiftName(from: savedTranscription, personName: matchedPerson.name)
                    let giftItem = GiftItem(personId: matchedPerson.id, name: giftName, occasion: occasion)
                    giftItem.linkedMemoryId = memory.id
                    modelContext.insert(giftItem)
                    giftCreatedForPersonIds.insert(matchedPerson.id)
                }
            }
        }

        withAnimation(.spring(duration: 0.4)) { showBanner = true }
    }

    // MARK: - Dismiss and Close

    private func dismissAndClose() {
        let descriptor = FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let lastMemory = try? modelContext.fetch(descriptor).first
        let echoName = echos.first { $0.id == lastMemory?.echoId }?.name ?? sonarResult?.echoName ?? "Memory"
        let echoEmoji = echos.first { $0.name == echoName }?.emoji ?? "📝"
        let message = "Dropped to \(echoName) \(echoEmoji)"
        isPresented = false
        onComplete?(message)
    }

    // MARK: - Undo and Close

    private func undoAndClose() {
        let recent = try? modelContext.fetch(
            FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )
        if let last = recent?.first {
            let id = last.id
            // Remove everything created alongside the memory — otherwise its pings
            // still fire, and subtasks/gifts/spotlight entries are left orphaned.
            let pings = (try? modelContext.fetch(FetchDescriptor<Ping>())) ?? []
            for ping in pings where ping.memoryId == id {
                let pingId = ping.id
                NotificationService.shared.cancelPing(pingId: pingId)
                modelContext.delete(ping)
                Task { await SupabaseSyncService.shared.deletePing(id: pingId) }
            }
            let subTasks = (try? modelContext.fetch(FetchDescriptor<SubTask>())) ?? []
            for subTask in subTasks where subTask.memoryId == id {
                let subTaskId = subTask.id
                modelContext.delete(subTask)
                Task { await SupabaseSyncService.shared.deleteSubTask(id: subTaskId) }
            }
            let gifts = (try? modelContext.fetch(FetchDescriptor<GiftItem>())) ?? []
            for gift in gifts where gift.linkedMemoryId == id {
                let giftId = gift.id
                modelContext.delete(gift)
                Task { await SupabaseSyncService.shared.deleteGiftItem(id: giftId) }
            }
            SpotlightService.shared.removeMemory(id: id)
            modelContext.delete(last)
            SupabaseSyncService.shared.scheduleDelete(id: id)
        }
        isPresented = false
    }
}
