//
//  ManageEchosView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI
import SwiftData

struct ManageEchosView: View {
    @Query(sort: \Echo.sortOrder) private var echos: [Echo]
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService

    @State private var showAddEcho = false
    @State private var editingEcho: Echo?

    var body: some View {
        List {
            Section {
                ForEach(echos) { echo in
                    HStack(spacing: 12) {
                        Text(echo.emoji)
                            .font(.system(size: 24))
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(echo.name)
                                .font(.custom("DMSans-Medium", size: 16))
                                .foregroundColor(.deepNavy)
                        }
                        Spacer()
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editingEcho = echo }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            let id = echo.id
                            modelContext.delete(echo)
                            Task {
                                await SupabaseSyncService.shared.deleteEcho(id: id)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onMove { from, to in
                    var reordered = echos
                    reordered.move(fromOffsets: from, toOffset: to)
                    for (index, echo) in reordered.enumerated() {
                        echo.sortOrder = index
                    }
                }
            } header: {
                Text("Tap to edit · Swipe to delete · Drag to reorder")
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundColor(.gray)
                    .textCase(nil)
            }

            Section {
                Button {
                    showAddEcho = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.oceanTeal)
                        Text("Add Echo")
                            .font(.custom("DMSans-Medium", size: 16))
                            .foregroundColor(.oceanTeal)
                    }
                }
            }
        }
        .navigationTitle("Manage Echos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .sheet(isPresented: $showAddEcho) {
            EchoEditSheet(echo: nil)
        }
        .sheet(item: $editingEcho) { echo in
            EchoEditSheet(echo: echo)
        }
    }
}

// MARK: - Echo Edit Sheet

struct EchoEditSheet: View {
    let echo: Echo?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService
    @Query(sort: \Echo.sortOrder) private var echos: [Echo]

    @State private var name: String = ""
    @State private var emoji: String = ""

    let commonEmojis = [
        "📝","🏥","👨‍👩‍👧","🎂","🎁","✈️","🍳","🍽️","🏆","🛍️",
        "🏠","🎓","💼","🐾","💰","🎉","🧹","🎮","❤️","🌟",
        "🧠","🎸","🎨","🌿","📷","🏋️","🐕","🐈","🚗","🚀",
        "💡","🔑","🛠️","📦","🧳","🎯","🌊","🍎","☕","🍕",
        "🎵","🏖️","⚽","🎬","📚","🎤","🌙","🌈","🔥","💎",
        "🧘","🪴","🦋","🎠","🧩","🪄","🎪","🌺","🦊","🐬"
    ]

    var isEditing: Bool { echo != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Michael, Side Project, Garage...", text: $name)
                        .font(.custom("DMSans-Regular", size: 16))
                }

                Section("Icon") {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.mist)
                                .frame(width: 52, height: 52)
                            Text(emoji.isEmpty ? "?" : emoji)
                                .font(.system(size: 28))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Type or paste any emoji")
                                .font(.custom("DMSans-Medium", size: 14))
                                .foregroundColor(.deepNavy)
                            TextField("🎯", text: $emoji)
                                .font(.system(size: 24))
                                .frame(height: 36)
                                .onChange(of: emoji) { _, newValue in
                                    let filtered = newValue.filter { $0.isEmoji }
                                    emoji = String(filtered.prefix(1))
                                }
                        }
                    }
                    .padding(.vertical, 4)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                        ForEach(Array(commonEmojis.enumerated()), id: \.offset) { _, e in
                            Button {
                                emoji = e
                            } label: {
                                Text(e)
                                    .font(.system(size: 24))
                                    .frame(width: 44, height: 44)
                                    .background(emoji == e ? Color.oceanTeal.opacity(0.15) : Color.mist)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(emoji == e ? Color.oceanTeal : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(isEditing ? "Edit Echo" : "New Echo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEcho()
                        dismiss()
                    }
                    .font(.custom("DMSans-Medium", size: 16))
                    .foregroundColor(canSave ? .oceanTeal : .gray)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if let echo {
                    name = echo.name
                    emoji = echo.emoji
                }
            }
        }
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !emoji.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func saveEcho() {
        if let existing = echo {
            existing.name = name.trimmingCharacters(in: .whitespaces)
            existing.emoji = emoji.trimmingCharacters(in: .whitespaces)
            if let userId = authService.userId {
                Task { await SupabaseSyncService.shared.pushEcho(existing, userId: userId) }
            }
        } else {
            let nextOrder = (echos.last?.sortOrder ?? -1) + 1
            let newEcho = Echo(
                name: name.trimmingCharacters(in: .whitespaces),
                emoji: emoji.trimmingCharacters(in: .whitespaces),
                isDefault: false,
                sortOrder: nextOrder
            )
            modelContext.insert(newEcho)
            if let userId = authService.userId {
                Task { await SupabaseSyncService.shared.pushEcho(newEcho, userId: userId) }
            }
        }
    }
}

// MARK: - Character emoji detection

private extension Character {
    var isEmoji: Bool {
        unicodeScalars.first.map {
            $0.properties.isEmojiPresentation ||
            ($0.value >= 0x1F600 && $0.value <= 0x1FFFF)
        } ?? false
    }
}
