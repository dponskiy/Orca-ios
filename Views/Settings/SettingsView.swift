//
//  SettingsView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

//
//  SettingsView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasSkippedAuth") private var hasSkippedAuth = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    
    @Query private var memories: [Memory]
    @State private var showManageEchos = false
    @State private var showClearConfirm = false
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Account
                Section("Account") {
                    if authService.isAuthenticated {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.oceanTeal)
                                    .frame(width: 44, height: 44)
                                Text(initials)
                                    .font(.custom("DMSans-Medium", size: 16))
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(authService.displayName ?? "Orca User")
                                    .font(.custom("DMSans-Medium", size: 16))
                                    .foregroundColor(.deepNavy)
                                Text(authService.userEmail ?? "Signed in with Apple")
                                    .font(.custom("DMSans-Regular", size: 13))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        Button {
                            Task {
                                await authService.signOut()
                                hasSkippedAuth = false
                            }
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.coral)
                        }
                    } else {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.mist)
                                    .frame(width: 44, height: 44)
                                Image(systemName: "person.fill")
                                    .foregroundColor(.oceanTeal)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sign in")
                                    .font(.custom("DMSans-Medium", size: 16))
                                    .foregroundColor(.deepNavy)
                                Text("Sync your memories across devices")
                                    .font(.custom("DMSans-Regular", size: 13))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                        .onTapGesture {
                            hasSkippedAuth = false
                        }
                    }
                }
                
                // MARK: - Preferences
                Section("Preferences") {
                    Button {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Notifications", systemImage: "bell")
                            .foregroundColor(.deepNavy)
                    }
                    
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }

                    } label: {
                        Label("Set as Action Button", systemImage: "button.angledtop.vertical.right")
                            .foregroundColor(.deepNavy)
                    }
                    
                    Button {
                        showManageEchos = true
                    } label: {
                        Label("Manage Echos", systemImage: "circle.grid.2x2")
                            .foregroundColor(.deepNavy)
                    }
                }
                
                // MARK: - Support
                Section("Support") {
                    Button {
                        hasCompletedOnboarding = false
                        AnalyticsService.shared.trackOnboardingReplayed()
                    } label: {
                        Label("Replay Onboarding", systemImage: "arrow.counterclockwise")
                            .foregroundColor(.deepNavy)
                    }
                    
                    Button {
                        AnalyticsService.shared.trackAppRated()
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            AppStore.requestReview(in: scene)
                        }
                    } label: {
                        Label("Rate Orca", systemImage: "star")
                            .foregroundColor(.deepNavy)
                    }
                    
                    Button {
                        AnalyticsService.shared.trackFeedbackSent()
                        if let url = URL(string: "mailto:support@orca.app?subject=Orca%20Feedback") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Send Feedback", systemImage: "envelope")
                            .foregroundColor(.deepNavy)
                    }
                }
                
                // MARK: - About
                Section("About") {
                    Link(destination: URL(string: Config.privacyURL)!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    Link(destination: URL(string: Config.termsURL)!) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                }
                
                // MARK: - Danger Zone
                Section("Data") {
                    Button {
                        showClearConfirm = true
                    } label: {
                        Label("Clear All Memories", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
                
                // MARK: - Version
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            FinIcon()
                                .fill(Color.seafoam.opacity(0.4))
                                .frame(width: 24, height: 28)
                            Text("Orca v1.0")
                                .font(.custom("DMMono-Regular", size: 12))
                                .foregroundColor(.gray)
                            Text("\(memories.count) memories saved")
                                .font(.custom("DMMono-Regular", size: 11))
                                .foregroundColor(.gray.opacity(0.7))
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Settings")
            .navigationDestination(isPresented: $showManageEchos) {
                ManageEchosView()
            }
            .confirmationDialog(
                "Clear all memories?",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    clearAllMemories()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all \(memories.count) memories. This cannot be undone.")
            }
        }
    }
    
    private var initials: String {
        guard let name = authService.displayName else { return "O" }
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? "O"
        let last = parts.count > 1 ? parts.last?.prefix(1) ?? "" : ""
        return "\(first)\(last)".uppercased()
    }
    
    private func clearAllMemories() {
        AnalyticsService.shared.trackAllMemoriesCleared(count: memories.count)
        for memory in memories {
            modelContext.delete(memory)
        }
    }
}

#Preview {
    SettingsView()
        .environment(AuthService())
}
