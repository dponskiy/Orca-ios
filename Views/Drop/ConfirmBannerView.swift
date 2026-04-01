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
    let onDone: (Bool) -> Void
    let onUndo: () -> Void
    var onEchoChanged: ((UUID) -> Void)? = nil
    var onRecipeFetched: ((RecipeResult) -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onLocationSet: ((String, String?, Double, Double) -> Void)? = nil
    var onGroceryHint: (() -> Void)? = nil

    @State private var countdown: CGFloat = 1.0
    @State private var isPaused = false
    @State private var isEditing = false
    @State private var isTask: Bool = false
    @State private var showEchoPicker = false
    @State private var selectedEchoId: UUID?
    @State private var isFetchingRecipe = false
    @State private var recipeFetchError: String? = nil
    @State private var recipeFetchSuccess = false
    @State private var wasCancelled = false
    @State private var locationName: String? = nil
    @State private var locationAddress: String? = nil
    @State private var latitude: Double? = nil
    @State private var longitude: Double? = nil
    @State private var showLocationSearch = false
    @State private var showAddPerson = false
    @State private var personToCreate = ""

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

    private func extractRestaurantName(from text: String) -> String {
        let commonWords = Set([
            "the", "a", "an", "for", "at", "in", "on", "to", "of", "and", "with",
            "from", "by", "i", "we", "my", "our", "is", "are", "was", "were",
            "tomorrow", "today", "tonight", "dinner", "lunch", "brunch", "breakfast",
            "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
            "pm", "am", "next", "this", "going", "want", "lets", "let", "have", "had"
        ])
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
        VStack(spacing: 0) {
            // Progress bar
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.oceanTeal)
                    .frame(width: geo.size.width * countdown, height: 3)
            }
            .frame(height: 3)

            VStack(spacing: 12) {
                let echoName = echos.first { $0.id == selectedEchoId }?.name
                    ?? sonarResult?.echoName ?? "Memory"
                let echoEmoji = echos.first { $0.id == selectedEchoId }?.emoji
                    ?? echos.first { $0.name == sonarResult?.echoName }?.emoji ?? "📝"

                // MARK: - Title row
                HStack(spacing: 4) {
                    Text("Dropped to \(echoName) \(echoEmoji)")
                        .font(.custom("DMSans-Medium", size: 15))
                        .foregroundColor(.deepNavy)
                        .lineLimit(1)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.oceanTeal)
                    if isPaused {
                        Text("· editing")
                            .font(.custom("DMSans-Regular", size: 12))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    Spacer()
                }

                // MARK: - Buttons row
                HStack(spacing: 8) {
                    Button {
                        isPaused = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(duration: 0.2)) { isTask.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isTask ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 13))
                                .foregroundColor(isTask ? .white : .gray)
                            Text("Task")
                                .font(.custom("DMSans-Medium", size: 13))
                                .foregroundColor(isTask ? .white : .gray)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(isTask ? Color.oceanTeal : Color.mist)
                        .clipShape(Capsule())
                    }

                    Spacer()

                    Button {
                        wasCancelled = true
                        onUndo()
                    } label: {
                        Text("Undo")
                            .font(.custom("DMSans-Medium", size: 14))
                            .foregroundColor(.deepNavy)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        let echoId = selectedEchoId ?? echos.first { $0.name == sonarResult?.echoName }?.id
                        if let echoId, let confirmedEcho = echos.first(where: { $0.id == echoId }) {
                            SonarEngine.learnKeywords(from: transcription, echo: confirmedEcho)
                        }
                        onDone(isTask)
                    } label: {
                        Text("Done")
                            .font(.custom("DMSans-Medium", size: 14))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(Color.oceanTeal)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }

                // MARK: - Transcription box
                VStack(alignment: .leading, spacing: 4) {
                    Text(transcription)
                        .font(.custom("DMSans-Regular", size: 15))
                        .foregroundColor(.deepNavy)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !isEditing {
                        Text("Tap to edit")
                            .font(.custom("DMSans-Regular", size: 12))
                            .foregroundColor(.gray)
                    }
                }
                .padding(12)
                .background(Color.pearl)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onTapGesture {
                    isPaused = true
                    onEdit?()
                }

                // MARK: - Chips row (scrollable)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let result = sonarResult {
                            // Echo chip
                            Button {
                                isPaused = true
                                withAnimation(.easeOut(duration: 0.2)) { showEchoPicker.toggle() }
                            } label: {
                                HStack(spacing: 4) {
                                    if let echoId = selectedEchoId,
                                       let echo = echos.first(where: { $0.id == echoId }) {
                                        Text(echo.emoji).font(.system(size: 13))
                                        Text(echo.name)
                                            .font(.custom("DMSans-Medium", size: 13))
                                            .foregroundColor(.deepNavy).lineLimit(1)
                                    } else {
                                        let echo = echos.first { $0.name == result.echoName }
                                        Text(echo?.emoji ?? "📝").font(.system(size: 13))
                                        Text(result.echoName)
                                            .font(.custom("DMSans-Medium", size: 13))
                                            .foregroundColor(.deepNavy).lineLimit(1)
                                    }
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 9, weight: .bold)).foregroundColor(.gray)
                                    if result.echoConfidence < 0.7 {
                                        Text("?")
                                            .font(.custom("DMSans-Bold", size: 11)).foregroundColor(.white)
                                            .frame(width: 16, height: 16).background(Color.coral).clipShape(Circle())
                                    }
                                }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.mist).clipShape(Capsule())
                            }

                            // Date chip
                            if let date = result.detectedDate {
                                HStack(spacing: 4) {
                                    Text("📅").font(.system(size: 13))
                                    if let endDate = result.endDate {
                                        Text("\(date.formatted(.dateTime.month(.abbreviated).day())) – \(endDate.formatted(.dateTime.month(.abbreviated).day()))")
                                            .font(.custom("DMSans-Medium", size: 13))
                                            .foregroundColor(.deepNavy).lineLimit(1)
                                    } else {
                                        Text(date, format: .dateTime.month(.abbreviated).day())
                                            .font(.custom("DMSans-Medium", size: 13))
                                            .foregroundColor(.deepNavy).lineLimit(1)
                                    }
                                    if (result.dateConfidence ?? 0) < 0.7 {
                                        Text("?")
                                            .font(.custom("DMSans-Bold", size: 11)).foregroundColor(.white)
                                            .frame(width: 16, height: 16).background(Color.coral).clipShape(Circle())
                                    }
                                }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.mist).clipShape(Capsule())
                            }

                            // Ping chip
                            if result.shouldCreatePing {
                                HStack(spacing: 4) {
                                    Text("🔔").font(.system(size: 13))
                                    Text(result.pingRecurrence == .none ? "Ping" : result.pingRecurrence.rawValue.capitalized)
                                        .font(.custom("DMSans-Medium", size: 13))
                                        .foregroundColor(.deepNavy).lineLimit(1)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.mist).clipShape(Capsule())
                            }

                            // Location chip
                            if isDiningOrEvents {
                                Button {
                                    isPaused = true
                                    showLocationSearch = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: locationName != nil ? "mappin.circle.fill" : "mappin.circle")
                                            .font(.system(size: 13))
                                            .foregroundColor(locationName != nil ? Color.oceanTeal : .secondary)
                                        Text(locationName ?? "Add Location")
                                            .font(.custom("DMSans-Medium", size: 13))
                                            .foregroundColor(locationName != nil ? .deepNavy : .secondary)
                                            .lineLimit(1)
                                        if locationName != nil {
                                            Image(systemName: "xmark")
                                                .font(.caption2).foregroundColor(.secondary)
                                                .onTapGesture {
                                                    locationName = nil
                                                    locationAddress = nil
                                                    latitude = nil
                                                    longitude = nil
                                                }
                                        }
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Color.mist).clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // MARK: - Person suggestion row
                let isTravelEcho = sonarResult?.echoName.lowercased().contains("travel") == true

                let commonNonNames = Set([
                    // Months
                    "january", "february", "march", "april", "may", "june", "july",
                    "august", "september", "october", "november", "december",
                    // Days
                    "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "day", "eve", "eve's",
                    // Occasions
                    "birthday", "christmas", "holiday", "anniversary", "halloween", "thanksgiving",
                    // Time
                    "today", "tomorrow", "tonight", "morning", "afternoon", "evening",
                    // Action verbs
                    "get", "got", "getting", "buy", "bought", "buying", "remind", "remember",
                    "call", "need", "want", "make", "take", "send", "find", "pick", "grab",
                    "order", "ordered", "check", "set", "ask", "tell", "show",
                    // Tech brands
                    "xbox", "playstation", "nintendo", "apple", "google", "amazon", "samsung",
                    "microsoft", "sony", "meta", "tesla", "netflix", "spotify", "airpods",
                    "iphone", "ipad", "macbook", "android",
                    // Clothing brands
                    "nike", "adidas", "lululemon", "zara", "gucci", "prada", "louis",
                    // Common gift items
                    "controller", "headphones", "keyboard", "monitor", "laptop", "tablet",
                    // Holidays
                    "christmas", "thanksgiving", "halloween", "hanukkah", "easter",
                    "valentine", "valentines", "mothers", "fathers", "mother", "father", "independence",
                    "memorial", "labor", "presidents", "martin", "luther", "king",
                    "columbus", "veterans", "passover", "ramadan", "kwanzaa", "diwali",
                    // Other common words that get capitalized mid-sentence
                    "new", "the", "a", "an", "for", "with", "from", "just", "also",
                ])

                let nlpPeople = sonarResult?.detectedPeople ?? []
                // Fixed: only flag capitalized words that appear after person-indicating words
                let personIndicators = Set(["for", "with", "tell", "ask", "remind", "call", "text",
                                             "email", "invite", "get", "buy", "give", "send", "show"])
                let words = transcription.components(separatedBy: .whitespaces)
                let textScannedPeople: [String] = words.enumerated().compactMap { i, word in
                    let clean = word.trimmingCharacters(in: .punctuationCharacters)
                    guard clean.count > 2,
                          clean.first?.isUppercase == true,
                          !commonNonNames.contains(clean.lowercased()) else { return nil }

                    // Must be preceded by a person-indicating word
                    guard i > 0 else { return nil }
                    let prevWord = words[i - 1].trimmingCharacters(in: .punctuationCharacters).lowercased()
                    guard personIndicators.contains(prevWord) else { return nil }

                    return clean
                }
                let allDetectedPeople = Array(Set(
                    nlpPeople.map { name in
                        let stripped = name.hasSuffix("'s") ? String(name.dropLast(2)) : name.hasSuffix("s'") ? String(name.dropLast(1)) : name
                        return stripped.capitalized
                    } +
                    textScannedPeople.map { name in
                        name.hasSuffix("'s") ? String(name.dropLast(2)) : name.hasSuffix("s'") ? String(name.dropLast(1)) : name
                    }
                ))

                if !allDetectedPeople.isEmpty, !isTravelEcho {
                    let unmatched = allDetectedPeople.filter { detectedName in
                        !persons.contains { person in
                            let firstName = person.name.split(separator: " ").first.map(String.init) ?? person.name
                            return firstName.lowercased() == detectedName.lowercased()
                        }
                    }
                    if let firstUnmatched = unmatched.first {
                        Button {
                            isPaused = true
                            personToCreate = firstUnmatched
                            showAddPerson = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 16))
                                    .foregroundColor(.oceanTeal)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Create \(firstUnmatched)'s profile")
                                        .font(.custom("DMSans-Medium", size: 13))
                                        .foregroundColor(.deepNavy)
                                    Text("Tap to save birthday, gifts & more")
                                        .font(.custom("DMSans-Regular", size: 11))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray.opacity(0.4))
                            }
                            .padding(12)
                            .background(Color.oceanTeal.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.oceanTeal.opacity(0.15), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // MARK: - Echo picker expanded
                if showEchoPicker {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(echos.sorted { $0.sortOrder < $1.sortOrder }, id: \.id) { echo in
                                Button {
                                    selectedEchoId = echo.id
                                    onEchoChanged?(echo.id)
                                    withAnimation(.easeOut(duration: 0.2)) { showEchoPicker = false }
                                } label: {
                                    HStack(spacing: 3) {
                                        Text(echo.emoji).font(.system(size: 12))
                                        Text(echo.name)
                                            .font(.custom("DMSans-Medium", size: 12))
                                            .foregroundColor(selectedEchoId == echo.id ? .white : .deepNavy)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(selectedEchoId == echo.id ? Color.oceanTeal : Color.mist)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }

                // MARK: - Recipe fetch
                if sonarResult?.shouldOfferRecipeFetch == true {
                    VStack(alignment: .leading, spacing: 6) {
                        Button { fetchRecipe() } label: {
                            HStack(spacing: 8) {
                                if isFetchingRecipe {
                                    ProgressView().scaleEffect(0.75).tint(.white)
                                } else {
                                    Image(systemName: recipeFetchSuccess ? "checkmark" : "fork.knife")
                                        .font(.system(size: 13))
                                }
                                Text(isFetchingRecipe ? "Fetching recipe..." : recipeFetchSuccess ? "Recipe imported!" : "🍳 Fetch Recipe from Link")
                                    .font(.custom("DMSans-Medium", size: 13))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.oceanTeal)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(isFetchingRecipe)

                        if let error = recipeFetchError {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.circle")
                                    .font(.system(size: 11))
                                    .foregroundColor(.coral)
                                Text(error)
                                    .font(.custom("DMSans-Regular", size: 12))
                                    .foregroundColor(.coral)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 16, y: -4)
        .padding(.horizontal, 8)
        .transition(.move(edge: .bottom))
        .onAppear {
            isTask = sonarResult?.isActionable ?? false
            selectedEchoId = echos.first { $0.name == sonarResult?.echoName }?.id
            startCountdown()
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            // Auto-update birthday on existing profile
            if sonarResult?.echoName == "Birthday",
               let detectedDate = sonarResult?.detectedDate {
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

            // Auto-update occasion dates on existing profile
            if let detectedDate = sonarResult?.detectedDate {
                let allNames = (sonarResult?.detectedPeople ?? []).map { $0.capitalized }
                let occasionMap: [String: String] = [
                    "anniversary": "Anniversary",
                    "christmas": "Christmas",
                    "graduation": "Graduation",
                    "valentine": "Valentine's Day",
                    "halloween": "Halloween"
                ]
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
        .sheet(isPresented: $showAddPerson) {
            AddPersonView(
                suggestedName: personToCreate,
                suggestedBirthday: sonarResult?.detectedDate
            )
        }
        .sheet(isPresented: $showLocationSearch) {
            LocationSearchView(
                initialQuery: sonarResult?.suggestedLocationName ?? extractRestaurantName(from: transcription)
            ) { name, address, lat, lng in
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
        withAnimation(.linear(duration: 7)) { countdown = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if !isPaused && !wasCancelled {
                let echoId = selectedEchoId ?? echos.first { $0.name == sonarResult?.echoName }?.id
                if let echoId, let confirmedEcho = echos.first(where: { $0.id == echoId }) {
                    SonarEngine.learnKeywords(from: transcription, echo: confirmedEcho)
                }
                onDone(isTask)
            }
        }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            onGroceryHint?()
        }
    }
}
