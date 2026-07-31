//
//  PhotoCaptureView.swift
//  Orca
//
//  Created by David Piliponskiy on 3/3/26.
//

import SwiftUI
import SwiftData
import PhotosUI
import Vision
import CoreSpotlight
import Speech
import AVFoundation

private struct RecipeEditPreview: View {
    let onBack: () -> Void
    let onSave: () -> Void
    @Binding var editTitle: String
    @Binding var editIngredients: [String]
    @Binding var editInstructions: [String]
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color.deepNavy.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    if focused {
                        Button("Done") { focused = false }
                            .font(.custom("DMSans-Medium", size: 16)).foregroundColor(.white.opacity(0.7))
                    } else {
                        Button("Back", action: onBack)
                            .font(.custom("DMSans-Regular", size: 16)).foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    Text("Recipe Detected")
                        .font(.custom("DMSans-Medium", size: 16)).foregroundColor(.white)
                    Spacer()
                    Button("Save", action: onSave)
                        .font(.custom("DMSans-Medium", size: 16)).foregroundColor(.oceanTeal)
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 20)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {

                            HStack(spacing: 10) {
                                Text("🍽").font(.system(size: 24))
                                TextField("Recipe title", text: $editTitle)
                                    .font(.custom("DMSans-Medium", size: 17)).foregroundColor(.deepNavy)
                                    .focused($focused)
                            }
                            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("INGREDIENTS")
                                    .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.oceanTeal).tracking(1)
                                ForEach(editIngredients.indices, id: \.self) { i in
                                    HStack(alignment: .top, spacing: 10) {
                                        Circle().fill(Color.oceanTeal).frame(width: 6, height: 6).padding(.top, 7)
                                        TextField("Ingredient", text: $editIngredients[i], axis: .vertical)
                                            .font(.custom("DMSans-Regular", size: 14)).foregroundColor(.deepNavy)
                                            .focused($focused)
                                        Button { editIngredients.remove(at: i) } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.system(size: 18)).foregroundColor(.coral.opacity(0.7))
                                        }
                                    }
                                }
                                Button { editIngredients.append("") } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "plus.circle").font(.system(size: 13))
                                        Text("Add ingredient").font(.custom("DMSans-Regular", size: 13))
                                    }.foregroundColor(.oceanTeal)
                                }
                                .padding(.top, 4)
                            }
                            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("INSTRUCTIONS")
                                    .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.oceanTeal).tracking(1)
                                ForEach(editInstructions.indices, id: \.self) { i in
                                    HStack(alignment: .top, spacing: 10) {
                                        Text("\(i + 1)")
                                            .font(.custom("DMMono-Regular", size: 11)).foregroundColor(.white)
                                            .frame(width: 20, height: 20)
                                            .background(Color.oceanTeal).clipShape(Circle())
                                        TextField("Step \(i + 1)", text: $editInstructions[i], axis: .vertical)
                                            .font(.custom("DMSans-Regular", size: 14)).foregroundColor(.deepNavy)
                                            .focused($focused)
                                        Button { editInstructions.remove(at: i) } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.system(size: 18)).foregroundColor(.coral.opacity(0.7))
                                        }
                                    }
                                    if i < editInstructions.count - 1 {
                                        Divider().padding(.leading, 30)
                                    }
                                }
                                Button { editInstructions.append("") } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "plus.circle").font(.system(size: 13))
                                        Text("Add step").font(.custom("DMSans-Regular", size: 13))
                                    }.foregroundColor(.oceanTeal)
                                }
                                .padding(.top, 4)
                            }
                            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)

                            Text("Tap any field to edit before saving.")
                                .font(.custom("DMSans-Regular", size: 12))
                                .foregroundColor(.white.opacity(0.4))
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(20)
                    }
                }
            }
        }
    }

