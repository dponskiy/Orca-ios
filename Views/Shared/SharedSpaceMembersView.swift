//
//  SharedSpaceMembersView.swift
//  Orca
//
//  Who's in a household, and the controls for managing them. Names live on the
//  membership row rather than the account, so you can be "Dad" here and "David"
//  everywhere else. You name yourself when you join; the owner can rename anyone,
//  which is what stops a household from staring at four email addresses.
//

import SwiftUI
import SwiftData

struct SharedSpaceMembersView: View {
    let space: SharedSpace

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Query private var allMembers: [SharedSpaceMember]

    @State private var renamingMember: SharedSpaceMember? = nil
    @State private var nameDraft = ""
    @State private var showRename = false
    @State private var memberToRemove: SharedSpaceMember? = nil
    @State private var showRemoveConfirm = false
    @State private var isRegenerating = false
    @State private var shareURL: URL? = nil
    @State private var showShare = false
    @State private var errorMessage: String? = nil
    @State private var showRenameSpace = false
    @State private var spaceNameDraft = ""

    private let memberCap = SharedSpaceMember.cap

    private var members: [SharedSpaceMember] {
        allMembers
            .filter { $0.spaceId == space.id }
            .sorted { ($0.isOwner ? 0 : 1, $0.joinedAt) < ($1.isOwner ? 0 : 1, $1.joinedAt) }
    }

