//
//  TypeCaptureView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI
import SwiftData
import CoreSpotlight

struct TypeCaptureView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Query private var echos: [Echo]
    
    @State private var text = ""
    @State private var urlText = ""
    @State private var showBanner = false
    @State private var sonarResult: SonarResult?
    @FocusState private var isFocused: Bool
    @State private var editMemory: Memory? = nil
    @State private var isFetchingRecipe = false
    @State private var recipeFetched = false
    @State private var recipeError: String? = nil
    @State private var savedMemory: Memory? = nil
    
    private let sonarEngine = SonarEngine()

    private func handleRecipeFetch(_ recipe: RecipeResult) {
        guard let memory = savedMemory else { return }
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
        if let last = recent?.first { last.isActionable = isTask }
    }

    private func updateLastMemoryDuration(_ minutes: Int) {
        let descriptor = FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        if let last = try? modelContext.fetch(descriptor).first {
            last.estimatedMinutes = minutes
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
    
    var body: some View {
        ZStack {
            if showBanner {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { isPresented = false }
                
                VStack {
                    Spacer()
                    ConfirmBannerView(
                        transcription: text,
                        sonarResult: sonarResult,
                        echos: echos,
                        onDone: { isTask, duration in
                            updateLastMemoryTask(isTask: isTask)
                            if let duration = duration, duration > 0 {
                                updateLastMemoryDuration(duration)
                            }
                            isPresented = false
                        },
                        onUndo: { undoMemory() },
                        onEchoChanged: { newEchoId in updateLastMemoryEcho(newEchoId) },
                        onRecipeFetched: { recipe in handleRecipeFetch(recipe) },
                        onEdit: {
                            let descriptor = FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
                            editMemory = try? modelContext.fetch(descriptor).first
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
                ZStack {
                    Color.deepNavy.ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        HStack {
                            Button("Cancel") { isPresented = false }
                                .font(.custom("DMSans-Regular", size: 16))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Button("Save") { saveMemory() }
                                .font(.custom("DMSans-Medium", size: 16))
                                .foregroundColor(text.isEmpty ? .white.opacity(0.3) : .oceanTeal)
                                .disabled(text.isEmpty)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                        
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $text)
                                .font(.custom("DMSans-Regular", size: 18))
                                .foregroundColor(.white)
                                .scrollContentBackground(.hidden)
                                .padding(.horizontal, 16)
                                .focused($isFocused)
                            if text.isEmpty {
                                Text("Type a memory...")
                                    .font(.custom("DMSans-Regular", size: 18))
                                    .foregroundColor(.white.opacity(0.3))
                                    .padding(.horizontal, 20)
                                    .padding(.top, 8)
                                    .allowsHitTesting(false)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "link")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.5))
                                ZStack(alignment: .leading) {
                                    if urlText.isEmpty {
                                        Text("Add a URL (optional)...")
                                            .font(.custom("DMSans-Regular", size: 14))
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                    TextField("", text: $urlText)
                                        .font(.custom("DMSans-Regular", size: 14))
                                        .foregroundColor(.white)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .keyboardType(.URL)
                                        .tint(.white)
                                }
                                if !urlText.isEmpty {
                                    Button {
                                        urlText = ""
                                        recipeFetched = false
                                        recipeError = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            
                            if !urlText.isEmpty {
                                Button { fetchRecipeInline() } label: {
                                    HStack(spacing: 6) {
                                        if isFetchingRecipe {
                                            ProgressView().scaleEffect(0.7).tint(.white)
                                            Text("Fetching...").font(.custom("DMSans-Medium", size: 13))
                                        } else if recipeFetched {
                                            Image(systemName: "checkmark.circle.fill").font(.system(size: 13))
                                            Text("Recipe fetched!").font(.custom("DMSans-Medium", size: 13))
                                        } else {
                                            Image(systemName: "fork.knife").font(.system(size: 13))
                                            Text("Fetch Recipe").font(.custom("DMSans-Medium", size: 13))
                                        }
                                    }
                                    .foregroundColor(recipeFetched ? .green : .white)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(recipeFetched ? Color.green.opacity(0.2) : Color.oceanTeal.opacity(0.3))
                                    .clipShape(Capsule())
                                }
                                .disabled(isFetchingRecipe || recipeFetched)
                                
                                if let error = recipeError {
                                    Text(error)
                                        .font(.custom("DMSans-Regular", size: 12))
                                        .foregroundColor(.coral)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
                .onAppear { isFocused = true }
            }
        }
        .sheet(item: $editMemory) { memory in
            MemoryEditView(memory: memory)
        }
    }
    
    private func fetchRecipeInline() {
        guard !urlText.isEmpty else { return }
        recipeError = nil
        isFetchingRecipe = true
        isFocused = false
        Task {
            do {
                let recipe = try await RecipeExtractor.shared.extract(from: urlText)
                await MainActor.run {
                    var parts: [String] = ["🍽 \(recipe.title)"]
                    var meta: [String] = []
                    if let prep = recipe.prepTime { meta.append("Prep: \(prep)") }
                    if let cook = recipe.cookTime { meta.append("Cook: \(cook)") }
                    if let srv = recipe.servings { meta.append("Serves: \(srv)") }
                    if !meta.isEmpty { parts.append(meta.joined(separator: " · ")) }
                    if !recipe.instructions.isEmpty {
                        parts.append("\nInstructions:")
                        for (i, step) in recipe.instructions.enumerated() {
                            parts.append("\(i + 1). \(step)")
                        }
                    }
                    text = parts.joined(separator: "\n")
                    isFetchingRecipe = false
                    recipeFetched = true
                }
            } catch {
                await MainActor.run {
                    isFetchingRecipe = false
                    recipeError = "Couldn't fetch recipe. Check the URL and try again."
                }
            }
        }
    }
    
    private func saveMemory() {
        guard !text.isEmpty else { return }
        sonarResult = sonarEngine.process(text: text, echos: echos)

        let isWorkout = sonarResult?.echoName.lowercased().contains("workout") == true
        if isWorkout,
           let existing = WorkoutSessionManager.shared.mergeIntoTodaySession(
               text: text, echos: echos, context: modelContext) {
            savedMemory = existing
            if let userId = authService.userId {
                Task { await SupabaseSyncService.shared.pushMemory(existing, userId: userId) }
            }
            withAnimation(.spring(duration: 0.4)) { showBanner = true }
            return
        }

        let echoId = sonarResult?.echoId ?? echos.first?.id ?? UUID()
        let memory = Memory(text: text, echoId: echoId, captureType: Memory.CaptureType.typed)
        memory.tags = sonarResult?.tags ?? []
        memory.detectedDate = sonarResult?.detectedDate
        memory.endDate = sonarResult?.endDate
        memory.echoConfidence = sonarResult?.echoConfidence ?? 1.0
        memory.dateConfidence = sonarResult?.dateConfidence
        memory.sonarConfidence = sonarResult?.echoConfidence ?? 1.0
        memory.isActionable = sonarResult?.isActionable ?? false
        memory.estimatedMinutes = sonarResult?.estimatedMinutes
        memory.url = urlText.isEmpty ? nil : urlText
        modelContext.insert(memory)
        SpotlightService.shared.indexMemory(
            memory,
            echoName: sonarResult?.echoName ?? "Notes",
            echoEmoji: echos.first { $0.id == memory.echoId }?.emoji ?? "📝"
        )
        savedMemory = memory
        NotificationService.shared.scheduleInactivityReminder(afterDays: 5)

        if let userId = authService.userId, let result = sonarResult {
            Task {
                await SupabaseSyncService.shared.pushMemory(memory, userId: userId)
                for suggestion in result.pingSuggestions {
                    let fireDate = suggestion.fireDate ?? result.detectedDate ?? Date()
                    let ping = Ping(memoryId: memory.id, fireDate: fireDate, recurrence: suggestion.recurrence)
                    if let fireTime = suggestion.fireTime { ping.fireTime = fireTime }
                    modelContext.insert(ping)
                    await SupabaseSyncService.shared.pushPing(ping, userId: userId)
                    NotificationService.shared.schedulePing(ping: ping, memoryText: memory.text)
                }
                if result.detectedSportsTeam != nil {
                    await SportsMemoryService.shared.createGamePings(
                        for: text, memory: memory,
                        modelContext: modelContext, userId: userId.uuidString)
                }
            }
        }

        AnalyticsService.shared.trackMemoryDropped(
            captureType: "typed", echoName: sonarResult?.echoName ?? "Unknown",
            hasPing: sonarResult?.shouldCreatePing ?? false,
            hasDate: sonarResult?.detectedDate != nil, hasURL: memory.url != nil,
            hasChecklist: memory.hasChecklist, wordCount: text.split(separator: " ").count)

        if urlText.isEmpty {
            if let detectedURL = sonarEngine.detectURL(text: text) { memory.url = detectedURL }
        }
        if !recipeFetched, let checklistItems = sonarEngine.detectChecklist(text: text) {
            memory.hasChecklist = true
            for (index, item) in checklistItems.enumerated() {
                let subTask = SubTask(memoryId: memory.id, text: item, sortOrder: index)
                modelContext.insert(subTask)
            }
        }

        withAnimation(.spring(duration: 0.4)) { showBanner = true }
    }
    
    private func undoMemory() {
        let recent = try? modelContext.fetch(
            FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )
        if let last = recent?.first {
            let id = last.id
            modelContext.delete(last)
            Task { await SupabaseSyncService.shared.deleteMemory(id: id) }
        }
        isPresented = false
    }
}

#Preview {
    TypeCaptureView(isPresented: .constant(true))
        .modelContainer(for: [Memory.self, Echo.self, Ping.self], inMemory: true)
}
