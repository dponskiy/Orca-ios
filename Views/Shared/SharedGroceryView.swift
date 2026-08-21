//
//  SharedGroceryView.swift
//  Orca
//
//  The household grocery list. Everyone's recipes pool here; ticking one copies its
//  ingredients onto the list (a snapshot, so editing a recipe never changes a list
//  someone is mid-way through shopping). Combining and aisle order come from
//  GroceryAisles / IngredientParser — the same code the personal list uses.
//

import SwiftUI
import SwiftData

struct SharedGroceryView: View {
    let space: SharedSpace

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService
    @Query private var allRecipes: [SharedRecipe]
    @Query private var allItems: [SharedGroceryItem]
    @Query private var allMembers: [SharedSpaceMember]

    @State private var newItemText = ""
    @State private var showRecipes = false
    @State private var showClearConfirm = false
    @State private var byAisle = true
    @State private var busyRecipeId: UUID? = nil
    @State private var errorMessage: String? = nil
    @FocusState private var addFocused: Bool

    // MARK: Data

    private var recipes: [SharedRecipe] {
        allRecipes.filter { $0.spaceId == space.id }
            .sorted { $0.title.lowercased() < $1.title.lowercased() }
    }
    private var items: [SharedGroceryItem] {
        allItems.filter { $0.spaceId == space.id }
    }
    private var selectedRecipeIds: Set<UUID> {
        Set(items.compactMap { $0.sourceRecipeId })
    }
    private var checkedCount: Int { items.filter { $0.isChecked }.count }

    private func memberName(_ userId: String?) -> String {
        guard let userId else { return "" }
        if userId == authService.userId?.uuidString { return "you" }
        let name = allMembers.first { $0.spaceId == space.id && $0.userId == userId }?.displayName
        return (name?.isEmpty == false) ? name! : "someone"
    }

    // MARK: Merging — same parser as the personal list

    private struct Line: Identifiable {
        let id: String
        let name: String
        let quantity: String?
        let sources: [String]        // recipe titles, for the ×N detail
        let items: [SharedGroceryItem]
        var isChecked: Bool { !items.isEmpty && items.allSatisfy { $0.isChecked } }
    }

    private func mergedLines(_ source: [SharedGroceryItem]) -> [Line] {
        var order: [String] = []
        var buckets: [String: (name: String, amounts: [(Double?, String?)],
                              sources: [String], items: [SharedGroceryItem])] = [:]
        for item in source {
            let parsed = IngredientParser.parse(item.text)
            let key = parsed.key.isEmpty ? item.text.lowercased() : parsed.key
            if buckets[key] == nil {
                buckets[key] = (parsed.displayName.isEmpty ? item.text : parsed.displayName, [], [], [])
                order.append(key)
            }
            buckets[key]?.amounts.append((parsed.value, parsed.unit))
            if !item.sourceRecipeTitle.isEmpty { buckets[key]?.sources.append(item.sourceRecipeTitle) }
            buckets[key]?.items.append(item)
        }
        return order.compactMap { key in
            guard let b = buckets[key] else { return nil }
            return Line(id: key, name: b.name,
                        quantity: IngredientParser.summarize(b.amounts),
                        sources: b.sources, items: b.items)
        }
    }

