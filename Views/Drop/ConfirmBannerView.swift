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
                // Progress bar
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.oceanTeal)
                        .frame(width: geo.size.width * countdown, height: 3)
                }
                .frame(height: 3)

                VStack(spacing: 10) {
                    let echoName = echos.first { $0.id == selectedEchoId }?.name
                        ?? sonarResult?.echoName ?? "Memory"
                    let echoEmoji = echos.first { $0.id == selectedEchoId }?.emoji
                        ?? echos.first { $0.name == sonarResult?.echoName }?.emoji ?? "📝"

                    // MARK: - Top row
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
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
                                    .lineLimit(3)
                                    .onTapGesture {
                                        isPaused = true
                                        isEditingText = true
                                        textFieldFocused = true
                                    }

                                HStack(spacing: 6) {
                                    Text("tap to edit")
                                        .font(.custom("DMSans-Regular", size: 11))
                                        .foregroundColor(.gray)
                                    Text("·")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                    Button {
                                        isPaused = true
                                        onEdit?()
                                    } label: {
                                        Text("full edit")
                                            .font(.custom("DMSans-Regular", size: 11))
                                            .foregroundColor(.oceanTeal)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 6) {
                            Button {
                                wasCancelled = true
                                onUndo()
                            } label: {
                                Text("Undo")
                                    .font(.custom("DMSans-Medium", size: 13))
                                    .foregroundColor(.deepNavy)
                                    .padding(.horizontal, 14).padding(.vertical, 6)
                                    .overlay(Capsule().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                            }

                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                let echoId = selectedEchoId ?? echos.first { $0.name == sonarResult?.echoName }?.id
                                if let echoId, let confirmedEcho = echos.first(where: { $0.id == echoId }) {
                                    SonarEngine.learnKeywords(from: editedText, echo: confirmedEcho)
                                }
                                onDone(isTask, effectiveDuration)
                            } label: {
                                Text("Done")
                                    .font(.custom("DMSans-Medium", size: 13))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14).padding(.vertical, 6)
                                    .background(Color.oceanTeal)
                                    .clipShape(Capsule())
                            }
                        }
                        .fixedSize()
                    }

                    // MARK: - Chips hint row
                    HStack {
                        Text("Wrong echo? Tap to change")
                            .font(.custom("DMSans-Regular", size: 11))
                            .foregroundColor(.gray)
                        Spacer()
                        Button {
                            isPaused = true
                            withAnimation(.spring(duration: 0.3)) { showTipOverlay = true }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "questionmark.circle").font(.system(size: 11))
                                Text("Show tips").font(.custom("DMSans-Regular", size: 11))
                            }
                            .foregroundColor(.gray.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }

                    // MARK: - Chip scroll view
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            if let result = sonarResult {

                                // Echo chip
                                Button {
                                    isPaused = true
                                    withAnimation(.easeOut(duration: 0.2)) { showEchoPicker.toggle() }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(echoEmoji).font(.system(size: 13))
                                        Text(echoName)
                                            .font(.custom("DMSans-Medium", size: 13))
                                            .foregroundColor(.deepNavy)
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
                                                .foregroundColor(.deepNavy)
                                        } else {
                                            Text(date, format: .dateTime.month(.abbreviated).day())
                                                .font(.custom("DMSans-Medium", size: 13))
                                                .foregroundColor(.deepNavy)
                                        }
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Color.mist).clipShape(Capsule())
                                }

                                // Add to Calendar chip — only for date-bearing memories
                                if let date = result.detectedDate {
                                    Button {
                                        guard !addedToCalendar else { return }
                                        Task {
                                            let granted = CalendarService.shared.isAuthorized
                                                ? true
                                                : await CalendarService.shared.requestAccess()
                                            if granted {
                                                CalendarService.shared.addEvent(
                                                    title: editedText.isEmpty ? transcription : editedText,
                                                    startDate: date,
                                                    endDate: result.endDate
                                                )
                                                await MainActor.run {
                                                    withAnimation(.spring(duration: 0.2)) { addedToCalendar = true }
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: addedToCalendar ? "calendar.badge.checkmark" : "calendar.badge.plus")
                                                .font(.system(size: 12))
                                                .foregroundColor(addedToCalendar ? .white : .deepNavy)
                                            Text(addedToCalendar ? "Added ✓" : "Add to Calendar")
                                                .font(.custom("DMSans-Medium", size: 13))
                                                .foregroundColor(addedToCalendar ? .white : .deepNavy)
                                        }
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(addedToCalendar ? Color.oceanTeal : Color.mist)
                                        .clipShape(Capsule())
                                    }
                                }

                                // Ping chip
                                if result.shouldCreatePing {
                                    HStack(spacing: 4) {
                                        Text("🔔").font(.system(size: 13))
                                        Text(result.pingRecurrence == .none ? "Ping" : result.pingRecurrence.rawValue.capitalized)
                                            .font(.custom("DMSans-Medium", size: 13))
                                            .foregroundColor(.deepNavy)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Color.mist).clipShape(Capsule())
                                }

                                // Duration chip
                                if let mins = effectiveDuration, mins > 0 {
                                    HStack(spacing: 4) {
                                        Text("⏱").font(.system(size: 13))
                                        Text(DurationParser.shared.format(mins))
                                            .font(.custom("DMSans-Medium", size: 13))
                                            .foregroundColor(.deepNavy)
                                        if selectedDuration != nil {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 9, weight: .medium))
                                                .foregroundColor(.gray)
                                                .onTapGesture { selectedDuration = nil }
                                        }
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
                                                .foregroundColor(locationName != nil ? .oceanTeal : .secondary)
                                            Text(locationName ?? "Add location")
                                                .font(.custom("DMSans-Medium", size: 13))
                                                .foregroundColor(locationName != nil ? .deepNavy : .secondary)
                                        }
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(Color.mist).clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }

                                // Task chip
                                Button {
                                    isPaused = true
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    withAnimation(.spring(duration: 0.2)) { isTask.toggle() }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: isTask ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 12))
                                            .foregroundColor(isTask ? .white : .gray)
                                        Text("Task")
                                            .font(.custom("DMSans-Medium", size: 13))
                                            .foregroundColor(isTask ? .white : .gray)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(isTask ? Color.oceanTeal : Color.mist)
                                    .clipShape(Capsule())
                                }

                                // Watchlist chip
                                let currentEchoName = (echos.first { $0.id == selectedEchoId }?.name ?? sonarResult?.echoName ?? "").lowercased()
                                let isWatchable = currentEchoName.contains("movie") || currentEchoName.contains("book") || currentEchoName.contains("show")

                                if isWatchable {
                                    Button {
                                        guard !addedToWatchlist else { return }
                                        isPaused = true
                                        let itemType = currentEchoName.contains("book") ? "book" : currentEchoName.contains("movie") ? "movie" : "show"
                                        let service = SonarEngine.detectStreamingService(from: transcription)
                                        Task {
                                            let title = await AppleIntelligenceService.shared.extractMediaTitle(from: editedText)
                                            await MainActor.run {
                                                onAddToWatchlist?(title ?? editedText, itemType, service)
                                                withAnimation(.spring(duration: 0.2)) { addedToWatchlist = true }
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: addedToWatchlist ? "checkmark.circle.fill" : "plus.circle")
                                                .font(.system(size: 12))
                                                .foregroundColor(addedToWatchlist ? .white : .deepNavy)
                                            Text(addedToWatchlist ? "Added ✓" : currentEchoName.contains("book") ? "Add to reading list" : "Add to watch list")
                                                .font(.custom("DMSans-Medium", size: 13))
                                                .foregroundColor(addedToWatchlist ? .white : .deepNavy)
                                        }
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(addedToWatchlist ? Color.coral : Color.mist)
                                        .clipShape(Capsule())
                                    }
                                } // end if isWatchable

                            } // end if let result
                        } // end HStack
                    } // end ScrollView

                    // MARK: - Duration quick-pick row
                    if showDurationRow {
                        VStack(alignment: .leading, spacing: 7) {
                            Divider()
                            Text("How long?")
                                .font(.custom("DMSans-Regular", size: 12))
                                .foregroundColor(.gray)
                            HStack(spacing: 7) {
                                ForEach([15, 30, 60, 120], id: \.self) { mins in
                                    Button {
                                        withAnimation(.spring(duration: 0.2)) {
                                            selectedDuration = mins
                                            isPaused = true
                                        }
                                    } label: {
                                        Text(DurationParser.shared.format(mins))
                                            .font(.custom("DMSans-Medium", size: 13))
                                            .foregroundColor(.deepNavy)
                                            .padding(.horizontal, 12).padding(.vertical, 6)
                                            .background(Color.mist)
                                            .clipShape(Capsule())
                                    }
                                }
                                Button {
                                    withAnimation(.spring(duration: 0.2)) { selectedDuration = -1 }
                                } label: {
                                    Text("Skip")
                                        .font(.custom("DMSans-Medium", size: 13))
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(Color.mist)
                                        .clipShape(Capsule())
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
                                        }
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(selectedEchoId == echo.id ? Color.oceanTeal : Color.mist)
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }

                    // MARK: - Person suggestion
                    let isTravelEcho = sonarResult?.echoName.lowercased().contains("travel") == true
                    let commonNonNames = Set(["january","february","march","april","may","june","july","august","september","october","november","december","monday","tuesday","wednesday","thursday","friday","saturday","sunday","day","eve","birthday","christmas","holiday","anniversary","halloween","thanksgiving","today","tomorrow","tonight","morning","afternoon","evening","get","got","getting","buy","bought","buying","remind","remember","call","need","want","make","take","send","find","pick","grab","order","ordered","check","set","ask","tell","show","xbox","playstation","nintendo","apple","google","amazon","samsung","microsoft","sony","meta","tesla","netflix","spotify","airpods","iphone","ipad","macbook","android","nike","adidas","lululemon","zara","gucci","prada","controller","headphones","keyboard","monitor","laptop","tablet","new","the","a","an","for","with","from","just","also"])
                    let personIndicators = Set(["for","with","tell","ask","remind","call","text","email","invite","get","buy","give","send","show"])
                    let words = editedText.components(separatedBy: .whitespaces)
                    let textScannedPeople: [String] = words.enumerated().compactMap { i, word in
                        let clean = word.trimmingCharacters(in: .punctuationCharacters)
                        guard clean.count > 2, clean.first?.isUppercase == true, !commonNonNames.contains(clean.lowercased()) else { return nil }
                        guard i > 0 else { return nil }
                        let prevWord = words[i - 1].trimmingCharacters(in: .punctuationCharacters).lowercased()
                        guard personIndicators.contains(prevWord) else { return nil }
                        return clean
                    }
                    let nlpPeople = sonarResult?.detectedPeople ?? []
                    let allDetectedPeople = Array(Set(
                        nlpPeople.map { n in n.hasSuffix("'s") ? String(n.dropLast(2)).capitalized : n.capitalized } +
                        textScannedPeople.map { n in n.hasSuffix("'s") ? String(n.dropLast(2)) : n }
                    ))

                    if !allDetectedPeople.isEmpty && !isTravelEcho {
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
                                        .font(.system(size: 15)).foregroundColor(.oceanTeal)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Create \(firstUnmatched)'s profile")
                                            .font(.custom("DMSans-Medium", size: 13)).foregroundColor(.deepNavy)
                                        Text("Save birthday, gifts & more")
                                            .font(.custom("DMSans-Regular", size: 11)).foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11)).foregroundColor(.gray.opacity(0.4))
                                }
                                .padding(10)
                                .background(Color.oceanTeal.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.oceanTeal.opacity(0.15), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // MARK: - Recipe fetch
                    if sonarResult?.shouldOfferRecipeFetch == true {
                        Button { fetchRecipe() } label: {
                            HStack(spacing: 8) {
                                if isFetchingRecipe {
                                    ProgressView().scaleEffect(0.75).tint(.white)
                                } else {
                                    Image(systemName: recipeFetchSuccess ? "checkmark" : "fork.knife").font(.system(size: 13))
                                }
                                Text(isFetchingRecipe ? "Fetching recipe..." : recipeFetchSuccess ? "Recipe imported!" : "🍳 Fetch recipe from link")
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
                                Image(systemName: "exclamationmark.circle").font(.system(size: 11)).foregroundColor(.coral)
                                Text(error).font(.custom("DMSans-Regular", size: 12)).foregroundColor(.coral)
                            }
                        }

                        Button {
                            isPaused = true
                            showRecipeBuilder = true
                        } label: {
                            Text("Don't have a URL? Build your own")
                                .font(.custom("DMSans-Medium", size: 13))
                                .foregroundColor(.oceanTeal)
                                .frame(maxWidth: .infinity)
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
            if !isPaused && !wasCancelled {
                let echoId = selectedEchoId ?? echos.first { $0.name == sonarResult?.echoName }?.id
                if let echoId, let confirmedEcho = echos.first(where: { $0.id == echoId }) {
                    SonarEngine.learnKeywords(from: editedText, echo: confirmedEcho)
                }
                onDone(isTask, effectiveDuration)
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
