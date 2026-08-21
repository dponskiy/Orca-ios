//
//  GroceryAisles.swift
//  Orca
//
//  Shared by the personal grocery list and the household one. Extracted rather than
//  copied so the two can't drift — a shared list that sorted differently from your
//  own would be its own kind of bug.
//

import Foundation

enum GroceryAisles {
    /// Store order for a grocery trip — produce first, household last.
    static let groceryOrder: [String] = [
        "🥬 Produce", "🥩 Meat", "🐟 Seafood", "🥛 Dairy & Eggs", "🧀 Deli & Prepared",
        "🍞 Bakery & Bread", "❄️ Frozen", "🥫 Canned & Jarred", "🌾 Pasta, Rice & Grains",
        "🥣 Breakfast", "🍿 Snacks", "🥤 Beverages", "🍷 Beer, Wine & Spirits",
        "🫙 Condiments & Sauces", "🫒 Oils & Vinegars", "🧂 Baking & Spices",
        "💊 Supplements", "🧴 Body Care", "🏠 Household", "🐾 Pet", "📦 Other"
    ]

    /// Short words that would wrongly match inside longer ones — "pea" is a
    /// substring of "peanut butter", "rice" of "rice vinegar". Matched whole,
    /// before any substring rule runs. Note the merged item name is singularised,
    /// so "peas" arrives here as "pea".
    private static let wholeWordAisles: [String: String] = [
        "pea": "🥬 Produce",
        "peas": "🥬 Produce",
        "water": "🥤 Beverages",
        "rice": "🌾 Pasta, Rice & Grains",
        "ice": "❄️ Frozen",
        "oil": "🫒 Oils & Vinegars",
        "salt": "🧂 Baking & Spices",
        "flour": "🧂 Baking & Spices",
        "sugar": "🧂 Baking & Spices"
    ]

