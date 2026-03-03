//
//  Untitled.swift
//  Orca
//
//  Created by David Piliponskiy on 3/3/26.
//

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
                    .onTapGesture {
                        editingEcho = echo
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            modelContext.delete(echo)
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
        .toolbar {
            EditButton()
        }
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
    @Query(sort: \Echo.sortOrder) private var echos: [Echo]
    
    @State private var name: String = ""
    @State private var emoji: String = ""
    
    let commonEmojis = ["📝", "🏥", "👨‍👩‍👧", "🎂", "🎁", "✈️", "🍳", "🍽️", "🏆", "🛍️", "🏠", "🎓", "💼", "🐾", "💰", "🎉", "🧹", "🎮", "❤️", "🌟"]
    
    var isEditing: Bool { echo != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Cooking, Travel, Work...", text: $name)
                        .font(.custom("DMSans-Regular", size: 16))
                }
                
                Section("Emoji") {
                    TextField("Paste or type an emoji", text: $emoji)
                        .font(.system(size: 24))
                        .frame(height: 44)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(commonEmojis, id: \.self) { e in
                            Button {
                                emoji = e
                            } label: {
                                Text(e)
                                    .font(.system(size: 28))
                                    .frame(width: 52, height: 52)
                                    .background(emoji == e ? Color.oceanTeal.opacity(0.15) : Color.mist)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(emoji == e ? Color.oceanTeal : Color.clear, lineWidth: 2)
                                    )
                            }
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
                if let echo = echo {
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
        } else {
            let nextOrder = (echos.last?.sortOrder ?? -1) + 1
            let newEcho = Echo(name: name.trimmingCharacters(in: .whitespaces),
                               emoji: emoji.trimmingCharacters(in: .whitespaces),
                               sortOrder: nextOrder)
            modelContext.insert(newEcho)
        }
    }
}
