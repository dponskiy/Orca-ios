
//
//  OrcaApp.swift
//  Orca
//
//  Created by David Piliponskiy on 2/24/26.
//

import SwiftUI
import SwiftData

@main
struct OrcaApp: App {
    @State private var authService = AuthService()
    @AppStorage("hasSkippedAuth") private var hasSkippedAuth = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCompletedOnboarding {
                    OnboardingFlow()
                } else if authService.isAuthenticated || hasSkippedAuth {
                    ContentView()
                        .environment(authService)
                } else {
                    AuthView(authService: authService) {
                        hasSkippedAuth = true
                    }
                }
            }
            .preferredColorScheme(.light)
            .onAppear {
                AnalyticsService.shared.initialize()
                seedNewEchosIfNeeded()
            }
        }
        .modelContainer(for: [Memory.self, Echo.self, Ping.self, SubTask.self])
    }
    
    private func seedNewEchosIfNeeded() {
        guard let container = try? ModelContainer(for: Memory.self, Echo.self, Ping.self, SubTask.self) else { return }
        let context = container.mainContext
        
        Echo.seedDefaults(context: context)
        
        let newDefaults: [(String, String, Int)] = [
            ("Birthday", "🎂", 2),
            ("Events", "🎉", 8),
            ("School", "📚", 11),
            ("Holidays", "🎄", 15),
            ("Movies", "🎬", 18),
            ("Books", "📖", 19),
        ]
        
        for (name, emoji, order) in newDefaults {
            let descriptor = FetchDescriptor<Echo>(predicate: #Predicate { echo in
                echo.name == name
            })
            let exists = (try? context.fetchCount(descriptor)) ?? 0
            if exists == 0 {
                let echo = Echo(name: name, emoji: emoji, sortOrder: order)
                context.insert(echo)
            }
        }
    }
}