    static func category(for item: String) -> String {
        let lower = item.lowercased()
        if let exact = wholeWordAisles[lower.trimmingCharacters(in: .whitespacesAndNewlines)] {
            return exact
        }

        let produce = ["apple", "apples", "banana", "bananas", "orange", "oranges", "lemon", "lemons", "lime", "limes", "grape", "grapes", "strawberry", "strawberries", "blueberry", "blueberries", "raspberry", "raspberries", "blackberry", "blackberries", "cranberry", "cranberries", "gooseberry", "gooseberries", "cherry", "cherries", "berry", "berries", "mango", "mangoes", "pineapple", "peach", "peaches", "pear", "pears", "plum", "plums", "watermelon", "cantaloupe", "honeydew", "kiwi", "avocado", "avocados", "tomato", "tomatoes", "cucumber", "cucumbers", "zucchini", "squash", "pepper", "peppers", "jalapen", "jalapeño", "jalapeños", "jalapeno", "jalapenos", "poblano", "serrano", "habanero", "chile", "chiles", "onion", "onions", "shallot", "shallots", "garlic", "ginger", "carrot", "carrots", "celery", "broccoli", "cauliflower", "cabbage", "kale", "spinach", "lettuce", "arugula", "romaine", "chard", "beet", "beets", "turnip", "turnips", "parsnip", "parsnips", "potato", "potatoes", "sweet potato", "sweet potatoes", "yam", "yams", "corn", "mushroom", "mushrooms", "asparagus", "artichoke", "artichokes", "brussels", "eggplant", "leek", "leeks", "fennel", "radish", "radishes", "bok choy", "daikon", "scallion", "scallions", "green onion", "green onions", "chive", "chives", "cilantro", "parsley", "basil", "mint", "thyme", "rosemary", "sage", "dill", "oregano", "herb", "herbs", "sprout", "sprouts", "snap pea", "snap peas", "green bean", "green beans", "edamame", "plantain", "plantains", "papaya", "guava", "coconut", "fig", "figs", "date", "dates", "pomegranate", "pomegranates", "persimmon", "persimmons", "lychee", "tarragon", "watercress", "endive", "radicchio", "microgreen", "microgreens", "tofu", "tempeh", "silken tofu", "firm tofu", "extra firm tofu"]
        let meat = ["chicken", "beef", "pork", "lamb", "turkey", "veal", "duck", "bison", "venison", "steak", "ground beef", "ground turkey", "ground chicken", "breast", "thigh", "drumstick", "wing", "tenderloin", "loin", "rib", "pork chop", "lamb chop", "veal chop", "roast", "sausage", "bacon", "ham", "prosciutto", "pancetta", "guanciale", "chorizo", "bratwurst", "hot dog", "meatball", "meatloaf", "burger", "patty", "brisket", "chuck", "sirloin", "flank", "skirt steak", "ribeye", "filet", "short rib", "salami", "pepperoni", "kielbasa", "andouille"]
        let seafood = ["fish", "salmon", "tuna", "cod", "halibut", "tilapia", "sea bass", "mahi", "snapper", "trout", "sardine", "anchovy", "herring", "mackerel", "shrimp", "prawn", "lobster", "crab", "scallop", "clam", "mussel", "oyster", "squid", "octopus", "calamari", "seafood", "lox", "branzino", "swordfish", "catfish", "pollock", "sole", "flounder", "monkfish", "ahi"]
        let dairy = ["milk", "oat milk", "almond milk", "soy milk", "cream", "half and half", "heavy cream", "sour cream", "cream cheese", "butter", "ghee", "yogurt", "greek yogurt", "kefir", "cheese", "cheddar", "mozzarella", "parmesan", "parmigiano", "pecorino", "brie", "gouda", "gruyere", "swiss", "provolone", "feta", "ricotta", "cottage cheese", "egg", "whipped cream", "creme fraiche", "dairy", "manchego", "havarti", "colby", "monterey jack", "pepper jack", "asiago", "romano", "camembert", "gorgonzola", "burrata"]
        let deli = ["deli", "lunch meat", "pastrami", "corned beef", "mortadella", "bologna", "rotisserie", "sushi", "hummus", "tzatziki", "guacamole", "pate", "smoked salmon", "charcuterie", "prepared food", "ready to eat"]
        let bakery = ["bread", "sourdough", "baguette", "ciabatta", "focaccia", "roll", "bun", "croissant", "bagel", "english muffin", "pita", "naan", "flatbread", "tortilla", "wrap", "muffin", "scone", "danish", "brownie", "donut", "doughnut", "pretzel bread", "challah", "rye bread", "brioche", "pumpernickel", "multigrain"]
        let frozen = ["frozen", "ice cream", "gelato", "sorbet", "popsicle", "frozen pizza", "frozen meal", "frozen vegetable", "frozen fruit", "frozen shrimp", "frozen fish", "frozen chicken", "frozen waffle", "frozen burrito", "frozen dumpling", "acai pack"]
        let canned = ["canned", "can of", "jar", "tomato sauce", "tomato paste", "crushed tomato", "diced tomato", "whole tomato", "pasta sauce", "marinara", "arrabiata", "chickpea", "lentil", "black bean", "kidney bean", "pinto bean", "white bean", "cannellini", "garbanzo", "butter bean", "butter beans", "navy bean", "great northern bean", "chicken broth", "beef broth", "vegetable broth", "stock", "coconut milk can", "artichoke heart", "roasted pepper", "roasted red pepper", "canned olive", "pickle", "capers", "pumpkin puree", "applesauce", "soup can", "sardine can", "tuna can", "anchovy can"]
        let pasta = ["pasta", "spaghetti", "penne", "rigatoni", "fettuccine", "linguine", "tagliatelle", "farfalle", "fusilli", "rotini", "orzo", "lasagna", "macaroni", "gnocchi", "ramen noodle", "rice noodle", "udon", "soba", "vermicelli", "white rice", "brown rice", "basmati", "jasmine rice", "arborio", "wild rice", "grain rice", "sushi rice", "sticky rice", "rice pilaf", "black rice", "red rice", "quinoa", "farro", "barley", "couscous", "bulgur", "millet", "polenta", "grits", "oat", "oatmeal", "rolled oat", "steel cut", "panko", "breadcrumb", "buckwheat", "amaranth", "teff", "spelt"]
        let breakfast = ["cereal", "granola", "muesli", "instant oatmeal", "pancake mix", "waffle mix", "maple syrup", "honey", "jam", "jelly", "peanut butter", "almond butter", "nutella", "protein bar", "granola bar", "pop tart"]
        let snacks = ["chip", "crisp", "cracker", "pretzel", "popcorn", "trail mix", "jerky", "rice cake", "pita chip", "tortilla chip", "nacho", "cookie", "candy", "chocolate bar", "dark chocolate", "gummy", "fruit snack", "nut mix", "snack", "almond", "cashew", "walnut", "pecan", "pistachio", "peanut", "macadamia", "pine nut", "hazelnut", "brazil nut", "sunflower seed", "pumpkin seed", "mixed nuts", "dried mango", "dried cranberry", "raisin", "dried apricot", "prune"]
        let beverages = ["water bottle", "sparkling water", "seltzer", "orange juice", "apple juice", "cranberry juice", "kombucha", "iced tea", "cold brew", "matcha drink", "lemonade", "soda", "energy drink", "sports drink", "coconut water", "smoothie drink", "juice box", "gatorade", "powerade", "coffee", "espresso", "coffee bean", "ground coffee", "instant coffee", "tea bag", "loose leaf tea", "green tea", "black tea", "herbal tea", "chamomile", "chai", "la croix", "pellegrino", "perrier"]
        let alcohol = ["beer", "wine", "red wine", "white wine", "rose", "champagne", "prosecco", "cava", "vodka", "whiskey", "bourbon", "gin", "rum", "tequila", "mezcal", "sake", "hard cider", "hard seltzer", "white claw", "truly", "spirits", "six pack", "ipa", "lager", "stout", "porter"]
        let condiments = ["ketchup", "mustard", "mayo", "mayonnaise", "hot sauce", "sriracha", "tabasco", "soy sauce", "tamari", "worcestershire", "fish sauce", "oyster sauce", "hoisin", "teriyaki", "salad dressing", "vinaigrette", "ranch", "caesar dressing", "balsamic glaze", "bbq sauce", "buffalo sauce", "salsa", "pesto", "tahini", "miso", "harissa", "gochujang", "kochujang", "chili paste", "chili sauce", "steak sauce", "horseradish", "relish", "aioli", "coconut aminos", "ponzu", "sambal", "kimchi", "ssamjang", "doenjang", "fermented bean", "bean paste", "doubanjiang", "XO sauce", "black bean sauce", "hoisin sauce", "plum sauce", "sweet soy", "ketjap manis"]
        let oils = ["olive oil", "extra virgin", "vegetable oil", "canola oil", "coconut oil", "avocado oil", "sesame oil", "peanut oil", "grape seed oil", "sunflower oil", "vinegar", "balsamic", "apple cider vinegar", "rice vinegar", "white vinegar", "red wine vinegar", "sherry vinegar", "truffle oil"]
        let baking = ["sugar", "brown sugar", "powdered sugar", "baking powder", "baking soda", "yeast", "vanilla", "vanilla extract", "cocoa", "cocoa powder", "chocolate chip", "salt", "black pepper", "cumin", "paprika", "turmeric", "cinnamon", "nutmeg", "cardamom", "coriander", "cayenne", "red pepper flake", "chili powder", "curry powder", "garam masala", "italian seasoning", "bay leaf", "clove", "allspice", "five spice", "five-spice", "garam masala", "herbes de provence", "za'atar", "ras el hanout", "everything bagel seasoning", "italian seasoning", "poultry seasoning", "pumpkin pie spice", "old bay", "star anise", "fennel seed", "poppy seed", "sesame seed", "sesame seeds", "toasted sesame", "flax seed", "flaxseed", "chia seed", "chia seeds", "hemp seed", "hemp seeds", "cornstarch", "arrowroot", "gelatin", "cream of tartar", "shortening", "lard", "cooking spray", "saffron", "sumac"]
        let supplements = ["vitamin", "supplement", "protein powder", "whey protein", "collagen", "probiotic", "omega", "fish oil", "multivitamin", "magnesium", "zinc", "iron supplement", "b12", "vitamin d", "melatonin", "creatine", "bcaa", "pre workout", "electrolyte", "ashwagandha", "spirulina", "greens powder"]
        let bodycare = ["shampoo", "conditioner", "body wash", "hand soap", "face wash", "toothpaste", "toothbrush", "floss", "mouthwash", "deodorant", "lotion", "moisturizer", "sunscreen", "razor", "shaving cream", "hair mask", "dry shampoo", "chapstick", "lip balm", "cotton swab", "cotton ball", "bandage", "ibuprofen", "tylenol", "advil", "allergy", "cold medicine"]
        let household = ["paper towel", "toilet paper", "tissue", "trash bag", "garbage bag", "zip lock", "ziploc", "foil", "aluminum foil", "plastic wrap", "parchment paper", "dish soap", "dishwasher pod", "laundry detergent", "fabric softener", "bleach", "sponge", "cleaning spray", "windex", "lysol", "hand sanitizer", "candle", "batteries", "light bulb", "dryer sheet", "dish tab"]
        let pet = ["dog food", "cat food", "pet food", "dog treat", "cat treat", "kibble", "cat litter", "dog toy", "pet supplement", "flea treatment", "heartworm", "puppy", "kitten food", "wet food pet", "pee pad", "catnip"]

        // Flour must be checked before pasta/grains to prevent "all purpose flour" matching grains
        let flourOverrides = ["all purpose flour", "all-purpose flour", "bread flour", "whole wheat flour", "almond flour", "coconut flour", "cake flour", "self rising flour", "cornmeal", "corn meal", "corn starch", "cornstarch", "rice flour", "oat flour", "rye flour", "spelt flour", "plain flour"]
        if flourOverrides.contains(where: { lower.contains($0) }) { return "🧂 Baking & Spices" }

        // Spice compounds must be checked before produce to prevent "garlic", "onion", "pepper" matching produce
        let spiceOverrides = ["black pepper", "white pepper", "garlic powder", "onion powder", "garlic salt", "onion salt", "chili powder", "red pepper flake", "pepper flake", "cayenne pepper", "crushed red pepper", "crushed pepper"]
        if spiceOverrides.contains(where: { lower.contains($0) }) { return "🧂 Baking & Spices" }

        // "1 tsp pepper" = spice; "1 pepper" or "2 red peppers" = produce.
        // If a measurement unit is present alongside "pepper"/"garlic"/"ginger"/"onion", treat as spice.
        let measurementUnits = ["tsp", "teaspoon", "tbsp", "tablespoon", "cup", " oz ", "ounce", " g ", "gram", "ml", "pinch", "dash", "lb ", "pound"]
        let hasMeasurement = measurementUnits.contains(where: { lower.contains($0) })
        if hasMeasurement {
            let spiceProduceWords = ["pepper", "garlic", "ginger", "onion"]
            if spiceProduceWords.contains(where: { lower.contains($0) }) { return "🧂 Baking & Spices" }
        }

        // Cheese compounds must be checked before produce to prevent "pepper" matching produce
        let dairyOverrides = ["pepper jack", "monterey jack", "string cheese"]
        if dairyOverrides.contains(where: { lower.contains($0) }) { return "🥛 Dairy & Eggs" }

        // Canned compounds must be checked before produce to prevent "corn" matching produce
        let cannedOverrides = ["creamed corn", "cream corn"]
        if cannedOverrides.contains(where: { lower.contains($0) }) { return "🥫 Canned & Jarred" }

        // Vinegar/oil must be checked before meat — "champagne" contains substring "ham"
        // and generic "oil" (neutral oil, grapeseed oil, etc.) won't match specific oil names
        if lower.contains("vinegar") { return "🫒 Oils & Vinegars" }
        if lower.hasSuffix("oil") && !lower.contains("fish oil") && !lower.contains("cod liver") { return "🫒 Oils & Vinegars" }

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
}

// MARK: - Ingredient parsing

enum IngredientParser {

