//
//  AddGiftItemView.swift
//  Orca
//
//  Created by David Piliponskiy on 3/29/26.
//

import SwiftUI
import SwiftData

struct AddGiftItemView: View {
    let person: Person
    let occasion: String
    var existingItem: GiftItem? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allMemories: [Memory]

    @State private var name = ""
    @State private var priceText = ""
    @State private var status: GiftStatus = .idea
    @State private var url = ""
    @State private var selectedMemoryId: UUID? = nil
    @State private var showMemoryPicker = false

    var isEditing: Bool { existingItem != nil }
    var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    private var recentMemories: [Memory] {
        Array(allMemories.sorted { $0.createdAt > $1.createdAt }.prefix(30))
    }

    private var selectedMemory: Memory? {
        guard let id = selectedMemoryId else { return nil }
        return allMemories.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {

                    // For + Occasion display
                    HStack(spacing: 10) {
                        infoCard(label: "For", value: person.name)
                        infoCard(label: "Occasion", value: occasion)
                    }

                    // Item name
                    fieldCard {
                        fieldLabel("ITEM NAME")
                        TextField("e.g. Silk pillowcase", text: $name)
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(.deepNavy)
                    }

                    // Price
                    fieldCard {
                        fieldLabel("PRICE (OPTIONAL)")
                        HStack(spacing: 2) {
                            Text("$").font(.custom("DMSans-Regular", size: 15)).foregroundColor(.gray)
                            TextField("0", text: $priceText)
                                .font(.custom("DMSans-Regular", size: 15))
                                .foregroundColor(.deepNavy)
                                .keyboardType(.decimalPad)
                        }
                    }

                    // Status
                    VStack(alignment: .leading, spacing: 8) {
                        Text("STATUS")
                            .font(.custom("DMSans-Medium", size: 11))
                            .foregroundColor(.gray).tracking(0.5)
                        HStack(spacing: 8) {
                            statusPill("Idea", for: .idea)
                            statusPill("Purchased", for: .purchased)
                        }
                    }

                    // Product URL
                    fieldCard {
                        fieldLabel("PRODUCT LINK (OPTIONAL)")
                        TextField("https://amazon.com/...", text: $url)
                            .font(.custom("DMSans-Regular", size: 14))
                            .foregroundColor(.deepNavy)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    // Memory link
                    Button { showMemoryPicker = true } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("LINK TO MEMORY (OPTIONAL)")
                                    .font(.custom("DMSans-Medium", size: 11))
                                    .foregroundColor(.gray).tracking(0.5)
                                if let memory = selectedMemory {
                                    Text(memory.text)
                                        .font(.custom("DMSans-Regular", size: 13))
                                        .foregroundColor(.deepNavy).lineLimit(2)
                                } else {
                                    Text("Link a memory where they mentioned this")
                                        .font(.custom("DMSans-Regular", size: 13))
                                        .foregroundColor(.gray)
                                }
                            }
                            Spacer()
                            Image(systemName: selectedMemoryId != nil ? "checkmark.circle.fill" : "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(selectedMemoryId != nil ? .oceanTeal : .gray.opacity(0.4))
                        }
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)

                    // Delete — editing only
                    if isEditing {
                        Button {
                            if let item = existingItem {
                                let id = item.id
                                modelContext.delete(item)
                                Task {
                                    await SupabaseSyncService.shared.deleteGiftItem(id: id)
                                }
                            }
                            dismiss()
                        } label: {
                            Text("Delete Gift Idea")
                                .font(.custom("DMSans-Medium", size: 15))
                                .foregroundColor(.coral)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.coral.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.top, 8)
                    }

                    Spacer().frame(height: 40)
                }
                .padding(20)
            }
            .background(Color.pearl)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.gray)
                }
                ToolbarItem(placement: .principal) {
                    Text(isEditing ? "Edit Gift Idea" : "Add Gift Idea")
                        .font(.custom("DMSans-Medium", size: 17)).foregroundColor(.deepNavy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.custom("DMSans-Medium", size: 16))
                        .foregroundColor(canSave ? .oceanTeal : .gray)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showMemoryPicker) {
                NavigationStack {
                    List {
                        if selectedMemoryId != nil {
                            Button {
                                selectedMemoryId = nil
                                showMemoryPicker = false
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "xmark.circle").foregroundColor(.coral)
                                    Text("Remove link").foregroundColor(.coral)
                                }
                            }
                        }
                        ForEach(recentMemories) { memory in
                            Button {
                                selectedMemoryId = memory.id
                                showMemoryPicker = false
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(memory.text)
                                        .font(.custom("DMSans-Regular", size: 14))
                                        .foregroundColor(.deepNavy).lineLimit(2)
                                    Text(memory.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                                        .font(.custom("DMMono-Regular", size: 11)).foregroundColor(.gray)
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(selectedMemoryId == memory.id ? Color.oceanTeal.opacity(0.06) : Color.white)
                        }
                    }
                    .listStyle(.plain)
                    .navigationTitle("Link a Memory")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showMemoryPicker = false }.foregroundColor(.oceanTeal)
                        }
                    }
                }
            }
            .onAppear { loadExisting() }
        }
    }

    // MARK: - Helpers

    private func loadExisting() {
        guard let item = existingItem else { return }
        name = item.name
        priceText = item.price.map {
            $0.truncatingRemainder(dividingBy: 1) == 0 ? String(Int($0)) : String(format: "%.2f", $0)
        } ?? ""
        status = item.status
        url = item.url ?? ""
        selectedMemoryId = item.linkedMemoryId
    }

    private func infoCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).tracking(0.5)
            Text(value).font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.custom("DMSans-Medium", size: 11))
            .foregroundColor(.gray).tracking(0.5)
            .padding(.bottom, 4)
    }

    private func fieldCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    private func statusPill(_ label: String, for s: GiftStatus) -> some View {
        Button { status = s } label: {
            Text(label)
                .font(.custom("DMSans-Medium", size: 13))
                .foregroundColor(status == s ? .white : .deepNavy)
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(status == s ? Color.oceanTeal : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                    status == s ? Color.oceanTeal : Color.black.opacity(0.08),
                    lineWidth: status == s ? 1 : 0.5))
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let item = existingItem {
            item.name = trimmed
            item.price = Double(priceText)
            item.status = status
            item.url = url.isEmpty ? nil : url
            item.linkedMemoryId = selectedMemoryId
        } else {
            let item = GiftItem(personId: person.id, name: trimmed, occasion: occasion)
            item.price = Double(priceText)
            item.status = status
            item.url = url.isEmpty ? nil : url
            item.linkedMemoryId = selectedMemoryId
            modelContext.insert(item)
        }
        dismiss()
    }
}
