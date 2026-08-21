//
//  ConfirmBannerView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI
import SwiftData

struct ConfirmBannerView: View {
    let transcription: String
    let sonarResult: SonarResult?
    let echos: [Echo]
    let onDone: (Bool, Int?) -> Void
    let onUndo: () -> Void
    var onEchoChanged: ((UUID) -> Void)? = nil
    var onRecipeFetched: ((RecipeResult) -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    // Fired when the inline text was changed: carries the edited text plus a fresh
    // SonarResult so the host can update the memory's date/pings/tags to match.
    var onTextEdited: ((String, SonarResult) -> Void)? = nil
    var onLocationSet: ((String, String?, Double, Double) -> Void)? = nil
    var onGroceryHint: (() -> Void)? = nil
    var onAddToWatchlist: ((String, String, String?) -> Void)? = nil

    @AppStorage("hasSeenBannerTip") private var hasSeenBannerTip = false

    @State private var countdown: CGFloat = 1.0
    @State private var isPaused = false
    @State private var isTask: Bool = false
    @State private var showEchoPicker = false
    @State private var selectedEchoId: UUID?
    @State private var isFetchingRecipe = false
    @State private var recipeFetchError: String? = nil
    @State private var recipeFetchSuccess = false
    @State private var wasCancelled = false
    @State private var didComplete = false
    // Sonar re-run bookkeeping: don't clobber choices the user made by hand
    @State private var userPickedEcho = false
    @State private var userToggledTask = false
    @State private var lastSonarText = ""
    @State private var locationName: String? = nil
    @State private var locationAddress: String? = nil
    @State private var latitude: Double? = nil
    @State private var longitude: Double? = nil
    @State private var showLocationSearch = false
    @State private var showAddPerson = false
    @State private var showRecipeBuilder = false
    @State private var personToCreate = ""
    @State private var isEditingText = false
    @State private var editedText: String = ""
    @State private var selectedDuration: Int? = nil
    @FocusState private var textFieldFocused: Bool
    @State private var addedToWatchlist = false
    @State private var showTipOverlay = false
    @State private var addedToCalendar = false

    @Query private var persons: [Person]

    private var isDiningOrEvents: Bool {
        let echoName: String
        if let id = selectedEchoId, let echo = echos.first(where: { $0.id == id }) {
            echoName = echo.name
        } else {
            echoName = sonarResult?.echoName ?? ""
        }
        return echoName == "Dining" || echoName == "Events" || (sonarResult?.hasRestaurantSignal == true)
    }

    private var hasDetectedDuration: Bool {
        if let mins = sonarResult?.estimatedMinutes, mins > 0 { return true }
        return false
    }

    private var showDurationRow: Bool {
        isTask && !hasDetectedDuration && selectedDuration == nil
    }

    private var effectiveDuration: Int? {
        if let selected = selectedDuration { return selected }
        if let mins = sonarResult?.estimatedMinutes, mins > 0 { return mins }
        return nil
    }

    /// Sonar wasn't confident about the echo and the user hasn't overridden it.
    private var isUncertain: Bool {
        guard let result = sonarResult, !userPickedEcho else { return false }
        return result.echoConfidence < 0.7
    }

    /// One quiet line saying where it landed and when — replaces the chip row.
    private func summaryLine(echoName: String) -> String {
        var parts: [String] = [echoName]
        if let date = sonarResult?.detectedDate {
            if let end = sonarResult?.endDate {
                parts.append("\(date.formatted(.dateTime.month(.abbreviated).day()))–\(end.formatted(.dateTime.month(.abbreviated).day()))")
            } else {
                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                let hasTime = (comps.hour ?? 0) != 0 || (comps.minute ?? 0) != 0
                // Always name the date — "Thu 3:00 PM" is ambiguous past this week
                parts.append(hasTime
                    ? date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                    : date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
            }
        }
        parts.append(contentsOf: reminderPart())
        return parts.joined(separator: " · ")
    }

    /// When the reminder actually fires. "reminder set" alongside a 7pm event hides
    /// the fact that the ping is at 6 — which is exactly the detail worth confirming.
    private func reminderPart() -> [String] {
        guard sonarResult?.shouldCreatePing == true,
              let suggestion = sonarResult?.pingSuggestions.first else { return [] }

        let cal = Calendar.current
        let event = sonarResult?.detectedDate
        // Mirrors how the notification is scheduled: day from fireDate, time from fireTime
        guard let daySource = suggestion.fireDate ?? event else { return ["reminder set"] }
        let timeSource = suggestion.fireTime ?? suggestion.fireDate ?? daySource
        var comps = cal.dateComponents([.year, .month, .day], from: daySource)
        let t = cal.dateComponents([.hour, .minute], from: timeSource)
        comps.hour = t.hour; comps.minute = t.minute
        guard let firesAt = cal.date(from: comps) else { return ["reminder set"] }

        let recurrence = suggestion.recurrence
        if recurrence != .none {
            return ["reminds \(recurrence.rawValue) \(firesAt.formatted(.dateTime.hour().minute()))"]
        }
        // Same moment as the event — no need to repeat it
        if let event, abs(firesAt.timeIntervalSince(event)) < 60 { return ["reminder set"] }
        if let event, cal.isDate(firesAt, inSameDayAs: event) {
            return ["reminder \(firesAt.formatted(.dateTime.hour().minute()))"]
        }
        return ["reminder \(firesAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))"]
    }

    private func extractRestaurantName(from text: String) -> String {
        let commonWords = Set(["the","a","an","for","at","in","on","to","of","and","with","from","by","i","we","my","our","is","are","was","were","tomorrow","today","tonight","dinner","lunch","brunch","breakfast","monday","tuesday","wednesday","thursday","friday","saturday","sunday","pm","am","next","this","going","want","lets","let","have","had"])
        let words = text.components(separatedBy: .whitespaces)
        var properNouns: [String] = []
        for word in words {
            let clean = word.trimmingCharacters(in: .punctuationCharacters)
            guard clean.count > 1 else { continue }
            if let first = clean.first, first.isLowercase {
                if !properNouns.isEmpty && !commonWords.contains(clean.lowercased()) { break }
                continue
            }
            guard !commonWords.contains(clean.lowercased()) else { continue }
            properNouns.append(clean)
            if properNouns.count == 3 { break }
        }
        return properNouns.isEmpty ? text : properNouns.joined(separator: " ")
    }

    var body: some View {
        VStack(spacing: 8) {

            // MARK: - Tip overlay
            if showTipOverlay {
                BannerTipOverlay {
                    withAnimation(.spring(duration: 0.3)) {
                        showTipOverlay = false
                        hasSeenBannerTip = true
                        isPaused = false
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // MARK: - Main banner
            VStack(spacing: 0) {
                // Auto-dismiss indicator, deliberately quiet. A bold teal countdown
                // turned a confirmation into a timed test; this still signals "this
                // will close itself" without making it feel like a clock.
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.gray.opacity(0.18))
                        .frame(width: geo.size.width * countdown, height: 2)
                }
                .frame(height: 2)

                VStack(spacing: 10) {
                    let echoName = echos.first { $0.id == selectedEchoId }?.name
                        ?? sonarResult?.echoName ?? "Memory"
                    let echoEmoji = echos.first { $0.id == selectedEchoId }?.emoji
                        ?? echos.first { $0.name == sonarResult?.echoName }?.emoji ?? "📝"

                    // MARK: - What happened
                    //
                    // The banner's job is to say "got it", not to run a form. Chips
                    // are an admission of uncertainty, so they only appear when
                    // Sonar actually is uncertain. Everything else moved to the
                    // memory detail, where there's no clock running.

                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            if isEditingText {
                                TextField("Edit memory...", text: $editedText, axis: .vertical)
                                    .font(.custom("DMSans-Regular", size: 15))
                                    .foregroundColor(.deepNavy)
                                    .focused($textFieldFocused)
                                    .lineLimit(4)
                                    .padding(8)
                                    .background(Color.pearl)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.oceanTeal, lineWidth: 1.5))
                                Button {
                                    isEditingText = false
                                    textFieldFocused = false
                                    reRunSonarIfNeeded()
                                } label: {
                                    Text("Done editing")
                                        .font(.custom("DMSans-Medium", size: 12))
                                        .foregroundColor(.oceanTeal)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text(editedText)
                                    .font(.custom("DMSans-Medium", size: 15))
                                    .foregroundColor(.deepNavy)
                                    .lineLimit(2)
                                    .onTapGesture {
                                        isPaused = true
                                        isEditingText = true
                                        textFieldFocused = true
                                    }

                                // One quiet line saying where it went
                                Button {
                                    isPaused = true
                                    withAnimation(.easeOut(duration: 0.2)) { showEchoPicker.toggle() }
                                } label: {
                                    HStack(spacing: 5) {
                                        Text(echoEmoji).font(.system(size: 11))
                                        Text(summaryLine(echoName: echoName))
                                            .font(.custom("DMSans-Regular", size: 12))
                                            .foregroundColor(isUncertain ? .coral : .gray)
                                            .lineLimit(1)
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 7, weight: .bold))
                                            .foregroundColor(isUncertain ? .coral.opacity(0.7) : .gray.opacity(0.5))
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                    }

                    // MARK: - Adaptive row
                    //
                    // Shown only when there's a real decision to make.

                    if showEchoPicker {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(echos.sorted { $0.sortOrder < $1.sortOrder }, id: \.id) { echo in
                                    Button {
                                        selectedEchoId = echo.id
                                        userPickedEcho = true
                                        onEchoChanged?(echo.id)
                                        withAnimation(.easeOut(duration: 0.2)) { showEchoPicker = false }
                                    } label: {
                                        HStack(spacing: 3) {
                                            Text(echo.emoji).font(.system(size: 12))
                                            Text(echo.name)
                                                .font(.custom("DMSans-Medium", size: 12))
                                                .foregroundColor(selectedEchoId == echo.id ? .white : .deepNavy)
                                        }
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(selectedEchoId == echo.id ? Color.oceanTeal : Color.mist)
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    } else {
                        HStack(spacing: 18) {
                            Button {
                                wasCancelled = true
                                onUndo()
                            } label: {
                                Text("Undo")
                                    .font(.custom("DMSans-Medium", size: 13))
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(.plain)

                            Button {
                                isPaused = true
                                onEdit?()
                            } label: {
                                Text("Edit")
                                    .font(.custom("DMSans-Medium", size: 13))
                                    .foregroundColor(.oceanTeal)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            // The one edit people make constantly
                            Button {
                                isPaused = true
                                userToggledTask = true
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(duration: 0.2)) { isTask.toggle() }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: isTask ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 12))
                                    Text("Task").font(.custom("DMSans-Medium", size: 13))
                                }
                                .foregroundColor(isTask ? .oceanTeal : .gray.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // The only thing you have to hit, so it gets the full width
                    Button {
                        guard !didComplete else { return }
                        didComplete = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        reRunSonarIfNeeded()
                        let echoId = selectedEchoId ?? echos.first { $0.name == sonarResult?.echoName }?.id
                        if let echoId, let confirmedEcho = echos.first(where: { $0.id == echoId }) {
                            SonarEngine.learnKeywords(from: editedText, echo: confirmedEcho)
                        }
                        onDone(isTask, effectiveDuration)
                    } label: {
                        Text("Looks good!")
                            .font(.custom("DMSans-Medium", size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.oceanTeal)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.top, 2)

                    // Recipe fetch stays — it's only relevant right now, while the
                    // link is fresh, and it does real work rather than adjusting a field
                    if sonarResult?.shouldOfferRecipeFetch == true {
                        Button { fetchRecipe() } label: {
                            HStack(spacing: 8) {
                                if isFetchingRecipe {
                                    ProgressView().scaleEffect(0.7).tint(.white)
                                } else {
                                    Image(systemName: recipeFetchSuccess ? "checkmark" : "fork.knife")
                                        .font(.system(size: 12))
                                }
                                Text(isFetchingRecipe ? "Fetching recipe..."
                                     : recipeFetchSuccess ? "Recipe imported" : "Fetch recipe from link")
                                    .font(.custom("DMSans-Medium", size: 13))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Color.oceanTeal)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(isFetchingRecipe)

                        if let error = recipeFetchError {
                            Text(error).font(.custom("DMSans-Regular", size: 11)).foregroundColor(.coral)
                        }
                    }

                } // end VStack(spacing: 10)
                .padding(16)

            } // end main banner VStack
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 20, y: -4)

        } // end outer VStack
        .padding(.horizontal, 12)
        .padding(.bottom, 32)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            editedText = transcription
            lastSonarText = transcription
            isTask = sonarResult?.isActionable ?? false
            selectedEchoId = echos.first { $0.name == sonarResult?.echoName }?.id
            if let date = sonarResult?.detectedDate {
                addedToCalendar = CalendarService.shared.isAlreadyAdded(title: transcription, date: date)
            }
            if !hasSeenBannerTip {
                isPaused = true
                withAnimation(.spring(duration: 0.4).delay(0.3)) {
                    showTipOverlay = true
                }
            }
            startCountdown()
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            if sonarResult?.echoName == "Birthday", let detectedDate = sonarResult?.detectedDate {
                let allNames = (sonarResult?.detectedPeople ?? []).map { $0.capitalized }
                for name in allNames {
                    if let match = persons.first(where: { person in
                        let firstName = person.name.split(separator: " ").first.map(String.init) ?? person.name
                        return firstName.lowercased() == name.lowercased()
                    }), match.birthday == nil {
                        match.birthday = detectedDate
                        match.updatedAt = Date()
                    }
                }
            }

            if let detectedDate = sonarResult?.detectedDate {
                let allNames = (sonarResult?.detectedPeople ?? []).map { $0.capitalized }
                let occasionMap: [String: String] = ["anniversary": "Anniversary","christmas": "Christmas","graduation": "Graduation","valentine": "Valentine's Day","halloween": "Halloween"]
                for (keyword, occasionName) in occasionMap {
                    if transcription.lowercased().contains(keyword) {
                        for name in allNames {
                            if let match = persons.first(where: { person in
                                let firstName = person.name.split(separator: " ").first.map(String.init) ?? person.name
                                return firstName.lowercased() == name.lowercased()
                            }), match.occasionDates[occasionName] == nil {
                                match.occasionDates[occasionName] = detectedDate
                                match.updatedAt = Date()
                            }
                        }
                    }
                }
            }
        }
        // Full edit (MemoryEditView) syncs back through `transcription` — refresh the
        // inline draft so a later Done can't overwrite the full edit with stale text,
        // and treat the synced text as already-processed so we don't re-run over it.
        .onChange(of: transcription) { _, newValue in
            if !isEditingText { editedText = newValue }
            lastSonarText = newValue
        }
        .sheet(isPresented: $showAddPerson) {
            AddPersonView(suggestedName: personToCreate, suggestedBirthday: sonarResult?.detectedDate)
        }
        .sheet(isPresented: $showRecipeBuilder) { RecipeBuilderView() }
        .sheet(isPresented: $showLocationSearch) {
            LocationSearchView(initialQuery: sonarResult?.suggestedLocationName ?? extractRestaurantName(from: transcription)) { name, address, lat, lng in
                locationName = name
                locationAddress = address
                latitude = lat
                longitude = lng
                onLocationSet?(name, address, lat, lng)
                let currentEchoName: String
                if let id = selectedEchoId, let echo = echos.first(where: { $0.id == id }) {
                    currentEchoName = echo.name
                } else {
                    currentEchoName = sonarResult?.echoName ?? ""
                }
                if currentEchoName != "Dining" && currentEchoName != "Events" {
                    if let diningEcho = echos.first(where: { $0.name == "Dining" }) {
                        selectedEchoId = diningEcho.id
                        onEchoChanged?(diningEcho.id)
                    }
                }
            }
        }
    }

    private func startCountdown() {
        withAnimation(.linear(duration: 15)) { countdown = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            // didComplete guards against firing after a manual Done — otherwise this
            // stale closure would stamp whatever memory is newest 15s later.
            if !isPaused && !wasCancelled && !didComplete {
                didComplete = true
                reRunSonarIfNeeded()
                let echoId = selectedEchoId ?? echos.first { $0.name == sonarResult?.echoName }?.id
                if let echoId, let confirmedEcho = echos.first(where: { $0.id == echoId }) {
                    SonarEngine.learnKeywords(from: editedText, echo: confirmedEcho)
                }
                onDone(isTask, effectiveDuration)
            }
        }
    }

    // Re-run Sonar over the edited text so the echo/date/ping chips (and, via
    // onTextEdited, the saved memory) track what the user actually wrote — e.g.
    // editing "4pm" to "3pm" moves the ping. Choices made by hand win: a manually
    // picked echo and a manually toggled Task chip are never overwritten.
    private func reRunSonarIfNeeded() {
        guard editedText != lastSonarText,
              !editedText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        lastSonarText = editedText
        let newResult = SonarEngine().process(text: editedText, echos: echos)
        if !userPickedEcho {
            let newEchoId = newResult.echoId ?? echos.first { $0.name == newResult.echoName }?.id
            if let newEchoId, newEchoId != selectedEchoId {
                selectedEchoId = newEchoId
                onEchoChanged?(newEchoId)
            }
        }
        if !userToggledTask { isTask = newResult.isActionable }
        onTextEdited?(editedText, newResult)
    }

    private func fetchRecipe() {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(transcription.startIndex..<transcription.endIndex, in: transcription)
        guard let urlString = detector?.matches(in: transcription, range: range).first?.url?.absoluteString else { return }
        isPaused = true
        isFetchingRecipe = true
        recipeFetchError = nil
        Task {
            do {
                let recipe = try await RecipeExtractor.shared.extract(from: urlString)
                await MainActor.run {
                    onRecipeFetched?(recipe)
                    isFetchingRecipe = false
                    recipeFetchSuccess = true
                    showGroceryHintIfNeeded()
                }
            } catch {
                await MainActor.run {
                    isFetchingRecipe = false
                    recipeFetchError = error.localizedDescription
                }
            }
        }
    }

    private func showGroceryHintIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: "orcaShownGroceryHint") else { return }
        UserDefaults.standard.set(true, forKey: "orcaShownGroceryHint")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { onGroceryHint?() }
    }
}

// MARK: - Banner Tip Overlay

private struct BannerTipOverlay: View {
    let onDismiss: () -> Void

    let tips: [(String, String, String)] = [
        ("waveform", "Sonar filed your memory", "Orca auto-detected the echo, date, and reminder."),
        ("square.grid.2x2", "Wrong echo? Tap it", "The echo chip is tappable — swap it to any category instantly."),
        ("bell.fill", "🔔 means a ping is set", "Orca will remind you at the right time automatically."),
        ("checkmark.circle", "Toggle Task on or off", "Tap the Task chip to mark this as something to do."),
        ("pencil", "Tap your text to edit", "Fix any transcription errors before saving."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your first Drop 🎉")
                            .font(.custom("DMSans-Medium", size: 17))
                            .foregroundColor(.white)
                        Text("Here's what everything does")
                            .font(.custom("DMSans-Regular", size: 13))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                VStack(spacing: 0) {
                    ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(.white.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: tip.0)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tip.1)
                                    .font(.custom("DMSans-Medium", size: 14))
                                    .foregroundColor(.white)
                                Text(tip.2)
                                    .font(.custom("DMSans-Regular", size: 12))
                                    .foregroundColor(.white.opacity(0.65))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)

                        if index < tips.count - 1 {
                            Divider()
                                .background(.white.opacity(0.15))
                                .padding(.leading, 70)
                        }
                    }
                }

                Button {
                    onDismiss()
                } label: {
                    Text("Got it")
                        .font(.custom("DMSans-Medium", size: 16))
                        .foregroundColor(.oceanTeal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "0B1D33"), Color(hex: "1A3A5C")],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 24, y: -8)
    }
}
