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
        print("🔍 Checking existing session...")
        do {
            let session = try await supabase.auth.session
            print("✅ Found existing session for user: \(session.user.id)")
            await MainActor.run {
                self.userId = session.user.id
                self.userEmail = session.user.email
                self.isAuthenticated = true
            }
        } catch {
            print("⚠️ No existing session: \(error.localizedDescription)")
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
            print("❌ No identity token from Apple")
            await MainActor.run { isLoading = false }
            return
        }
        
        print("✅ Got Apple token, sending to Supabase...")
        print("🔑 Token prefix: \(String(tokenString.prefix(50)))...")
        print("🌐 Supabase URL: \(Config.supabaseURL)")
        
        do {
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: tokenString
                )
            )
            
            print("✅ Supabase session created for user: \(session.user.id)")
            
            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            
            print("👤 User name: \(name.isEmpty ? "(none)" : name)")
            print("📧 User email: \(session.user.email ?? "(none)")")
            
            await MainActor.run {
                self.userId = session.user.id
                self.userEmail = session.user.email
                self.displayName = name.isEmpty ? nil : name
                self.isAuthenticated = true
                self.isLoading = false
            }
            
            print("✅ Auth state set, isAuthenticated: \(self.isAuthenticated)")
            
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
                print("✅ User record upserted")
            } catch {
                print("⚠️ User upsert failed: \(error)")
            }
                
        } catch {
            print("❌ Supabase sign in error: \(error)")
            print("❌ Error type: \(type(of: error))")
            print("❌ Error details: \(String(describing: error))")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() async {
        print("🔄 Signing out...")
        do {
            try await supabase.auth.signOut()
            await MainActor.run {
                self.isAuthenticated = false
                self.userId = nil
                self.userEmail = nil
                self.displayName = nil
            }
            print("✅ Signed out")
        } catch {
            print("❌ Sign out error: \(error)")
        }
    }
}
