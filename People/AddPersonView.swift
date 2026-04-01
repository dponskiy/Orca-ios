//
//  AddPersonView.swift
//  Orca
//
//  Created by David Piliponskiy on 3/29/26.
//

import SwiftUI
import SwiftData

struct AddPersonView: View {
    var person: Person? = nil
    var suggestedName: String = ""
    var suggestedBirthday: Date? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var relationship = ""
    @State private var hasBirthday = false
    @State private var birthday = Date()
    @State private var showDeleteConfirm = false

    private let relationships = ["Wife", "Husband", "Partner", "Mom", "Dad",
                                  "Sister", "Brother", "Daughter", "Son",
                                  "Friend", "Coworker", "Other"]

    var isEditing: Bool { person != nil }
    var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {

                    // Avatar preview
                    let index = abs(name.unicodeScalars.reduce(0) { $0 + Int($1.value) }) % 5
                    let colors = avatarColors(for: index)
                    ZStack {
                        Circle().fill(colors.background).frame(width: 72, height: 72)
                        Text(name.isEmpty ? "?" : initials(for: name))
                            .font(.custom("DMSans-Medium", size: 24))
                            .foregroundColor(name.isEmpty ? Color.gray : colors.text)
                    }
                    .padding(.top, 8)

                    // Name
                    fieldCard {
                        VStack(alignment: .leading, spacing: 4) {
                            fieldLabel("NAME")
                            TextField("e.g. Sarah", text: $name)
                                .font(.custom("DMSans-Regular", size: 15))
                                .foregroundColor(.deepNavy)
                        }
                    }

                    // Relationship
                    fieldCard {
                        VStack(alignment: .leading, spacing: 10) {
                            fieldLabel("RELATIONSHIP")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(relationships, id: \.self) { rel in
                                        Button {
                                            relationship = relationship == rel ? "" : rel
                                        } label: {
                                            Text(rel)
                                                .font(.custom("DMSans-Regular", size: 13))
                                                .foregroundColor(relationship == rel ? .white : .deepNavy)
                                                .padding(.horizontal, 12).padding(.vertical, 7)
                                                .background(relationship == rel ? Color.oceanTeal : Color.mist)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Birthday
                    fieldCard {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                fieldLabel("BIRTHDAY")
                                Spacer()
                                Toggle("", isOn: $hasBirthday)
                                    .tint(.oceanTeal).labelsHidden()
                            }
                            if hasBirthday {
                                Divider().padding(.top, 8)
                                DatePicker("", selection: $birthday, displayedComponents: .date)
                                    .datePickerStyle(.graphical)
                                    .tint(.oceanTeal)
                                    .padding(.horizontal, 4)
                            }
                        }
                    }

                    // Delete — editing only
                    if isEditing {
                        Button { showDeleteConfirm = true } label: {
                            Text("Delete \(person?.name ?? "Person")")
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
                    Text(isEditing ? "Edit Person" : "Add Person")
                        .font(.custom("DMSans-Medium", size: 17)).foregroundColor(.deepNavy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.custom("DMSans-Medium", size: 16))
                        .foregroundColor(canSave ? .oceanTeal : .gray)
                        .disabled(!canSave)
                }
            }
            .confirmationDialog(
                "Delete \(person?.name ?? "Person")?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deletePerson() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will also remove all gift items. This cannot be undone.")
            }
            .onAppear { loadExisting() }
        }
    }

    // MARK: - Helpers

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.custom("DMSans-Medium", size: 11))
            .foregroundColor(.gray).tracking(0.5)
    }

    private func fieldCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1)).uppercased() + String(parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
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

    private func loadExisting() {
        if let p = person {
            name = p.name
            relationship = p.relationship ?? ""
            if let bd = p.birthday { hasBirthday = true; birthday = bd }
        } else {
            if !suggestedName.isEmpty { name = suggestedName }
            if let bd = suggestedBirthday { hasBirthday = true; birthday = bd }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let existing = person {
            existing.name = trimmed
            existing.relationship = relationship.isEmpty ? nil : relationship
            existing.birthday = hasBirthday ? birthday : nil
            existing.updatedAt = Date()
        } else {
            let p = Person(
                name: trimmed,
                relationship: relationship.isEmpty ? nil : relationship,
                birthday: hasBirthday ? birthday : nil
            )
            modelContext.insert(p)
        }
        dismiss()
    }

    private func deletePerson() {
        guard let p = person else { return }
        let personId = p.id
        // Delete gift items locally and remotely
        let descriptor = FetchDescriptor<GiftItem>()
        if let items = try? modelContext.fetch(descriptor) {
            let personItems = items.filter { $0.personId == p.id }
            personItems.forEach { item in
                let itemId = item.id
                Task { await SupabaseSyncService.shared.deleteGiftItem(id: itemId) }
                modelContext.delete(item)
            }
        }
        modelContext.delete(p)
        Task { await SupabaseSyncService.shared.deletePerson(id: personId) }
        dismiss()
    }
}