    struct Parsed {
        let value: Double?
        let unit: String?      // canonical, e.g. "cup", "tbsp"
        let key: String        // normalized name used for merging
        let displayName: String
    }

    private static let unitMap: [String: String] = [
        "cup": "cup", "cups": "cup", "c": "cup",
        "tablespoon": "tbsp", "tablespoons": "tbsp", "tbsp": "tbsp", "tbs": "tbsp", "tbl": "tbsp",
        "teaspoon": "tsp", "teaspoons": "tsp", "tsp": "tsp",
        "ounce": "oz", "ounces": "oz", "oz": "oz",
        "pound": "lb", "pounds": "lb", "lb": "lb", "lbs": "lb",
        "gram": "g", "grams": "g", "g": "g",
        "kilogram": "kg", "kilograms": "kg", "kg": "kg",
        "milliliter": "ml", "milliliters": "ml", "ml": "ml",
        "liter": "l", "liters": "l", "litre": "l", "litres": "l",
        "clove": "clove", "cloves": "clove",
        "can": "can", "cans": "can",
        "jar": "jar", "jars": "jar",
        "slice": "slice", "slices": "slice",
        "bunch": "bunch", "bunches": "bunch",
        "head": "head", "heads": "head",
        "stick": "stick", "sticks": "stick",
        "package": "pkg", "packages": "pkg", "pkg": "pkg",
        "piece": "piece", "pieces": "piece",
        "bag": "bag", "bags": "bag",
        "box": "box", "boxes": "box",
        "bottle": "bottle", "bottles": "bottle",
        "stalk": "stalk", "stalks": "stalk",
        "sprig": "sprig", "sprigs": "sprig",
        "ear": "ear", "ears": "ear",
        "fillet": "fillet", "fillets": "fillet", "filet": "fillet", "filets": "fillet",
        "pinch": "pinch", "pinches": "pinch",
        "dash": "dash", "dashes": "dash",
    ]