struct PhotoCaptureView: View {
    @Binding var isPresented: Bool
    var onRecipeSaved: ((Memory) -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Query private var echos: [Echo]

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var cameraImage: UIImage?
    @State private var extractedText: String = ""
    @State private var isProcessing = false
    @State private var showBanner = false
    @State private var sonarResult: SonarResult?
    @State private var showCamera = false
    @State private var editMemory: Memory? = nil
    @State private var hasExtracted = false
    @State private var travelResult: TravelParseResult? = nil
    @State private var showTravelPreview = false
    @State private var recipeOCRResult: RecipeOCRParser.OCRRecipeResult? = nil
    @State private var showRecipePreview = false
    @State private var editTitle = ""
    @State private var editIngredients: [String] = []
    @State private var editInstructions: [String] = []

    @State private var bannerText: String = ""
    @State private var photoNote: String = ""
    @State private var isRecordingNote = false
    @FocusState private var noteFocused: Bool

    private let sonarEngine = SonarEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?

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

    private func handleRecipeFetch(_ recipe: RecipeResult) {
        let descriptor = FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        guard let memory = try? modelContext.fetch(descriptor).first else { return }
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
        memory.text = parts.joined(separator: "\n")
        if !recipe.ingredients.isEmpty {
            memory.hasChecklist = true
            for (index, ingredient) in recipe.ingredients.enumerated() {
                let subTask = SubTask(memoryId: memory.id, text: ingredient, sortOrder: index)
                modelContext.insert(subTask)
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
                        transcription: bannerText,
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
                        onAddToWatchlist: { title, type, service in
                            let item = WatchlistItem(title: title, itemType: type, streamingService: service)
                            modelContext.insert(item)
                        }
                    )
                }
            } else if isProcessing {
                processingView
            } else if showTravelPreview, let travel = travelResult {
                travelPreviewView(travel: travel)
            } else if showRecipePreview, let recipe = recipeOCRResult {
                recipePreviewView(recipe: recipe)
            } else if !selectedImages.isEmpty {
                reviewView
            } else {
                sourcePickerView
            }
        }
        .onChange(of: selectedItems) { _, newItems in
            if !newItems.isEmpty { loadImages(from: newItems) }
        }
        .onChange(of: cameraImage) { _, newImage in
            if let img = newImage {
                selectedImages.append(img)
                cameraImage = nil
                extractTextFromImages()
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(image: $cameraImage).ignoresSafeArea()
        }
        .sheet(item: $editMemory) { memory in
            MemoryEditView(memory: memory)
        }
    }

    // MARK: - Source Picker

