//
//  SettingsView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AuthService.self) private var authService
    @AppStorage("hasSkippedAuth") private var hasSkippedAuth = false
    
    var body: some View {
        NavigationStack {
            List {
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
                
                Section("Preferences") {
                    Label("Notifications", systemImage: "bell")
                    Label("Manage Echos", systemImage: "circle.grid.2x2")
                }
                
                Section("About") {
                    Link(destination: URL(string: Config.privacyURL)!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    Link(destination: URL(string: Config.termsURL)!) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                }
                
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
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Settings")
        }
    }
    
    private var initials: String {
        guard let name = authService.displayName else { return "O" }
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? "O"
        let last = parts.count > 1 ? parts.last?.prefix(1) ?? "" : ""
        return "\(first)\(last)".uppercased()
    }
}

#Preview {
    SettingsView()
        .environment(AuthService())
}