    // Word-style units pluralize in summaries ("5 cloves"); abbreviations don't ("3 tbsp")
    private static let wordUnits: Set<String> = ["cup", "clove", "can", "jar", "slice", "bunch", "head",
                                                 "stick", "piece", "bag", "box", "bottle", "stalk",
                                                 "sprig", "ear", "fillet", "pinch", "dash"]

    // Prep words stripped for matching — "onion, diced" merges with "2 onions".
    // Distinguishing words (red, ground, boneless…) are deliberately kept so
    // different products never merge.
    private static let descriptorWords: Set<String> = [
        "chopped", "minced", "diced", "sliced", "grated", "shredded", "melted", "softened",
        "beaten", "peeled", "crushed", "drained", "rinsed", "divided", "optional",
        "fresh", "freshly", "finely", "thinly", "roughly", "coarsely", "lightly",
        "large", "small", "medium", "ripe", "halved", "quartered", "cubed", "trimmed",
        "packed", "heaping", "cooked", "uncooked"
    ]

    private static let unicodeFractions: [Character: Double] = [
        "½": 0.5, "⅓": 1.0/3.0, "⅔": 2.0/3.0, "¼": 0.25, "¾": 0.75,
        "⅕": 0.2, "⅖": 0.4, "⅗": 0.6, "⅛": 0.125, "⅜": 0.375, "⅝": 0.625, "⅞": 0.875
    ]

