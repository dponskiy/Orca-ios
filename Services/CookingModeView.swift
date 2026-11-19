//
//  CookingModeView.swift
//  Orca
//
//  Shopping mode gets you home with the ingredients. This is the half after: the recipe
//  propped on the counter while your hands are busy.
//
//  Three things it has to get right, in this order:
//
//  1. The screen stays lit. A recipe that blanks out mid-step is the whole reason this
//     exists, so the idle timer is disabled here — and released on the way out and on
//     backgrounding, because a phone that never sleeps again is a worse bug than the one
//     being fixed.
//  2. You can see what's next. Steps tick off rather than advancing one at a time, so
//     the next thing is already on screen while you're doing this one.
//  3. Timers start from the step you're reading. Times in the text are drawn as chips;
//     tapping one starts it.
//
//  Ticks are kept per recipe, so putting the phone down with something in the oven and
//  coming back doesn't lose your place.
//

import SwiftUI
import SwiftData

// MARK: - Picker

/// The shelf: which recipe are we cooking.
struct CookingModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var memories: [Memory]
    @Query private var allSubTasks: [SubTask]
    @Query private var echoes: [Echo]

    @State private var search = ""
    @State private var cooking: Memory?

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    searchField

                    if !recentlyCooked.isEmpty && search.isEmpty {
                        shelfLabel("Cook again")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(recentlyCooked) { recipe in
                                    card(for: recipe, width: 150)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.horizontal, -16)
                    }

                    if filtered.isEmpty {
                        emptyState
                    } else {
                        if !recentlyCooked.isEmpty && search.isEmpty { shelfLabel("Everything else") }
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(filtered) { recipe in card(for: recipe, width: nil) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .background(cafeBg.ignoresSafeArea())
            .navigationTitle("Cook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.oceanTeal)
                }
            }
            .fullScreenCover(item: $cooking) { recipe in
                CookingSessionView(memory: recipe, ingredients: subTasks(for: recipe))
            }
        }
    }

    // MARK: Picker pieces

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14)).foregroundColor(inkMuted)
            TextField("Search name or ingredient", text: $search)
                .font(.custom("DMSans-Regular", size: 15))
                .foregroundColor(inkPrimary)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15)).foregroundColor(inkMuted.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(inkPrimary.opacity(0.10), lineWidth: 0.5))
        .padding(.top, 8)
    }

    private func shelfLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.custom("DMMono-Regular", size: 10))
            .tracking(1.4)
            .foregroundColor(inkMuted)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(search.isEmpty ? "No recipes yet" : "Nothing matches “\(search)”")
                .font(.custom("DMSans-Medium", size: 15)).foregroundColor(inkPrimary)
            Text(search.isEmpty
                 ? "Anything you save with an ingredient list turns up here."
                 : "Try an ingredient — “chicken” finds recipes that use it.")
                .font(.custom("DMSans-Regular", size: 13))
                .foregroundColor(inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
    }

    /// A card with no photo is a designed state, not a gap: the name gets the room the
    /// picture would have had.
    private func card(for recipe: Memory, width: CGFloat?) -> some View {
        let title = RecipeDocument.title(in: recipe.text)
        let count = subTasks(for: recipe).count
        let steps = RecipeDocument.steps(in: recipe.text).count

        return Button {
            cooking = recipe
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // The name lives up here either way — over the photo when there is one,
                // filling the space when there isn't. The box below is then free to be
                // just the facts, instead of repeating the title underneath itself.
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: [shelfWood.opacity(0.30), shelfWood.opacity(0.14)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)

                    let photo = recipe.imageData.flatMap(UIImage.init(data:))
                    if let photo {
                        Image(uiImage: photo)
                            .resizable().aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                        // So the name stays readable whatever the photo is doing
                        LinearGradient(colors: [.clear, .black.opacity(0.55)],
                                       startPoint: .center, endPoint: .bottom)
                    }

                    Text(title)
                        .font(.custom("DMSans-Medium", size: photo == nil ? 17 : 15))
                        .foregroundColor(photo == nil ? inkPrimary.opacity(0.78) : .white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .shadow(color: photo == nil ? .clear : .black.opacity(0.4), radius: 3, y: 1)
                        .padding(12)
                }
                .frame(height: 104)
                .clipped()
                // Recipes saved before photos were kept fill in as you look at them,
                // rather than in one migration that hammers a dozen sites at once.
                .task {
                    guard recipe.imageData == nil,
                          let page = RecipePhoto.sourceURL(for: recipe),
                          let data = await RecipePhoto.fetchFromPage(page) else { return }
                    recipe.imageData = data
                    try? modelContext.save()
                }

                Text(subtitle(ingredients: count, steps: steps))
                    .font(.custom("DMMono-Regular", size: 11))
                    .foregroundColor(inkMuted).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10).padding(.vertical, 9)
            }
            .frame(width: width)
            .background(Color.white.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(inkPrimary.opacity(0.08), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.07), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func subtitle(ingredients: Int, steps: Int) -> String {
        let left = "\(ingredients) ingredient\(ingredients == 1 ? "" : "s")"
        return steps > 0 ? "\(left) · \(steps) step\(steps == 1 ? "" : "s")" : left
    }

    // MARK: Picker data

    private var recipes: [Memory] {
        let cookingEchoIds = Set(echoes.filter {
            let name = $0.name.lowercased()
            return name.contains("cook") || name.contains("recipe")
        }.map { $0.id })

        return memories.filter { memory in
            guard memory.hasChecklist else { return false }
            // A recipe is a checklist in a cooking echo, or one that kept its steps.
            return cookingEchoIds.contains(memory.echoId)
                || !RecipeDocument.steps(in: memory.text).isEmpty
        }
    }

    /// Matches the name or any ingredient, so "pasta" finds Sunday Sauce even when the
    /// word only appears in what you need to buy for it.
    private var filtered: [Memory] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return recipes }
        var byMemory: [UUID: [String]] = [:]
        for task in allSubTasks { byMemory[task.memoryId, default: []].append(task.text) }

        return recipes.filter { recipe in
            if recipe.text.lowercased().contains(query) { return true }
            return byMemory[recipe.id]?.contains { $0.lowercased().contains(query) } ?? false
        }
    }

    /// Most cooking is repeats, so the ones you've actually cooked come first.
    private var recentlyCooked: [Memory] {
        recipes
            .compactMap { recipe -> (Memory, Date)? in
                guard let when = CookingSessionView.lastCooked(recipe.id) else { return nil }
                return (recipe, when)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(6)
            .map { $0.0 }
    }

    private func subTasks(for memory: Memory) -> [SubTask] {
        var seen = Set<UUID>()
        return allSubTasks.filter { $0.memoryId == memory.id && seen.insert($0.id).inserted }
    }
}
