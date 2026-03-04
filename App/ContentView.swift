//
//  ContentView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/24/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showDrop = false
    @State private var showDrawer = false
    @State private var showTyped = false
    @State private var showSearch = false
    @State private var showScreenshot = false
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                DashboardView(showSearch: $showSearch)
                    .tabItem {
                        Image(systemName: "circle.grid.2x2.fill")
                        Text("Dashboard")
                    }
                    .tag(0)
                
                TodayView()
                    .tabItem {
                        Image(systemName: "checkmark.circle")
                        Text("Today")
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
                    
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.oceanTeal.opacity(0.8))
                        .phaseAnimator([0.4, 0.8]) { view, opacity in
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
                            }
                        },
                        onCancel: { showDrawer = false }
                    )
                }
                .transition(.move(edge: .bottom))
            }
        }
        .animation(.spring(duration: 0.3), value: showDrawer)
        .fullScreenCover(isPresented: $showDrop) {
            DropOverlayView(isPresented: $showDrop)
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
