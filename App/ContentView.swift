//
//  ContentView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/24/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 1
    @State private var resetDashboardTrigger = false
    @State private var showDrop = false
    @State private var showDrawer = false
    @State private var showTyped = false
    @State private var showSearch = false
    @State private var showScreenshot = false
    @State private var showToast = false
    @State private var showRecipe = false
    @State private var toastMessage = ""
    @State private var showCalendarPrompt = false
    @State private var pendingCalendarMemory: Memory? = nil
    @AppStorage("calendarSyncEnabled") private var calendarSyncEnabled = false
    @AppStorage("calendarSyncSingleOnly") private var calendarSyncSingleOnly = true
    @Environment(\.modelContext) private var modelContext
    @Query private var echos: [Echo]

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            TabView(selection: Binding(
                get: { selectedTab },
                set: { newTab in
                    if newTab == 0 {
                        NotificationCenter.default.post(name: .resetToToday, object: nil)
                    }
                    selectedTab = newTab
                }
            )) {
                TodayView()
                    .tag(0)

                DashboardView(showSearch: $showSearch, resetTrigger: $resetDashboardTrigger)
                    .tag(1)

                PeopleView()
                    .tag(2)

                CalendarTabView()
                    .tag(3)
            }
            .tint(.oceanTeal)
            .toolbar(.hidden, for: .tabBar)
            // Push tab content up so it doesn't hide behind the custom tab bar
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 64)
            }

            // Custom tab bar
            customTabBar

            // Capture drawer overlay
            if showDrawer {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { showDrawer = false }
                    .zIndex(1)

                VStack {
                    Spacer()
                    CaptureDrawerView(
                        onSelect: { mode in
                            showDrawer = false
                            switch mode {
                            case .voice:       showDrop = true
                            case .typed:       showTyped = true
                            case .screenshot:  showScreenshot = true
                            case .recipe:      showRecipe = true
                            case .cards:       break
                            }
                        },
                        onCancel: { showDrawer = false }
                    )
                }
                .transition(.move(edge: .bottom))
                .zIndex(2)
            }

            // Toast
            if showToast {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15)).foregroundColor(.oceanTeal)
                        Text(toastMessage)
                            .font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(.white).clipShape(Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(3)
            }
        }
        .animation(.spring(duration: 0.3), value: showDrawer)
        .fullScreenCover(isPresented: $showDrop) {
            DropOverlayView(isPresented: $showDrop) { message in
                toastMessage = message
                withAnimation(.spring(duration: 0.4)) { showToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation(.easeOut(duration: 0.4)) { showToast = false }
                }
            }
        }
        .fullScreenCover(isPresented: $showRecipe) {
            RecipeCaptureView(isPresented: $showRecipe) { message in
                toastMessage = message
                withAnimation(.spring(duration: 0.4)) { showToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation(.easeOut(duration: 0.4)) { showToast = false }
                }
            }
        }
        .fullScreenCover(isPresented: $showTyped)      { TypeCaptureView(isPresented: $showTyped) }
        .fullScreenCover(isPresented: $showScreenshot) { PhotoCaptureView(isPresented: $showScreenshot) }
        .fullScreenCover(isPresented: $showSearch)     { SearchView(isPresented: $showSearch) }
        .alert("Add Events to Apple Calendar?", isPresented: $showCalendarPrompt) {
            Button("Turn On") {
                Task {
                    let granted = await CalendarService.shared.requestAccess()
                    await MainActor.run {
                        calendarSyncEnabled = granted
                        CalendarService.shared.promptShown = true
                        // Add whichever item triggered the prompt
                        if granted, let memory = pendingCalendarMemory {
                            CalendarService.shared.addMemory(memory)
                        }
                        pendingCalendarMemory = nil
                    }
                }
            }
            Button("Not Now", role: .cancel) {
                CalendarService.shared.promptShown = true
                pendingCalendarMemory = nil
            }
        } message: {
            Text("Orca can automatically add memories and shared events with dates to your iPhone Calendar — so they show up in Siri, your lock screen, and Calendar.app.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .calendarSyncCheck)) { notification in
            if !CalendarService.shared.promptShown {
                // First time — show the one-time prompt regardless of source
                pendingCalendarMemory = notification.object as? Memory
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    showCalendarPrompt = true
                }
            } else if calendarSyncEnabled, let memory = notification.object as? Memory {
                // Already opted in — check recurrence
                let recurrenceRaw = (notification.userInfo?["recurrence"] as? String) ?? "none"
                let recurrence = Ping.Recurrence(rawValue: recurrenceRaw) ?? .none
                if CalendarService.shared.shouldAutoSync(memory: memory, recurrence: recurrence) {
                    CalendarService.shared.addMemory(memory)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openDropOverlay))      { _ in showDrop = true }
        .onReceive(NotificationCenter.default.publisher(for: .openTypeCapture))      { _ in showTyped = true }
        .onReceive(NotificationCenter.default.publisher(for: .openScreenshotCapture)){ _ in showScreenshot = true }
        .onReceive(NotificationCenter.default.publisher(for: .groceryModeHint)) { _ in
            toastMessage = "🛒 Recipe saved! Try Grocery Mode in your Cooking echo."
            withAnimation(.spring(duration: 0.4)) { showToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation(.easeOut(duration: 0.4)) { showToast = false }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .inviteAccepted)) { _ in
            toastMessage = "🤝 You joined a Shared Space!"
            withAnimation(.spring(duration: 0.4)) { showToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation(.easeOut(duration: 0.4)) { showToast = false }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .recipeImport)) { notification in
            let ctx = modelContext
            let currentEchos = echos

            // Inline payload (OCR/manual recipe shared as base64 JSON)
            if let base64 = notification.userInfo?["data"] as? String,
               let payload = SharedRecipePayload.from(base64: base64) {
                toastMessage = "🍽️ Adding recipe…"
                withAnimation(.spring(duration: 0.4)) { showToast = true }
                let title = RecipeImportService.shared.importAndSave(from: payload, modelContext: ctx, echos: currentEchos)
                toastMessage = title != nil ? "🍽️ \"\(title!)\" added to Cooking!" : "Couldn't import recipe."
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    withAnimation(.easeOut(duration: 0.4)) { showToast = false }
                }
                return
            }

            // URL-based recipe (original flow)
            guard let urlString = notification.userInfo?["url"] as? String else { return }
            Task {
                toastMessage = "🍽️ Importing recipe…"
                withAnimation(.spring(duration: 0.4)) { showToast = true }
                if let title = await RecipeImportService.shared.importAndSave(from: urlString, modelContext: ctx, echos: currentEchos) {
                    await MainActor.run {
                        toastMessage = "🍽️ \"\(title)\" added to Cooking!"
                    }
                } else {
                    await MainActor.run {
                        toastMessage = "Couldn't import recipe. Check the link."
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    withAnimation(.easeOut(duration: 0.4)) { showToast = false }
                }
            }
        }
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabBarItem(icon: "checkmark.circle", label: "Planner", tag: 0)
            tabBarItem(icon: "house.fill", label: "Home", tag: 1)

            // Center capture button
            Button {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                withAnimation(.spring(duration: 0.3)) { showDrawer = true }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.oceanTeal)
                        .frame(width: 56, height: 56)
                        .shadow(color: .oceanTeal.opacity(0.4), radius: 10, y: 4)

                    // Sonar rings + mic icon
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.28), lineWidth: 1)
                            .frame(width: 46, height: 46)
                            .offset(y: -2)
                        Circle()
                            .stroke(Color.white.opacity(0.55), lineWidth: 1.5)
                            .frame(width: 30, height: 30)
                            .offset(y: -2)
                        Circle()
                            .stroke(Color.white.opacity(0.95), lineWidth: 2.2)
                            .frame(width: 14, height: 14)
                            .offset(y: -2)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 7, height: 7)
                            .offset(y: -2)
                        Rectangle()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: 2, height: 10)
                            .clipShape(Capsule())
                            .offset(y: 12)
                        Rectangle()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: 14, height: 2)
                            .clipShape(Capsule())
                            .offset(y: 17)
                    }
                }
                .offset(y: -14)
            }
            .frame(maxWidth: .infinity)

            tabBarItem(icon: "person.2.fill", label: "People", tag: 2)
            tabBarItem(icon: "calendar", label: "Calendar", tag: 3)
        }
        .frame(height: 49)
        .background(
            Color.white
                .shadow(color: .black.opacity(0.08), radius: 8, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(
            Divider().frame(maxWidth: .infinity),
            alignment: .top
        )
        .zIndex(0)
    }

    private func tabBarItem(icon: String, label: String, tag: Int) -> some View {
        Button {
            if tag == selectedTab {
                if tag == 0 { NotificationCenter.default.post(name: .resetToToday, object: nil) }
                if tag == 1 { resetDashboardTrigger.toggle() }
            }
            selectedTab = tag
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(selectedTab == tag ? .oceanTeal : .gray.opacity(0.6))
                Text(label)
                    .font(.custom("DMSans-Regular", size: 10))
                    .foregroundColor(selectedTab == tag ? .oceanTeal : .gray.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Memory.self, Echo.self, Ping.self, Person.self, GiftItem.self, TCGCard.self], inMemory: true)
        .environment(AuthService())
}
