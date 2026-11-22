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
    @State private var recentIds: [UUID] = []

    /// One cover, two destinations. Two presentation modifiers stacked on the same view
    /// destabilise each other — the dashboard learned that the hard way — so what's on
    /// top of this screen is one piece of state.
    private enum Showing: Identifiable {
        case cooking(Memory)
        case addRecipe

        var id: String {
            switch self {
            case .cooking(let recipe): return recipe.id.uuidString
            case .addRecipe:           return "add"
            }
        }
    }
    @State private var showing: Showing?

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    /// Every card is this tall, whatever is in it.
    private let artHeight: CGFloat = 104
    private let footerHeight: CGFloat = 34

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
                                    card(for: recipe)
                                        .frame(width: 150)
                                        // The shelf is a convenience, so it has to be
                                        // clearable. One dinner you're not making again
                                        // shouldn't hold the top of the screen for weeks.
                                        .overlay(alignment: .topTrailing) {
                                            removeButton { forget(recipe) }
                                        }
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
                            ForEach(filtered) { recipe in card(for: recipe) }
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
            .onAppear(perform: refreshRecent)
            .fullScreenCover(item: $showing, onDismiss: refreshRecent) { what in
                switch what {
                case .cooking(let recipe):
                    CookingSessionView(memory: recipe, ingredients: subTasks(for: recipe))
                case .addRecipe:
                    // The same screen the Drop button opens, so a recipe added from
                    // here lands exactly where one added anywhere else does — and the
                    // shelf behind picks it up on its own, being a @Query.
                    RecipeCaptureView(isPresented: Binding(
                        get: { showing != nil },
                        set: { if !$0 { showing = nil } }
                    ))
                }
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

    /// An empty shelf should hand you the way out of it. Opening cooking mode with
    /// nothing saved otherwise explains the problem and leaves you to go and find the
    /// capture screen yourself.
    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(search.isEmpty ? "No recipes yet" : "Nothing matches “\(search)”")
                .font(.custom("DMSans-Medium", size: 15)).foregroundColor(inkPrimary)
            Text(search.isEmpty
                 ? "Paste a link and the ingredients and steps come with it."
                 : "Try an ingredient — “chicken” finds recipes that use it.")
                .font(.custom("DMSans-Regular", size: 13))
                .foregroundColor(inkMuted)
                .multilineTextAlignment(.center)

            if search.isEmpty {
                Button { showing = .addRecipe } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "plus").font(.system(size: 12, weight: .semibold))
                        Text("Add a recipe").font(.custom("DMSans-Medium", size: 14))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 11)
                    .background(Capsule().fill(Color.oceanTeal))
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            } else {
                Button("Clear search") { search = "" }
                    .font(.custom("DMSans-Medium", size: 13))
                    .foregroundColor(.oceanTeal)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
    }

    /// A card with no photo is a designed state, not a gap: the name gets the room the
    /// picture would have had.
    ///
    /// Both dimensions are declared here rather than inherited from the contents, because
    /// a card that sizes itself is a card that comes out a different size to the one next
    /// to it. The artwork has a height; the footer has a height; the card takes whatever
    /// width it's handed. Nothing inside gets a say.
    private func card(for recipe: Memory) -> some View {
        let title = RecipeDocument.title(in: recipe.text)
        let count = subTasks(for: recipe).count
        let steps = RecipeDocument.steps(in: recipe.text).count

        return Button {
            showing = .cooking(recipe)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                artwork(title: title, photo: recipe.imageData.flatMap(UIImage.init(data:)))
                    .frame(height: artHeight)
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
                    .frame(maxWidth: .infinity, minHeight: footerHeight, alignment: .leading)
                    .padding(.horizontal, 10)
            }
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(inkPrimary.opacity(0.08), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.07), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    /// The name lives on the artwork either way — over the photo when there is one,
    /// filling the space when there isn't. The box below is then free to be just the
    /// facts, instead of repeating the title underneath itself.
    ///
    /// The photo goes in an overlay on an empty colour, not straight into the stack: a
    /// `.fill` image reports a layout size larger than the box it's drawn in — that's what
    /// filling means — and a stack asked to hold one sizes itself to the overflow. An
    /// overlay can't change what it's drawn on, so a tall photo and a wide one give the
    /// same card.
    private func artwork(title: String, photo: UIImage?) -> some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [shelfWood.opacity(0.30), shelfWood.opacity(0.14)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            if let photo {
                Color.clear
                    .overlay { Image(uiImage: photo).resizable().aspectRatio(contentMode: .fill) }
                    .clipped()
                // The name has to hold up over whatever the photo turns out to be — a
                // bright dish shot on a white plate, or the blogger's face. The scrim is
                // most of the way to solid by the bottom for that reason: white on a
                // light photo reads as nothing at all, which looks like a missing title
                // rather than a hard-to-read one.
                LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black.opacity(0.10), location: 0.30),
                    .init(color: .black.opacity(0.55), location: 0.62),
                    .init(color: .black.opacity(0.90), location: 1),
                ], startPoint: .top, endPoint: .bottom)
            }

            Text(title)
                .font(.custom("DMSans-Medium", size: photo == nil ? 17 : 15))
                .foregroundColor(photo == nil ? inkPrimary.opacity(0.78) : .white)
                .multilineTextAlignment(.leading)
                // Two lines over a photo, three without. A third line would climb into
                // the part of the scrim that's still mostly photo; a name cut short with
                // an ellipsis can at least be read.
                .lineLimit(photo == nil ? 3 : 2)
                .shadow(color: photo == nil ? .clear : .black.opacity(0.8), radius: 4, y: 1)
                .padding(12)
        }
    }

    /// Sits on top of the card rather than inside it. A button nested in another button's
    /// label doesn't reliably get the tap — the card would swallow it and start cooking.
    private func removeButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.black.opacity(0.45)))
                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 0.5))
                .padding(7)            // widens the target without growing the badge
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove from Cook again")
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
    ///
    /// Held in state rather than read from storage every time the body runs: taking a
    /// card off the shelf has to redraw the row, and a property that reads UserDefaults
    /// gives SwiftUI nothing to notice. Refreshed on the way in and after each cook.
    private var recentlyCooked: [Memory] {
        recentIds.compactMap { id in recipes.first { $0.id == id } }
    }

    private func refreshRecent() {
        recentIds = recipes
            .compactMap { recipe -> (UUID, Date)? in
                guard let when = CookingSessionView.lastCooked(recipe.id) else { return nil }
                return (recipe.id, when)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(6)
            .map { $0.0 }
    }

    /// Off the shelf, not out of the app. The recipe stays in "Everything else", keeps
    /// its ticks, and cooking it again puts it back at the front.
    private func forget(_ recipe: Memory) {
        CookingSessionView.forgetCooked(recipe.id)
        withAnimation(.easeOut(duration: 0.22)) {
            recentIds.removeAll { $0 == recipe.id }
        }
    }

    private func subTasks(for memory: Memory) -> [SubTask] {
        var seen = Set<UUID>()
        return allSubTasks.filter { $0.memoryId == memory.id && seen.insert($0.id).inserted }
    }
}