    private var myUserId: String { authService.userId?.uuidString ?? "" }
    private var iAmOwner: Bool {
        members.first { $0.userId == myUserId }?.isOwner
            ?? (space.createdByUserId == myUserId)
    }
    private var isFull: Bool { members.count >= memberCap }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    nameCard
                    membersCard
                    if !isFull { inviteCard } else { fullNotice }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.custom("DMSans-Regular", size: 12))
                            .foregroundColor(.coral)
                    }
                    Spacer().frame(height: 30)
                }
                .padding(20)
            }
            .background(Color.pearl.ignoresSafeArea())
            .navigationTitle("Household")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.oceanTeal)
                }
            }
            .alert("Name this household", isPresented: $showRenameSpace) {
                TextField("Name", text: $spaceNameDraft)
                Button("Save") { saveSpaceName() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Everyone in the space sees this name.")
            }
            .alert("What should we call you?", isPresented: $showRename) {
                TextField("Name", text: $nameDraft)
                Button("Save") { saveName() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This is how you'll appear in \(spaceLabel).")
            }
            .confirmationDialog(
                "Remove \(memberToRemove.map(displayName) ?? "this person")?",
                isPresented: $showRemoveConfirm, titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) { removeMember() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("They'll lose access to this space. They can rejoin with a new invite link.")
            }
            .sheet(isPresented: $showShare) {
                if let shareURL { ShareSheet(items: [shareURL]) }
            }
        }
    }

    private var spaceLabel: String {
        space.spaceName.isEmpty ? "this space" : space.spaceName
    }

    private func displayName(_ member: SharedSpaceMember) -> String {
        if !member.displayName.isEmpty { return member.displayName }
        if member.userId == myUserId { return "You" }
        return "Member"
    }

    // MARK: - Household name

    private var nameCard: some View {
        Button {
            spaceNameDraft = space.spaceName
            showRenameSpace = true
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("HOUSEHOLD NAME")
                        .font(.custom("DMSans-Medium", size: 11))
                        .foregroundColor(.gray).tracking(0.5)
                    Text(space.spaceName.isEmpty ? "Unnamed" : space.spaceName)
                        .font(.custom("DMSans-Medium", size: 16))
                        .foregroundColor(space.spaceName.isEmpty ? .gray : .deepNavy)
                }
                Spacer()
                Image(systemName: "pencil")
                    .font(.system(size: 13)).foregroundColor(.gray.opacity(0.4))
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func saveSpaceName() {
        let trimmed = spaceNameDraft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        space.spaceName = trimmed
        try? modelContext.save()
        Task {
            do { try await SharedSpaceSyncService.shared.renameSpace(space, to: trimmed) }
            catch { await MainActor.run { errorMessage = "Couldn't save that name. It'll retry on next sync." } }
        }
    }

    // MARK: - Members

    private var membersCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(members.count) of \(memberCap)")
                    .font(.custom("DMMono-Regular", size: 12))
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)

            ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                if index > 0 { Divider().padding(.leading, 60) }
                memberRow(member)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    private func memberRow(_ member: SharedSpaceMember) -> some View {
        let isMe = member.userId == myUserId
        let unnamed = member.displayName.isEmpty
        // You can always rename yourself; the owner can tidy up anyone
        let canRename = isMe || iAmOwner

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(member.isOwner ? Color.oceanTeal.opacity(0.12) : Color.mist)
                    .frame(width: 36, height: 36)
                Text(initials(for: member))
                    .font(.custom("DMSans-Medium", size: 13))
                    .foregroundColor(member.isOwner ? .oceanTeal : .gray)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(displayName(member))
                        .font(.custom("DMSans-Medium", size: 15))
                        .foregroundColor(unnamed ? .gray : .deepNavy)
                    if member.isOwner {
                        Text("Owner")
                            .font(.custom("DMSans-Regular", size: 10))
                            .foregroundColor(.oceanTeal)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.oceanTeal.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    if isMe && !member.isOwner {
                        Text("You")
                            .font(.custom("DMSans-Regular", size: 10))
                            .foregroundColor(.gray)
                    }
                }
                if unnamed && canRename {
                    Text("Tap to add a name")
                        .font(.custom("DMSans-Regular", size: 11))
                        .foregroundColor(.oceanTeal)
                }
            }

            Spacer()

            if canRename {
                Image(systemName: "pencil")
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.4))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            guard canRename else { return }
            renamingMember = member
            nameDraft = member.displayName
            showRename = true
        }
        .contextMenu {
            if canRename {
                Button {
                    renamingMember = member
                    nameDraft = member.displayName
                    showRename = true
                } label: { Label("Rename", systemImage: "pencil") }
            }
            // The owner can't remove themselves — that would orphan the space
            if iAmOwner && !member.isOwner {
                Button(role: .destructive) {
                    memberToRemove = member
                    showRemoveConfirm = true
                } label: { Label("Remove", systemImage: "person.badge.minus") }
            }
        }
    }

    private func initials(for member: SharedSpaceMember) -> String {
        let source = member.displayName.isEmpty ? "?" : member.displayName
        let parts = source.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)).uppercased() }.joined()
    }

    // MARK: - Invite

    private var inviteCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INVITE")
                .font(.custom("DMSans-Medium", size: 11))
                .foregroundColor(.gray).tracking(0.5)

            Text("Anyone with this link can join, up to \(memberCap) people. Send it by text or however you like.")
                .font(.custom("DMSans-Regular", size: 13))
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                guard let token = space.inviteToken else { return }
                shareURL = URL(string: "https://links.orcadrop.app/invite/\(token)")
                showShare = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share invite link").font(.custom("DMSans-Medium", size: 15))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(Color.oceanTeal)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if iAmOwner {
                Button {
                    regenerate()
                } label: {
                    HStack(spacing: 7) {
                        if isRegenerating {
                            ProgressView().scaleEffect(0.7).tint(.oceanTeal)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 12))
                        }
                        Text("Create a new link").font(.custom("DMSans-Medium", size: 13))
                    }
                    .foregroundColor(.oceanTeal)
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(Color.oceanTeal.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isRegenerating)

                Text("Makes the old link stop working — use this if it was forwarded to someone who shouldn't have it.")
                    .font(.custom("DMSans-Regular", size: 11))
                    .foregroundColor(.gray.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    private var fullNotice: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.3.fill").font(.system(size: 14)).foregroundColor(.gray)
            Text("This space is full (\(memberCap) people). Remove someone to invite another.")
                .font(.custom("DMSans-Regular", size: 12))
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.mist.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private func saveName() {
        guard let member = renamingMember else { return }
        let trimmed = nameDraft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        member.displayName = trimmed
        try? modelContext.save()
        Task {
            do { try await SharedSpaceSyncService.shared.setDisplayName(trimmed, memberId: member.id) }
            catch { await MainActor.run { errorMessage = "Couldn't save that name. It'll retry on next sync." } }
        }
    }

    private func removeMember() {
        guard let member = memberToRemove else { return }
        Task {
            do { try await SharedSpaceSyncService.shared.removeMember(member) }
            catch { await MainActor.run { errorMessage = "Couldn't remove them. Try again." } }
        }
    }

    private func regenerate() {
        isRegenerating = true
        Task {
            do {
                _ = try await SharedSpaceSyncService.shared.regenerateInviteToken(for: space)
                await MainActor.run { isRegenerating = false; errorMessage = nil }
            } catch {
                await MainActor.run { isRegenerating = false; errorMessage = "Couldn't create a new link." }
            }
        }
    }
}
