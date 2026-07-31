//
//  InvitePartnerView.swift
//  Orca
//

import SwiftUI

struct InvitePartnerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService

    @State private var spaceName = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var inviteURL: URL? = nil
    @State private var showShareSheet = false

    var onCreated: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 24) {

                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.oceanTeal.opacity(0.1))
                            .frame(width: 72, height: 72)
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.oceanTeal)
                    }
                    .padding(.top, 32)

                    VStack(spacing: 8) {
                        Text("Invite someone")
                            .font(.custom("DMSans-Medium", size: 22))
                            .foregroundColor(.deepNavy)
                        Text("Give the space a name, then share the invite link via iMessage, WhatsApp, or any app.")
                            .font(.custom("DMSans-Regular", size: 14))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Space name")
                            .font(.custom("DMSans-Medium", size: 13))
                            .foregroundColor(.deepNavy)
                        TextField("e.g. Jake, Family, Roommates", text: $spaceName)
                            .font(.custom("DMSans-Regular", size: 16))
                            .autocorrectionDisabled()
                            .padding(14)
                            .background(Color.mist)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.custom("DMSans-Regular", size: 13))
                            .foregroundColor(.red.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }

                    Button(action: createAndShare) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "link.badge.plus")
                                    .font(.system(size: 15, weight: .medium))
                                Text("Create Invite Link")
                                    .font(.custom("DMSans-Medium", size: 16))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isLoading || spaceName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.3) : Color.oceanTeal)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .oceanTeal.opacity(0.3), radius: 8, y: 3)
                    }
                    .disabled(isLoading || spaceName.trimmingCharacters(in: .whitespaces).isEmpty)

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .background(Color.pearl)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.gray)
                }
            }
        }
        .presentationDetents([.medium])
        .sheet(isPresented: $showShareSheet, onDismiss: {
            if inviteURL != nil {
                onCreated?()
                dismiss()
            }
        }) {
            if let url = inviteURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func createAndShare() {
        guard let userId = authService.userId else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let space = try await SharedSpaceSyncService.shared.createSpace(
                    name: spaceName.trimmingCharacters(in: .whitespaces),
                    userId: userId
                )
                await MainActor.run {
                    isLoading = false
                    if let token = space.inviteToken {
                        inviteURL = URL(string: "https://links.orcadrop.app/invite/\(token)")
                        showShareSheet = true
                    } else {
                        onCreated?()
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Something went wrong. Please try again."
                }
            }
        }
    }
}

