//
//  GroceryModeView.swift
//  Orca
//
//  Created by David Piliponskiy on 3/21/26.
//

import SwiftUI
import SwiftData

struct GroceryModeView: View {
    let memories: [Memory]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GroceryList.createdAt, order: .reverse) private var savedLists: [GroceryList]

    @State private var selectedMemoryIds: Set<UUID> = []
    @State private var checkedItems: Set<UUID> = []
    @State private var shopping = false
    @State private var showSaveSheet = false
    @State private var saveListName = ""

    private var recipeMemories: [Memory] {
        memories.filter { $0.hasChecklist }
    }

    private func subTasks(for memory: Memory) -> [SubTask] {
        let descriptor = FetchDescriptor<SubTask>(sortBy: [SortDescriptor(\.sortOrder)])
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { $0.memoryId == memory.id }
    }

    private var selectedMemories: [Memory] {
        recipeMemories.filter { selectedMemoryIds.contains($0.id) }
    }

    private var totalItems: Int {
        selectedMemories.reduce(0) { $0 + subTasks(for: $1).count }
    }

    var body: some View {
        NavigationStack {
            if shopping {
                shoppingView
            } else {
                selectionView
            }
        }
    }

    // MARK: - Recipe Selection View

    private var selectionView: some View {
        VStack(spacing: 0) {
            if recipeMemories.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "cart")
                        .font(.system(size: 44))
                        .foregroundColor(.seafoam.opacity(0.5))
                    Text("No recipes yet")
                        .font(.custom("DMSans-Medium", size: 20))
                        .foregroundColor(.deepNavy)
                    Text("Save some recipes with ingredients first.")
                        .font(.custom("DMSans-Regular", size: 14))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    // Saved lists section
                    if !savedLists.isEmpty {
                        Section {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(savedLists) { list in
                                        HStack(spacing: 0) {
                                            // Tap to load list
                                            Button {
                                                let ids = list.memoryUUIDs
                                                selectedMemoryIds = Set(ids.filter { id in
                                                    recipeMemories.contains { $0.id == id }
                                                })
                                            } label: {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    HStack(spacing: 6) {
                                                        Image(systemName: "cart.fill")
                                                            .font(.system(size: 12))
                                                            .foregroundColor(.oceanTeal)
                                                        Text(list.name)
                                                            .font(.custom("DMSans-Medium", size: 13))
                                                            .foregroundColor(.deepNavy)
                                                            .lineLimit(1)
                                                    }
                                                    Text("\(list.memoryIds.count) \(list.memoryIds.count == 1 ? "recipe" : "recipes")")
                                                        .font(.custom("DMMono-Regular", size: 11))
                                                        .foregroundColor(.gray)
                                                }
                                                .padding(.leading, 14)
                                                .padding(.trailing, 8)
                                                .padding(.vertical, 10)
                                            }

                                            // Visible delete button
                                            Button {
                                                modelContext.delete(list)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 15))
                                                    .foregroundColor(.gray.opacity(0.5))
                                            }
                                            .padding(.trailing, 10)
                                        }
                                        .background(Color.oceanTeal.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.oceanTeal.opacity(0.2), lineWidth: 1)
                                        )
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        } header: {
                            Text("Saved Lists")
                                .font(.custom("DMSans-Medium", size: 13))
                                .foregroundColor(.gray)
                                .textCase(nil)
                        }
                    }

                    // Recipe selection
                    Section {
                        Text("Select the recipes you want to shop for.")
                            .font(.custom("DMSans-Regular", size: 14))
                            .foregroundColor(.gray)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                        ForEach(recipeMemories) { memory in
                            let isSelected = selectedMemoryIds.contains(memory.id)
                            let items = subTasks(for: memory)

                            Button {
                                if isSelected {
                                    selectedMemoryIds.remove(memory.id)
                                } else {
                                    selectedMemoryIds.insert(memory.id)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundColor(isSelected ? .oceanTeal : .gray.opacity(0.4))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(memory.text.components(separatedBy: "\n").first ?? memory.text)
                                            .font(.custom("DMSans-Medium", size: 15))
                                            .foregroundColor(.deepNavy)
                                            .lineLimit(2)
                                        Text("\(items.count) \(items.count == 1 ? "ingredient" : "ingredients")")
                                            .font(.custom("DMMono-Regular", size: 12))
                                            .foregroundColor(.gray)
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(isSelected ? Color.oceanTeal.opacity(0.06) : Color.white)
                        }
                    }
                }
                .listStyle(.plain)

                // Bottom bar
                VStack(spacing: 0) {
                    Divider()
                    VStack(spacing: 10) {
                        // Info row
                        HStack {
                            Text("\(selectedMemoryIds.count) \(selectedMemoryIds.count == 1 ? "recipe" : "recipes") selected")
                                .font(.custom("DMSans-Medium", size: 14))
                                .foregroundColor(.deepNavy)
                            Spacer()
                            Text("\(totalItems) ingredients")
                                .font(.custom("DMMono-Regular", size: 12))
                                .foregroundColor(.gray)
                        }

                        // Buttons row
                        HStack(spacing: 10) {
                            if !selectedMemoryIds.isEmpty {
                                Button {
                                    saveListName = ""
                                    showSaveSheet = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "bookmark.fill")
                                            .font(.system(size: 13))
                                        Text("Save List")
                                            .font(.custom("DMSans-Medium", size: 14))
                                    }
                                    .foregroundColor(.oceanTeal)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.oceanTeal.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.oceanTeal.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                            Button {
                                withAnimation(.spring(duration: 0.3)) {
                                    shopping = true
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "cart.fill")
                                        .font(.system(size: 14))
                                    Text("Start Shopping")
                                        .font(.custom("DMSans-Medium", size: 15))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(selectedMemoryIds.isEmpty ? Color.gray.opacity(0.4) : Color.oceanTeal)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(selectedMemoryIds.isEmpty)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.white)
                }
            }
        }
        .navigationTitle("🛒 Grocery Mode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundColor(.gray)
            }
        }
        .alert("Save List", isPresented: $showSaveSheet) {
            TextField("e.g. Weekly Meals, Sunday Shop...", text: $saveListName)
            Button("Save") {
                guard !saveListName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                let list = GroceryList(
                    name: saveListName.trimmingCharacters(in: .whitespaces),
                    memoryIds: Array(selectedMemoryIds)
                )
                modelContext.insert(list)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Name this grocery list so you can reuse it later.")
        }
    }

    // MARK: - Shopping View

    private var shoppingView: some View {
        VStack(spacing: 0) {
            List {
                ForEach(selectedMemories) { memory in
                    let items = subTasks(for: memory)
                    let title = memory.text.components(separatedBy: "\n").first ?? memory.text
                    let checkedCount = items.filter { checkedItems.contains($0.id) }.count

                    Section {
                        ForEach(items) { subTask in
                            let isChecked = checkedItems.contains(subTask.id)
                            Button {
                                withAnimation(.spring(duration: 0.2)) {
                                    if isChecked {
                                        checkedItems.remove(subTask.id)
                                    } else {
                                        checkedItems.insert(subTask.id)
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .stroke(Color.oceanTeal.opacity(0.4), lineWidth: 1.5)
                                            .frame(width: 22, height: 22)
                                        if isChecked {
                                            Circle()
                                                .fill(Color.oceanTeal)
                                                .frame(width: 22, height: 22)
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    Text(subTask.text)
                                        .font(.custom("DMSans-Regular", size: 15))
                                        .foregroundColor(isChecked ? .gray : .deepNavy)
                                        .strikethrough(isChecked)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        HStack {
                            Text(title)
                                .font(.custom("DMSans-Medium", size: 14))
                                .foregroundColor(.deepNavy)
                                .textCase(nil)
                            Spacer()
                            Text("\(checkedCount)/\(items.count)")
                                .font(.custom("DMMono-Regular", size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)

            // Progress bar + controls
            VStack(spacing: 0) {
                Divider()
                VStack(spacing: 10) {
                    let total = selectedMemories.reduce(0) { $0 + subTasks(for: $1).count }
                    let checked = checkedItems.count
                    let progress = total > 0 ? CGFloat(checked) / CGFloat(total) : 0

                    HStack {
                        Text("\(checked) of \(total) items")
                            .font(.custom("DMSans-Medium", size: 14))
                            .foregroundColor(.deepNavy)
                        Spacer()
                        if checked == total && total > 0 {
                            Text("All done! 🎉")
                                .font(.custom("DMSans-Medium", size: 14))
                                .foregroundColor(.seafoam)
                        }
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.mist)
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.oceanTeal)
                                .frame(width: geo.size.width * progress, height: 6)
                                .animation(.spring(duration: 0.3), value: progress)
                        }
                    }
                    .frame(height: 6)

                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            shopping = false
                            checkedItems = []
                        }
                    } label: {
                        Text("Back to Recipes")
                            .font(.custom("DMSans-Medium", size: 15))
                            .foregroundColor(.oceanTeal)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.white)
            }
        }
        .navigationTitle("Shopping List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
                    .foregroundColor(.oceanTeal)
            }
        }
    }
}
