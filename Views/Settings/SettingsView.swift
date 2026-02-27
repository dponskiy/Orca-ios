//
//  SettingsView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
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
                }
                
                Section("Preferences") {
                    Label("Notifications", systemImage: "bell")
                    Label("Manage Echos", systemImage: "circle.grid.2x2")
                }
                
                Section("About") {
                    Link(destination: URL(string: "https://orcadrop.app/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    Link(destination: URL(string: "https://orcadrop.app/terms")!) {
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
}

#Preview {
    SettingsView()
}
