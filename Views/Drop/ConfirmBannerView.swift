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

                // MARK: - Title row (separate from buttons)
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

                // MARK: - Buttons row (separate line)
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
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
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
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
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
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
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
                                            .foregroundColor(.deepNavy)
                                            .lineLimit(1)
                                    } else {
                                        let echo = echos.first { $0.name == result.echoName }
                                        Text(echo?.emoji ?? "📝").font(.system(size: 13))
                                        Text(result.echoName)
                                            .font(.custom("DMSans-Medium", size: 13))
                                            .foregroundColor(.deepNavy)
                                            .lineLimit(1)
                                    }
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.gray)
                                    if result.echoConfidence < 0.7 {
                                        Text("?")
                                            .font(.custom("DMSans-Bold", size: 11))
                                            .foregroundColor(.white)
                                            .frame(width: 16, height: 16)
                                            .background(Color.coral)
                                            .clipShape(Circle())
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.mist)
                                .clipShape(Capsule())
                            }

                            // Date chip
                            if let date = result.detectedDate {
                                HStack(spacing: 4) {
                                    Text("📅").font(.system(size: 13))
                                    if let endDate = result.endDate {
                                        Text("\(date.formatted(.dateTime.month(.abbreviated).day())) – \(endDate.formatted(.dateTime.month(.abbreviated).day()))")
                                            .font(.custom("DMSans-Medium", size: 13))
                                            .foregroundColor(.deepNavy)
                                            .lineLimit(1)
                                    } else {
                                        Text(date, format: .dateTime.month(.abbreviated).day())
                                            .font(.custom("DMSans-Medium", size: 13))
                                            .foregroundColor(.deepNavy)
                                            .lineLimit(1)
                                    }
                                    if (result.dateConfidence ?? 0) < 0.7 {
                                        Text("?")
                                            .font(.custom("DMSans-Bold", size: 11))
                                            .foregroundColor(.white)
                                            .frame(width: 16, height: 16)
                                            .background(Color.coral)
                                            .clipShape(Circle())
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.mist)
                                .clipShape(Capsule())
                            }

                            // Ping chip
                            if result.shouldCreatePing {
                                HStack(spacing: 4) {
                                    Text("🔔").font(.system(size: 13))
                                    Text(result.pingRecurrence == .none ? "Ping" : result.pingRecurrence.rawValue.capitalized)
                                        .font(.custom("DMSans-Medium", size: 13))
                                        .foregroundColor(.deepNavy)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.mist)
                                .clipShape(Capsule())
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
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .onTapGesture {
                                                    locationName = nil
                                                    locationAddress = nil
                                                    latitude = nil
                                                    longitude = nil
                                                }
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.mist)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
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
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
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
        withAnimation(.linear(duration: 5)) { countdown = 0 }
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
        // Small delay so it doesn't compete with the recipe success state
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            onGroceryHint?()
        }
    }
}
