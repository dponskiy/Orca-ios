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
    
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.oceanTeal)
                    .frame(width: geo.size.width * countdown, height: 3)
            }
            .frame(height: 3)
            
            VStack(spacing: 16) {
                let echoName = echos.first { $0.id == selectedEchoId }?.name
                    ?? sonarResult?.echoName
                    ?? "Memory"
                let echoEmoji = echos.first { $0.id == selectedEchoId }?.emoji
                    ?? echos.first { $0.name == sonarResult?.echoName }?.emoji
                    ?? "📝"
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text("Dropped to \(echoName) \(echoEmoji)")
                            .font(.custom("DMSans-Medium", size: 16))
                            .foregroundColor(.deepNavy)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.oceanTeal)
                        if isPaused {
                            Text("· editing")
                                .font(.custom("DMSans-Regular", size: 13))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        isPaused = true
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        withAnimation(.spring(duration: 0.2)) {
                            isTask.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isTask ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 14))
                                .foregroundColor(isTask ? .white : .gray)
                            Text("Task")
                                .font(.custom("DMSans-Medium", size: 13))
                                .foregroundColor(isTask ? .white : .gray)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isTask ? Color.oceanTeal : Color.mist)
                        .clipShape(Capsule())
                    }
                    
                    Button(action: {
                        wasCancelled = true
                        onUndo()
                    }) {
                        Text("Undo")
                            .font(.custom("DMSans-Medium", size: 14))
                            .foregroundColor(.deepNavy)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        onDone(isTask)
                    } label: {
                        Text("Done")
                            .font(.custom("DMSans-Medium", size: 14))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.oceanTeal)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                
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
                
                HStack(spacing: 8) {
                    if let result = sonarResult {
                        Button {
                            isPaused = true
                            withAnimation(.easeOut(duration: 0.2)) {
                                showEchoPicker.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if let echoId = selectedEchoId,
                                   let echo = echos.first(where: { $0.id == echoId }) {
                                    Text(echo.emoji).font(.system(size: 14))
                                    Text(echo.name)
                                        .font(.custom("DMSans-Medium", size: 13))
                                        .foregroundColor(.deepNavy)
                                } else {
                                    let echo = echos.first { $0.name == result.echoName }
                                    Text(echo?.emoji ?? "📝").font(.system(size: 14))
                                    Text(result.echoName)
                                        .font(.custom("DMSans-Medium", size: 13))
                                        .foregroundColor(.deepNavy)
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
                        
                        // Date chip — shows range if endDate exists
                        if let date = result.detectedDate {
                            HStack(spacing: 4) {
                                Text("📅").font(.system(size: 14))
                                if let endDate = result.endDate {
                                    Text("\(date.formatted(.dateTime.month(.abbreviated).day())) – \(endDate.formatted(.dateTime.month(.abbreviated).day()))")
                                        .font(.custom("DMSans-Medium", size: 13))
                                        .foregroundColor(.deepNavy)
                                } else {
                                    Text(date, format: .dateTime.month(.abbreviated).day())
                                        .font(.custom("DMSans-Medium", size: 13))
                                        .foregroundColor(.deepNavy)
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
                        
                        if result.shouldCreatePing {
                            HStack(spacing: 4) {
                                Text("🔔").font(.system(size: 14))
                                Text(result.pingRecurrence == .none ? "Ping" : result.pingRecurrence.rawValue.capitalized)
                                    .font(.custom("DMSans-Medium", size: 13))
                                    .foregroundColor(.deepNavy)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.mist)
                            .clipShape(Capsule())
                        }
                    }
                    Spacer()
                }
                
                if showEchoPicker {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(echos.sorted { $0.sortOrder < $1.sortOrder }, id: \.id) { echo in
                                Button {
                                    selectedEchoId = echo.id
                                    onEchoChanged?(echo.id)
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        showEchoPicker = false
                                    }
                                } label: {
                                    HStack(spacing: 3) {
                                        Text(echo.emoji).font(.system(size: 12))
                                        Text(echo.name)
                                            .font(.custom("DMSans-Medium", size: 12))
                                            .foregroundColor(selectedEchoId == echo.id ? .white : .deepNavy)
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
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
    
    private func startCountdown() {
        withAnimation(.linear(duration: 5)) {
            countdown = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if !isPaused && !wasCancelled {
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
                }
            } catch {
                await MainActor.run {
                    isFetchingRecipe = false
                    recipeFetchError = error.localizedDescription
                }
            }
        }
    }
}
