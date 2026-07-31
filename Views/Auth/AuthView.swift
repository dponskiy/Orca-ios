//
//  AuthView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/27/26.
//

import SwiftUI
import AuthenticationServices

struct AuthView: View {
    let authService: AuthService
    var onSkip: () -> Void
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.deepNavy, Color(hex: "1A2A44")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Logo
                VStack(spacing: 16) {
                    
                    Text("Orca")
                        .font(.custom("InstrumentSerif-Regular", size: 40))
                        .foregroundColor(.white)
                    
                    Text("Your memory, surfaced.")
                        .font(.custom("DMSans-Regular", size: 16))
                        .foregroundColor(.white.opacity(0.6))
                }
                // Features
                VStack(alignment: .leading, spacing: 16) {
                    featureRow(icon: "mic.fill", text: "Drop memories in seconds")
                    featureRow(icon: "waveform", text: "Sonar sorts them automatically")
                    featureRow(icon: "bell.fill", text: "Pings remind you at the right time")
                    featureRow(icon: "checkmark.circle.fill", text: "Track tasks without the overhead")
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Sign In with Apple
                VStack(spacing: 16) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        switch result {
                        case .success(let auth):
                            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                                Task {
                                    await authService.signInWithApple(credential: credential)
                                }
                            }
                        case .failure(let error):
                            print("Apple sign in failed: \(error)")
                        }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    
                    Text("Reminders, sync, and the full Orca experience require an account. Sign in takes 3 seconds.")
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundColor(.white.opacity(0.3))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.oceanTeal)
                .frame(width: 24)
            
            Text(text)
                .font(.custom("DMSans-Regular", size: 15))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

#Preview {
    AuthView(authService: AuthService(), onSkip: { })
}
