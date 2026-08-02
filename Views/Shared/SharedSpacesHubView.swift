//
//  SharedSpacesHubView.swift
//  Orca
//

import SwiftUI
import SwiftData

struct SharedSpacesHubView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService
    @Environment(\.modelContext) private var modelContext
    @Query private var allSpaces: [SharedSpace]
    @Query private var allEvents: [SharedEvent]

    @State private var showInvite = false
    @State private var spaceToDelete: SharedSpace? = nil
    @State private var showDeleteConfirm = false
    @State private var spaceToRename: SharedSpace? = nil
    @State private var renameText = ""
    @State private var showRenameAlert = false
    @AppStorage("infoBannerDismissed_sharedSpace") private var bannerDismissed = false

    private var mySpaces: [SharedSpace] {
        let userId = authService.userId?.uuidString ?? ""
        return allSpaces.filter {
            $0.createdByUserId == userId || $0.invitedUserId == userId
        }.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    if !bannerDismissed { sharedSpaceInfoBanner }

                    if mySpaces.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(mySpaces.enumerated()), id: \.element.id) { index, space in
                                if index > 0 { Divider().padding(.horizontal, 16) }
                                spaceRow(space: space)
                                    .contextMenu {
                                        Button {
                                            renameText = space.spaceName
                                            spaceToRename = space
                                            showRenameAlert = true
                                        } label: {
                                            Label("Rename", systemImage: "pencil")
                                        }
                                        Divider()
                                        Button(role: .destructive) {
                                            spaceToDelete = space
                                            showDeleteConfirm = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))

                        Text("Hold a space to rename or delete")
                            .font(.custom("DMSans-Regular", size: 12))
                            .foregroundColor(.gray.opacity(0.5))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 6)
                    }

                    Spacer().frame(height: 40)
                }
                .padding(20)
            }
            .background(Color.pearl)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.oceanTeal)
                }
                ToolbarItem(placement: .principal) {
                    Text("Shared Spaces")
                        .font(.custom("DMSans-Medium", size: 17))
                        .foregroundColor(.primary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { showInvite = true } label: {
                        Text("Create New")
                            .font(.custom("DMSans-Medium", size: 15))
                            .foregroundColor(.oceanTeal)
                    }
                }
            }
            .sheet(isPresented: $showInvite) {
                InvitePartnerView()
            }
            .confirmationDialog(
                "Delete this shared space?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let space = spaceToDelete {
                        Task { try? await SharedSpaceSyncService.shared.deleteSpace(space) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the space and all its events. This can't be undone.")
            }
            .alert("Rename Space", isPresented: $showRenameAlert) {
                TextField("Space name", text: $renameText)
                Button("Save") {
                    if let space = spaceToRename, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                        space.spaceName = renameText.trimmingCharacters(in: .whitespaces)
                        try? modelContext.save()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a new name for this shared space.")
            }
        }
    }

    // MARK: - Space Row

    private func spaceRow(space: SharedSpace) -> some View {
        let events = allEvents.filter { $0.spaceId == space.id }
        let today = Calendar.current.startOfDay(for: Date())
        let upcoming = events.filter { event in
            guard let start = event.date else { return false }
            let effectiveEnd = event.endDate.map { Calendar.current.startOfDay(for: $0) } ?? Calendar.current.startOfDay(for: start)
            return start >= today || effectiveEnd >= today
        }
        .sorted { $0.date! < $1.date! }
        let displayName = space.spaceName.isEmpty ? "Shared Space" : space.spaceName

        return NavigationLink(destination: SharedSpaceView(space: space)) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(space.status == .active ? Color.oceanTeal.opacity(0.1) : Color.mist)
                        .frame(width: 44, height: 44)
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 17))
                        .foregroundColor(space.status == .active ? .oceanTeal : .gray)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(displayName)
                            .font(.custom("DMSans-Medium", size: 15))
                            .foregroundColor(.deepNavy)
                        if space.status == .pending {
                            Text("Pending")
                                .font(.custom("DMSans-Regular", size: 11))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Color.mist)
                                .clipShape(Capsule())
                        }
                    }

                    if let next = upcoming.first {
                        Text("Next: \(next.title) · \(next.date!.formatted(.dateTime.month(.abbreviated).day()))")
                            .font(.custom("DMSans-Regular", size: 12))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    } else {
                        Text("\(events.count) \(events.count == 1 ? "item" : "items")")
                            .font(.custom("DMSans-Regular", size: 12))
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var sharedSpaceInfoBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 13))
                .foregroundColor(.oceanTeal.opacity(0.7))
                .padding(.top, 1)
            Text("Shared Spaces let you plan events, trips, and notes with a partner, family member, or roommate — in real time. Tap **Create New** to invite someone and get started.")
                .font(.custom("DMSans-Regular", size: 12))
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button { withAnimation { bannerDismissed = true } } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.mist.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)
            ZStack {
                Circle().fill(Color.oceanTeal.opacity(0.08)).frame(width: 80, height: 80)
                Image(systemName: "person.2.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.oceanTeal.opacity(0.4))
            }
            Text("No shared spaces yet")
                .font(.custom("DMSans-Medium", size: 18))
                .foregroundColor(.deepNavy)
            Text("Invite someone to start planning\nevents and notes together")
                .font(.custom("DMSans-Regular", size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Button { showInvite = true } label: {
                Text("Invite someone")
                    .font(.custom("DMSans-Medium", size: 15))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28).padding(.vertical, 12)
                    .background(Color.oceanTeal)
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }
}
