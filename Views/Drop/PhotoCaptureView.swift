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

struct PhotoCaptureView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Query private var echos: [Echo]
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var extractedText: String = ""
    @State private var isProcessing = false
    @State private var showBanner = false
    @State private var sonarResult: SonarResult?
    @State private var showCamera = false
    @State private var editMemory: Memory? = nil
    
    private func updateLastMemoryEcho(_ echoId: UUID) {
        let descriptor = FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        if let last = try? modelContext.fetch(descriptor).first {
            last.echoId = echoId
        }
    }

    private let sonarEngine = SonarEngine()
    
    private func handleRecipeFetch(_ recipe: RecipeResult) {
        let descriptor = FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        guard let memory = try? modelContext.fetch(descriptor).first else { return }
        
        // Update memory text with instructions
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
        
        // Add ingredients as subtasks
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
                        transcription: extractedText,
                        sonarResult: sonarResult,
                        echos: echos,
                        onDone: { isTask in
                            updateLastMemoryTask(isTask: isTask)
                            isPresented = false
                        },
                            onUndo: { undoMemory() },
                            onEchoChanged: { newEchoId in
                                updateLastMemoryEcho(newEchoId)
                            },
                            onRecipeFetched: { recipe in
                                handleRecipeFetch(recipe)
                            },
                            onEdit: {
                                let descriptor = FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
                                editMemory = try? modelContext.fetch(descriptor).first
                            }
                        )
                }
            } else if isProcessing {
                processingView
            } else if let image = selectedImage {
                reviewView(image: image)
            } else {
                sourcePickerView
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            if let newItem = newItem {
                loadImage(from: newItem)
            }
        }
        .onChange(of: selectedImage) { _, newImage in
            if newImage != nil {
                extractTextFromImage()
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(image: $selectedImage)
                .ignoresSafeArea()
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
                    .font(.system(size: 56))
                    .foregroundColor(.oceanTeal)
                
                Text("Capture a Screenshot")
                    .font(.custom("DMSans-Medium", size: 20))
                    .foregroundColor(.white)
                
                Text("Take a photo or choose from your library.\nOrca will extract the text automatically.")
                    .font(.custom("DMSans-Regular", size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button {
                        showCamera = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 18))
                            Text("Take Photo")
                                .font(.custom("DMSans-Medium", size: 16))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.oceanTeal)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 18))
                            Text("Choose from Library")
                                .font(.custom("DMSans-Medium", size: 16))
                        }
                        .foregroundColor(.oceanTeal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.oceanTeal.opacity(0.5), lineWidth: 1)
                        )
                    }
                    
                    Button("Cancel") {
                        isPresented = false
                    }
                    .font(.custom("DMSans-Regular", size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Review View
    
    private func reviewView(image: UIImage) -> some View {
        ZStack {
            Color.deepNavy.ignoresSafeArea()
            
            VStack(spacing: 16) {
                HStack {
                    Button("Retake") {
                        selectedImage = nil
                        selectedItem = nil
                        extractedText = ""
                    }
                    .font(.custom("DMSans-Regular", size: 16))
                    .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                    
                    Button("Save") {
                        saveMemory()
                    }
                    .font(.custom("DMSans-Medium", size: 16))
                    .foregroundColor(extractedText.isEmpty ? .white.opacity(0.3) : .oceanTeal)
                    .disabled(extractedText.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 13))
                            .foregroundColor(.oceanTeal)
                        Text("Extracted Text")
                            .font(.custom("DMSans-Medium", size: 13))
                            .foregroundColor(.oceanTeal)
                    }
                    
                    if extractedText.isEmpty {
                        Text("No text found in image")
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(.white.opacity(0.4))
                    } else {
                        TextEditor(text: $extractedText)
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 80, maxHeight: 200)
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Processing View
    
    private var processingView: some View {
        ZStack {
            Color.deepNavy.ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .tint(.oceanTeal)
                    .scaleEffect(1.5)
                
                Text("Extracting text...")
                    .font(.custom("DMSans-Medium", size: 16))
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Image Loading
    
    private func loadImage(from item: PhotosPickerItem) {
        item.loadTransferable(type: Data.self) { result in
            switch result {
            case .success(let data):
                if let data = data, let uiImage = UIImage(data: data) {
                    DispatchQueue.main.async {
                        selectedImage = uiImage
                    }
                }
            case .failure(let error):
                print("Failed to load image: \(error)")
            }
        }
    }
    
    // MARK: - OCR
    
    private func extractTextFromImage() {
        guard let image = selectedImage, let cgImage = image.cgImage else { return }
        isProcessing = true
        
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                DispatchQueue.main.async {
                    isProcessing = false
                }
                return
            }
            
            let text = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            DispatchQueue.main.async {
                extractedText = text
                isProcessing = false
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }
    
    // MARK: - Save
    
    private func saveMemory() {
        guard !extractedText.isEmpty else { return }
        
        sonarResult = sonarEngine.process(text: extractedText, echos: echos)
        
        let echoId = sonarResult?.echoId ?? echos.first?.id ?? UUID()
        let memory = Memory(text: extractedText, echoId: echoId, captureType: .screenshot)
        memory.tags = sonarResult?.tags ?? []
        memory.detectedDate = sonarResult?.detectedDate
        memory.echoConfidence = sonarResult?.echoConfidence ?? 1.0
        memory.dateConfidence = sonarResult?.dateConfidence
        memory.sonarConfidence = sonarResult?.echoConfidence ?? 1.0
        memory.isActionable = sonarResult?.isActionable ?? false
        modelContext.insert(memory)

        // Detect URL
        if let detectedURL = sonarEngine.detectURL(text: extractedText) {
            memory.url = detectedURL
        }
        
        // Detect checklist
        if let checklistItems = sonarEngine.detectChecklist(text: extractedText) {
            memory.hasChecklist = true
            for (index, item) in checklistItems.enumerated() {
                let subTask = SubTask(memoryId: memory.id, text: item, sortOrder: index)
                modelContext.insert(subTask)
            }
        }

        if let result = sonarResult {
            for suggestion in result.pingSuggestions {
                let fireDate = suggestion.fireDate ?? result.detectedDate ?? Date()
                let ping = Ping(memoryId: memory.id, fireDate: fireDate, recurrence: suggestion.recurrence)
                if let fireTime = suggestion.fireTime {
                    ping.fireTime = fireTime
                }
                modelContext.insert(ping)
                NotificationService.shared.schedulePing(ping: ping, memoryText: memory.text)
            }
        }
        
        withAnimation(.spring(duration: 0.4)) {
            showBanner = true
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
    
    private func undoMemory() {
        let recent = try? modelContext.fetch(
            FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )
        if let last = recent?.first {
            modelContext.delete(last)
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
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