    static func parse(_ raw: String) -> Parsed {
        // Prep notes live after the first comma ("garlic, minced") — ignore them
        let beforeComma = raw.components(separatedBy: ",").first ?? raw
        let cleaned = beforeComma
            .replacingOccurrences(of: "⁄", with: "/")  // OCR fraction slash (U+2044) → plain slash
            .replacingOccurrences(of: #"\([^)]*\)"#, with: " ", options: .regularExpression)
        var tokens = cleaned.lowercased()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        // Glued metric amounts from cookbook scans: "250g" / "500ml" → "250" + "g"
        if let first = tokens.first,
           first.range(of: #"^\d+(\.\d+)?[a-z]+$"#, options: .regularExpression) != nil {
            let digits = first.prefix { $0.isNumber || $0 == "." }
            let alpha = first.drop { $0.isNumber || $0 == "." }
            if unitMap[String(alpha)] != nil {
                tokens[0] = String(digits)
                tokens.insert(String(alpha), at: 1)
            }
        }

        var value: Double? = nil
        if let first = tokens.first, let v = numericValue(first) {
            value = v
            tokens.removeFirst()
            // "1 1/2 cups" — a second numeric token adds on
            if let second = tokens.first, let v2 = numericValue(second) {
                value = v + v2
                tokens.removeFirst()
            }
        }

        var unit: String? = nil
        if value != nil, let unitToken = tokens.first {
            let stripped = unitToken.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            if let canonical = unitMap[stripped] {
                unit = canonical
                tokens.removeFirst()
            }
        }
        if tokens.first == "of" { tokens.removeFirst() }

        let nameWords = tokens.filter { !descriptorWords.contains($0) }
        let key = nameWords.map { singularize($0) }.joined(separator: " ")
        let displayName = key.isEmpty ? "" : key.prefix(1).uppercased() + key.dropFirst()

        return Parsed(value: value, unit: unit, key: key, displayName: displayName)
    }

    private static func numericValue(_ token: String) -> Double? {
        if token.count == 1, let f = unicodeFractions[token.first!] { return f }
        if let last = token.last, let f = unicodeFractions[last] {
            let head = String(token.dropLast())
            if head.isEmpty { return f }
            if let whole = Double(head) { return whole + f }
        }
        if token.contains("/") {
            let parts = token.split(separator: "/")
            if parts.count == 2, let n = Double(parts[0]), let d = Double(parts[1]), d != 0 {
                return n / d
            }
            return nil
        }
        // Range "2-3" — shop for the upper bound
        if token.contains("-") {
            let parts = token.split(separator: "-")
            if parts.count == 2, Double(parts[0]) != nil, let upper = Double(parts[1]) {
                return upper
            }
        }
        return Double(token)
    }

    private static func singularize(_ word: String) -> String {
        guard word.count > 3 else { return word }
        if word.hasSuffix("ss") || word.hasSuffix("us") { return word }
        if word.hasSuffix("ies") { return String(word.dropLast(3)) + "y" }
        if word.hasSuffix("oes") { return String(word.dropLast(2)) }
        if word.hasSuffix("s") { return String(word.dropLast()) }
        return word
    }

    // "5 cloves" (same unit summed) · "1 cup + 2 tbsp" (mixed units listed, never
    // converted) · "2 cups + more" (a mention had no amount) · nil (nothing to show)
    static func summarize(_ amounts: [(value: Double?, unit: String?)]) -> String? {
        var byUnit: [String: Double] = [:]
        var unitOrder: [String] = []
        var bareTotal = 0.0
        var hasBare = false
        var unquantified = 0

        for (value, unit) in amounts {
            guard let value else { unquantified += 1; continue }
            if let unit {
                if byUnit[unit] == nil { unitOrder.append(unit) }
                byUnit[unit, default: 0] += value
            } else {
                bareTotal += value
                hasBare = true
            }
        }

        var parts: [String] = []
        if hasBare { parts.append(format(bareTotal)) }
        for unit in unitOrder {
            let total = byUnit[unit] ?? 0
            parts.append("\(format(total)) \(pluralized(unit, for: total))")
        }
        guard !parts.isEmpty else { return nil }
        var result = parts.joined(separator: " + ")
        if unquantified > 0 { result += " + more" }
        return result
    }

    private static func pluralized(_ unit: String, for value: Double) -> String {
        guard wordUnits.contains(unit), value != 1 else { return unit }
        if unit.hasSuffix("ch") || unit.hasSuffix("sh") || unit.hasSuffix("x") { return unit + "es" }
        return unit + "s"
    }

    private static func format(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        if rounded == rounded.rounded() { return String(Int(rounded.rounded())) }
        return String(rounded)
    }
}

// MARK: - Pantry staples
//
// Things most people already have, so they can be checked off in one tap rather
// than hunted down an aisle. Shared by the personal and household lists.

enum PantryStaples {
    /// Pepper spices are listed explicitly so they don't match produce (bell pepper etc.)
    static let terms: [String] = [
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

    /// Phrases confirming an item is water, not watermelon / water chestnut.
    static let waterPhrases: [String] = [
        "cold water", "warm water", "hot water", "boiling water",
        "ice water", "room temperature water", "lukewarm water",
        "cups of water", "cup of water", "tablespoons of water",
        "tablespoon of water", "liters of water", "ml of water",
        "ounces of water", "oz water",
    ]

    static func matches(_ text: String) -> Bool {
        let lower = text.lowercased()
        if terms.contains(where: { lower.contains($0) }) { return true }
        // Salt — catches "kosher salt", "sea salt", "1 tsp salt". Safe in a recipe
        // context; "assault" isn't an ingredient.
        if lower.contains("salt") { return true }
        // Water only as a standalone ingredient, never inside another word
        if lower == "water" || lower.hasPrefix("water ") || lower.hasPrefix("water,")
            || lower.hasSuffix(" water") { return true }
        return waterPhrases.contains(where: { lower.contains($0) })
    }
}
