//
//  CreateEchoView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/26/26.
//

import SwiftUI
import SwiftData

struct CreateEchoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name = ""
    @State private var selectedEmoji = "📝"
    
    let emojiOptions = ["📝", "🎵", "📚", "🎬", "🏠", "💡", "🎯", "🌱", "📷", "🎨", "🧘", "🍕", "☕", "🐶", "🚗", "📦", "💰", "🛠️", "🎮", "⚽"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Preview
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.mist)
                            .frame(width: 80, height: 80)
                        Text(selectedEmoji)
                            .font(.system(size: 36))
                    }
                    
                    if !name.isEmpty {
                        Text(name)
                            .font(.custom("DMSans-Medium", size: 16))
                            .foregroundColor(.deepNavy)
                    }
                }
                .padding(.top, 20)
                
                // Name field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.custom("DMSans-Medium", size: 14))
                        .foregroundColor(.gray)
                    
                    TextField("Echo name", text: $name)
                        .font(.custom("DMSans-Regular", size: 16))
                        .padding(12)
                        .background(Color.pearl)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.oceanTeal.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 20)
                
                // Emoji picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Icon")
                        .font(.custom("DMSans-Medium", size: 14))
                        .foregroundColor(.gray)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(emojiOptions, id: \.self) { emoji in
                            Button {
                                selectedEmoji = emoji
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(selectedEmoji == emoji ? Color.oceanTeal.opacity(0.15) : Color.mist)
                                        .frame(width: 48, height: 48)
                                    
                                    Text(emoji)
                                        .font(.system(size: 22))
                                }
                                .overlay(
                                    Circle()
                                        .stroke(selectedEmoji == emoji ? Color.oceanTeal : Color.clear, lineWidth: 2)
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .background(Color.white)
            .navigationTitle("New Echo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let echo = Echo(name: name, emoji: selectedEmoji)
                        echo.sortOrder = 99
                        modelContext.insert(echo)
                        dismiss()
                    }
                    .font(.custom("DMSans-Medium", size: 16))
                    .foregroundColor(.oceanTeal)
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

#Preview {
    CreateEchoView()
        .modelContainer(for: [Echo.self], inMemory: true)
}
