//  OnboardingFlow.swift
//  Orca
//
//  Created by David Piliponskiy on 3/3/26.
//

import SwiftUI
import SwiftData
import AVFoundation
import UserNotifications

struct OnboardingFlow: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var step = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            switch step {
            case 0: SplashScreen(onNext: {
                AnalyticsService.shared.trackOnboardingStepViewed(step: 1, name: "Quick Actions")
                step = 1
            })
            case 1: CaptureModesScreen(onNext: {
                AnalyticsService.shared.trackOnboardingStepViewed(step: 2, name: "Quick Actions")
                step = 2
            })
            case 2: QuickActionsScreen(onNext: {
                AnalyticsService.shared.trackOnboardingStepViewed(step: 3, name: "Thought Bubbles")
                step = 3
            })
            case 3: ShowcaseScreen(onNext: {
                AnalyticsService.shared.trackOnboardingStepViewed(step: 4, name: "Grocery Mode")
                step = 4
            })
            case 4: GroceryModeScreen(onNext: {
                AnalyticsService.shared.trackOnboardingStepViewed(step: 5, name: "All Set")
                step = 5
            })
            case 5: AllSetScreen(onDone: {
                AnalyticsService.shared.trackOnboardingCompleted(droppedFirstMemory: false)
                hasCompletedOnboarding = true
            })
            default: AllSetScreen(onDone: { hasCompletedOnboarding = true })
            }

            if step > 0 && step < 5 {
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.4)) { step -= 1 }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.system(size: 12, weight: .medium))
                            Text("Back").font(.custom("DMSans-Regular", size: 14))
                        }
                        .foregroundColor(.white.opacity(0.35))
                    }
                    Spacer()
                    Button {
                        AnalyticsService.shared.trackOnboardingSkipped(atStep: step)
                        hasCompletedOnboarding = true
                    } label: {
                        Text("Skip").font(.custom("DMSans-Regular", size: 14)).foregroundColor(.white.opacity(0.35))
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 16)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: step)
        .onAppear {
            AnalyticsService.shared.trackOnboardingStarted()
            AnalyticsService.shared.trackOnboardingStepViewed(step: 0, name: "Splash")
        }
    }

    // MARK: - Splash

    struct SplashScreen: View {
        let onNext: () -> Void
        @State private var logoScale: CGFloat = 0.6
        @State private var logoOpacity: CGFloat = 0
        @State private var textOpacity: CGFloat = 0
        @State private var buttonOpacity: CGFloat = 0

        var body: some View {
            ZStack {
                LinearGradient(colors: [Color(hex: "0B1D33"), Color(hex: "1A3A5C")], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: 20) {
                        Image("OrcaLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                            .shadow(color: .oceanTeal.opacity(0.4), radius: 24, y: 8)
                            .scaleEffect(logoScale)
                            .opacity(logoOpacity)

                        VStack(spacing: 6) {
                            Text("Orca").font(.custom("DMSans-Medium", size: 36)).foregroundColor(.white)
                            Text("Everything you forget.").font(.custom("DMSans-Regular", size: 17)).foregroundColor(.white.opacity(0.55))
                            Text("Finally remembered.").font(.custom("DMSans-Medium", size: 17)).foregroundColor(.white.opacity(0.85))
                        }
                        .opacity(textOpacity)
                    }

                    Spacer()

                    VStack(spacing: 14) {
                        Button { onNext() } label: {
                            Text("Get Started")
                                .font(.custom("DMSans-Medium", size: 17))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(LinearGradient(colors: [.oceanTeal, .seafoam], startPoint: .leading, endPoint: .trailing))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .oceanTeal.opacity(0.4), radius: 12, y: 4)
                        }
                        Text("Takes less than 2 minutes")
                            .font(.custom("DMSans-Regular", size: 13))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 52)
                    .opacity(buttonOpacity)
                }
            }
            .onAppear {
                withAnimation(.spring(duration: 0.7, bounce: 0.4)) { logoScale = 1.0; logoOpacity = 1.0 }
                withAnimation(.easeOut(duration: 0.5).delay(0.4)) { textOpacity = 1.0 }
                withAnimation(.easeOut(duration: 0.5).delay(0.7)) { buttonOpacity = 1.0 }
            }
        }
    }

    // MARK: - Quick Actions

    struct QuickActionsScreen: View {
        let onNext: () -> Void
        @State private var itemsVisible = false
        @State private var tappedIndices: Set<Int> = []

        private var allTapped: Bool { tappedIndices.count == 6 }

        let actions: [(String, String, String)] = [
            ("cart.fill",             "Shopping",      "Import recipes & build grocery lists by aisle."),
            ("note.text",             "Thoughts",      "Private notebook — never categorized or pinged."),
            ("person.2.wave.2.fill",  "Shared Space",  "Share lists and plans with family, live."),
            ("popcorn.fill",          "Media",         "Queue shows, movies & books to watch or read."),
            ("gift.fill",             "Gifts",         "Track birthdays, gift ideas, and budgets."),
            ("sparkle",               "Collectibles",  "Track Pokémon cards, Lego & more."),
        ]

        var body: some View {
            ZStack(alignment: .bottom) {
                LinearGradient(colors: [Color(hex: "0B1D33"), Color(hex: "1A3A5C")], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer().frame(height: 52)

                    VStack(spacing: 6) {
                        Text("Six ways Orca")
                            .font(.custom("DMSans-Regular", size: 26)).foregroundColor(.white)
                        Text("has your back.")
                            .font(.custom("DMSans-Medium", size: 26)).foregroundColor(.oceanTeal)
                    }
                    .multilineTextAlignment(.center)
                    .opacity(itemsVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.4), value: itemsVisible)
                    .padding(.bottom, 16)

                    VStack(spacing: 8) {
                        ForEach(Array(stride(from: 0, to: actions.count, by: 2)), id: \.self) { row in
                            HStack(spacing: 8) {
                                ForEach(row..<min(row + 2, actions.count), id: \.self) { i in
                                    actionCard(index: i)
                                }
                                if row + 1 >= actions.count {
                                    Spacer().frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }

                VStack(spacing: 10) {
                    Text(allTapped ? "You've seen them all!" : "Tap all \(6 - tappedIndices.count) remaining to continue")
                        .font(.custom("DMSans-Regular", size: 13))
                        .foregroundColor(.white.opacity(0.3))
                        .animation(.easeOut(duration: 0.3), value: tappedIndices.count)
                    HStack(spacing: 6) {
                        ForEach(0..<6, id: \.self) { i in
                            Circle()
                                .fill(tappedIndices.contains(i) ? Color.oceanTeal : Color.white.opacity(0.2))
                                .frame(width: 6, height: 6)
                                .animation(.spring(duration: 0.3), value: tappedIndices.contains(i))
                        }
                    }
                    Button { onNext() } label: {
                        Text("Continue")
                            .font(.custom("DMSans-Medium", size: 17)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(
                                allTapped
                                    ? LinearGradient(colors: [.oceanTeal, .seafoam], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [.white.opacity(0.12), .white.opacity(0.12)], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: allTapped ? .oceanTeal.opacity(0.4) : .clear, radius: 12, y: 4)
                    }
                    .disabled(!allTapped)
                    .padding(.horizontal, 28).padding(.bottom, 52)
                    .background(Color(hex: "1A3A5C"))
                }
            }
            .onAppear { withAnimation { itemsVisible = true } }
        }

        @ViewBuilder
        private func actionCardLabel(icon: String, title: String, desc: String, tapped: Bool) -> some View {
            let iconBg = tapped ? Color.oceanTeal.opacity(0.25) : Color.oceanTeal.opacity(0.15)
            let cardBg = tapped ? Color.white.opacity(0.11) : Color.white.opacity(0.07)
            let borderColor = tapped ? Color.oceanTeal.opacity(0.3) : Color.white.opacity(0.1)
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconBg)
                        .frame(width: 30, height: 30)
                        .overlay(Image(systemName: icon).font(.system(size: 13)).foregroundColor(.oceanTeal))
                    if tapped {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12)).foregroundColor(.seafoam)
                            .offset(x: 6, y: -6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.custom("DMSans-Medium", size: 13)).foregroundColor(.white)
                    Text(desc).font(.custom("DMSans-Regular", size: 11)).foregroundColor(.white.opacity(0.45)).lineLimit(2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 125, maxHeight: 125, alignment: .topLeading)
            .background(cardBg)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(borderColor, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }

        private func actionCard(index i: Int) -> some View {
            let a = actions[i]
            let tapped = tappedIndices.contains(i)
            return Button {
                withAnimation(.spring(duration: 0.3)) { _ = tappedIndices.insert(i) }
            } label: {
                actionCardLabel(icon: a.0, title: a.1, desc: a.2, tapped: tapped)
            }
            .buttonStyle(.plain)
            .opacity(itemsVisible ? 1 : 0)
            .offset(y: itemsVisible ? 0 : 20)
            .animation(.easeOut(duration: 0.4).delay(Double(i) * 0.08), value: itemsVisible)
        }
    }

    // MARK: - Capture Modes

    struct CaptureModesScreen: View {
        let onNext: () -> Void
        @State private var drawerVisible = false
        @State private var selectedIndex: Int? = nil
        @State private var tappedIndices: Set<Int> = []

        private var allTapped: Bool { tappedIndices.count == 4 }

        let modes: [(String, String, String, String)] = [
            ("mic.fill",    "Voice",   "Say anything — Orca hears it, files it, and sets reminders automatically.",      "\"Remind me tomorrow at 4pm to call the vet\""),
            ("keyboard",    "Text",    "Type a memory, a thought, or a to-do. Orca figures out the rest.",               "\"Dinner at Carbone Friday — try the lamb chops\""),
            ("camera.fill", "Photo",   "Screenshot receipts, hotel bookings, or anything you want saved.",               "Screenshot a flight confirmation → date auto-saved"),
            ("fork.knife",  "Recipe",  "Paste a URL or snap a cookbook page — ingredients and instructions import to your list.", "Snap any recipe → Orca extracts every ingredient and instruction"),
        ]

        let angles: [Double] = [-55, -18, 18, 55]

        var body: some View {
            ZStack {
                LinearGradient(colors: [Color(hex: "0B1D33"), Color(hex: "0F2640")], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 6) {
                        Text("Drop anything.")
                            .font(.custom("DMSans-Medium", size: 30)).foregroundColor(.white)
                        Text("Four ways to capture.")
                            .font(.custom("DMSans-Regular", size: 18)).foregroundColor(.white.opacity(0.45))
                    }
                    .multilineTextAlignment(.center)
                    .opacity(drawerVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.4), value: drawerVisible)

                    Spacer()

                    // Capture drawer animation
                    ZStack {
                        // Mode buttons fanning out
                        ForEach(modes.indices, id: \.self) { i in
                            let angle = angles[i]
                            let radius: CGFloat = 110
                            let rad = angle * .pi / 180
                            let x = CGFloat(sin(rad)) * radius
                            let y = -CGFloat(cos(rad)) * radius

                            Button {
                                withAnimation(.spring(duration: 0.3)) {
                                    selectedIndex = selectedIndex == i ? nil : i
                                    tappedIndices.insert(i)
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    ZStack {
                                        Circle()
                                            .fill(selectedIndex == i ? Color.oceanTeal : Color.white.opacity(0.12))
                                            .frame(width: 52, height: 52)
                                            .shadow(color: selectedIndex == i ? .oceanTeal.opacity(0.5) : .clear, radius: 10, y: 3)
                                        Image(systemName: modes[i].0)
                                            .font(.system(size: 20))
                                            .foregroundColor(selectedIndex == i ? .white : .white.opacity(0.8))
                                        if tappedIndices.contains(i) && selectedIndex != i {
                                            Circle()
                                                .fill(Color.seafoam)
                                                .frame(width: 16, height: 16)
                                                .overlay(Image(systemName: "checkmark").font(.system(size: 8, weight: .bold)).foregroundColor(.white))
                                                .offset(x: 18, y: -18)
                                        }
                                    }
                                    Text(modes[i].1)
                                        .font(.custom("DMSans-Medium", size: 11))
                                        .foregroundColor(selectedIndex == i ? .oceanTeal : .white.opacity(0.5))
                                }
                            }
                            .offset(
                                x: drawerVisible ? x : 0,
                                y: drawerVisible ? y : 0
                            )
                            .opacity(drawerVisible ? 1 : 0)
                            .scaleEffect(drawerVisible ? 1 : 0.5)
                            .animation(.spring(duration: 0.5, bounce: 0.4).delay(Double(i) * 0.07), value: drawerVisible)
                        }

                        // Center Orca button
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.oceanTeal, .seafoam], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 64, height: 64)
                                .shadow(color: .oceanTeal.opacity(0.5), radius: 16, y: 4)
                            Image("OrcaLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                        }
                    }
                    .frame(height: 280)

                    // Description card for selected mode
                    ZStack(alignment: .topLeading) {
                        if let i = selectedIndex {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(modes[i].1)
                                    .font(.custom("DMSans-Medium", size: 16)).foregroundColor(.white)
                                Text(modes[i].2)
                                    .font(.custom("DMSans-Regular", size: 13)).foregroundColor(.white.opacity(0.6))
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(modes[i].3)
                                    .font(.custom("DMSans-Regular", size: 12)).foregroundColor(.oceanTeal)
                                    .italic()
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120, alignment: .topLeading)
                            .background(.white.opacity(0.07))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.1), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .transition(.scale(scale: 0.95).combined(with: .opacity))
                        } else {
                            Text(allTapped ? "Nice! You've tried them all." : "Tap all 4 to continue")
                                .font(.custom("DMSans-Regular", size: 14))
                                .foregroundColor(.white.opacity(0.25))
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 28)
                    .frame(height: 140, alignment: .top)
                    .animation(.spring(duration: 0.3), value: selectedIndex)

                    // Progress dots
                    HStack(spacing: 6) {
                        ForEach(0..<4, id: \.self) { i in
                            Circle()
                                .fill(tappedIndices.contains(i) ? Color.oceanTeal : Color.white.opacity(0.2))
                                .frame(width: 6, height: 6)
                                .animation(.spring(duration: 0.3), value: tappedIndices.contains(i))
                        }
                    }
                    .opacity(drawerVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.5), value: drawerVisible)

                    Spacer()

                    Button { onNext() } label: {
                        Text("Continue")
                            .font(.custom("DMSans-Medium", size: 17)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(
                                allTapped
                                    ? LinearGradient(colors: [.oceanTeal, .seafoam], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [.white.opacity(0.12), .white.opacity(0.12)], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: allTapped ? .oceanTeal.opacity(0.4) : .clear, radius: 12, y: 4)
                    }
                    .disabled(!allTapped)
                    .padding(.horizontal, 28).padding(.bottom, 52)
                    .opacity(drawerVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.5), value: drawerVisible)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation { drawerVisible = true }
                }
            }
        }
    }

    // MARK: - Showcase

    struct ShowcaseScreen: View {
        let onNext: () -> Void
        @State private var currentPage = 0
        @State private var seenPages: Set<Int> = []

        var allSeen: Bool { seenPages.count == 3 }

        var body: some View {
            ZStack(alignment: .bottom) {
                LinearGradient(colors: [Color(hex: "0B1D33"), Color(hex: "0F2640")], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer().frame(height: 52)

                    VStack(spacing: 6) {
                        Text("See it in action.")
                            .font(.custom("DMSans-Medium", size: 28)).foregroundColor(.white)
                        Text("Try doing this in Notes.")
                            .font(.custom("DMSans-Regular", size: 15)).foregroundColor(.white.opacity(0.35))
                    }
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 20)

                    TabView(selection: $currentPage) {
                        ReminderCard().tag(0)
                        PassiveCaptureCard().tag(1)
                        SharedSpaceCard().tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 340)
                    .onChange(of: currentPage) { _, new in
                        withAnimation { _ = seenPages.insert(new) }
                    }

                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(seenPages.contains(i) ? Color.oceanTeal : Color.white.opacity(0.2))
                                .frame(width: 7, height: 7)
                                .animation(.spring(duration: 0.3), value: seenPages.contains(i))
                        }
                    }
                    .padding(.top, 16)

                    Spacer()

                    VStack(spacing: 12) {
                        Text(allSeen ? "" : "Swipe through all 3  →")
                            .font(.custom("DMSans-Regular", size: 13))
                            .foregroundColor(.white.opacity(0.3))
                            .animation(.easeOut(duration: 0.3), value: allSeen)

                        Button { onNext() } label: {
                            Text("Continue")
                                .font(.custom("DMSans-Medium", size: 17)).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(
                                    allSeen
                                        ? LinearGradient(colors: [.oceanTeal, .seafoam], startPoint: .leading, endPoint: .trailing)
                                        : LinearGradient(colors: [.white.opacity(0.12), .white.opacity(0.12)], startPoint: .leading, endPoint: .trailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: allSeen ? .oceanTeal.opacity(0.4) : .clear, radius: 12, y: 4)
                        }
                        .disabled(!allSeen)
                    }
                    .padding(.horizontal, 28).padding(.bottom, 52)
                }
            }
            .onAppear { _ = seenPages.insert(0) }
        }

        // MARK: Card 1 — Smart Reminder

        struct ReminderCard: View {
            let fullText = "Remind me tomorrow at 4pm to call the vet, pick up dry cleaning, and grab groceries"
            @State private var displayed = ""
            @State private var typingDone = false
            @State private var checklistVisible = false
            @State private var checkedCount = 0
            @State private var hasStarted = false
            let tasks = ["Call the vet", "Pick up dry cleaning", "Grab groceries"]

            var body: some View {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 6) {
                        Image(systemName: "mic.fill").font(.system(size: 11)).foregroundColor(.oceanTeal)
                        Text("Voice capture").font(.custom("DMSans-Medium", size: 12)).foregroundColor(.oceanTeal)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.oceanTeal.opacity(0.12)).clipShape(Capsule())

                    (Text(displayed).foregroundColor(.white.opacity(0.9))
                     + Text(displayed.count < fullText.count ? "▌" : "").foregroundColor(.oceanTeal))
                        .font(.custom("DMSans-Regular", size: 14))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    if typingDone {
                        HStack(spacing: 8) {
                            Image(systemName: "bell.fill").font(.system(size: 12)).foregroundColor(.oceanTeal)
                            Text("Tomorrow · 4:00 PM").font(.custom("DMMono-Regular", size: 13)).foregroundColor(.white)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.oceanTeal.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 10))
                        .transition(.scale(scale: 0.9).combined(with: .opacity))

                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(Array(tasks.enumerated()), id: \.offset) { i, task in
                                let done = checkedCount > i
                                HStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(done ? Color.seafoam : Color.clear)
                                            .frame(width: 16, height: 16)
                                        Circle()
                                            .strokeBorder(done ? Color.seafoam : Color.seafoam.opacity(0.5), lineWidth: 1.5)
                                            .frame(width: 16, height: 16)
                                        if done {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .animation(.spring(duration: 0.3), value: done)
                                    Text(task)
                                        .font(.custom("DMSans-Regular", size: 13))
                                        .foregroundColor(done ? .white.opacity(0.35) : .white.opacity(0.8))
                                        .strikethrough(done, color: .white.opacity(0.3))
                                        .animation(.easeOut(duration: 0.2), value: done)
                                }
                                .opacity(checklistVisible ? 1 : 0)
                                .offset(x: checklistVisible ? 0 : -10)
                                .animation(.easeOut(duration: 0.3).delay(Double(i) * 0.1), value: checklistVisible)
                            }
                        }
                        .transition(.opacity)
                    }
                    Spacer(minLength: 0)
                }
                .padding(18)
                .frame(maxHeight: .infinity)
                .background(.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.08), lineWidth: 1))
                .padding(.horizontal, 24)
                .onAppear {
                    guard !hasStarted else { return }
                    hasStarted = true
                    for (i, char) in fullText.enumerated() {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.032) { displayed.append(char) }
                    }
                    let delay = Double(fullText.count) * 0.032 + 0.4
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        withAnimation(.spring(duration: 0.4)) { typingDone = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            withAnimation { checklistVisible = true }
                            for i in 0..<3 {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 + Double(i) * 0.5) {
                                    withAnimation(.spring(duration: 0.3)) { checkedCount = i + 1 }
                                }
                            }
                        }
                    }
                }
            }
        }

        // MARK: Card 2 — Passive Capture

        struct PassiveCaptureCard: View {
            let fullText = "Dinner at Carbone last night, great lamb chops, skip the pasta next time"
            @State private var displayed = ""
            @State private var typingDone = false
            @State private var collectionVisible = false
            @State private var hasStarted = false

            let pastNotes = [
                ("Carbone", "Great lamb chops, skip the pasta next time"),
                ("Nobu", "Black cod miso — perfect. Book the private room next time"),
                ("Joe's Shanghai", "Get the soup dumplings, skip the noodles"),
            ]

            var body: some View {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "keyboard").font(.system(size: 11)).foregroundColor(.oceanTeal)
                        Text("Text capture").font(.custom("DMSans-Medium", size: 12)).foregroundColor(.oceanTeal)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.oceanTeal.opacity(0.12)).clipShape(Capsule())

                    (Text(displayed).foregroundColor(.white.opacity(0.9))
                     + Text(displayed.count < fullText.count ? "▌" : "").foregroundColor(.oceanTeal))
                        .font(.custom("DMSans-Regular", size: 14))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    if typingDone {
                        HStack(spacing: 10) {
                            Text("🍽️").font(.system(size: 16))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Dining").font(.custom("DMSans-Medium", size: 13)).foregroundColor(.white)
                                Text("Your Dining collection").font(.custom("DMSans-Regular", size: 11)).foregroundColor(.white.opacity(0.35))
                            }
                            Spacer()
                            Text("3 notes").font(.custom("DMMono-Regular", size: 11)).foregroundColor(.oceanTeal.opacity(0.7))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.white.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 12))
                        .transition(.scale(scale: 0.9).combined(with: .opacity))

                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(pastNotes.enumerated()), id: \.offset) { i, note in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("🍽️").font(.system(size: 12))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(note.0).font(.custom("DMSans-Medium", size: 12)).foregroundColor(.white.opacity(0.7))
                                        Text(note.1).font(.custom("DMSans-Regular", size: 11)).foregroundColor(.white.opacity(0.4))
                                            .lineLimit(1)
                                    }
                                }
                                .padding(.vertical, 7)
                                .opacity(collectionVisible ? 1 : 0)
                                .offset(y: collectionVisible ? 0 : 6)
                                .animation(.easeOut(duration: 0.3).delay(Double(i) * 0.15), value: collectionVisible)
                                if i < pastNotes.count - 1 { Divider().background(.white.opacity(0.06)) }
                            }
                        }
                        .padding(.horizontal, 12)
                        .background(.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .transition(.opacity)
                    }
                    Spacer(minLength: 0)
                }
                .padding(18)
                .frame(maxHeight: .infinity)
                .background(.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.08), lineWidth: 1))
                .padding(.horizontal, 24)
                .onAppear {
                    guard !hasStarted else { return }
                    hasStarted = true
                    for (i, char) in fullText.enumerated() {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.036) { displayed.append(char) }
                    }
                    let delay = Double(fullText.count) * 0.036 + 0.4
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        withAnimation(.spring(duration: 0.4)) { typingDone = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            withAnimation { collectionVisible = true }
                        }
                    }
                }
            }
        }

        // MARK: Card 3 — Shared Space

        struct SharedSpaceCard: View {
            @State private var itemsVisible = 0
            @State private var tasksVisible = false
            @State private var hasStarted = false

            // (emoji, title, subtitle, isPast)
            let items: [(String, String, String, Bool)] = [
                ("📅", "Venue walkthrough",        "May 10",      false),
                ("📅", "Wedding",                  "June 14–15",  false),
                ("📝", "Guest list – Cara's side", "Note",        false),
                ("📝", "Song ideas for reception",  "Note",        false),
                ("✅", "Florist deposit",           "Paid · done", true),
            ]

            // Tasks shown under the Wedding event
            let weddingTasks = [
                ("Book photographer", true),
                ("Send invites",      true),
                ("Confirm caterer",   false),
            ]

            var body: some View {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        ZStack(alignment: .leading) {
                            Circle().fill(Color.seafoam).frame(width: 28, height: 28)
                                .overlay(Text("C").font(.system(size: 12, weight: .semibold)).foregroundColor(.white))
                                .offset(x: 16)
                            Circle().fill(Color.oceanTeal).frame(width: 28, height: 28)
                                .overlay(Text("D").font(.system(size: 12, weight: .semibold)).foregroundColor(.white))
                        }
                        .frame(width: 44)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Us 🤍").font(.custom("DMSans-Medium", size: 15)).foregroundColor(.white)
                            Text("Live · always in sync").font(.custom("DMSans-Regular", size: 11)).foregroundColor(.white.opacity(0.35))
                        }
                        Spacer()
                        Image(systemName: "person.2.fill").font(.system(size: 13)).foregroundColor(.oceanTeal.opacity(0.5))
                    }
                    .padding(.bottom, 10)

                    Divider().background(.white.opacity(0.08)).padding(.bottom, 6)

                    ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 12) {
                                Text(item.0).font(.system(size: 14)).frame(width: 20)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.1)
                                        .font(.custom("DMSans-Medium", size: 12))
                                        .foregroundColor(item.3 ? .white.opacity(0.4) : .white)
                                        .strikethrough(item.3, color: .white.opacity(0.3))
                                    Text(item.2)
                                        .font(.custom("DMMono-Regular", size: 10))
                                        .foregroundColor(item.3 ? .white.opacity(0.25) : .oceanTeal.opacity(0.7))
                                }
                                Spacer()
                                if !item.3 {
                                    Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(.white.opacity(0.2))
                                }
                            }
                            .padding(.vertical, 6)

                            // Wedding tasks expand below that row
                            if i == 1 && tasksVisible {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(Array(weddingTasks.enumerated()), id: \.offset) { j, task in
                                        HStack(spacing: 6) {
                                            ZStack {
                                                Circle()
                                                    .fill(task.1 ? Color.seafoam : Color.clear)
                                                    .frame(width: 13, height: 13)
                                                Circle()
                                                    .strokeBorder(task.1 ? Color.seafoam : Color.seafoam.opacity(0.4), lineWidth: 1.2)
                                                    .frame(width: 13, height: 13)
                                                if task.1 {
                                                    Image(systemName: "checkmark").font(.system(size: 7, weight: .bold)).foregroundColor(.white)
                                                }
                                            }
                                            Text(task.0)
                                                .font(.custom("DMSans-Regular", size: 11))
                                                .foregroundColor(task.1 ? .white.opacity(0.35) : .white.opacity(0.65))
                                                .strikethrough(task.1, color: .white.opacity(0.25))
                                        }
                                        .opacity(tasksVisible ? 1 : 0)
                                        .offset(x: tasksVisible ? 0 : -8)
                                        .animation(.easeOut(duration: 0.25).delay(Double(j) * 0.08), value: tasksVisible)
                                    }
                                }
                                .padding(.leading, 32).padding(.bottom, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .opacity(itemsVisible > i ? 1 : 0)
                        .offset(x: itemsVisible > i ? 0 : 16)
                        .animation(.easeOut(duration: 0.3).delay(Double(i) * 0.1), value: itemsVisible)

                        if i < items.count - 1 { Divider().background(.white.opacity(0.06)) }
                    }
                    Spacer(minLength: 0)
                }
                .padding(18)
                .frame(maxHeight: .infinity)
                .background(.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.08), lineWidth: 1))
                .padding(.horizontal, 24)
                .onAppear {
                    guard !hasStarted else { return }
                    hasStarted = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation { itemsVisible = items.count }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            withAnimation(.spring(duration: 0.4)) { tasksVisible = true }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Grocery Mode

    struct GroceryModeScreen: View {
        let onNext: () -> Void
        @State private var hasStarted = false
        @State private var contentVisible = false
        @State private var recipe1Checked = false
        @State private var recipe2Checked = false
        @State private var listVisible = false
        @State private var groceryCheckedCount = 0

        let recipes = [
            ("🍛", "Chicken Tikka Masala", "45 min"),
            ("🍝", "Pasta Carbonara", "25 min"),
            ("🥗", "Greek Salad", "15 min"),
        ]

        let groceryItems = [
            "Chicken thighs",
            "Heavy cream",
            "Garlic",
            "Tikka masala paste",
            "Parmesan",
            "Pasta",
        ]

        var body: some View {
            ZStack {
                LinearGradient(colors: [Color(hex: "0B1D33"), Color(hex: "1A3A5C")], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer().frame(height: 52)

                    VStack(spacing: 6) {
                        Text("Import recipes from URLs or cookbooks.")
                            .font(.custom("DMSans-Medium", size: 20))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                        Text("Pick what to cook, we'll build your grocery list.")
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .opacity(contentVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.4), value: contentVisible)

                    Spacer().frame(height: 24)

                    // Recipe selection cards
                    VStack(spacing: 10) {
                        ForEach(Array(recipes.enumerated()), id: \.offset) { i, recipe in
                            let checked = i == 0 ? recipe1Checked : i == 1 ? recipe2Checked : false
                            recipeCard(emoji: recipe.0, name: recipe.1, time: recipe.2, checked: checked)
                        }
                    }
                    .padding(.horizontal, 24)
                    .opacity(contentVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.1), value: contentVisible)

                    Spacer().frame(height: 18)

                    // Grocery list slides in after recipes selected
                    if listVisible {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 8) {
                                Image(systemName: "cart.fill").font(.system(size: 13)).foregroundColor(.oceanTeal)
                                Text("Your Grocery List").font(.custom("DMSans-Medium", size: 14)).foregroundColor(.deepNavy)
                                Spacer()
                                Text("\(min(groceryCheckedCount, groceryItems.count)) of \(groceryItems.count)")
                                    .font(.custom("DMMono-Regular", size: 11)).foregroundColor(.gray)
                            }
                            .padding(.bottom, 10)

                            ForEach(Array(groceryItems.enumerated()), id: \.offset) { i, item in
                                groceryRow(name: item, checked: groceryCheckedCount > i)
                                if i < groceryItems.count - 1 {
                                    Divider().padding(.leading, 28).padding(.vertical, 1)
                                }
                            }
                        }
                        .padding(16)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: .black.opacity(0.14), radius: 16, y: 6)
                        .padding(.horizontal, 24)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    Spacer()

                    Button { onNext() } label: {
                        Text("Next")
                            .font(.custom("DMSans-Medium", size: 17)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(LinearGradient(colors: [.oceanTeal, .seafoam], startPoint: .leading, endPoint: .trailing))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .oceanTeal.opacity(0.4), radius: 12, y: 4)
                    }
                    .padding(.horizontal, 28).padding(.bottom, 52)
                    .opacity(contentVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.3), value: contentVisible)
                }
            }
            .onAppear {
                guard !hasStarted else { return }
                hasStarted = true
                contentVisible = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { withAnimation(.spring(duration: 0.3)) { recipe1Checked = true } }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { withAnimation(.spring(duration: 0.3)) { recipe2Checked = true } }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { withAnimation(.spring(duration: 0.5, bounce: 0.2)) { listVisible = true } }
                for i in 0..<groceryItems.count {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0 + Double(i) * 0.35) {
                        withAnimation(.spring(duration: 0.3)) { groceryCheckedCount = i + 1 }
                    }
                }
            }
        }

        private func recipeCard(emoji: String, name: String, time: String, checked: Bool) -> some View {
            HStack(spacing: 12) {
                Text(emoji).font(.system(size: 26))
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.custom("DMSans-Medium", size: 14)).foregroundColor(.white)
                    Text(time).font(.custom("DMMono-Regular", size: 11)).foregroundColor(.white.opacity(0.35))
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(checked ? Color.seafoam : Color.clear)
                        .frame(width: 22, height: 22)
                    Circle()
                        .strokeBorder(checked ? Color.seafoam : Color.white.opacity(0.2), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if checked {
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .background(checked ? Color.white.opacity(0.1) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(checked ? Color.seafoam.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 1)
            )
            .animation(.spring(duration: 0.3), value: checked)
        }

        private func groceryRow(name: String, checked: Bool) -> some View {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(checked ? Color.oceanTeal : Color.clear).frame(width: 18, height: 18)
                    Circle().strokeBorder(checked ? Color.oceanTeal : Color.gray.opacity(0.3), lineWidth: 1.5).frame(width: 18, height: 18)
                    if checked {
                        Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                    }
                }
                Text(name)
                    .font(.custom("DMSans-Regular", size: 13))
                    .foregroundColor(checked ? .gray : .deepNavy)
                    .strikethrough(checked, color: .gray)
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Notifications

    struct NotificationsScreen: View {
        let onNext: () -> Void
        @State private var granted = false
        @State private var contentVisible = false

        var body: some View {
            ZStack {
                LinearGradient(colors: [Color(hex: "0B1D33"), Color(hex: "1A3A5C")], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: 28) {
                        ZStack {
                            Circle().fill(.white.opacity(0.08)).frame(width: 96, height: 96)
                            Text("🔔").font(.system(size: 44))
                        }
                        .scaleEffect(contentVisible ? 1 : 0.6).opacity(contentVisible ? 1 : 0)
                        .animation(.spring(duration: 0.6, bounce: 0.4), value: contentVisible)

                        VStack(spacing: 10) {
                            Text("Never miss a thing").font(.custom("DMSans-Medium", size: 28)).foregroundColor(.white)
                            Text("Orca fires Pings at exactly the right moment — not a minute early, not a minute late.")
                                .font(.custom("DMSans-Regular", size: 15)).foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center).padding(.horizontal, 32)
                        }
                        .opacity(contentVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.2), value: contentVisible)

                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(LinearGradient(colors: [.oceanTeal, .seafoam], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 40, height: 40)
                                FinIcon().fill(.white).frame(width: 20, height: 24)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Orca · now").font(.custom("DMMono-Regular", size: 11)).foregroundColor(.white.opacity(0.4))
                                Text("🧺 Pick up dry cleaning — tomorrow at 4pm")
                                    .font(.custom("DMSans-Medium", size: 14)).foregroundColor(.white).lineLimit(2)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(.white.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.1), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 28)
                        .opacity(contentVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.35), value: contentVisible)
                    }

                    Spacer()

                    VStack(spacing: 12) {
                        if granted {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.oceanTeal)
                                Text("Notifications enabled").font(.custom("DMSans-Medium", size: 16)).foregroundColor(.white)
                            }
                            .transition(.scale.combined(with: .opacity))

                            Button { onNext() } label: {
                                Text("Almost done")
                                    .font(.custom("DMSans-Medium", size: 17)).foregroundColor(.white)
                                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                                    .background(LinearGradient(colors: [.oceanTeal, .seafoam], startPoint: .leading, endPoint: .trailing))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .transition(.opacity)
                        } else {
                            Button { requestNotifications() } label: {
                                Text("Turn on Pings")
                                    .font(.custom("DMSans-Medium", size: 17)).foregroundColor(.white)
                                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                                    .background(LinearGradient(colors: [.oceanTeal, .seafoam], startPoint: .leading, endPoint: .trailing))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: .oceanTeal.opacity(0.4), radius: 12, y: 4)
                            }
                            Button { onNext() } label: {
                                Text("Maybe later").font(.custom("DMSans-Regular", size: 15)).foregroundColor(.white.opacity(0.35))
                            }
                        }
                    }
                    .padding(.horizontal, 28).padding(.bottom, 52)
                    .animation(.spring(duration: 0.4), value: granted)
                }
            }
            .onAppear { withAnimation { contentVisible = true } }
        }

        private func requestNotifications() {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async {
                    withAnimation { self.granted = granted }
                    if !granted { onNext() }
                }
            }
        }
    }

    // MARK: - All Set

    struct AllSetScreen: View {
        let onDone: () -> Void
        @State private var contentVisible = false

        var body: some View {
            ZStack {
                LinearGradient(colors: [Color(hex: "0B1D33"), Color(hex: "1A3A5C")], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    Image("OrcaLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .oceanTeal.opacity(0.5), radius: 24, y: 8)
                        .scaleEffect(contentVisible ? 1 : 0.5).opacity(contentVisible ? 1 : 0)
                        .animation(.spring(duration: 0.7, bounce: 0.5), value: contentVisible)
                        .padding(.bottom, 28)

                    VStack(spacing: 10) {
                        Text("You're All Set!")
                            .font(.custom("DMSans-Medium", size: 32)).foregroundColor(.white)
                        Text("Your personal assistant is ready.")
                            .font(.custom("DMSans-Regular", size: 16)).foregroundColor(.white.opacity(0.7))
                        Text("The more you Drop, the smarter it gets.")
                            .font(.custom("DMSans-Regular", size: 15)).foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center).padding(.horizontal, 32)
                    }
                    .opacity(contentVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.3), value: contentVisible)

                    Spacer().frame(height: 36)

                    HStack(spacing: 10) {
                        Image(systemName: "gear").font(.system(size: 14)).foregroundColor(.white.opacity(0.4))
                        Text("Go to Settings to adjust permissions and allow adding to iOS Calendar.")
                            .font(.custom("DMSans-Regular", size: 13))
                            .foregroundColor(.white.opacity(0.35))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 32)
                    .opacity(contentVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.5), value: contentVisible)

                    Spacer()

                    Button {
                        AnalyticsService.shared.trackOnboardingCompleted(droppedFirstMemory: true)
                        onDone()
                    } label: {
                        Text("You're All Set!")
                            .font(.custom("DMSans-Medium", size: 17)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(LinearGradient(colors: [.oceanTeal, .seafoam], startPoint: .leading, endPoint: .trailing))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .oceanTeal.opacity(0.4), radius: 12, y: 4)
                    }
                    .padding(.horizontal, 28).padding(.bottom, 52)
                    .opacity(contentVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.6), value: contentVisible)
                }
            }
            .onAppear {
                withAnimation { contentVisible = true }
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
            }
        }
    }
}
