//
//  GiftQuickActionView.swift
//  Orca
//

import SwiftUI
import SwiftData

struct GiftQuickActionView: View {
    var openWishlistDirectly: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Query(sort: \Person.name) private var persons: [Person]
    @Query private var echos: [Echo]

    @State private var selectedPerson: Person? = nil
    @State private var isMyWishlist = false
    @State private var searchText = ""
    @State private var showAddPerson = false
    @State private var newPersonName = ""
    @FocusState private var newPersonFocused: Bool
    @FocusState private var searchFocused: Bool

    private var inGiftList: Bool { selectedPerson != nil || isMyWishlist }

    private var filteredPersons: [Person] {
        let unique = deduplicatedPersons
        if searchText.isEmpty { return unique }
        return unique.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var deduplicatedPersons: [Person] {
        var seen = Set<String>()
        return persons.filter { seen.insert($0.name.lowercased()).inserted }
    }

    var body: some View {
        NavigationStack {
            Group {
                if inGiftList {
                    GiftListView(
                        person: selectedPerson,
                        isWishlist: isMyWishlist,
                        onBack: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                selectedPerson = nil
                                isMyWishlist = false
                            }
                        }
                    )
                } else {
                    personPickerView
                }
            }
            .background(Color.pearl.ignoresSafeArea())
        }
        .presentationDetents([.large])
        .onAppear {
            if openWishlistDirectly { isMyWishlist = true }
        }
    }

    // MARK: - Person Picker

    private var personPickerView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                TextField("Search people...", text: $searchText)
                    .font(.custom("DMSans-Regular", size: 15))
                    .focused($searchFocused)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(Color.mist)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 0) {
                    // My Wishlist
                    if searchText.isEmpty {
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) { isMyWishlist = true }
                        } label: {
                            personRow(
                                avatar: AnyView(ZStack {
                                    Circle().fill(Color.oceanTeal.opacity(0.12)).frame(width: 44, height: 44)
                                    Image(systemName: "star.fill").font(.system(size: 17)).foregroundColor(.oceanTeal)
                                }),
                                title: "My Wishlist",
                                subtitle: "Things you want for yourself"
                            )
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 78)
                    }

                    // People list
                    ForEach(filteredPersons) { person in
                        let colors = avatarColors(for: person.colorIndex)
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) { selectedPerson = person }
                        } label: {
                            personRow(
                                avatar: AnyView(ZStack {
                                    Circle().fill(colors.background).frame(width: 44, height: 44)
                                    Text(person.initials)
                                        .font(.custom("DMSans-Medium", size: 15))
                                        .foregroundColor(colors.text)
                                }),
                                title: person.name,
                                subtitle: person.relationship?.capitalized
                            )
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 78)
                    }

                    // Add person
                    if showAddPerson {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Color.mist).frame(width: 44, height: 44)
                                Image(systemName: "person.badge.plus").font(.system(size: 16)).foregroundColor(.gray)
                            }
                            TextField("Name...", text: $newPersonName)
                                .font(.custom("DMSans-Regular", size: 15))
                                .focused($newPersonFocused)
                                .onSubmit { commitNewPerson() }
                                .submitLabel(.done)
                            Button("Add") { commitNewPerson() }
                                .font(.custom("DMSans-Medium", size: 14))
                                .foregroundColor(.oceanTeal)
                                .disabled(newPersonName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 14)
                    } else {
                        Button {
                            showAddPerson = true
                            newPersonFocused = true
                        } label: {
                            personRow(
                                avatar: AnyView(ZStack {
                                    Circle().fill(Color.mist).frame(width: 44, height: 44)
                                    Circle().stroke(Color.gray.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4])).frame(width: 44, height: 44)
                                    Image(systemName: "plus").font(.system(size: 16)).foregroundColor(.gray)
                                }),
                                title: "Add Person",
                                subtitle: nil
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer().frame(height: 60)
                }
            }
        }
        .navigationTitle("Gifts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }.foregroundColor(.oceanTeal)
            }
        }
    }

    private func personRow(avatar: AnyView, title: String, subtitle: String?) -> some View {
        HStack(spacing: 14) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("DMSans-Medium", size: 15))
                    .foregroundColor(.deepNavy)
                if let sub = subtitle {
                    Text(sub).font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray.opacity(0.3))
        }
        .padding(.horizontal, 20).padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    private func commitNewPerson() {
        let trimmed = newPersonName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let person = Person(name: trimmed)
        modelContext.insert(person)
        withAnimation(.easeOut(duration: 0.2)) { selectedPerson = person }
        showAddPerson = false
        newPersonName = ""
    }

    private func avatarColors(for index: Int) -> (background: Color, text: Color) {
        let palette: [(Color, Color)] = [
            (Color(red: 0.878, green: 0.961, blue: 0.933), Color(red: 0.059, green: 0.431, blue: 0.337)),
            (Color(red: 0.980, green: 0.933, blue: 0.851), Color(red: 0.522, green: 0.310, blue: 0.043)),
            (Color(red: 0.902, green: 0.945, blue: 0.984), Color(red: 0.094, green: 0.373, blue: 0.647)),
            (Color(red: 0.980, green: 0.925, blue: 0.906), Color(red: 0.600, green: 0.235, blue: 0.110)),
            (Color(red: 0.933, green: 0.929, blue: 0.996), Color(red: 0.325, green: 0.290, blue: 0.718)),
        ]
        return palette[index % palette.count]
    }
}

// MARK: - Gift List (per person or wishlist)