    private var sourcePickerView: some View {
        ZStack {
            Color.deepNavy.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 56)).foregroundColor(.oceanTeal)
                VStack(spacing: 8) {
                    Text("Capture a Screenshot")
                        .font(.custom("DMSans-Medium", size: 20)).foregroundColor(.white)
                    Text("Flights, hotels, recipes and more — Orca reads it automatically.")
                        .font(.custom("DMSans-Regular", size: 14)).foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center).padding(.horizontal, 40)
                }
                Spacer()
                VStack(spacing: 12) {
                    Button { showCamera = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "camera.fill").font(.system(size: 18))
                            Text("Take Photo").font(.custom("DMSans-Medium", size: 16))
                        }
                        .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.oceanTeal).clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    PhotosPicker(selection: $selectedItems, maxSelectionCount: 6, matching: .images) {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle").font(.system(size: 18))
                            Text("Choose from Library").font(.custom("DMSans-Medium", size: 16))
                        }
                        .foregroundColor(.oceanTeal).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.white.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.oceanTeal.opacity(0.5), lineWidth: 1))
                    }
                    Button("Cancel") { isPresented = false }
                        .font(.custom("DMSans-Regular", size: 14)).foregroundColor(.white.opacity(0.5)).padding(.top, 4)
                }
                .padding(.horizontal, 24).padding(.bottom, 40)
            }
        }
    }

    // MARK: - Review View

    private var reviewView: some View {
        ZStack {
            Color.deepNavy.ignoresSafeArea()
            VStack(spacing: 16) {
                HStack {
                    Button("Retake") {
                        stopNoteRecording()
                        selectedImages = []; selectedItems = []; cameraImage = nil
                        extractedText = ""; hasExtracted = false
                        travelResult = nil; showTravelPreview = false
                        recipeOCRResult = nil; showRecipePreview = false
                        photoNote = ""
                    }
                    .font(.custom("DMSans-Regular", size: 16)).foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Button("Save") { saveMemory() }
                        .font(.custom("DMSans-Medium", size: 16)).foregroundColor(.oceanTeal)
                }
                .padding(.horizontal, 20).padding(.top, 16)

                // Image strip
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(selectedImages.enumerated()), id: \.offset) { i, img in
                            ZStack(alignment: .bottom) {
                                Image(uiImage: img)
                                    .resizable().aspectRatio(contentMode: .fill)
                                    .frame(width: selectedImages.count == 1 ? 280 : 120, height: 160)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                if selectedImages.count > 1 {
                                    Text("Page \(i + 1)")
                                        .font(.custom("DMSans-Regular", size: 10))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(Color.black.opacity(0.55))
                                        .clipShape(Capsule())
                                        .padding(.bottom, 6)
                                }
                            }
                        }
                        // Add page button
                        Button { showCamera = true } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "plus.circle").font(.system(size: 22))
                                Text("Add page").font(.custom("DMSans-Regular", size: 11))
                            }
                            .foregroundColor(.oceanTeal)
                            .frame(width: 80, height: 160)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.oceanTeal.opacity(0.4), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 170)

                // Note + mic field
                HStack(spacing: 10) {
                    TextField("Add a note or reminder...", text: $photoNote)
                        .font(.custom("DMSans-Regular", size: 15))
                        .foregroundColor(.white)
                        .focused($noteFocused)
                        .submitLabel(.done)
                    Button {
                        if isRecordingNote { stopNoteRecording() } else { startNoteRecording() }
                    } label: {
                        Image(systemName: isRecordingNote ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(isRecordingNote ? .red : .oceanTeal)
                            .symbolEffect(.pulse, isActive: isRecordingNote)
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)

                HStack(spacing: 5) {
                    Image(systemName: "lock.fill").font(.system(size: 10))
                    Text("Photo stored locally on device only")
                        .font(.custom("DMSans-Regular", size: 12))
                }
                .foregroundColor(.white.opacity(0.35))
                .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "text.viewfinder").font(.system(size: 13)).foregroundColor(.oceanTeal)
                        Text("Extract text from image").font(.custom("DMSans-Medium", size: 13)).foregroundColor(.oceanTeal)
                        Spacer()
                        if !hasExtracted {
                            Button { extractTextFromImages() } label: {
                                Text("Extract").font(.custom("DMSans-Medium", size: 13))
                                    .foregroundColor(.white).padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(Color.oceanTeal).clipShape(Capsule())
                            }
                        }
                    }

                    if extractedText.isEmpty {
                        Text(hasExtracted ? "No text found in image" : "Tap \"Extract Text\" to scan, or save as-is.")
                            .font(.custom("DMSans-Regular", size: 14)).foregroundColor(.white.opacity(0.4))
                    } else {
                        if let travel = travelResult {
                            Button { showTravelPreview = true } label: {
                                HStack(spacing: 8) {
                                    Text(travel.type == .flight ? "✈️" : "🏨").font(.system(size: 16))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(travel.type == .flight ? "Flight detected!" : "Hotel detected!")
                                            .font(.custom("DMSans-Medium", size: 13)).foregroundColor(.deepNavy)
                                        Text("Tap to preview structured memory")
                                            .font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.gray)
                                }
                                .padding(12).background(Color.seafoam.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.seafoam.opacity(0.4), lineWidth: 1))
                            }
                        }
                        if let recipe = recipeOCRResult {
                            Button { showRecipePreview = true } label: {
                                HStack(spacing: 8) {
                                    Text("🍽").font(.system(size: 16))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Recipe detected!")
                                            .font(.custom("DMSans-Medium", size: 13)).foregroundColor(.deepNavy)
                                        Text("\(recipe.ingredients.count) ingredients · \(recipe.instructions.count) steps")
                                            .font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.gray)
                                }
                                .padding(12).background(Color.oceanTeal.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.oceanTeal.opacity(0.3), lineWidth: 1))
                            }
                        }
                        TextEditor(text: $extractedText)
                            .font(.custom("DMSans-Regular", size: 15)).foregroundColor(.white)
                            .scrollContentBackground(.hidden).frame(minHeight: 80, maxHeight: 160)
                    }
                }
                .padding(16).background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 20)
                Spacer()
            }
        }
    }

    // MARK: - Travel Preview View

    private func travelPreviewView(travel: TravelParseResult) -> some View {
        ZStack {
            Color.deepNavy.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button("Back") { showTravelPreview = false }
                        .font(.custom("DMSans-Regular", size: 16)).foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text(travel.type == .flight ? "Flight Detected" : "Hotel Detected")
                        .font(.custom("DMSans-Medium", size: 16)).foregroundColor(.white)
                    Spacer()
                    Button("Save") { saveTravelMemory(travel: travel) }
                        .font(.custom("DMSans-Medium", size: 16)).foregroundColor(.oceanTeal)
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 20)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Text(travel.type == .flight ? "✈️" : "🏨").font(.system(size: 28))
                                VStack(alignment: .leading, spacing: 2) {
                                    if travel.type == .flight {
                                        Text("\(travel.airline ?? "Flight") \(travel.flightNumber ?? "")")
                                            .font(.custom("DMSans-Medium", size: 17)).foregroundColor(.deepNavy)
                                        if let dep = travel.departureAirport, let arr = travel.arrivalAirport {
                                            Text("\(dep) → \(arr)").font(.custom("DMMono-Regular", size: 14)).foregroundColor(.gray)
                                        }
                                    } else {
                                        Text(travel.hotelName ?? "Hotel Reservation")
                                            .font(.custom("DMSans-Medium", size: 17)).foregroundColor(.deepNavy)
                                    }
                                }
                                Spacer()
                                Text(travel.type == .flight ? "✈️" : "🏨").font(.system(size: 14))
                                    .padding(6).background(Color.mist).clipShape(Capsule())
                            }
                            Divider()
                            if travel.type == .flight {
                                if let depDate = travel.departureDate {
                                    detailRow(icon: "calendar", label: "Departure", value: depDate.formatted(.dateTime.month(.wide).day().year()))
                                }
                                if let time = travel.departureTime {
                                    detailRow(icon: "clock", label: "Time", value: time)
                                }
                                if let retDate = travel.returnDate {
                                    detailRow(icon: "calendar.badge.clock", label: "Return", value: retDate.formatted(.dateTime.month(.wide).day().year()))
                                }
                                if let gate = travel.gateNumber {
                                    detailRow(icon: "door.right.hand.open", label: "Gate", value: gate)
                                }
                            } else {
                                if let checkIn = travel.checkInDate {
                                    detailRow(icon: "arrow.right.square", label: "Check-in", value: checkIn.formatted(.dateTime.month(.wide).day().year()))
                                }
                                if let checkOut = travel.checkOutDate {
                                    detailRow(icon: "arrow.left.square", label: "Check-out", value: checkOut.formatted(.dateTime.month(.wide).day().year()))
                                }
                            }
                            if let conf = travel.confirmationCode {
                                detailRow(icon: "number", label: "Confirmation", value: conf)
                            }
                        }
                        .padding(16).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)

                        if travel.type == .flight {
                            if let depDate = travel.departureDate,
                               let checkInPing = Calendar.current.date(byAdding: .hour, value: -24, to: depDate) {
                                pingRow(text: "Check-in opens", detail: checkInPing.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                            }
                            if let pingDate = travel.pingDate {
                                pingRow(text: "3 hours before departure", detail: pingDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                            }
                        } else {
                            if let checkIn = travel.checkInDate,
                               let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: checkIn),
                               let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: dayBefore) {
                                pingRow(text: "Day before check-in", detail: noon.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
    }

    // MARK: - Recipe Preview View

    private func recipePreviewView(recipe: RecipeOCRParser.OCRRecipeResult) -> some View {
        RecipeEditPreview(
            onBack: { showRecipePreview = false },
            onSave: { saveRecipeMemory() },
            editTitle: $editTitle,
            editIngredients: $editIngredients,
            editInstructions: $editInstructions
        )
        .onAppear {
            editTitle = recipe.title
            editIngredients = recipe.ingredients
            editInstructions = recipe.instructions
        }
    }

    // MARK: - Save Recipe Memory

    private func saveRecipeMemory() {
        let cookingEcho = echos.first {
            $0.name.lowercased().contains("cook") || $0.emoji == "🍳" || $0.emoji == "👨‍🍳"
        } ?? echos.first { $0.name == "Notes" }

        let echoId = cookingEcho?.id ?? UUID()

        let title = editTitle.isEmpty ? "Recipe" : editTitle
        let ingredients = editIngredients.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let instructions = editInstructions.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        var parts: [String] = ["🍽 \(title)"]
        if let recipe = recipeOCRResult {
            var meta: [String] = []
            if let prep = recipe.prepTime { meta.append("Prep: \(prep)") }
            if let cook = recipe.cookTime { meta.append("Cook: \(cook)") }
            if let srv = recipe.servings { meta.append("Serves: \(srv)") }
            if !meta.isEmpty { parts.append(meta.joined(separator: " · ")) }
        }
        if !instructions.isEmpty {
            parts.append("\nInstructions:")
            for (i, step) in instructions.enumerated() {
                parts.append("\(i + 1). \(step)")
            }
        }
        let fullText = parts.joined(separator: "\n")

        let memory = Memory(text: fullText, echoId: echoId, captureType: .screenshot)
        memory.hasChecklist = !ingredients.isEmpty
        memory.isActionable = false
        if let image = selectedImages.first, let compressed = image.jpegData(compressionQuality: 0.6) {
            memory.imageData = compressed
        }

        modelContext.insert(memory)

        for (index, ingredient) in ingredients.enumerated() {
            modelContext.insert(SubTask(memoryId: memory.id, text: ingredient, sortOrder: index))
        }

        onRecipeSaved?(memory)
        SpotlightService.shared.indexMemory(memory, echoName: cookingEcho?.name ?? "Cooking", echoEmoji: cookingEcho?.emoji ?? "🍳")

        if let userId = authService.userId {
            Task { await SupabaseSyncService.shared.pushMemory(memory, userId: userId) }
        }

        isPresented = false
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(.oceanTeal).frame(width: 20)
            Text(label).font(.custom("DMSans-Regular", size: 14)).foregroundColor(.gray).frame(width: 90, alignment: .leading)
            Text(value).font(.custom("DMSans-Medium", size: 14)).foregroundColor(.deepNavy)
            Spacer()
        }
    }

    private func pingRow(text: String, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "bell.fill").foregroundColor(.oceanTeal).font(.system(size: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text(text).font(.custom("DMSans-Medium", size: 14)).foregroundColor(.white)
                Text(detail).font(.custom("DMMono-Regular", size: 12)).foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(14).background(Color.white.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Processing View

    private var processingView: some View {
        ZStack {
            Color.deepNavy.ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().tint(.oceanTeal).scaleEffect(1.5)
                Text("Scanning...").font(.custom("DMSans-Medium", size: 16)).foregroundColor(.white)
            }
        }
    }

    // MARK: - Image Loading

    private func loadImages(from items: [PhotosPickerItem]) {
        selectedImages = []
        let group = DispatchGroup()
        var loaded: [(Int, UIImage)] = []
        for (i, item) in items.enumerated() {
            group.enter()
            item.loadTransferable(type: Data.self) { result in
                if case .success(let data) = result, let data, let img = UIImage(data: data) {
                    loaded.append((i, img))
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            selectedImages = loaded.sorted { $0.0 < $1.0 }.map { $0.1 }
            extractTextFromImages()
        }
    }

    // MARK: - OCR

    private func extractTextFromImages() {
        guard !selectedImages.isEmpty else { return }
        isProcessing = true
        extractedText = ""
        hasExtracted = false

        Task {
            var parts: [String] = []
            for image in selectedImages {
                guard let cgImage = image.cgImage else { continue }
                let text = await recognizeText(in: cgImage)
                if !text.isEmpty { parts.append(text) }
            }
            let combined = parts.joined(separator: "\n\n")
            await MainActor.run {
                extractedText = combined
                isProcessing = false
                hasExtracted = true
                guard !combined.isEmpty else { return }
                travelResult = TravelConfirmationParser.shared.parse(text: combined)
                if travelResult != nil {
                    showTravelPreview = true
                } else {
                    recipeOCRResult = RecipeOCRParser.detect(in: combined)
                    if recipeOCRResult != nil { showRecipePreview = true }
                }
            }
        }
    }

    private func recognizeText(in cgImage: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, _ in
                let observations = req.results as? [VNRecognizedTextObservation] ?? []
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            DispatchQueue.global(qos: .userInitiated).async {
                try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            }
        }
    }

    // MARK: - Save Travel Memory

    private func saveTravelMemory(travel: TravelParseResult) {
        let travelEcho = echos.first {
            $0.name.lowercased().contains("travel") || $0.name.lowercased().contains("trip")
        } ?? echos.first { $0.name == "Notes" }

        let echoId = travelEcho?.id ?? UUID()
        let memory = Memory(text: travel.formattedMemory, echoId: echoId, captureType: .screenshot)
        memory.detectedDate = travel.departureDate ?? travel.checkInDate
        memory.endDate = travel.returnDate ?? travel.checkOutDate
        memory.isActionable = false
        modelContext.insert(memory)
        SpotlightService.shared.indexMemory(memory, echoName: travelEcho?.name ?? "Travel", echoEmoji: travelEcho?.emoji ?? "✈️")

        if let userId = authService.userId {
            Task {
                await SupabaseSyncService.shared.pushMemory(memory, userId: userId)
                if travel.type == .flight {
                    if let depDate = travel.departureDate,
                       let checkInPing = Calendar.current.date(byAdding: .hour, value: -24, to: depDate) {
                        let ping1 = Ping(memoryId: memory.id, fireDate: checkInPing, recurrence: .none)
                        ping1.fireTime = checkInPing
                        modelContext.insert(ping1)
                        await SupabaseSyncService.shared.pushPing(ping1, userId: userId)
                        NotificationService.shared.schedulePing(ping: ping1, memoryText: "Check-in opens: \(memory.text.components(separatedBy: "\n").first ?? "")")
                    }
                    if let pingDate = travel.pingDate {
                        let ping2 = Ping(memoryId: memory.id, fireDate: pingDate, recurrence: .none)
                        ping2.fireTime = pingDate
                        modelContext.insert(ping2)
                        await SupabaseSyncService.shared.pushPing(ping2, userId: userId)
                        NotificationService.shared.schedulePing(ping: ping2, memoryText: "Departing soon: \(memory.text.components(separatedBy: "\n").first ?? "")")
                    }
                } else if travel.type == .hotel {
                    if let checkIn = travel.checkInDate,
                       let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: checkIn),
                       let noonDayBefore = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: dayBefore) {
                        let ping = Ping(memoryId: memory.id, fireDate: noonDayBefore, recurrence: .none)
                        ping.fireTime = noonDayBefore
                        modelContext.insert(ping)
                        await SupabaseSyncService.shared.pushPing(ping, userId: userId)
                        NotificationService.shared.schedulePing(ping: ping, memoryText: "Check-in tomorrow: \(travel.hotelName ?? "Hotel")")
                    }
                }
            }
        }

        sonarResult = sonarEngine.process(text: travel.formattedMemory, echos: echos)
        AnalyticsService.shared.trackMemoryDropped(
            captureType: "photo", echoName: travelEcho?.name ?? "Travel",
            hasPing: travel.pingDate != nil,
            hasDate: travel.departureDate != nil || travel.checkInDate != nil,
            hasURL: false, hasChecklist: false,
            wordCount: travel.formattedMemory.split(separator: " ").count)

        bannerText = travel.formattedMemory
        withAnimation(.spring(duration: 0.4)) { showBanner = true }
    }

    // MARK: - Save Regular Memory

    private func saveMemory() {
        stopNoteRecording()
        // Combine note + extracted text; note drives SonarEngine (reminders), extracted text is context
        let note = photoNote.trimmingCharacters(in: .whitespaces)
        let sonarInput = note.isEmpty ? (extractedText.isEmpty ? "📷 Photo" : extractedText) : note
        let fullText: String = {
            if note.isEmpty { return extractedText.isEmpty ? "📷 Photo" : extractedText }
            if extractedText.isEmpty { return note }
            return "\(note)\n\n\(extractedText)"
        }()

        sonarResult = sonarEngine.process(text: sonarInput, echos: echos)
        let echoId = sonarResult?.echoId ?? echos.first?.id ?? UUID()
        let memory = Memory(text: fullText, echoId: echoId, captureType: .screenshot)
        memory.tags = sonarResult?.tags ?? []
        memory.detectedDate = sonarResult?.detectedDate
        memory.endDate = sonarResult?.endDate
        memory.echoConfidence = sonarResult?.echoConfidence ?? 1.0
        memory.dateConfidence = sonarResult?.dateConfidence
        memory.sonarConfidence = sonarResult?.echoConfidence ?? 1.0
        memory.isActionable = sonarResult?.isActionable ?? false
        memory.estimatedMinutes = sonarResult?.estimatedMinutes

        // Save the first image
        if let image = selectedImages.first,
           let compressed = image.jpegData(compressionQuality: 0.6) {
            memory.imageData = compressed
        }

        modelContext.insert(memory)
        SpotlightService.shared.indexMemory(memory, echoName: sonarResult?.echoName ?? "Notes", echoEmoji: echos.first { $0.id == memory.echoId }?.emoji ?? "📝")
        NotificationService.shared.scheduleInactivityReminder(afterDays: 5)

        if memory.detectedDate != nil {
            let recurrence = sonarResult?.pingRecurrence ?? .none
            NotificationCenter.default.post(
                name: .calendarSyncCheck,
                object: memory,
                userInfo: ["recurrence": recurrence.rawValue]
            )
        }

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
            }
        }

        AnalyticsService.shared.trackMemoryDropped(
            captureType: "photo", echoName: sonarResult?.echoName ?? "Unknown",
            hasPing: sonarResult?.shouldCreatePing ?? false,
            hasDate: sonarResult?.detectedDate != nil, hasURL: memory.url != nil,
            hasChecklist: memory.hasChecklist, wordCount: fullText.split(separator: " ").count)

        if let detectedURL = sonarEngine.detectURL(text: fullText) { memory.url = detectedURL }
        if let checklistItems = sonarEngine.detectChecklist(text: fullText) {
            memory.hasChecklist = true
            for (index, item) in checklistItems.enumerated() {
                let subTask = SubTask(memoryId: memory.id, text: item, sortOrder: index)
                modelContext.insert(subTask)
            }
        }

        bannerText = fullText
        withAnimation(.spring(duration: 0.4)) { showBanner = true }
    }

    // MARK: - Note Voice Recording

    private func startNoteRecording() {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else { return }
            DispatchQueue.main.async {
                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.record, mode: .measurement, options: .duckOthers)
                    try session.setActive(true, options: .notifyOthersOnDeactivation)

                    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
                    guard let request = recognitionRequest else { return }
                    request.shouldReportPartialResults = true

                    let inputNode = audioEngine.inputNode
                    let format = inputNode.outputFormat(forBus: 0)
                    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                        request.append(buffer)
                    }

                    audioEngine.prepare()
                    try audioEngine.start()
                    isRecordingNote = true

                    recognitionTask = speechRecognizer?.recognitionTask(with: request) { result, error in
                        if let result = result {
                            photoNote = result.bestTranscription.formattedString
                        }
                        if error != nil || (result?.isFinal == true) {
                            stopNoteRecording()
                        }
                    }
                } catch {
                    print("❌ Note recording error: \(error)")
                }
            }
        }
    }

    private func stopNoteRecording() {
        guard isRecordingNote else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(false)
        isRecordingNote = false
    }

    private func undoMemory() {
        let recent = try? modelContext.fetch(
            FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )
        if let last = recent?.first {
            let id = last.id
            modelContext.delete(last)
            SupabaseSyncService.shared.scheduleDelete(id: id)
        }
    }
}

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        init(_ parent: CameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage { parent.image = uiImage }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
