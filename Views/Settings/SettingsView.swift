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
    @Query private var pings: [Ping]
    @State private var showManageEchos = false
    @State private var showClearConfirm = false
    @State private var showClearConfirmFinal = false
    @State private var showCleanUpSheet = false
    @State private var showDeleteAccountConfirm = false
    @State private var showDeleteAccountFinal = false
    @State private var isDeletingAccount = false

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

                        Button {
                            showDeleteAccountConfirm = true
                        } label: {
                            if isDeletingAccount {
                                HStack(spacing: 8) {
                                    ProgressView().scaleEffect(0.8).tint(.red)
                                    Text("Deleting account...")
                                        .font(.custom("DMSans-Regular", size: 16))
                                        .foregroundColor(.red)
                                }
                            } else {
                                Label("Delete Account", systemImage: "person.crop.circle.badge.minus")
                                    .foregroundColor(.red)
                            }
                        }
                        .disabled(isDeletingAccount)

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
                        if let url = URL(string: "mailto:support@orcadrop.app?subject=Orca%20Feedback") {
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

                // MARK: - Data
                Section("Data") {
                    Button {
                        showCleanUpSheet = true
                    } label: {
                        Label("Clean Up Old Tasks", systemImage: "sparkles.rectangle.stack")
                            .foregroundColor(.deepNavy)
                    }

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
            .sheet(isPresented: $showCleanUpSheet) {
                CleanUpSheet(memories: memories, pings: pings) { toDelete in
                    for memory in toDelete {
                        let id = memory.id
                        let memoryPings = pings.filter { $0.memoryId == memory.id }
                        for ping in memoryPings {
                            NotificationService.shared.cancelPing(pingId: ping.id)
                            modelContext.delete(ping)
                        }
                        modelContext.delete(memory)
                        SpotlightService.shared.removeMemory(id: memory.id)
                        Task {
                            await SupabaseSyncService.shared.deleteMemory(id: id)
                        }
                    }
                }
            }
            // Clear all memories — first confirmation
            .alert("Clear all memories?", isPresented: $showClearConfirm) {
                Button("Clear All", role: .destructive) { showClearConfirmFinal = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all \(memories.count) memories. This cannot be undone.")
            }
            // Clear all memories — second confirmation
            .alert("Are you sure?", isPresented: $showClearConfirmFinal) {
                Button("Clear All", role: .destructive) { clearAllMemories() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All \(memories.count) memories will be gone forever.")
            }
            // Delete account — first confirmation
            .alert("Delete your account?", isPresented: $showDeleteAccountConfirm) {
                Button("Delete Account", role: .destructive) { showDeleteAccountFinal = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your account and all \(memories.count) memories. This cannot be undone.")
            }
            // Delete account — second confirmation
            .alert("Are you absolutely sure?", isPresented: $showDeleteAccountFinal) {
                Button("Yes, Delete Everything", role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your account, all memories, and all data will be permanently removed from our servers within 30 days.")
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
            let id = memory.id
            let memoryPings = pings.filter { $0.memoryId == memory.id }
            for ping in memoryPings {
                NotificationService.shared.cancelPing(pingId: ping.id)
                modelContext.delete(ping)
            }
            modelContext.delete(memory)
            SpotlightService.shared.removeMemory(id: id)
            Task {
                await SupabaseSyncService.shared.deleteMemory(id: id)
            }
        }
    }

    private func deleteAccount() async {
        isDeletingAccount = true

        // 1. Cancel all notifications
        for ping in pings {
            NotificationService.shared.cancelPing(pingId: ping.id)
        }

        // 2. Delete all memories from Supabase
        for memory in memories {
            await SupabaseSyncService.shared.deleteMemory(id: memory.id)
            SpotlightService.shared.removeMemory(id: memory.id)
        }

        // 3. Delete local SwiftData
        for ping in pings { modelContext.delete(ping) }
        for memory in memories { modelContext.delete(memory) }

        // 4. Delete Supabase account
        await authService.deleteAccount()

        // 5. Reset app state
        await MainActor.run {
            isDeletingAccount = false
            hasSkippedAuth = false
            hasCompletedOnboarding = false
            UserDefaults.standard.removeObject(forKey: "orcaDidSeedDefaults")
        }
    }

    // MARK: - Clean Up Sheet

    struct CleanUpSheet: View {
        let memories: [Memory]
        let pings: [Ping]
        let onConfirm: ([Memory]) -> Void

        @Environment(\.dismiss) private var dismiss
        @State private var deselected: Set<UUID> = []

        private var candidates: [Memory] {
            let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            return memories.filter { memory in
                guard memory.isActionable else { return false }
                guard !memory.isPinned else { return false }
                guard !memory.hasChecklist else { return false }
                guard memory.url == nil || memory.url?.isEmpty == true else { return false }
                let hasRecurringPing = pings.contains { $0.memoryId == memory.id && $0.recurrence != .none }
                guard !hasRecurringPing else { return false }
                if memory.isCompleted, let completedAt = memory.completedAt {
                    return completedAt < cutoff
                }
                if let detectedDate = memory.detectedDate {
                    return detectedDate < cutoff
                }
                return false
            }
            .sorted { ($0.completedAt ?? $0.detectedDate ?? $0.createdAt) < ($1.completedAt ?? $1.detectedDate ?? $1.createdAt) }
        }

        private var toDelete: [Memory] {
            candidates.filter { !deselected.contains($0.id) }
        }

        var body: some View {
            NavigationStack {
                Group {
                    if candidates.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "sparkles")
                                .font(.system(size: 44))
                                .foregroundColor(.seafoam.opacity(0.5))
                            Text("All clean!")
                                .font(.custom("DMSans-Medium", size: 20))
                                .foregroundColor(.deepNavy)
                            Text("No completed tasks older than 30 days.")
                                .font(.custom("DMSans-Regular", size: 14))
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        List {
                            Section {
                                Text("Uncheck any tasks you want to keep. Everything else will be removed.")
                                    .font(.custom("DMSans-Regular", size: 13))
                                    .foregroundColor(.gray)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }

                            ForEach(candidates) { memory in
                                let isSelected = !deselected.contains(memory.id)
                                HStack(spacing: 12) {
                                    Button {
                                        if deselected.contains(memory.id) {
                                            deselected.remove(memory.id)
                                        } else {
                                            deselected.insert(memory.id)
                                        }
                                    } label: {
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 22))
                                            .foregroundColor(isSelected ? .coral : .gray.opacity(0.4))
                                    }
                                    .buttonStyle(.plain)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(memory.text)
                                            .font(.custom("DMSans-Regular", size: 15))
                                            .foregroundColor(isSelected ? .deepNavy : .gray)
                                            .strikethrough(isSelected)
                                            .lineLimit(2)

                                        if let date = memory.completedAt ?? memory.detectedDate {
                                            Text(date, format: .dateTime.month(.abbreviated).day().year())
                                                .font(.custom("DMMono-Regular", size: 12))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .navigationTitle("Clean Up")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .foregroundColor(.gray)
                    }

                    if !candidates.isEmpty {
                        ToolbarItem(placement: .confirmationAction) {
                            Button {
                                onConfirm(toDelete)
                                dismiss()
                            } label: {
                                Text("Remove \(toDelete.count)")
                                    .font(.custom("DMSans-Medium", size: 15))
                                    .foregroundColor(toDelete.isEmpty ? .gray : .coral)
                            }
                            .disabled(toDelete.isEmpty)
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

#Preview {
    SettingsView()
        .environment(AuthService())
}
