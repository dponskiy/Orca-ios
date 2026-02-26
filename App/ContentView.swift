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
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem {
                        Image(systemName: "circle.grid.2x2.fill")
                        Text("Dashboard")
                    }
                    .tag(0)
                
                SearchView()
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("Search")
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
                DropButton {
                    showDrop = true
                }
                .padding(.bottom, 28)
            }
        }
        .fullScreenCover(isPresented: $showDrop) {
            DropOverlayView(isPresented: $showDrop)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Memory.self, Echo.self, Ping.self], inMemory: true)
}

