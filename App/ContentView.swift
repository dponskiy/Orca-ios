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
    @State private var showDrop = false
    @State private var showDrawer = false
    @State private var showTyped = false
    @State private var showSearch = false
    @State private var showScreenshot = false
    @State private var showToast = false
    @State private var showRecipe = false
    @State private var toastMessage = ""
    
    var body: some View {
        ZStack {
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
                    .tabItem {
                        Image(systemName: "checkmark.circle")
                        Text("Today")
                    }
                    .tag(0)
                
                DashboardView(showSearch: $showSearch)
                    .tabItem {
                        Image(systemName: "circle.grid.2x2.fill")
                        Text("Dashboard")
                    }
                    .tag(1)
                
                CalendarTabView()
                    .tabItem {
                        Image(systemName: "calendar")
                        Text("Calendar")
                    }
                    .tag(2)
            }
            .tint(.oceanTeal)
            
            // Drop button (FAB)
            VStack {
                Spacer()
                VStack(spacing: 4) {
                    DropButton {
                        showDrop = true
                    } onLongPress: {
                        showDrawer = true
                    }
                    
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .semibold))
                        Text("swipe up")
                            .font(.custom("DMSans-Medium", size: 11))
                    }
                    .foregroundColor(.oceanTeal)
                    .phaseAnimator([0.5, 1.0]) { view, opacity in
                        view.opacity(opacity)
                    } animation: { _ in
                        .easeInOut(duration: 1.2)
                    }
                }
                .padding(.bottom, 70)
            }
            
            // Capture drawer
            if showDrawer {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { showDrawer = false }
                
                VStack {
                    Spacer()
                    CaptureDrawerView(
                        onSelect: { mode in
                            showDrawer = false
                            switch mode {
                            case .voice: showDrop = true
                            case .typed: showTyped = true
                            case .screenshot: showScreenshot = true
                            case .recipe: showRecipe = true
                            }
                        },
                        onCancel: { showDrawer = false }
                    )
                }
                .transition(.move(edge: .bottom))
            }
            
            // Toast
            if showToast {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.oceanTeal)
                        Text(toastMessage)
                            .font(.custom("DMSans-Medium", size: 15))
                            .foregroundColor(.deepNavy)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(duration: 0.3), value: showDrawer)
        .fullScreenCover(isPresented: $showDrop) {
            DropOverlayView(isPresented: $showDrop) { message in
                toastMessage = message
                withAnimation(.spring(duration: 0.4)) {
                    showToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        showToast = false
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showRecipe) {
            RecipeCaptureView(isPresented: $showRecipe) { message in
                toastMessage = message
                withAnimation(.spring(duration: 0.4)) {
                    showToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        showToast = false
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showTyped) {
            TypeCaptureView(isPresented: $showTyped)
        }
        .fullScreenCover(isPresented: $showScreenshot) {
            PhotoCaptureView(isPresented: $showScreenshot)
        }
        .fullScreenCover(isPresented: $showSearch) {
            SearchView(isPresented: $showSearch)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openDropOverlay)) { _ in
            showDrop = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openTypeCapture)) { _ in
            showTyped = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openScreenshotCapture)) { _ in
            showScreenshot = true
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Memory.self, Echo.self, Ping.self], inMemory: true)
        .environment(AuthService())
}
