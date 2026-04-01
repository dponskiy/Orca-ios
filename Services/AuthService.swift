//
//  AuthService.swift
//  Orca
//
//  Created by David Piliponskiy on 2/24/26.
//

import Foundation
import AuthenticationServices
import SwiftUI
import Supabase

@Observable
class AuthService {
    var isAuthenticated = false
    var userId: UUID?
    var userEmail: String?
    var displayName: String?
    var isLoading = false

    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    init() {
        Task {
            await checkSession()
        }
    }

    // MARK: - Check Existing Session

    func checkSession() async {
        do {
            let session = try await supabase.auth.session
            await MainActor.run {
                self.userId = session.user.id
                self.userEmail = session.user.email
                self.isAuthenticated = true
            }
        } catch {
            await MainActor.run {
                self.isAuthenticated = false
            }
        }
    }

    // MARK: - Apple Sign In

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async {
        await MainActor.run { isLoading = true }

        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            await MainActor.run { isLoading = false }
            return
        }

        do {
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: tokenString
                )
            )

            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            await MainActor.run {
                self.userId = session.user.id
                self.userEmail = session.user.email
                self.displayName = name.isEmpty ? nil : name
                self.isAuthenticated = true
                self.isLoading = false
            }

            // Upsert user record
            do {
                try await supabase
                    .from("users")
                    .upsert([
                        "id": session.user.id.uuidString,
                        "email": session.user.email ?? "",
                        "display_name": name.isEmpty ? "" : name,
                        "updated_at": ISO8601DateFormatter().string(from: Date())
                    ])
                    .execute()
            } catch {
                print("⚠️ User upsert failed: \(error)")
            }

        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        do {
            try await supabase.auth.signOut()
            await MainActor.run {
                self.isAuthenticated = false
                self.userId = nil
                self.userEmail = nil
                self.displayName = nil
            }
        } catch {
            print("❌ Sign out error: \(error)")
        }
    }

    // MARK: - Delete Account

    func deleteAccount() async {
        guard let userId = userId else { return }
        do {
            try await supabase.from("pings").delete().eq("user_id", value: userId.uuidString).execute()
            try await supabase.from("memories").delete().eq("user_id", value: userId.uuidString).execute()
            try await supabase.from("persons").delete().eq("user_id", value: userId.uuidString).execute()
            try await supabase.from("gift_items").delete().eq("user_id", value: userId.uuidString).execute()
            try await supabase.from("echos").delete().eq("user_id", value: userId.uuidString).execute()
            try await supabase.from("users").delete().eq("id", value: userId.uuidString).execute()
        } catch {
            print("❌ Error deleting user data: \(error)")
        }
        await signOut()
    }
}
