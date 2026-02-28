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
    
    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated || hasSkippedAuth {
                ContentView()
                    .environment(authService)
            } else {
                AuthView(authService: authService) {
                    hasSkippedAuth = true
                }
            }
        }
        .modelContainer(for: [Memory.self, Echo.self, Ping.self])
    }
}