struct GiftListView: View {
    let person: Person?
    let isWishlist: Bool
    let onBack: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Query private var allGifts: [GiftItem]
    @Query private var echos: [Echo]

    @State private var newGiftText = ""
    @State private var showLinkField = false
    @State private var linkText = ""
    @State private var pendingLinkForGift: GiftItem? = nil
    @FocusState private var inputFocused: Bool
    @FocusState private var linkFocused: Bool

    private var personId: UUID {
        person?.id ?? GiftItem.wishlistPersonId
    }

    private var gifts: [GiftItem] {
        allGifts
            .filter { $0.personId == personId }
            .sorted {
                if $0.isStarred != $1.isStarred { return $0.isStarred }
                return $0.createdAt < $1.createdAt
            }
    }

    private var title: String {
        if isWishlist { return "My Wishlist" }
        return person?.name.split(separator: " ").first.map(String.init) ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            if gifts.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(gifts) { gift in
                        giftRow(gift: gift)
                            .listRowBackground(Color.white)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            .listRowSeparatorTint(Color.black.opacity(0.06))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    modelContext.delete(gift)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .background(Color.pearl)
                .scrollContentBackground(.hidden)
            }

            // Input bar pinned at bottom
            VStack(spacing: 0) {
                Divider()
                if showLinkField {
                    HStack(spacing: 10) {
                        Image(systemName: "link").font(.system(size: 14)).foregroundColor(.oceanTeal)
                        TextField("Product link (optional)", text: $linkText)
                            .font(.custom("DMSans-Regular", size: 14))
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($linkFocused)
                        Button("Save") { saveLink() }
                            .font(.custom("DMSans-Medium", size: 14))
                            .foregroundColor(.oceanTeal)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(Color.white)
                    Divider()
                }
                HStack(spacing: 12) {
                    TextField("Add a gift idea...", text: $newGiftText)
                        .font(.custom("DMSans-Regular", size: 15))
                        .foregroundColor(.deepNavy)
                        .focused($inputFocused)
                        .onSubmit { addGift() }
                        .submitLabel(.done)
                    if !newGiftText.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button { addGift() } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.oceanTeal)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 14)
                .background(Color.white)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { onBack() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 13, weight: .medium))
                        Text("Back")
                    }
                    .foregroundColor(.oceanTeal)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { inputFocused = true }
        }
    }

    // MARK: - Gift Row

    private func giftRow(gift: GiftItem) -> some View {
        HStack(spacing: 14) {
            Button {
                gift.status = gift.isPurchased ? .idea : .purchased
            } label: {
                Image(systemName: gift.isPurchased ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(gift.isPurchased ? .oceanTeal : .gray.opacity(0.35))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(gift.name)
                    .font(.custom("DMSans-Regular", size: 15))
                    .foregroundColor(gift.isPurchased ? .gray : .deepNavy)
                    .strikethrough(gift.isPurchased, color: .gray.opacity(0.5))
                if let urlStr = gift.url, let url = URL(string: urlStr) {
                    Link(urlStr.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "").prefix(40).description, destination: url)
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundColor(.oceanTeal)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 14) {
                Button {
                    withAnimation(.spring(duration: 0.2)) { gift.isStarred.toggle() }
                } label: {
                    Image(systemName: gift.isStarred ? "star.fill" : "star")
                        .font(.system(size: 15))
                        .foregroundColor(gift.isStarred ? .yellow : .gray.opacity(0.35))
                }
                .buttonStyle(.plain)

                Button {
                    pendingLinkForGift = gift
                    linkText = gift.url ?? ""
                    withAnimation { showLinkField = true }
                    linkFocused = true
                } label: {
                    Image(systemName: gift.url != nil ? "link" : "link.badge.plus")
                        .font(.system(size: 13))
                        .foregroundColor(gift.url != nil ? .oceanTeal : .gray.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 0).padding(.vertical, 13)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            ZStack {
                Circle().fill(Color.mist).frame(width: 64, height: 64)
                Image(systemName: isWishlist ? "star" : "gift")
                    .font(.system(size: 26)).foregroundColor(.oceanTeal)
            }
            Text(isWishlist ? "Your wishlist is empty" : "No gift ideas yet")
                .font(.custom("DMSans-Medium", size: 16)).foregroundColor(.deepNavy)
            Text(isWishlist ? "Add things you'd love to receive" : "Add ideas below — you can check them off as you go")
                .font(.custom("DMSans-Regular", size: 14)).foregroundColor(.gray)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func addGift() {
        let trimmed = newGiftText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        newGiftText = ""

        let gift = GiftItem(personId: personId, name: trimmed)
        modelContext.insert(gift)

        // Also save as Memory in Gifts echo
        let echoId = echos.first { $0.name == "Gifts" }?.id ?? echos.first?.id ?? UUID()
        let memText = isWishlist ? "Wishlist: \(trimmed)" : "Gift for \(person?.name ?? ""): \(trimmed)"
        let memory = Memory(text: memText, echoId: echoId, captureType: .typed)
        memory.isActionable = true
        gift.linkedMemoryId = memory.id
        modelContext.insert(memory)

        if let userId = authService.userId {
            Task { await SupabaseSyncService.shared.pushMemory(memory, userId: userId) }
        }
    }

    private func saveLink() {
        guard let gift = pendingLinkForGift else { return }
        let trimmed = linkText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            gift.url = nil
        } else {
            gift.url = trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)"
        }
        pendingLinkForGift = nil
        linkText = ""
        withAnimation { showLinkField = false }
        inputFocused = true
    }
}