    private var groupedLines: [(aisle: String, lines: [Line])] {
        let lines = mergedLines(items)
        guard byAisle else { return [("", lines.sorted { !$0.isChecked && $1.isChecked })] }
        var grouped: [String: [Line]] = [:]
        for line in lines { grouped[GroceryAisles.category(for: line.name), default: []].append(line) }
        return GroceryAisles.groceryOrder.compactMap { aisle in
            guard let lines = grouped[aisle], !lines.isEmpty else { return nil }
            return (aisle, lines.sorted { !$0.isChecked && $1.isChecked })
        }
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            if items.isEmpty && recipes.isEmpty {
                emptyState
            } else {
                List {
                    recipeSection
                    if !items.isEmpty {
                        ForEach(groupedLines, id: \.aisle) { group in
                            Section {
                                ForEach(group.lines) { line in lineRow(line) }
                            } header: {
                                if !group.aisle.isEmpty {
                                    Text(group.aisle)
                                        .font(.custom("DMSans-Medium", size: 14))
                                        .foregroundColor(.deepNavy).textCase(nil)
                                }
                            }
                        }
                    }
                    Section { addRow }
                }
                .listStyle(.insetGrouped)
                progressBar
            }
        }
        .background(Color.pearl.ignoresSafeArea())
        .navigationTitle(space.spaceName.isEmpty ? "Household list" : space.spaceName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !items.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            withAnimation { byAisle.toggle() }
                        } label: {
                            Label(byAisle ? "Show as one list" : "Group by aisle",
                                  systemImage: byAisle ? "list.bullet" : "list.bullet.indent")
                        }
                        Divider()
                        // Mid-trip: drop what's in the basket, keep what isn't
                        Button {
                            clearChecked()
                        } label: { Label("Clear checked items", systemImage: "checkmark.circle") }
                        Button(role: .destructive) {
                            showClearConfirm = true
                        } label: { Label("Clear whole list", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis.circle").foregroundColor(.oceanTeal)
                    }
                }
            }
        }
        .confirmationDialog("Clear the whole list?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear everything", role: .destructive) { clearAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes every item and unticks all recipes, for everyone in the household.")
        }
        .sheet(isPresented: $showRecipes) { recipePicker }
    }

    // MARK: Recipes

    /// The recipes currently contributing items, in the order they were added.
    private var selectedRecipes: [SharedRecipe] {
        let ids = selectedRecipeIds
        return recipes.filter { ids.contains($0.id) }
    }

    private var recipeSection: some View {
        Section {
            Button { showRecipes = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "fork.knife").foregroundColor(.oceanTeal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedRecipeIds.isEmpty ? "Add recipes" : "\(selectedRecipeIds.count) recipe\(selectedRecipeIds.count == 1 ? "" : "s") on the list")
                            .font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy)
                        Text("\(recipes.count) in your household")
                            .font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.gray.opacity(0.4))
                }
            }
            .buttonStyle(.plain)

            // What's actually on the list, not just how many — so you can see at a
            // glance whether tonight's dinner made it on without opening the picker.
            ForEach(selectedRecipes) { recipe in
                HStack(spacing: 10) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 10))
                        .foregroundColor(.oceanTeal.opacity(0.6))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(recipe.title)
                            .font(.custom("DMSans-Regular", size: 14))
                            .foregroundColor(.deepNavy)
                            .lineLimit(1)
                        Text(memberName(recipe.ownerUserId).capitalized)
                            .font(.custom("DMSans-Regular", size: 11))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    if busyRecipeId == recipe.id {
                        ProgressView().scaleEffect(0.6)
                    } else {
                        Button {
                            toggleRecipe(recipe, currentlySelected: true)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.gray.opacity(0.5))
                                .padding(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 4)
            }
        }
    }

    private var recipePicker: some View {
        NavigationStack {
            List {
                if recipes.isEmpty {
                    Text("No recipes yet. Anything you save with an ingredient list shows up here for everyone.")
                        .font(.custom("DMSans-Regular", size: 14)).foregroundColor(.gray)
                } else {
                    ForEach(recipes) { recipe in
                        let selected = selectedRecipeIds.contains(recipe.id)
                        Button { toggleRecipe(recipe, currentlySelected: selected) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selected ? .oceanTeal : .gray.opacity(0.4))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(recipe.title)
                                        .font(.custom("DMSans-Medium", size: 15))
                                        .foregroundColor(.deepNavy).lineLimit(1)
                                    Text("\(recipe.ingredients.count) ingredients · \(memberName(recipe.ownerUserId).capitalized)")
                                        .font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                                }
                                Spacer()
                                if busyRecipeId == recipe.id { ProgressView().scaleEffect(0.7) }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Household recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showRecipes = false }.foregroundColor(.oceanTeal)
                }
            }
        }
    }

    // MARK: Rows

    private func lineRow(_ line: Line) -> some View {
        let checked = line.isChecked
        let checker = line.items.first { $0.isChecked }?.checkedByUserId
        return Button { toggle(line) } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().stroke(Color.oceanTeal.opacity(0.4), lineWidth: 1.5).frame(width: 22, height: 22)
                    if checked {
                        Circle().fill(Color.oceanTeal).frame(width: 22, height: 22)
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.name)
                        .font(.custom("DMSans-Regular", size: 15))
                        .foregroundColor(checked ? .gray : .deepNavy).strikethrough(checked)
                    // Quantity, which recipe it came from, and who grabbed it —
                    // matches the personal list, plus the bit only a shared list needs.
                    HStack(spacing: 5) {
                        if let q = line.quantity {
                            Text(q).font(.custom("DMSans-Regular", size: 11))
                                .foregroundColor(checked ? .gray.opacity(0.6) : .oceanTeal)
                        }
                        if let origin = recipeOrigin(line) {
                            if line.quantity != nil {
                                Text("·").font(.system(size: 10)).foregroundColor(.gray.opacity(0.4))
                            }
                            Text(origin).font(.custom("DMSans-Regular", size: 11))
                                .foregroundColor(.gray).lineLimit(1)
                        }
                        if checked, let checker {
                            Text("· \(memberName(checker)) got this")
                                .font(.custom("DMSans-Regular", size: 11)).foregroundColor(.gray)
                        }
                    }
                }
                Spacer()
                if line.sources.count > 1 {
                    Text("×\(line.sources.count)")
                        .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.oceanTeal)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.oceanTeal.opacity(0.1)).clipShape(Capsule())
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { remove(line) } label: { Label("Remove", systemImage: "trash") }
        }
    }

    /// Which recipe an item came from, or that someone added it by hand.
    private func recipeOrigin(_ line: Line) -> String? {
        let names = Array(Set(line.sources))
        if names.isEmpty { return "added by hand" }
        if names.count == 1 { return names[0] }
        return "\(names.count) recipes"
    }

    private var addRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle").font(.system(size: 18)).foregroundColor(.oceanTeal.opacity(0.6))
            TextField("Add an item...", text: $newItemText)
                .font(.custom("DMSans-Regular", size: 15))
                .focused($addFocused)
                .submitLabel(.done)
                .onSubmit { addExtra() }
            if !newItemText.isEmpty {
                Button { addExtra() } label: {
                    Text("Add").font(.custom("DMSans-Medium", size: 13)).foregroundColor(.oceanTeal)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var pantryButton: some View {
        Button { checkPantryStaples() } label: {
            VStack(spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 13))
                    Text("Pantry Items").font(.custom("DMSans-Medium", size: 13))
                }
                Text("salt, oils, spices & more")
                    .font(.custom("DMSans-Regular", size: 10)).opacity(0.75)
            }
            .foregroundColor(.oceanTeal)
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(Color.oceanTeal.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.oceanTeal.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// Ticks off the things you almost certainly already have. Everyone in the
    /// household sees them go, same as any other check.
    private func checkPantryStaples() {
        guard let userId = authService.userId else { return }
        let staples = items.filter { !$0.isChecked && PantryStaples.matches($0.text) }
        guard !staples.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            for item in staples {
                try? await SharedSpaceSyncService.shared.toggleGroceryItem(item, userId: userId)
            }
        }
    }

    private var progressBar: some View {
        VStack(spacing: 8) {
            Divider()
            if items.contains(where: { !$0.isChecked && PantryStaples.matches($0.text) }) {
                pantryButton.padding(.horizontal, 20).padding(.top, 4)
            }
            if !items.isEmpty && checkedCount == items.count {
                Button { showClearConfirm = true } label: {
                    HStack(spacing: 6) {
                        Text("All done 🎉").font(.custom("DMSans-Medium", size: 14))
                        Text("· start a new list")
                            .font(.custom("DMSans-Regular", size: 13)).opacity(0.8)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.seafoam)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20).padding(.top, 4)
            }

            HStack {
                Text("\(checkedCount) of \(mergedLines(items).count) items")
                    .font(.custom("DMSans-Medium", size: 14)).foregroundColor(.deepNavy)
                Spacer()
                if let errorMessage {
                    Text(errorMessage).font(.custom("DMSans-Regular", size: 12)).foregroundColor(.coral)
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
        .background(Color.white)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "cart").font(.system(size: 38)).foregroundColor(.oceanTeal.opacity(0.3))
            Text("Nothing on the list yet")
                .font(.custom("DMSans-Medium", size: 17)).foregroundColor(.deepNavy)
            Text("Recipes anyone in the household saves\nshow up here to add.")
                .font(.custom("DMSans-Regular", size: 13)).foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Button { showRecipes = true } label: {
                Text("Browse recipes")
                    .font(.custom("DMSans-Medium", size: 15)).foregroundColor(.white)
                    .padding(.horizontal, 24).padding(.vertical, 11)
                    .background(Color.oceanTeal).clipShape(Capsule())
            }
            Spacer()
        }
    }

    // MARK: Actions

    /// Everything goes — recipes come off the list because their items are gone,
    /// which is what "start next week fresh" means.
    private func clearAll() {
        let all = items
        guard !all.isEmpty else { return }
        Task {
            do { try await SharedSpaceSyncService.shared.removeGroceryItems(all) }
            catch { await MainActor.run { errorMessage = "Couldn't clear the list." } }
        }
    }

    /// Just what's in the basket already — leaves anything you didn't find.
    private func clearChecked() {
        let done = items.filter { $0.isChecked }
        guard !done.isEmpty else { return }
        Task {
            do { try await SharedSpaceSyncService.shared.removeGroceryItems(done) }
            catch { await MainActor.run { errorMessage = "Couldn't clear those items." } }
        }
    }

    private func toggleRecipe(_ recipe: SharedRecipe, currentlySelected: Bool) {
        guard let userId = authService.userId else { return }
        busyRecipeId = recipe.id
        Task {
            do {
                if currentlySelected {
                    // Unticking pulls that recipe's items back off the list
                    let mine = items.filter { $0.sourceRecipeId == recipe.id }
                    try await SharedSpaceSyncService.shared.removeGroceryItems(mine)
                } else {
                    try await SharedSpaceSyncService.shared.addGroceryItems(
                        recipe.ingredients, spaceId: space.id, userId: userId,
                        recipeId: recipe.id, recipeTitle: recipe.title)
                }
                await MainActor.run { busyRecipeId = nil; errorMessage = nil }
            } catch {
                await MainActor.run { busyRecipeId = nil; errorMessage = "Couldn't update the list." }
            }
        }
    }

    private func addExtra() {
        let text = newItemText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, let userId = authService.userId else { return }
        newItemText = ""
        Task {
            try? await SharedSpaceSyncService.shared.addGroceryItems(
                [text], spaceId: space.id, userId: userId)
        }
    }

    private func toggle(_ line: Line) {
        guard let userId = authService.userId else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        // A merged line can cover several rows — move them together
        let target = !line.isChecked
        Task {
            for item in line.items where item.isChecked != target {
                try? await SharedSpaceSyncService.shared.toggleGroceryItem(item, userId: userId)
            }
        }
    }

    private func remove(_ line: Line) {
        Task { try? await SharedSpaceSyncService.shared.removeGroceryItems(line.items) }
    }
}
