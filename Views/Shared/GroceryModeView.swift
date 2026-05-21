//
//  GroceryModeView.swift
//  Orca
//
//  Created by David Piliponskiy on 3/21/26.
//

import SwiftUI
import SwiftData
import Speech
import AVFoundation
import Supabase

struct GroceryModeView: View {
    let memories: [Memory]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GroceryList.createdAt, order: .reverse) private var savedLists: [GroceryList]

    enum ListType: String, CaseIterable {
        case grocery = "grocery"
        case hardware = "hardware"
        case warehouse = "warehouse"

        var label: String {
            switch self {
            case .grocery: return "Grocery"
            case .hardware: return "Hardware"
            case .warehouse: return "Warehouse"
            }
        }

        var icon: String {
            switch self {
            case .grocery: return "cart.fill"
            case .hardware: return "hammer.fill"
            case .warehouse: return "shippingbox.fill"
            }
        }

        var hasRecipes: Bool { self == .grocery }
        var hasAisleGrouping: Bool { true }
    }

    @State private var listType: ListType = .grocery
    @State private var activeCustomListId: UUID? = nil
    @State private var showNewCustomListAlert = false
    @State private var newCustomListName = ""
    @State private var selectedMemoryIds: Set<UUID> = []
    @State private var checkedItems: Set<UUID> = []
    @State private var checkedExtras: Set<String> = []
    @State private var extraItems: [String] = []
    @State private var hiddenIngredients: Set<UUID> = []
    @State private var newItemText: String = ""
    @State private var shoppingNewItemText: String = ""
    @State private var shopping = false
    @State private var showSaveSheet = false
    @State private var saveListName = ""
    @State private var groupByAisle = false
    @State private var isRecording = false
    @State private var currentTranscription = ""
    @State private var aiAisleOverrides: [String: String] = [:]

    // Recipe adding
    @State private var showAddRecipeOptions = false
    @State private var showURLInputSheet = false
    @State private var showRecipeBuilder = false
    @State private var viewingRecipe: Memory? = nil
    @State private var isCreatingShareLink = false
    @State private var shareURL: URL? = nil
    @State private var showShareSheet = false
    @Environment(AuthService.self) private var authService
    @State private var showRecipePreview = false
    @State private var recipeURLInput = ""
    @State private var isFetchingRecipe = false
    @State private var recipeFetchError: String? = nil
    @State private var fetchedRecipe: RecipeResult? = nil

    @State private var audioEngine = AVAudioEngine()
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?

    private let knownCompounds: Set<String> = [
        "olive oil", "greek yogurt", "plain yogurt", "whole milk", "skim milk", "oat milk",
        "almond milk", "soy milk", "coconut milk", "cashew milk", "heavy cream", "sour cream",
        "cream cheese", "cottage cheese", "half and half", "whipped cream", "creme fraiche",
        "buttermilk", "goat cheese", "goat milk", "ricotta cheese",
        "peanut butter", "almond butter", "cashew butter", "sunflower butter", "tahini paste",
        "hazelnut spread", "coconut butter", "brown sugar", "powdered sugar", "maple syrup",
        "baking powder", "baking soda", "vanilla extract", "almond extract", "cocoa powder",
        "bread flour", "cake flour", "whole wheat", "all purpose", "coconut flour",
        "almond flour", "corn starch", "corn meal", "cream of tartar", "active yeast",
        "instant yeast", "brown rice", "white rice", "wild rice", "basmati rice",
        "jasmine rice", "arborio rice", "black rice",
        "hot sauce", "soy sauce", "fish sauce", "oyster sauce", "hoisin sauce",
        "teriyaki sauce", "bbq sauce", "buffalo sauce", "steak sauce", "worcestershire sauce",
        "coconut aminos", "tomato sauce", "tomato paste", "crushed tomatoes", "diced tomatoes",
        "pasta sauce", "marinara sauce", "pesto sauce", "alfredo sauce", "tahini sauce",
        "chili sauce", "sweet chili", "rice vinegar", "apple cider vinegar", "balsamic vinegar",
        "red wine vinegar", "white vinegar", "sherry vinegar",
        "coconut oil", "avocado oil", "sesame oil", "peanut oil",
        "vegetable oil", "canola oil", "sunflower oil", "grape seed oil", "truffle oil",
        "bell pepper", "green pepper", "red pepper", "yellow pepper", "sweet potato",
        "green onion", "red onion", "yellow onion", "white onion", "spring onion",
        "grape tomato", "cherry tomato", "roma tomato", "heirloom tomato",
        "baby spinach", "baby kale", "baby arugula", "brussels sprouts", "snap peas",
        "snow peas", "sugar snap", "bok choy", "napa cabbage", "red cabbage",
        "butternut squash", "acorn squash", "spaghetti squash", "kabocha squash",
        "chicken breast", "chicken thigh", "chicken wing", "chicken drumstick",
        "ground beef", "ground turkey", "ground pork", "ground chicken", "ground lamb",
        "sea bass", "sea scallop", "bay scallop", "rock shrimp", "tiger shrimp",
        "king crab", "snow crab", "dungeness crab", "soft shell crab",
        "pork chop", "pork loin", "pork belly", "pork shoulder", "pork tenderloin",
        "beef tenderloin", "beef brisket", "beef chuck", "beef short rib",
        "egg noodle", "rice noodle", "udon noodle", "ramen noodle",
        "soba noodle", "glass noodle", "rice paper", "bread crumb", "panko bread",
        "sparkling water", "coconut water", "apple juice", "orange juice",
        "cranberry juice", "grape juice", "pomegranate juice", "tomato juice",
        "cold brew", "green tea", "black tea", "herbal tea", "chai tea", "matcha tea",
        "black pepper", "white pepper", "chili powder", "garlic powder",
        "onion powder", "smoked paprika", "sweet paprika", "cayenne pepper",
        "curry powder", "garam masala", "chinese five spice", "italian seasoning",
        "black bean", "kidney bean", "pinto bean", "white bean", "cannellini bean",
        "navy bean", "garbanzo bean", "chickpea can", "lentil soup", "tomato soup",
        "chicken broth", "beef broth", "vegetable broth", "bone broth",
        "coconut cream", "evaporated milk", "artichoke heart", "roasted pepper",
        "paper towel", "toilet paper", "tissue paper", "trash bag", "garbage bag",
        "dish soap", "hand soap", "body wash", "laundry detergent", "fabric softener",
        "dryer sheet", "cleaning spray", "hand sanitizer", "dish towel",
        "aluminum foil", "plastic wrap", "parchment paper", "wax paper",
        "protein powder", "whey protein", "fish oil", "vitamin d", "vitamin c",
        "vitamin b12", "b complex", "omega 3", "pre workout", "post workout",
        "miso paste", "rice wine", "dashi stock", "nori sheet", "rice wrapper",
        "spring roll", "wonton wrapper", "dumpling wrapper",
        "power drill", "drill bit", "circular saw", "reciprocating saw", "jig saw",
        "orbital sander", "belt sander", "pressure washer", "wet dry vac",
        "spray paint", "interior paint", "exterior paint", "primer coat",
        "pvc pipe", "copper pipe", "pipe fitting", "ball valve", "shut off valve",
        "wire nut", "electrical tape", "circuit breaker", "light switch",
        "laminate flooring", "vinyl plank", "ceramic tile", "grout sealer",
        "wood screw", "drywall screw", "lag bolt", "machine bolt", "hex nut",
        "drop cloth", "painter tape", "paint roller", "paint brush", "paint tray",
        "smoke detector", "carbon monoxide", "fire extinguisher", "door lock", "dead bolt",
    ]

    // MARK: - Computed Properties

    private var isCustomActive: Bool { activeCustomListId != nil }

    private var activeCustomList: GroceryList? {
        savedLists.first { $0.id == activeCustomListId }
    }

    private var customLists: [GroceryList] {
        savedLists.filter { $0.listType == "custom" }
    }

    private var navigationTitle: String {
        if let custom = activeCustomList { return custom.name }
        return listType.label
    }

    private var recipeMemories: [Memory] {
        memories.filter { $0.hasChecklist }
    }

    private func subTasks(for memory: Memory) -> [SubTask] {
        let descriptor = FetchDescriptor<SubTask>(sortBy: [SortDescriptor(\.sortOrder)])
        let all = (try? modelContext.fetch(descriptor)) ?? []
        var seen = Set<UUID>()
        return all.filter { st in
            st.memoryId == memory.id && seen.insert(st.id).inserted
        }
    }

    private func visibleSubTasks(for memory: Memory) -> [SubTask] {
        subTasks(for: memory).filter { !hiddenIngredients.contains($0.id) }
    }

    // MARK: - Share List

    private struct SharedListPayload: Encodable {
        let owner_id: String
        let title: String
        let items: [SharedListItem]

        struct SharedListItem: Encodable {
            let id: String
            let text: String
            let checked: Bool
            let aisle: String
        }
    }

    private func createAndShareList() async {
        isCreatingShareLink = true
        defer { isCreatingShareLink = false }

        var payloadItems: [SharedListPayload.SharedListItem] = []

        for memory in selectedMemories {
            for subTask in visibleSubTasks(for: memory) {
                let itemName = subTask.text
                let aisle = aisleCategory(for: itemName.lowercased())
                payloadItems.append(.init(
                    id: subTask.id.uuidString,
                    text: itemName,
                    checked: checkedItems.contains(subTask.id),
                    aisle: aisle
                ))
            }
        }
        for (index, extra) in extraItems.enumerated() {
            let aisle = aisleCategory(for: extra.lowercased())
            payloadItems.append(.init(
                id: "extra-\(index)",
                text: extra,
                checked: checkedExtras.contains(extra),
                aisle: aisle
            ))
        }

        guard !payloadItems.isEmpty, let userId = authService.userId else { return }

        let payload = SharedListPayload(
            owner_id: userId.uuidString,
            title: "\(navigationTitle) List",
            items: payloadItems
        )

        do {
            let result = try await SupabaseManager.shared.client
                .from("shared_lists")
                .insert(payload)
                .select("id")
                .single()
                .execute()

            struct IDRow: Decodable { let id: String }
            let row = try JSONDecoder().decode(IDRow.self, from: result.data)
            let urlString = "https://orca-web-three.vercel.app?id=\(row.id)"
            if let url = URL(string: urlString) {
                shareURL = url
                showShareSheet = true
            }
        } catch {
            print("❌ Failed to create shared list: \(error)")
        }
    }

    private var selectedMemories: [Memory] {
        recipeMemories.filter { selectedMemoryIds.contains($0.id) }
    }

    // MARK: - Pantry Staples

    /// Items almost everyone already has at home.
    /// Pepper spices are listed explicitly to avoid matching produce (bell pepper etc.)
    private let pantryStapleTerms: [String] = [
        // Pepper — spice only (NOT bell pepper / jalapeño / red pepper produce)
        "black pepper", "white pepper", "ground pepper", "cracked pepper",
        "peppercorn", "pepper flake", "cayenne pepper", "freshly ground pepper",
        // Oils — all common cooking oils
        "olive oil", "extra virgin olive oil", "vegetable oil", "canola oil",
        "sunflower oil", "cooking spray", "neutral oil", "avocado oil",
        "sesame oil", "coconut oil",
        // Basic sweeteners
        "granulated sugar", "white sugar", "caster sugar", "brown sugar",
        "powdered sugar", "confectioners sugar",
        // Flour / Baking
        "all-purpose flour", "all purpose flour", "plain flour",
        "baking powder", "baking soda", "bicarbonate of soda",
        // Extracts & basics
        "vanilla extract", "pure vanilla",
        // Common pantry acids
        "white vinegar", "apple cider vinegar",
        // Dry staples most people stock
        "dried oregano", "dried thyme", "dried basil", "dried rosemary",
        "garlic powder", "onion powder", "paprika", "cumin", "turmeric",
        "red pepper flakes", "chili flakes", "italian seasoning",
    ]

    /// Water phrases confirming the item is water, not watermelon / water chestnut etc.
    private let waterPhrases: [String] = [
        "cold water", "warm water", "hot water", "boiling water",
        "ice water", "room temperature water", "lukewarm water",
        "cups of water", "cup of water", "tablespoons of water",
        "tablespoon of water", "liters of water", "ml of water",
        "ounces of water", "oz water",
    ]

    private func isPantryStaple(_ text: String) -> Bool {
        let lower = text.lowercased()
        if pantryStapleTerms.contains(where: { lower.contains($0) }) { return true }
        // Salt — catches "kosher salt", "sea salt", "1 tsp salt", etc.
        // Safe in a recipe context; "assault" won't appear as an ingredient.
        if lower.contains("salt") { return true }
        // Water — only match as a standalone ingredient, not inside other words
        if lower == "water" || lower.hasPrefix("water ") || lower.hasPrefix("water,")
            || lower.hasSuffix(" water") { return true }
        if waterPhrases.contains(where: { lower.contains($0) }) { return true }
        return false
    }

    func checkPantryStaples() {
        withAnimation(.spring(duration: 0.3)) {
            for memory in selectedMemories {
                for subTask in visibleSubTasks(for: memory) {
                    if isPantryStaple(subTask.text) { checkedItems.insert(subTask.id) }
                }
            }
            for item in extraItems where isPantryStaple(item) {
                checkedExtras.insert(item)
            }
        }
    }

    private var totalItems: Int {
        selectedMemories.reduce(0) { $0 + visibleSubTasks(for: $1).count } + extraItems.count
    }

    private var canStartShopping: Bool {
        !selectedMemoryIds.isEmpty || !extraItems.isEmpty
    }

    private var savedListsForType: [GroceryList] {
        guard !isCustomActive else { return [] }
        return savedLists.filter { $0.listType == listType.rawValue }
    }

    private var itemAccentColor: Color {
        if isCustomActive { return Color.seafoam }
        switch listType {
        case .grocery: return Color(red: 0.498, green: 0.467, blue: 0.867)
        case .hardware: return Color(red: 0.7, green: 0.4, blue: 0.1)
        case .warehouse: return Color(red: 0.1, green: 0.4, blue: 0.7)
        }
    }

    private var addItemPlaceholder: String {
        if isCustomActive { return "Add anything..." }
        switch listType {
        case .grocery: return "Add an item..."
        case .hardware: return "Add a supply or material..."
        case .warehouse: return "Add an item..."
        }
    }

    private var itemsSectionHeader: String {
        if isCustomActive { return "Items" }
        switch listType {
        case .grocery: return "Extra items"
        case .hardware: return "Supplies & materials"
        case .warehouse: return "Items"
        }
    }

    private var selectionSummary: String {
        let recipes = selectedMemoryIds.count
        let extras = extraItems.count
        if recipes == 0 && extras == 0 { return "Nothing added yet" }
        if isCustomActive || !listType.hasRecipes || recipes == 0 {
            return "\(extras) \(extras == 1 ? "item" : "items")"
        }
        if extras == 0 { return "\(recipes) \(recipes == 1 ? "recipe" : "recipes") selected" }
        return "\(recipes) \(recipes == 1 ? "recipe" : "recipes") · \(extras) extras"
    }

    private var shareText: String {
        var lines: [String] = ["🛒 \(navigationTitle) List", ""]
        for memory in selectedMemories {
            let title = memory.text.components(separatedBy: "\n").first ?? memory.text
            lines.append(title)
            for subTask in visibleSubTasks(for: memory) {
                lines.append("\(checkedItems.contains(subTask.id) ? "✓" : "-") \(subTask.text)")
            }
            lines.append("")
        }
        if !extraItems.isEmpty {
            for item in extraItems {
                lines.append("\(checkedExtras.contains(item) ? "✓" : "-") \(item)")
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            if shopping { shoppingView } else { selectionView }
        }
        // Share sheet — top level so it works in both selection and shopping modes
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheet(items: [url])
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Selection View

    private var selectionView: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ListType.allCases, id: \.self) { type in
                                Button {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        listType = type
                                        activeCustomListId = nil
                                        selectedMemoryIds = []
                                        extraItems = []
                                        groupByAisle = false
                                        restoreToday()
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: type.icon).font(.system(size: 12))
                                        Text(type.label).font(.custom("DMSans-Medium", size: 13))
                                    }
                                    .foregroundColor(!isCustomActive && listType == type ? .white : .deepNavy)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(!isCustomActive && listType == type ? Color.oceanTeal : Color.mist)
                                    .clipShape(Capsule())
                                    .fixedSize()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(customLists) { list in
                                let listName = list.name
                                let listId = list.id
                                Button {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        activeCustomListId = listId
                                        extraItems = list.extraItems
                                        selectedMemoryIds = []
                                        groupByAisle = false
                                    }
                                } label: {
                                    Text(listName)
                                        .font(.custom("DMSans-Medium", size: 13))
                                        .foregroundColor(activeCustomListId == listId ? .white : .deepNavy)
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(activeCustomListId == listId ? Color.oceanTeal : Color.mist)
                                        .clipShape(Capsule())
                                        .fixedSize()
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                newCustomListName = ""
                                showNewCustomListAlert = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus").font(.system(size: 12, weight: .semibold))
                                    Text("New list").font(.custom("DMSans-Medium", size: 13))
                                }
                                .foregroundColor(.oceanTeal)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Color.oceanTeal.opacity(0.1))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.oceanTeal.opacity(0.3), lineWidth: 1))
                                .fixedSize()
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                } header: {
                    Text("List type")
                        .font(.custom("DMSans-Medium", size: 11))
                        .foregroundColor(.gray)
                        .textCase(nil)
                }

                if !savedListsForType.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(savedListsForType) { list in
                                    let listName = list.name
                                    let listMemoryCount = list.memoryIds.count
                                    let listExtraCount = list.extraItems.count
                                    let isTodayList = list.name == "Today's list"

                                    HStack(spacing: 0) {
                                        Button { loadList(list) } label: {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "bookmark.fill")
                                                        .font(.system(size: 11)).foregroundColor(.oceanTeal)
                                                    Text(listName)
                                                        .font(.custom("DMSans-Medium", size: 13)).foregroundColor(.deepNavy).lineLimit(1)
                                                }
                                                Text("\(listExtraCount) \(listExtraCount == 1 ? "item" : "items")\(listMemoryCount == 0 ? "" : " · \(listMemoryCount) recipes")")
                                                    .font(.custom("DMMono-Regular", size: 11)).foregroundColor(.gray)
                                            }
                                            .padding(.leading, 14).padding(.trailing, 8).padding(.vertical, 10)
                                        }
                                        if !isTodayList {
                                            Button { modelContext.delete(list) } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 15)).foregroundColor(.gray.opacity(0.5))
                                            }
                                            .padding(.trailing, 10)
                                        } else {
                                            Spacer().frame(width: 10)
                                        }
                                    }
                                    .background(isTodayList ? Color.oceanTeal.opacity(0.12) : Color.oceanTeal.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(isTodayList ? Color.oceanTeal.opacity(0.4) : Color.oceanTeal.opacity(0.2), lineWidth: 1))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } header: {
                        Text("Saved lists")
                            .font(.custom("DMSans-Medium", size: 11))
                            .foregroundColor(.gray)
                            .textCase(nil)
                    }
                }

                if !isCustomActive && listType.hasRecipes {
                    if recipeMemories.isEmpty {
                        Section {
                            Button {
                                showAddRecipeOptions = true
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "fork.knife")
                                        .font(.system(size: 14))
                                        .foregroundColor(.oceanTeal)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Add your first recipe")
                                            .font(.custom("DMSans-Medium", size: 14))
                                            .foregroundColor(.oceanTeal)
                                        Text("Paste a URL or build one manually")
                                            .font(.custom("DMSans-Regular", size: 12))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray.opacity(0.4))
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        } header: {
                            Text("From recipes")
                                .font(.custom("DMSans-Medium", size: 11))
                                .foregroundColor(.gray)
                                .textCase(nil)
                        }
                    } else {
                        Section {
                            ForEach(recipeMemories) { memory in
                                let isSelected = selectedMemoryIds.contains(memory.id)
                                let items = subTasks(for: memory)
                                HStack(spacing: 12) {
                                    Button {
                                        viewingRecipe = memory
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(memory.text.components(separatedBy: "\n").first ?? memory.text)
                                                .font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy).lineLimit(2)
                                            Text("\(items.count) \(items.count == 1 ? "ingredient" : "ingredients")")
                                                .font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { isSelected },
                                        set: { on in
                                            if on { selectedMemoryIds.insert(memory.id) }
                                            else { selectedMemoryIds.remove(memory.id) }
                                            autoSaveToday()
                                        }
                                    ))
                                    .labelsHidden().tint(.oceanTeal)
                                }
                                .padding(.vertical, 4)
                                .listRowBackground(isSelected ? Color.oceanTeal.opacity(0.06) : Color.white)
                            }
                        } header: {
                            HStack {
                                Text("From recipes")
                                    .font(.custom("DMSans-Medium", size: 11))
                                    .foregroundColor(.gray)
                                    .textCase(nil)
                                Spacer()
                                Button {
                                    showAddRecipeOptions = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                                        Text("Add recipe").font(.custom("DMSans-Medium", size: 11))
                                    }
                                    .foregroundColor(.oceanTeal)
                                }
                                .textCase(nil)
                            }
                        }
                    }
                }

                Section {
                    ForEach(extraItems.indices, id: \.self) { index in
                        HStack(spacing: 10) {
                            Circle().fill(itemAccentColor).frame(width: 7, height: 7)
                            TextField("Item", text: Binding(
                                get: { extraItems[index] },
                                set: { newValue in
                                    extraItems[index] = newValue
                                    autoSaveToday()
                                }
                            ))
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(.deepNavy)
                            .submitLabel(.done)
                            Spacer()
                            Button {
                                extraItems.remove(at: index)
                                autoSaveToday()
                            } label: {
                                Image(systemName: "xmark").font(.system(size: 11, weight: .medium)).foregroundColor(.gray.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle").font(.system(size: 18)).foregroundColor(.oceanTeal.opacity(0.6))
                        TextField(addItemPlaceholder, text: $newItemText)
                            .font(.custom("DMSans-Regular", size: 15)).foregroundColor(.deepNavy)
                            .submitLabel(.done).onSubmit { addExtraItem() }
                        if !newItemText.isEmpty {
                            Button { addExtraItem() } label: {
                                Text("Add").font(.custom("DMSans-Medium", size: 13)).foregroundColor(.oceanTeal)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button { toggleRecording() } label: {
                                Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(isRecording ? .red : .oceanTeal)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)

                    if isRecording {
                        HStack(spacing: 6) {
                            Circle().fill(Color.red).frame(width: 6, height: 6)
                            Text("Listening... say your items separated by commas")
                                .font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.red.opacity(0.04))
                    }
                } header: {
                    Text(itemsSectionHeader)
                        .font(.custom("DMSans-Medium", size: 11))
                        .foregroundColor(.gray)
                        .textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
            .onAppear { restoreToday() }

            VStack(spacing: 0) {
                Divider()
                VStack(spacing: 10) {
                    HStack {
                        Text(selectionSummary).font(.custom("DMSans-Medium", size: 14)).foregroundColor(.deepNavy)
                        Spacer()
                        if totalItems > 0 {
                            Text("\(totalItems) items").font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                        }
                    }

                    if isCustomActive, let customList = activeCustomList {
                        let customName = customList.name
                        Button(role: .destructive) {
                            modelContext.delete(customList)
                            activeCustomListId = nil
                            extraItems = []
                            selectedMemoryIds = []
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trash").font(.system(size: 13))
                                Text("Delete \"\(customName)\"")
                                    .font(.custom("DMSans-Medium", size: 14))
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    HStack(spacing: 10) {
                        if canStartShopping && !isCustomActive {
                            Button { saveListName = ""; showSaveSheet = true } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "bookmark.fill").font(.system(size: 13))
                                    Text("Save").font(.custom("DMSans-Medium", size: 14))
                                }
                                .foregroundColor(.oceanTeal)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color.oceanTeal.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.oceanTeal.opacity(0.3), lineWidth: 1))
                            }
                        }
                        Button {
                            withAnimation(.spring(duration: 0.3)) { shopping = true }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isCustomActive ? "list.bullet" : listType == .grocery ? "cart.fill" : listType == .hardware ? "hammer.fill" : "shippingbox.fill")
                                    .font(.system(size: 14))
                                Text("Start shopping").font(.custom("DMSans-Medium", size: 15))
                            }
                            .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(canStartShopping ? Color.oceanTeal : Color.gray.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!canStartShopping)
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 16).background(Color.white)
            }
        }
        .navigationTitle("🛒 \(navigationTitle)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }.foregroundColor(.gray)
            }
            if canStartShopping {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await createAndShareList() }
                    } label: {
                        if isCreatingShareLink {
                            ProgressView().tint(.oceanTeal)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15)).foregroundColor(.oceanTeal)
                        }
                    }
                    .disabled(isCreatingShareLink)
                }
            }
        }
        .confirmationDialog("Add Recipe", isPresented: $showAddRecipeOptions, titleVisibility: .visible) {
            Button("Paste recipe URL") {
                recipeURLInput = ""
                recipeFetchError = nil
                showURLInputSheet = true
            }
            Button("Build manually") { showRecipeBuilder = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Import ingredients automatically from a URL or build your own.")
        }
        .sheet(isPresented: $showURLInputSheet) {
            NavigationStack {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RECIPE URL")
                            .font(.custom("DMSans-Medium", size: 11))
                            .foregroundColor(.gray)
                            .tracking(0.5)
                        TextField("https://...", text: $recipeURLInput)
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(.deepNavy)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(14)
                            .background(Color.mist)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if let error = recipeFetchError {
                        Text(error)
                            .font(.custom("DMSans-Regular", size: 13))
                            .foregroundColor(.coral)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button { fetchAndSaveRecipe() } label: {
                        HStack(spacing: 8) {
                            if isFetchingRecipe {
                                ProgressView().scaleEffect(0.8).tint(.white)
                                Text("Fetching...").font(.custom("DMSans-Medium", size: 15))
                            } else {
                                Image(systemName: "arrow.down.circle.fill").font(.system(size: 15))
                                Text("Import Recipe").font(.custom("DMSans-Medium", size: 15))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(recipeURLInput.isEmpty ? Color.gray.opacity(0.4) : Color.oceanTeal)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(recipeURLInput.isEmpty || isFetchingRecipe)

                    Spacer()
                }
                .padding(20)
                .background(Color.pearl)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showURLInputSheet = false }.foregroundColor(.gray)
                    }
                    ToolbarItem(placement: .principal) {
                        Text("Import Recipe")
                            .font(.custom("DMSans-Medium", size: 17)).foregroundColor(.deepNavy)
                    }
                }
            }
        }
        .sheet(isPresented: $showRecipePreview) {
            if let recipe = fetchedRecipe {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(recipe.title)
                                    .font(.custom("DMSans-Medium", size: 22))
                                    .foregroundColor(.deepNavy)
                                HStack(spacing: 8) {
                                    if let prep = recipe.prepTime {
                                        Text("Prep: \(prep)").font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                                    }
                                    if let cook = recipe.cookTime {
                                        Text("Cook: \(cook)").font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                                    }
                                    if let srv = recipe.servings {
                                        Text("Serves: \(srv)").font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)

                            if !recipe.ingredients.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("INGREDIENTS")
                                        .font(.custom("DMSans-Medium", size: 11))
                                        .foregroundColor(.gray).tracking(0.5)
                                        .padding(.horizontal, 20)
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                                            HStack(spacing: 12) {
                                                Circle().fill(Color(red: 0.498, green: 0.467, blue: 0.867)).frame(width: 6, height: 6)
                                                Text(ingredient).font(.custom("DMSans-Regular", size: 15)).foregroundColor(.deepNavy)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 20).padding(.vertical, 10)
                                            if index < recipe.ingredients.count - 1 {
                                                Divider().padding(.leading, 44)
                                            }
                                        }
                                    }
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
                                    .padding(.horizontal, 20)
                                }
                            }

                            if !recipe.instructions.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("INSTRUCTIONS")
                                        .font(.custom("DMSans-Medium", size: 11))
                                        .foregroundColor(.gray).tracking(0.5)
                                        .padding(.horizontal, 20)
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, step in
                                            HStack(alignment: .top, spacing: 12) {
                                                Text("\(index + 1)")
                                                    .font(.custom("DMMono-Regular", size: 13)).foregroundColor(.white)
                                                    .frame(width: 24, height: 24).background(Color.oceanTeal).clipShape(Circle())
                                                Text(step).font(.custom("DMSans-Regular", size: 14)).foregroundColor(.deepNavy)
                                                    .fixedSize(horizontal: false, vertical: true)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 20).padding(.vertical, 12)
                                            if index < recipe.instructions.count - 1 {
                                                Divider().padding(.leading, 56)
                                            }
                                        }
                                    }
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
                                    .padding(.horizontal, 20)
                                }
                            }

                            Spacer().frame(height: 40)
                        }
                        .padding(.top, 16)
                    }
                    .background(Color.pearl)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showRecipePreview = false; fetchedRecipe = nil }.foregroundColor(.gray)
                        }
                        ToolbarItem(placement: .principal) {
                            Text("Review Recipe").font(.custom("DMSans-Medium", size: 17)).foregroundColor(.deepNavy)
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add to list") { saveReviewedRecipe(recipe) }
                                .font(.custom("DMSans-Medium", size: 16)).foregroundColor(.oceanTeal)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showRecipeBuilder) { RecipeBuilderView() }
        .sheet(item: $viewingRecipe) { recipe in
            MemoryDetailView(memory: recipe)
        }
        .alert("Save List", isPresented: $showSaveSheet) {
            TextField("e.g. Weekly Meals, Sunday Shop...", text: $saveListName)
            Button("Save") {
                let trimmed = saveListName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                let list = GroceryList(name: trimmed, listType: listType.rawValue, memoryIds: Array(selectedMemoryIds), extraItems: extraItems)
                modelContext.insert(list)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Name this list to reuse it next time.")
        }
        .alert("New list", isPresented: $showNewCustomListAlert) {
            TextField("e.g. Target run, CVS, Baby shower...", text: $newCustomListName)
            Button("Create") {
                let trimmed = newCustomListName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                let list = GroceryList(name: trimmed, listType: "custom", memoryIds: [], extraItems: [])
                modelContext.insert(list)
                activeCustomListId = list.id
                extraItems = []
                selectedMemoryIds = []
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Give your list a name.")
        }
    }

    // MARK: - Shopping View

    private var shoppingView: some View {
        let recipeChecked = selectedMemories.reduce(0) { count, memory in
            count + visibleSubTasks(for: memory).filter { checkedItems.contains($0.id) }.count
        }
        let extraChecked = checkedExtras.count
        let total = totalItems
        let checked = recipeChecked + extraChecked
        let progress = total > 0 ? CGFloat(checked) / CGFloat(total) : 0

        return VStack(spacing: 0) {
            if !isCustomActive && total > 0 {
                HStack(spacing: 0) {
                    Button { withAnimation { groupByAisle = false } } label: {
                        Text(listType == .grocery ? "By recipe" : "By item")
                            .font(.custom("DMSans-Medium", size: 13))
                            .foregroundColor(groupByAisle ? .gray : .white)
                            .frame(maxWidth: .infinity).padding(.vertical, 7)
                            .background(groupByAisle ? Color.clear : Color.oceanTeal)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Button { withAnimation { groupByAisle = true } } label: {
                        Text("By section")
                            .font(.custom("DMSans-Medium", size: 13))
                            .foregroundColor(groupByAisle ? .white : .gray)
                            .frame(maxWidth: .infinity).padding(.vertical, 7)
                            .background(groupByAisle ? Color.oceanTeal : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .background(Color.mist)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(Color.white)
            }

            List {
                if groupByAisle && !isCustomActive {
                    aisleGroupedView
                } else {
                    recipeGroupedView
                }
            }
            .listStyle(.insetGrouped)

            VStack(spacing: 0) {
                Divider()
                VStack(spacing: 10) {
                    HStack {
                        Text("\(checked) of \(total) items").font(.custom("DMSans-Medium", size: 14)).foregroundColor(.deepNavy)
                        Spacer()
                        if checked == total && total > 0 {
                            Text("All done! 🎉").font(.custom("DMSans-Medium", size: 14)).foregroundColor(.seafoam)
                        }
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(Color.mist).frame(height: 6)
                            RoundedRectangle(cornerRadius: 4).fill(Color.oceanTeal)
                                .frame(width: geo.size.width * progress, height: 6)
                                .animation(.spring(duration: 0.3), value: progress)
                        }
                    }
                    .frame(height: 6)

                    // Auto-check pantry staples
                    Button { checkPantryStaples() } label: {
                        VStack(spacing: 2) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 14))
                                Text("Check Pantry Items").font(.custom("DMSans-Medium", size: 14))
                            }
                            Text("auto-checks salt, oils, water, spices & more")
                                .font(.custom("DMSans-Regular", size: 11))
                                .opacity(0.75)
                        }
                        .foregroundColor(.oceanTeal)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.oceanTeal.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.oceanTeal.opacity(0.25), lineWidth: 1))
                    }

                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            shopping = false; checkedItems = []; checkedExtras = []
                            hiddenIngredients = []; groupByAisle = false
                        }
                    } label: {
                        Text("Back to list").font(.custom("DMSans-Medium", size: 15)).foregroundColor(.oceanTeal)
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 16).background(Color.white)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }.foregroundColor(.oceanTeal)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await createAndShareList() }
                } label: {
                    if isCreatingShareLink {
                        ProgressView().tint(.oceanTeal)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15)).foregroundColor(.oceanTeal)
                    }
                }
                .disabled(isCreatingShareLink)
            }
        }
        // AI resolves "Other" items when user switches to By Section
        .onChange(of: groupByAisle) { _, isGrouped in
            guard isGrouped else { return }
            let otherItems = extraItems.filter { item in
                guard aiAisleOverrides[item] == nil else { return false }
                let lower = item.lowercased()
                switch listType {
                case .grocery: return groceryCategory(for: lower) == "📦 Other"
                case .hardware: return hardwareCategory(for: lower) == "📦 Other"
                case .warehouse: return warehouseCategory(for: lower) == "📦 Other"
                }
            }
            guard !otherItems.isEmpty else { return }
            Task {
                let resolved = await AppleIntelligenceService.shared.resolveAisles(for: otherItems)
                await MainActor.run {
                    for (item, aisle) in resolved {
                        aiAisleOverrides[item] = aisle
                    }
                }
            }
        }
    }

    // MARK: - Recipe Grouped View

    @ViewBuilder
    private var recipeGroupedView: some View {
        if listType == .grocery && !selectedMemories.isEmpty {
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left").font(.system(size: 10))
                    Text("swipe to remove from this trip").font(.custom("DMSans-Regular", size: 12))
                }
                .foregroundColor(.gray.opacity(0.4))
                Spacer()
            }
            .listRowSeparator(.hidden).listRowBackground(Color.clear)
        }

        ForEach(selectedMemories) { memory in
            let items = visibleSubTasks(for: memory)
            let title = memory.text.components(separatedBy: "\n").first ?? memory.text
            let checkedCount = items.filter { checkedItems.contains($0.id) }.count

            Section {
                ForEach(items.sorted { !checkedItems.contains($0.id) && checkedItems.contains($1.id) }) { subTask in
                    recipeIngredientRow(subTask: subTask)
                }
            } header: {
                HStack {
                    Text(title).font(.custom("DMSans-Medium", size: 14)).foregroundColor(.deepNavy).textCase(nil)
                    Spacer()
                    Text("\(checkedCount)/\(items.count)").font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                }
            }
        }

        extraItemsSection
    }

    // MARK: - Aisle Grouped View

    @ViewBuilder
    private var aisleGroupedView: some View {
        let allItems = aisleGroupedItems()
        let order = aisleOrderForType

        ForEach(order.filter { allItems[$0] != nil }, id: \.self) { aisle in
            if let items = allItems[aisle] {
                Section {
                    ForEach(items, id: \.id) { item in aisleItemRow(item: item) }
                } header: {
                    let checkedInAisle = items.filter { item in
                        item.isExtra ? checkedExtras.contains(item.text) : checkedItems.contains(item.subtaskId ?? UUID())
                    }.count
                    HStack {
                        Text(aisle).font(.custom("DMSans-Medium", size: 14)).foregroundColor(.deepNavy).textCase(nil)
                        Spacer()
                        Text("\(checkedInAisle)/\(items.count)").font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                    }
                }
            }
        }

        Section {
            addItemRow(text: $shoppingNewItemText, onAdd: addShoppingExtraItem)
        }
    }

    private var aisleOrderForType: [String] {
        switch listType {
        case .grocery:
            return ["🥬 Produce", "🥩 Meat", "🐟 Seafood", "🥛 Dairy & Eggs", "🧀 Deli & Prepared",
                    "🍞 Bakery & Bread", "❄️ Frozen", "🥫 Canned & Jarred", "🌾 Pasta, Rice & Grains",
                    "🥣 Breakfast", "🍿 Snacks", "🥤 Beverages", "🍷 Beer, Wine & Spirits",
                    "🫙 Condiments & Sauces", "🫒 Oils & Vinegars", "🧂 Baking & Spices",
                    "💊 Supplements", "🧴 Body Care", "🏠 Household", "🐾 Pet", "📦 Other"]
        case .hardware:
            return ["🔨 Tools & Equipment", "🪵 Lumber & Building", "🎨 Paint & Supplies",
                    "🔧 Plumbing", "⚡ Electrical", "🏠 Flooring & Tile", "🌿 Garden & Outdoor",
                    "🔩 Hardware & Fasteners", "📦 Storage & Organization", "🔒 Safety & Security", "📦 Other"]
        case .warehouse:
            return ["🥩 Meat & Seafood", "🥛 Dairy & Refrigerated", "❄️ Frozen Foods",
                    "🥫 Pantry & Canned", "🥤 Beverages", "🍿 Snacks & Candy",
                    "🏠 Household & Cleaning", "🧴 Health & Beauty", "💊 Vitamins & Supplements",
                    "💻 Electronics & Tech", "👕 Clothing & Apparel", "🏋️ Sports & Outdoors",
                    "🐾 Pet Supplies", "📦 Other"]
        }
    }

    // MARK: - Extra Items Section

    @ViewBuilder
    private var extraItemsSection: some View {
        Section {
            ForEach(extraItems.sorted { !checkedExtras.contains($0) && checkedExtras.contains($1) }, id: \.self) { item in
                let isChecked = checkedExtras.contains(item)
                Button {
                    withAnimation(.spring(duration: 0.2)) {
                        if isChecked { checkedExtras.remove(item) } else { checkedExtras.insert(item) }
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().stroke(itemAccentColor.opacity(0.5), lineWidth: 1.5).frame(width: 22, height: 22)
                            if isChecked {
                                Circle().fill(itemAccentColor).frame(width: 22, height: 22)
                                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                            }
                        }
                        Text(item).font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(isChecked ? .gray : .deepNavy).strikethrough(isChecked)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("added").font(.custom("DMSans-Regular", size: 10))
                            .foregroundColor(itemAccentColor)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(itemAccentColor.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        withAnimation { extraItems.removeAll { $0 == item }; checkedExtras.remove(item); autoSaveToday() }
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }

            addItemRow(text: $shoppingNewItemText, onAdd: addShoppingExtraItem)

            if isRecording {
                HStack(spacing: 6) {
                    Circle().fill(Color.red).frame(width: 6, height: 6)
                    Text("Listening... say your items separated by commas")
                        .font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                }
                .padding(.vertical, 4).listRowBackground(Color.red.opacity(0.04))
            }
        } header: {
            HStack {
                Text(itemsSectionHeader).font(.custom("DMSans-Medium", size: 14)).foregroundColor(.deepNavy).textCase(nil)
                Spacer()
                Text("\(checkedExtras.count)/\(extraItems.count)").font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
            }
        }
    }

    // MARK: - Shared Add Item Row

    private func addItemRow(text: Binding<String>, onAdd: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle").font(.system(size: 18)).foregroundColor(.oceanTeal.opacity(0.6))
            TextField(addItemPlaceholder, text: text)
                .font(.custom("DMSans-Regular", size: 15)).foregroundColor(.deepNavy)
                .submitLabel(.done).onSubmit { onAdd() }
            if !text.wrappedValue.isEmpty {
                Button { onAdd() } label: {
                    Text("Add").font(.custom("DMSans-Medium", size: 13)).foregroundColor(.oceanTeal)
                }
                .buttonStyle(.plain)
            } else {
                Button { toggleRecording() } label: {
                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 22)).foregroundColor(isRecording ? .red : .oceanTeal)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Row Helpers

    private func recipeIngredientRow(subTask: SubTask) -> some View {
        let isChecked = checkedItems.contains(subTask.id)
        return Button {
            withAnimation(.spring(duration: 0.2)) {
                if isChecked { checkedItems.remove(subTask.id) } else { checkedItems.insert(subTask.id) }
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().stroke(Color.oceanTeal.opacity(0.4), lineWidth: 1.5).frame(width: 22, height: 22)
                    if isChecked {
                        Circle().fill(Color.oceanTeal).frame(width: 22, height: 22)
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                    }
                }
                Text(subTask.text).font(.custom("DMSans-Regular", size: 15))
                    .foregroundColor(isChecked ? .gray : .deepNavy).strikethrough(isChecked)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("recipe").font(.custom("DMSans-Regular", size: 10))
                    .foregroundColor(.oceanTeal).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.oceanTeal.opacity(0.1)).clipShape(Capsule())
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button {
                withAnimation { hiddenIngredients.insert(subTask.id); checkedItems.remove(subTask.id) }
            } label: { Label("Remove", systemImage: "minus.circle") }
            .tint(.orange)
        }
    }

    private func aisleItemRow(item: AisleItem) -> some View {
        let isChecked = item.isExtra ? checkedExtras.contains(item.text) : checkedItems.contains(item.subtaskId ?? UUID())
        return Button {
            withAnimation(.spring(duration: 0.2)) {
                if item.isExtra {
                    if isChecked { checkedExtras.remove(item.text) } else { checkedExtras.insert(item.text) }
                } else if let id = item.subtaskId {
                    if isChecked { checkedItems.remove(id) } else { checkedItems.insert(id) }
                }
            }
        } label: {
            HStack(spacing: 12) {
                let color: Color = item.isExtra ? itemAccentColor : .oceanTeal
                ZStack {
                    Circle().stroke(color.opacity(0.4), lineWidth: 1.5).frame(width: 22, height: 22)
                    if isChecked {
                        Circle().fill(color).frame(width: 22, height: 22)
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.text).font(.custom("DMSans-Regular", size: 15))
                        .foregroundColor(isChecked ? .gray : .deepNavy).strikethrough(isChecked)
                    if let recipe = item.recipeName {
                        Text(recipe).font(.custom("DMSans-Regular", size: 11)).foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(item.isExtra ? "added" : "recipe")
                    .font(.custom("DMSans-Regular", size: 10))
                    .foregroundColor(item.isExtra ? itemAccentColor : .oceanTeal)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background((item.isExtra ? itemAccentColor : Color.oceanTeal).opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            if item.isExtra {
                Button(role: .destructive) {
                    withAnimation { extraItems.removeAll { $0 == item.text }; checkedExtras.remove(item.text); autoSaveToday() }
                } label: { Label("Delete", systemImage: "trash") }
            } else if let id = item.subtaskId {
                Button {
                    withAnimation { hiddenIngredients.insert(id); checkedItems.remove(id) }
                } label: { Label("Remove", systemImage: "minus.circle") }
                .tint(.orange)
            }
        }
    }

    // MARK: - Aisle Grouping

    struct AisleItem: Identifiable {
        let id = UUID()
        let text: String
        let isExtra: Bool
        let subtaskId: UUID?
        let recipeName: String?
    }

    private func aisleGroupedItems() -> [String: [AisleItem]] {
        var grouped: [String: [AisleItem]] = [:]
        for memory in selectedMemories {
            let title = memory.text.components(separatedBy: "\n").first ?? memory.text
            for subTask in visibleSubTasks(for: memory) {
                let category = aisleCategory(for: subTask.text)
                grouped[category, default: []].append(AisleItem(text: subTask.text, isExtra: false, subtaskId: subTask.id, recipeName: title))
            }
        }
        for extra in extraItems {
            let category = aisleCategory(for: extra)
            grouped[category, default: []].append(AisleItem(text: extra, isExtra: true, subtaskId: nil, recipeName: nil))
        }
        for key in grouped.keys {
            grouped[key] = grouped[key]?.sorted { a, b in
                let aChecked = a.isExtra ? checkedExtras.contains(a.text) : checkedItems.contains(a.subtaskId ?? UUID())
                let bChecked = b.isExtra ? checkedExtras.contains(b.text) : checkedItems.contains(b.subtaskId ?? UUID())
                return !aChecked && bChecked
            }
        }
        return grouped
    }

    private func aisleCategory(for item: String) -> String {
        // AI override first — covers items like tofu, kimchi, tempeh
        if let override = aiAisleOverrides[item] {
            return aisleDisplayLabel(for: override)
        }
        let lower = item.lowercased()
        switch listType {
        case .grocery: return groceryCategory(for: lower)
        case .hardware: return hardwareCategory(for: lower)
        case .warehouse: return warehouseCategory(for: lower)
        }
    }

    private func aisleDisplayLabel(for aisle: String) -> String {
        switch listType {
        case .grocery:
            let map: [String: String] = [
                "Produce": "🥬 Produce", "Meat": "🥩 Meat", "Seafood": "🐟 Seafood",
                "Dairy & Eggs": "🥛 Dairy & Eggs", "Deli & Prepared": "🧀 Deli & Prepared",
                "Bakery & Bread": "🍞 Bakery & Bread", "Frozen": "❄️ Frozen",
                "Canned & Jarred": "🥫 Canned & Jarred", "Pasta Rice & Grains": "🌾 Pasta, Rice & Grains",
                "Breakfast": "🥣 Breakfast", "Snacks": "🍿 Snacks", "Beverages": "🥤 Beverages",
                "Beer Wine & Spirits": "🍷 Beer, Wine & Spirits", "Condiments & Sauces": "🫙 Condiments & Sauces",
                "Oils & Vinegars": "🫒 Oils & Vinegars", "Baking & Spices": "🧂 Baking & Spices",
                "Supplements": "💊 Supplements", "Body Care": "🧴 Body Care",
                "Household": "🏠 Household", "Pet": "🐾 Pet"
            ]
            return map[aisle] ?? "📦 Other"
        case .hardware:
            let map: [String: String] = [
                "Tools & Equipment": "🔨 Tools & Equipment", "Lumber & Building": "🪵 Lumber & Building",
                "Paint & Supplies": "🎨 Paint & Supplies", "Plumbing": "🔧 Plumbing",
                "Electrical": "⚡ Electrical", "Flooring & Tile": "🏠 Flooring & Tile",
                "Garden & Outdoor": "🌿 Garden & Outdoor", "Hardware & Fasteners": "🔩 Hardware & Fasteners",
                "Storage & Organization": "📦 Storage & Organization", "Safety & Security": "🔒 Safety & Security"
            ]
            return map[aisle] ?? "📦 Other"
        case .warehouse:
            let map: [String: String] = [
                "Meat & Seafood": "🥩 Meat & Seafood", "Dairy & Refrigerated": "🥛 Dairy & Refrigerated",
                "Frozen Foods": "❄️ Frozen Foods", "Pantry & Canned": "🥫 Pantry & Canned",
                "Beverages": "🥤 Beverages", "Snacks & Candy": "🍿 Snacks & Candy",
                "Household & Cleaning": "🏠 Household & Cleaning", "Health & Beauty": "🧴 Health & Beauty",
                "Vitamins & Supplements": "💊 Vitamins & Supplements", "Electronics & Tech": "💻 Electronics & Tech",
                "Clothing & Apparel": "👕 Clothing & Apparel", "Sports & Outdoors": "🏋️ Sports & Outdoors",
                "Pet Supplies": "🐾 Pet Supplies"
            ]
            return map[aisle] ?? "📦 Other"
        }
    }

    private func groceryCategory(for lower: String) -> String {
        let produce = ["apple", "apples", "banana", "bananas", "orange", "oranges", "lemon", "lemons", "lime", "limes", "grape", "grapes", "strawberry", "strawberries", "blueberry", "blueberries", "raspberry", "raspberries", "blackberry", "blackberries", "cranberry", "cranberries", "gooseberry", "gooseberries", "cherry", "cherries", "berry", "berries", "mango", "mangoes", "pineapple", "peach", "peaches", "pear", "pears", "plum", "plums", "watermelon", "cantaloupe", "honeydew", "kiwi", "avocado", "avocados", "tomato", "tomatoes", "cucumber", "cucumbers", "zucchini", "squash", "pepper", "peppers", "jalapen", "onion", "onions", "shallot", "shallots", "garlic", "ginger", "carrot", "carrots", "celery", "broccoli", "cauliflower", "cabbage", "kale", "spinach", "lettuce", "arugula", "romaine", "chard", "beet", "beets", "turnip", "turnips", "parsnip", "parsnips", "potato", "potatoes", "sweet potato", "sweet potatoes", "yam", "yams", "corn", "mushroom", "mushrooms", "asparagus", "artichoke", "artichokes", "brussels", "eggplant", "leek", "leeks", "fennel", "radish", "radishes", "bok choy", "daikon", "scallion", "scallions", "green onion", "green onions", "chive", "chives", "cilantro", "parsley", "basil", "mint", "thyme", "rosemary", "sage", "dill", "oregano", "herb", "herbs", "sprout", "sprouts", "snap pea", "snap peas", "green bean", "green beans", "edamame", "plantain", "plantains", "papaya", "guava", "coconut", "fig", "figs", "date", "dates", "pomegranate", "pomegranates", "persimmon", "persimmons", "lychee", "tarragon", "watercress", "endive", "radicchio", "microgreen", "microgreens"]
        let meat = ["chicken", "beef", "pork", "lamb", "turkey", "veal", "duck", "bison", "venison", "steak", "ground beef", "ground turkey", "ground chicken", "breast", "thigh", "drumstick", "wing", "tenderloin", "loin", "rib", "chop", "roast", "sausage", "bacon", "ham", "prosciutto", "pancetta", "guanciale", "chorizo", "bratwurst", "hot dog", "meatball", "burger", "patty", "brisket", "chuck", "sirloin", "flank", "skirt steak", "ribeye", "filet", "short rib", "salami", "pepperoni", "kielbasa", "andouille"]
        let seafood = ["fish", "salmon", "tuna", "cod", "halibut", "tilapia", "sea bass", "mahi", "snapper", "trout", "sardine", "anchovy", "herring", "mackerel", "shrimp", "prawn", "lobster", "crab", "scallop", "clam", "mussel", "oyster", "squid", "octopus", "calamari", "seafood", "lox", "branzino", "swordfish", "catfish", "pollock", "sole", "flounder", "monkfish", "ahi"]
        let dairy = ["milk", "oat milk", "almond milk", "soy milk", "cream", "half and half", "heavy cream", "sour cream", "cream cheese", "butter", "ghee", "yogurt", "greek yogurt", "kefir", "cheese", "cheddar", "mozzarella", "parmesan", "parmigiano", "pecorino", "brie", "gouda", "gruyere", "swiss", "provolone", "feta", "ricotta", "cottage cheese", "egg", "whipped cream", "creme fraiche", "dairy", "manchego", "havarti", "colby", "monterey jack", "pepper jack", "asiago", "romano", "camembert", "gorgonzola", "burrata"]
        let deli = ["deli", "lunch meat", "pastrami", "corned beef", "mortadella", "bologna", "rotisserie", "sushi", "hummus", "tzatziki", "guacamole", "pate", "smoked salmon", "charcuterie", "prepared food", "ready to eat"]
        let bakery = ["bread", "sourdough", "baguette", "ciabatta", "focaccia", "roll", "bun", "croissant", "bagel", "english muffin", "pita", "naan", "flatbread", "tortilla", "wrap", "muffin", "scone", "danish", "brownie", "donut", "doughnut", "pretzel bread", "challah", "rye bread", "brioche", "pumpernickel", "multigrain"]
        let frozen = ["frozen", "ice cream", "gelato", "sorbet", "popsicle", "frozen pizza", "frozen meal", "frozen vegetable", "frozen fruit", "frozen shrimp", "frozen fish", "frozen chicken", "frozen waffle", "frozen burrito", "frozen dumpling", "acai pack"]
        let canned = ["canned", "can of", "tomato sauce", "tomato paste", "crushed tomato", "diced tomato", "whole tomato", "pasta sauce", "marinara", "arrabiata", "chickpea", "lentil", "black bean", "kidney bean", "pinto bean", "white bean", "cannellini", "garbanzo", "chicken broth", "beef broth", "vegetable broth", "stock", "coconut milk can", "artichoke heart", "roasted pepper", "canned olive", "pickle", "capers", "pumpkin puree", "applesauce", "soup can", "sardine can", "tuna can", "anchovy can"]
        let pasta = ["pasta", "spaghetti", "penne", "rigatoni", "fettuccine", "linguine", "tagliatelle", "farfalle", "fusilli", "rotini", "orzo", "lasagna", "macaroni", "gnocchi", "ramen noodle", "rice noodle", "udon", "soba", "vermicelli", "white rice", "brown rice", "basmati", "jasmine rice", "arborio", "wild rice", "quinoa", "farro", "barley", "couscous", "bulgur", "millet", "polenta", "grits", "oat", "oatmeal", "rolled oat", "steel cut", "all purpose flour", "bread flour", "whole wheat flour", "almond flour", "cornmeal", "panko", "breadcrumb", "buckwheat", "amaranth", "teff", "spelt"]
        let breakfast = ["cereal", "granola", "muesli", "instant oatmeal", "pancake mix", "waffle mix", "maple syrup", "honey", "jam", "jelly", "peanut butter", "almond butter", "nutella", "protein bar", "granola bar", "pop tart"]
        let snacks = ["chip", "crisp", "cracker", "pretzel", "popcorn", "trail mix", "jerky", "rice cake", "pita chip", "tortilla chip", "nacho", "cookie", "candy", "chocolate bar", "dark chocolate", "gummy", "fruit snack", "nut mix", "snack", "almond", "cashew", "walnut", "pecan", "pistachio", "peanut", "macadamia", "pine nut", "hazelnut", "brazil nut", "sunflower seed", "pumpkin seed", "mixed nuts", "dried mango", "dried cranberry", "raisin", "dried apricot", "prune"]
        let beverages = ["water bottle", "sparkling water", "seltzer", "orange juice", "apple juice", "cranberry juice", "kombucha", "iced tea", "cold brew", "matcha drink", "lemonade", "soda", "energy drink", "sports drink", "coconut water", "smoothie drink", "juice box", "gatorade", "powerade", "coffee", "espresso", "coffee bean", "ground coffee", "instant coffee", "tea bag", "loose leaf tea", "green tea", "black tea", "herbal tea", "chamomile", "chai", "la croix", "pellegrino", "perrier"]
        let alcohol = ["beer", "wine", "red wine", "white wine", "rose", "champagne", "prosecco", "cava", "vodka", "whiskey", "bourbon", "gin", "rum", "tequila", "mezcal", "sake", "hard cider", "hard seltzer", "white claw", "truly", "spirits", "six pack", "ipa", "lager", "stout", "porter"]
        let condiments = ["ketchup", "mustard", "mayo", "mayonnaise", "hot sauce", "sriracha", "tabasco", "soy sauce", "tamari", "worcestershire", "fish sauce", "oyster sauce", "hoisin", "teriyaki", "salad dressing", "vinaigrette", "ranch", "caesar dressing", "balsamic glaze", "bbq sauce", "buffalo sauce", "salsa", "pesto", "tahini", "miso", "harissa", "gochujang", "kochujang", "chili paste", "chili sauce", "steak sauce", "horseradish", "relish", "aioli", "coconut aminos", "ponzu", "sambal", "kimchi", "ssamjang", "doenjang", "fermented bean", "bean paste", "doubanjiang", "XO sauce", "black bean sauce", "hoisin sauce", "plum sauce", "sweet soy", "ketjap manis"]
        let oils = ["olive oil", "extra virgin", "vegetable oil", "canola oil", "coconut oil", "avocado oil", "sesame oil", "peanut oil", "grape seed oil", "sunflower oil", "vinegar", "balsamic", "apple cider vinegar", "rice vinegar", "white vinegar", "red wine vinegar", "sherry vinegar", "truffle oil"]
        let baking = ["sugar", "brown sugar", "powdered sugar", "baking powder", "baking soda", "yeast", "vanilla", "vanilla extract", "cocoa", "cocoa powder", "chocolate chip", "salt", "black pepper", "cumin", "paprika", "turmeric", "cinnamon", "nutmeg", "cardamom", "coriander", "cayenne", "red pepper flake", "chili powder", "curry powder", "garam masala", "italian seasoning", "bay leaf", "clove", "allspice", "star anise", "fennel seed", "poppy seed", "cornstarch", "arrowroot", "gelatin", "cream of tartar", "shortening", "lard", "cooking spray", "saffron", "sumac"]
        let supplements = ["vitamin", "supplement", "protein powder", "whey protein", "collagen", "probiotic", "omega", "fish oil", "multivitamin", "magnesium", "zinc", "iron supplement", "b12", "vitamin d", "melatonin", "creatine", "bcaa", "pre workout", "electrolyte", "ashwagandha", "spirulina", "greens powder"]
        let bodycare = ["shampoo", "conditioner", "body wash", "hand soap", "face wash", "toothpaste", "toothbrush", "floss", "mouthwash", "deodorant", "lotion", "moisturizer", "sunscreen", "razor", "shaving cream", "hair mask", "dry shampoo", "chapstick", "lip balm", "cotton swab", "cotton ball", "bandage", "ibuprofen", "tylenol", "advil", "allergy", "cold medicine"]
        let household = ["paper towel", "toilet paper", "tissue", "trash bag", "garbage bag", "zip lock", "ziploc", "foil", "aluminum foil", "plastic wrap", "parchment paper", "dish soap", "dishwasher pod", "laundry detergent", "fabric softener", "bleach", "sponge", "cleaning spray", "windex", "lysol", "hand sanitizer", "candle", "batteries", "light bulb", "dryer sheet", "dish tab"]
        let pet = ["dog food", "cat food", "pet food", "dog treat", "cat treat", "kibble", "cat litter", "dog toy", "pet supplement", "flea treatment", "heartworm", "puppy", "kitten food", "wet food pet", "pee pad", "catnip"]

        // Spice compounds must be checked before produce to prevent "garlic", "onion", "pepper" matching produce
        let spiceOverrides = ["black pepper", "white pepper", "garlic powder", "onion powder", "garlic salt", "onion salt", "chili powder", "red pepper flake", "pepper flake", "cayenne pepper"]
        if spiceOverrides.contains(where: { lower.contains($0) }) { return "🧂 Baking & Spices" }

        // Frozen and canned must be checked before produce to prevent "tomato", "corn", etc. matching produce
        if frozen.contains(where: { lower.contains($0) }) { return "❄️ Frozen" }
        if canned.contains(where: { lower.contains($0) }) { return "🥫 Canned & Jarred" }

        if produce.contains(where: { lower.contains($0) }) { return "🥬 Produce" }
        if meat.contains(where: { lower.contains($0) }) { return "🥩 Meat" }
        if seafood.contains(where: { lower.contains($0) }) { return "🐟 Seafood" }
        if dairy.contains(where: { lower.contains($0) }) { return "🥛 Dairy & Eggs" }
        if deli.contains(where: { lower.contains($0) }) { return "🧀 Deli & Prepared" }
        if bakery.contains(where: { lower.contains($0) }) { return "🍞 Bakery & Bread" }
        if oils.contains(where: { lower.contains($0) }) { return "🫒 Oils & Vinegars" }
        if pasta.contains(where: { lower.contains($0) }) { return "🌾 Pasta, Rice & Grains" }
        if breakfast.contains(where: { lower.contains($0) }) { return "🥣 Breakfast" }
        if snacks.contains(where: { lower.contains($0) }) { return "🍿 Snacks" }
        if alcohol.contains(where: { lower.contains($0) }) { return "🍷 Beer, Wine & Spirits" }
        if beverages.contains(where: { lower.contains($0) }) { return "🥤 Beverages" }
        if condiments.contains(where: { lower.contains($0) }) { return "🫙 Condiments & Sauces" }
        if baking.contains(where: { lower.contains($0) }) { return "🧂 Baking & Spices" }
        if supplements.contains(where: { lower.contains($0) }) { return "💊 Supplements" }
        if bodycare.contains(where: { lower.contains($0) }) { return "🧴 Body Care" }
        if household.contains(where: { lower.contains($0) }) { return "🏠 Household" }
        if pet.contains(where: { lower.contains($0) }) { return "🐾 Pet" }
        return "📦 Other"
    }

    private func hardwareCategory(for lower: String) -> String {
        let tools = ["drill", "saw", "hammer", "screwdriver", "wrench", "pliers", "level", "tape measure", "chisel", "utility knife", "hex key", "allen key", "socket", "ratchet", "sander", "grinder", "router", "staple gun", "nail gun", "caulk gun", "heat gun", "multimeter", "stud finder", "laser level", "tool belt", "tool box", "vacuum", "blower", "pressure washer", "generator", "compressor", "jig saw", "circular saw", "reciprocating", "oscillating", "orbital sander", "belt sander", "bench vise", "clamp", "c-clamp", "bar clamp", "miter saw", "table saw", "band saw", "tile saw", "wet saw", "angle grinder", "die grinder", "soldering"]
        let lumber = ["lumber", "wood", "plywood", "mdf", "osb", "drywall", "cement board", "subflooring", "sheathing", "stud", "joist", "rafter", "beam", "post", "board", "plank", "molding", "trim", "baseboard", "crown molding", "door casing", "window casing", "pvc trim", "hardie", "fiber cement", "particle board", "wood filler", "wood glue", "wood stain", "wood sealer", "epoxy", "concrete", "mortar", "grout", "sand", "gravel", "stone", "brick", "block", "insulation", "foam board", "spray foam", "vapor barrier", "house wrap", "tyvek"]
        let paint = ["paint", "primer", "stain", "varnish", "polyurethane", "lacquer", "sealer", "epoxy floor", "paint brush", "paint roller", "roller cover", "paint tray", "roller frame", "paint pad", "drop cloth", "painter tape", "masking tape", "sandpaper", "sanding block", "putty knife", "spackling", "joint compound", "drywall tape", "texture spray", "paint thinner", "mineral spirits", "paint stripper", "paint remover", "spray paint", "touch up", "wood conditioner", "gel stain", "chalk paint"]
        let plumbing = ["pipe", "fitting", "coupling", "elbow", "tee", "reducer", "union", "cap", "plug", "valve", "ball valve", "gate valve", "shut off", "faucet", "showerhead", "toilet", "flapper", "wax ring", "tank", "supply line", "drain", "p-trap", "overflow", "strainer", "garbage disposal", "water heater", "sump pump", "water filter", "water softener", "pex", "copper", "pvc pipe", "cpvc", "galvanized", "flux", "solder", "teflon tape", "plumber putty", "pipe dope", "thread seal", "pipe wrench", "basin wrench", "plunger", "snake", "auger", "clog", "drain cleaner"]
        let electrical = ["wire", "cable", "romex", "conduit", "outlet", "switch", "breaker", "fuse", "panel", "junction box", "electrical box", "wire nut", "electrical tape", "gfci", "afci", "dimmer", "timer", "light switch", "outlet cover", "plate", "bulb", "light bulb", "led", "fluorescent", "fixture", "recessed light", "ceiling fan", "exhaust fan", "smoke detector", "carbon monoxide", "thermostat", "doorbell", "transformer", "relay", "voltage", "extension cord", "power strip", "surge protector", "ground", "neutral", "hot wire", "ethernet", "coax", "speaker wire", "low voltage", "data cable"]
        let flooring = ["flooring", "tile", "ceramic", "porcelain", "hardwood", "laminate", "vinyl plank", "lvp", "lvt", "carpet", "area rug", "underlayment", "subfloor", "floor adhesive", "thinset", "grout", "grout sealer", "tile spacer", "floor leveler", "transition strip", "threshold", "reducer strip", "t-molding", "floor nailer", "floor scraper", "knee pad", "floor finish", "floor wax", "floor cleaner"]
        let garden = ["shovel", "spade", "rake", "hoe", "trowel", "pruner", "shear", "hedge trimmer", "lawn mower", "weed wacker", "string trimmer", "edger", "leaf blower", "garden hose", "sprinkler", "drip irrigation", "soaker hose", "hose reel", "hose nozzle", "watering can", "planter", "pot", "raised bed", "garden bed", "soil", "mulch", "compost", "fertilizer", "weed killer", "herbicide", "pesticide", "insecticide", "plant food", "seed", "bulb", "plant", "shrub", "tree", "garden glove", "kneeling pad", "wheelbarrow", "garden cart", "bird feeder", "bird bath", "fence post", "fence panel", "garden stake", "trellis", "garden edging", "stepping stone", "paver", "retaining wall"]
        let hardware = ["screw", "nail", "bolt", "nut", "washer", "anchor", "toggle bolt", "lag screw", "wood screw", "drywall screw", "machine screw", "sheet metal screw", "eye bolt", "hook", "hanger", "bracket", "corner brace", "mending plate", "joist hanger", "post base", "post cap", "hurricane tie", "staple", "tack", "brad", "finishing nail", "common nail", "roofing nail", "masonry nail", "rivet", "pop rivet", "thread insert", "t-nut", "barrel nut", "coupling nut"]
        let storage = ["shelf", "shelving", "shelf bracket", "wire shelf", "storage rack", "garage cabinet", "tool cabinet", "drawer", "bin", "storage bin", "tote", "storage box", "pegboard", "hook", "wall organizer", "closet organizer", "storage system", "cabinet hardware", "door handle", "drawer pull", "hinge", "cabinet hinge", "door hinge", "piano hinge", "soft close", "drawer slide", "lazy susan", "shelf liner", "storage container", "plastic bin"]
        let safety = ["safety glass", "goggles", "safety glasses", "respirator", "dust mask", "ear plug", "ear muff", "hard hat", "safety vest", "work glove", "knee pad", "back brace", "first aid", "fire extinguisher", "smoke detector", "carbon monoxide detector", "deadbolt", "door lock", "padlock", "combination lock", "security camera", "motion sensor", "door alarm", "window alarm", "garage door", "door closer", "door stop", "door sweep", "weatherstrip", "door threshold", "window lock", "safe", "lock box"]

        if tools.contains(where: { lower.contains($0) }) { return "🔨 Tools & Equipment" }
        if lumber.contains(where: { lower.contains($0) }) { return "🪵 Lumber & Building" }
        if paint.contains(where: { lower.contains($0) }) { return "🎨 Paint & Supplies" }
        if plumbing.contains(where: { lower.contains($0) }) { return "🔧 Plumbing" }
        if electrical.contains(where: { lower.contains($0) }) { return "⚡ Electrical" }
        if flooring.contains(where: { lower.contains($0) }) { return "🏠 Flooring & Tile" }
        if garden.contains(where: { lower.contains($0) }) { return "🌿 Garden & Outdoor" }
        if hardware.contains(where: { lower.contains($0) }) { return "🔩 Hardware & Fasteners" }
        if storage.contains(where: { lower.contains($0) }) { return "📦 Storage & Organization" }
        if safety.contains(where: { lower.contains($0) }) { return "🔒 Safety & Security" }
        return "📦 Other"
    }

    private func warehouseCategory(for lower: String) -> String {
        let meat = ["chicken", "beef", "pork", "lamb", "turkey", "steak", "ground", "sausage", "bacon", "ham", "hot dog", "salmon", "shrimp", "fish", "seafood", "tuna", "crab", "lobster", "scallop", "rotisserie"]
        let dairy = ["milk", "cheese", "butter", "yogurt", "cream", "egg", "cream cheese", "sour cream", "half and half", "cottage cheese", "ghee", "dairy", "kefir", "whipped cream"]
        let frozen = ["frozen", "ice cream", "gelato", "sorbet", "popsicle", "frozen pizza", "frozen meal", "frozen vegetable", "frozen fruit", "frozen chicken", "frozen waffle", "frozen burrito", "frozen dumpling", "acai"]
        let pantry = ["rice", "pasta", "flour", "sugar", "oil", "vinegar", "sauce", "can", "canned", "broth", "stock", "beans", "lentils", "oat", "cereal", "granola", "peanut butter", "almond butter", "jam", "jelly", "honey", "maple syrup", "tomato", "coconut milk", "soup", "condiment", "ketchup", "mustard", "mayo", "soy sauce"]
        let beverages = ["water", "juice", "coffee", "tea", "soda", "sparkling", "energy drink", "sports drink", "kombucha", "coconut water", "gatorade", "protein shake", "smoothie", "lemonade", "cold brew", "espresso"]
        let snacks = ["chip", "cracker", "cookie", "candy", "chocolate", "trail mix", "nut", "almond", "cashew", "popcorn", "jerky", "protein bar", "granola bar", "pretzel", "rice cake", "dried fruit", "gummy"]
        let household = ["paper towel", "toilet paper", "tissue", "trash bag", "garbage bag", "zip lock", "ziploc", "foil", "aluminum foil", "plastic wrap", "dish soap", "dishwasher", "laundry detergent", "fabric softener", "bleach", "cleaning spray", "hand soap", "hand sanitizer", "sponge", "mop", "broom", "dryer sheet", "parchment paper", "candle", "batteries", "light bulb"]
        let health = ["shampoo", "conditioner", "body wash", "face wash", "lotion", "moisturizer", "sunscreen", "toothpaste", "toothbrush", "deodorant", "razor", "floss", "mouthwash", "bandage", "advil", "tylenol", "ibuprofen", "allergy", "cold medicine", "first aid", "thermometer"]
        let supplements = ["vitamin", "supplement", "protein powder", "whey protein", "collagen", "probiotic", "omega", "fish oil", "multivitamin", "magnesium", "zinc", "melatonin", "creatine", "bcaa", "pre workout", "electrolyte", "ashwagandha", "greens powder", "b12", "vitamin d"]
        let electronics = ["tv", "monitor", "laptop", "computer", "tablet", "ipad", "phone", "charger", "cable", "hdmi", "usb", "speaker", "headphone", "earbuds", "airpods", "keyboard", "mouse", "printer", "ink", "battery", "power bank", "smart watch", "camera", "drone", "gaming", "controller", "router", "wifi", "smart home", "alexa", "google home", "ring doorbell"]
        let clothing = ["shirt", "pants", "jacket", "coat", "sweater", "hoodie", "socks", "underwear", "shoes", "boots", "sneakers", "jeans", "dress", "shorts", "leggings", "activewear", "swimsuit", "hat", "gloves", "scarf", "belt", "watch", "bag", "backpack", "luggage"]
        let sports = ["gym", "workout", "exercise", "weight", "dumbbell", "barbell", "kettlebell", "resistance band", "yoga mat", "foam roller", "treadmill", "bike", "kayak", "camping", "tent", "sleeping bag", "hiking", "golf", "tennis", "basketball", "baseball", "football", "soccer", "swim", "goggles", "helmet", "sport", "athletic", "running shoe", "cleat"]
        let pet = ["dog food", "cat food", "pet food", "dog treat", "cat treat", "kibble", "cat litter", "dog toy", "pet supplement", "flea treatment", "heartworm", "puppy", "kitten food", "wet food", "pee pad", "catnip", "bird seed", "fish food", "aquarium", "pet bed", "leash", "collar", "harness", "crate"]

        if meat.contains(where: { lower.contains($0) }) { return "🥩 Meat & Seafood" }
        if dairy.contains(where: { lower.contains($0) }) { return "🥛 Dairy & Refrigerated" }
        if frozen.contains(where: { lower.contains($0) }) { return "❄️ Frozen Foods" }
        if pantry.contains(where: { lower.contains($0) }) { return "🥫 Pantry & Canned" }
        if beverages.contains(where: { lower.contains($0) }) { return "🥤 Beverages" }
        if snacks.contains(where: { lower.contains($0) }) { return "🍿 Snacks & Candy" }
        if household.contains(where: { lower.contains($0) }) { return "🏠 Household & Cleaning" }
        if health.contains(where: { lower.contains($0) }) { return "🧴 Health & Beauty" }
        if supplements.contains(where: { lower.contains($0) }) { return "💊 Vitamins & Supplements" }
        if electronics.contains(where: { lower.contains($0) }) { return "💻 Electronics & Tech" }
        if clothing.contains(where: { lower.contains($0) }) { return "👕 Clothing & Apparel" }
        if sports.contains(where: { lower.contains($0) }) { return "🏋️ Sports & Outdoors" }
        if pet.contains(where: { lower.contains($0) }) { return "🐾 Pet Supplies" }
        return "📦 Other"
    }

    // MARK: - Voice Recording

    private func toggleRecording() {
        if isRecording { stopRecording() } else { startRecording() }
    }

    private func startRecording() {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else { return }
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                guard granted else { return }
                DispatchQueue.main.async { beginRecording() }
            }
        }
    }

    private func beginRecording() {
        recognitionTask?.cancel()
        recognitionTask = nil
        audioEngine.stop()
        audioEngine.reset()

        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                DispatchQueue.main.async { self.currentTranscription = result.bestTranscription.formattedString }
                if result.isFinal {
                    let transcript = result.bestTranscription.formattedString
                    DispatchQueue.main.async { self.processVoiceItems(transcript); self.isRecording = false }
                }
            }
            if error != nil {
                DispatchQueue.main.async { self.isRecording = false }
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        audioEngine.prepare()
        try? audioEngine.start()
        isRecording = true
    }

    private func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if !currentTranscription.isEmpty {
            processVoiceItems(currentTranscription)
            currentTranscription = ""
        }
    }

    private func extractItems(from chunk: String) -> [String] {
        let words = chunk.components(separatedBy: " ").filter { !$0.isEmpty }
        let hasNumber = chunk.range(of: #"\d"#, options: .regularExpression) != nil
        if hasNumber { return [chunk] }
        var results: [String] = []
        var i = 0
        while i < words.count {
            if i + 2 < words.count {
                let threeWord = "\(words[i]) \(words[i+1]) \(words[i+2])".lowercased()
                if knownCompounds.contains(where: { threeWord.contains($0) }) {
                    results.append("\(words[i]) \(words[i+1]) \(words[i+2])")
                    i += 3; continue
                }
            }
            if i + 1 < words.count {
                let twoWord = "\(words[i]) \(words[i+1])".lowercased()
                if knownCompounds.contains(where: { twoWord.contains($0) }) {
                    results.append("\(words[i]) \(words[i+1])")
                    i += 2; continue
                }
            }
            results.append(words[i])
            i += 1
        }
        return results
    }

    // MARK: - Auto Save / Restore

    private func autoSaveToday() {
        if isCustomActive {
            if let customList = activeCustomList {
                customList.extraItems = extraItems
            }
            return
        }
        let todayName = "Today's list"
        if let existing = savedLists.first(where: { $0.name == todayName && $0.listType == listType.rawValue }) {
            existing.memoryIds = Array(selectedMemoryIds).map { $0.uuidString }
            existing.extraItems = extraItems
        } else {
            let list = GroceryList(name: todayName, listType: listType.rawValue, memoryIds: Array(selectedMemoryIds), extraItems: extraItems)
            modelContext.insert(list)
        }
    }

    private func restoreToday() {
        guard !isCustomActive else { return }
        guard let today = savedLists.first(where: { $0.name == "Today's list" && $0.listType == listType.rawValue }) else { return }
        selectedMemoryIds = Set(today.memoryUUIDs.filter { id in recipeMemories.contains { $0.id == id } })
        extraItems = today.extraItems
    }

    // MARK: - Helpers

    private func processVoiceItems(_ transcript: String) {
        let firstPass = transcript
            .components(separatedBy: ",")
            .flatMap { $0.components(separatedBy: " and ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var finalItems: [String] = []
        for chunk in firstPass {
            finalItems.append(contentsOf: extractItems(from: chunk))
        }

        for item in finalItems {
            let trimmed = item.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, trimmed.count > 1 else { continue }
            let capitalized = trimmed.prefix(1).uppercased() + trimmed.dropFirst().lowercased()
            if !extraItems.contains(capitalized) { extraItems.append(capitalized) }
        }
        autoSaveToday()
    }

    private func addExtraItem() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        extraItems.append(trimmed)
        newItemText = ""
        autoSaveToday()
    }

    private func addShoppingExtraItem() {
        let trimmed = shoppingNewItemText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        extraItems.append(trimmed)
        shoppingNewItemText = ""
        autoSaveToday()
    }
    private func loadList(_ list: GroceryList) {
        if let type = ListType(rawValue: list.listType) { listType = type }
        selectedMemoryIds = Set(list.memoryUUIDs.filter { id in recipeMemories.contains { $0.id == id } })
        extraItems = list.extraItems
        activeCustomListId = nil
    }

    private func fetchAndSaveRecipe() {
        guard !recipeURLInput.isEmpty else { return }
        isFetchingRecipe = true
        recipeFetchError = nil
        Task {
            do {
                let recipe = try await RecipeExtractor.shared.extract(from: recipeURLInput)
                await MainActor.run {
                    isFetchingRecipe = false
                    fetchedRecipe = recipe
                    showURLInputSheet = false
                    showRecipePreview = true
                }
            } catch {
                await MainActor.run {
                    isFetchingRecipe = false
                    recipeFetchError = error.localizedDescription
                }
            }
        }
    }

    private func saveReviewedRecipe(_ recipe: RecipeResult) {
        let descriptor = FetchDescriptor<Echo>()
        let echos = (try? modelContext.fetch(descriptor)) ?? []
        let cookingEcho = echos.first {
            $0.name.lowercased().contains("cook") ||
            $0.name.lowercased().contains("recipe") ||
            $0.emoji == "🍳" || $0.emoji == "🍽️"
        } ?? echos.first

        guard let echoId = cookingEcho?.id else { return }

        var parts: [String] = ["🍽 \(recipe.title)"]
        var meta: [String] = []
        if let prep = recipe.prepTime { meta.append("Prep: \(prep)") }
        if let cook = recipe.cookTime { meta.append("Cook: \(cook)") }
        if let srv = recipe.servings { meta.append("Serves: \(srv)") }
        if !meta.isEmpty { parts.append(meta.joined(separator: " · ")) }
        if !recipe.instructions.isEmpty {
            parts.append("\nInstructions:")
            for (i, step) in recipe.instructions.enumerated() {
                parts.append("\(i + 1). \(step)")
            }
        }

        let memory = Memory(text: parts.joined(separator: "\n"), echoId: echoId)
        memory.url = recipeURLInput
        memory.hasChecklist = !recipe.ingredients.isEmpty
        modelContext.insert(memory)

        for (index, ingredient) in recipe.ingredients.enumerated() {
            let subTask = SubTask(memoryId: memory.id, text: ingredient, sortOrder: index)
            modelContext.insert(subTask)
        }

        selectedMemoryIds.insert(memory.id)
        autoSaveToday()
        showRecipePreview = false
        fetchedRecipe = nil
        recipeURLInput = ""
    }
}

// MARK: - Share Sheet

import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

