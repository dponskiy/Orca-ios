//
//  SonarEngine.swift
//  Orca
//
//  Created by David Piliponskiy on 2/24/26.
//

import Foundation
import NaturalLanguage

struct PingSuggestion {
    let fireDate: Date?
    let fireTime: Date?
    let recurrence: Ping.Recurrence
}

struct SonarResult {
    let echoId: UUID?
    let echoName: String
    let echoConfidence: Double
    let detectedDate: Date?
    let endDate: Date?
    let dateConfidence: Double?
    let tags: [String]
    let shouldCreatePing: Bool
    let pingRecurrence: Ping.Recurrence
    let isActionable: Bool
    let pingFireDate: Date?
    let pingFireTime: Date?
    let pingSuggestions: [PingSuggestion]
    let shouldOfferRecipeFetch: Bool
    let suggestedLocationName: String?
    let hasRestaurantSignal: Bool
    let detectedSportsTeam: ESPNTeam?
    let detectedPeople: [String]
}

class SonarEngine {

    private let keywordMap: [(echo: String, keywords: [String], priority: Int)] = [
        ("Health", ["doctor", "medicine", "prescription", "appointment", "dentist", "therapy", "vitamin", "hospital", "symptoms", "allergy", "medication", "pharmacy", "sick", "pain", "blood pressure", "checkup", "nurse", "clinic", "urgent care", "specialist", "surgeon", "physical", "lab results", "diagnosis", "chronic", "inflammation", "fever", "nausea", "injury", "rehab", "physical therapy",
            // additions
            "mental health", "anxiety", "depression", "therapist", "psychiatrist", "psychologist",
            "dermatologist", "ophthalmologist", "optometrist", "chiropractor", "acupuncture",
            "blood work", "mri", "xray", "x-ray", "ultrasound", "scan", "biopsy",
            "insurance claim", "copay", "deductible", "referral", "prior authorization",
            "cholesterol", "diabetes", "thyroid", "migraine", "headache", "back pain",
            "sleep", "insomnia", "melatonin", "supplement", "probiotic", "omega",
            "colonoscopy", "mammogram", "annual physical", "flu shot", "vaccine", "booster"], 1),

        ("Kids", ["daycare", "teacher", "parent", "pediatrician", "baby", "child", "kid", "daughter", "son", "playground", "soccer practice", "ballet", "tutor", "school pickup", "drop off kids", "nanny", "babysitter", "kindergarten", "preschool", "school project",
            // additions
            "homework", "report card", "parent teacher", "pta", "field trip", "school supplies",
            "playdate", "birthday party", "after school", "summer camp", "swim lessons",
            "pediatric", "growth", "formula", "diaper", "stroller", "car seat",
            "teenager", "teen", "college prep", "sat", "act", "extracurricular"], 2),

        ("Birthday", ["birthday", "bday", "turning", "birthday party", "birthday gift", "birthday present", "happy birthday", "years old", "born",
            // additions
            "birth date", "date of birth", "age", "celebrate", "celebration", "party planning",
            "birthday cake", "birthday dinner", "surprise party", "birthday trip"], 3),

        ("Gifts", ["present", "gift", "christmas gift", "anniversary gift", "wishes", "wants", "wish list", "registry", "surprise", "wrapping", "send gift", "gift card",
            "white elephant", "secret santa", "stocking stuffer", "hostess gift",
            "thank you gift", "graduation gift", "baby gift", "wedding gift",
            "gift idea", "gift ideas", "gifting", "amazon wishlist", "birthday list",
            "mothers day gift", "fathers day gift", "wants for", "getting for",
            "buying for", "got for", "ordered for", "received for",
            // new
            "buy for", "get for", "bought for", "pick up for", "grabbing for",
            "headphones", "airpods", "beats", "jewelry", "perfume", "cologne",
            "flowers", "chocolates", "candle", "purse", "wallet",
            "mothers day", "mother's day", "fathers day", "father's day"], 4),

        ("Travel", ["flight", "hotel", "airport", "vacation", "trip", "booking", "passport", "luggage", "airbnb", "rental car", "itinerary", "resort", "cruise", "destination", "departure", "arrival", "layover", "boarding", "check-in", "check in", "visa", "packing", "suitcase", "travel insurance", "jet lag", "timezone",
            // additions
            "vrbo", "hostel", "bed and breakfast", "motel", "road trip", "staycation",
            "travel credit", "miles", "points", "lounge access", "global entry", "tsa precheck",
            "carry on", "checked bag", "seat upgrade", "aisle seat", "window seat",
            "travel adapter", "travel size", "packing list", "travel day",
            "train", "amtrak", "eurostar", "bullet train", "ferry", "cruise ship",
            "excursion", "tour", "guided tour", "day trip"], 5),

        ("Cooking", ["recipe", "ingredient", "cook", "bake", "tablespoon", "teaspoon", "oven", "stove", "marinade", "seasoning", "prep", "simmer", "saute", "roast", "grill", "homemade", "meal prep", "leftovers", "slow cooker", "instant pot", "air fryer", "degrees fahrenheit", "degrees celsius", "preheat", "chop", "dice", "mince", "boil", "fry", "whisk", "fold", "knead",
            // additions
            "dutch oven", "cast iron", "wok", "sheet pan", "baking dish", "mixing bowl",
            "food processor", "blender", "stand mixer", "thermometer",
            "meal plan", "weekly meals", "batch cook", "freezer meal",
            "gluten free", "dairy free", "vegan", "vegetarian", "keto", "paleo",
            "sous vide", "smoke", "smoker", "bbq sauce", "dry rub", "brine",
            "flour", "butter", "olive oil", "garlic", "onion", "pasta", "rice",
            "cuisine", "italian", "mexican", "thai", "japanese", "french"], 6),

        ("Dining", ["restaurant", "reservation", "menu", "waiter", "takeout", "delivery", "brunch", "lunch", "cafe", "appetizer", "entree", "dessert", "cocktail", "bar", "don't order", "dont order", "avoid ordering", "never order", "skip the", "dish was", "food was", "place was", "ate at", "eating at", "tried at", "recommend", "good at", "bad at", "overrated", "underrated", "must try", "never again", "great spot", "good spot", "yelp", "opentable", "resy", "uber eats", "doordash", "grubhub", "table for", "outdoor seating", "happy hour", "prix fixe", "tasting menu", "michelin", "omakase", "want to try", "looking to try", "have to try", "need to try", "heard about", "been meaning to", "wanna try", "dying to try", "check out this place", "great place", "this place",
            // additions
            "sushi", "pizza", "burger", "ramen", "tacos", "steakhouse", "seafood", "italian",
            "wine bar", "speakeasy", "rooftop", "patio", "brunch spot", "coffee shop",
            "bakery", "food truck", "pop up", "tasting", "chef", "sommelier",
            "corkage", "byob", "dress code", "valet", "parking", "wait list",
            "splurge", "date night", "business dinner", "group dinner"], 7),

        ("Sports", ["game", "score", "team", "season", "ticket", "stadium", "coach",
            "player", "league", "tournament", "playoffs", "match", "sports bar",
            "fantasy league", "draft", "standings", "highlights", "broadcast",
            "watch party", "betting", "odds", "spread", "parlay", "espn",
            "monday night", "sunday night", "playoff race", "division",
            "championship", "super bowl", "world series", "nba finals",
            "stanley cup", "trade deadline", "roster", "starting lineup",
            // additions
            "mvp", "hall of fame", "draft pick", "free agent", "trade", "signing",
            "injury report", "depth chart", "over under", "prop bet", "moneyline",
            "sportsbook", "fanduel", "draftkings", "prizepicks", "underdog",
            "nfl", "nba", "mlb", "nhl", "mls", "ncaa", "sec", "big ten",
            "college football", "march madness", "bracket", "bowl game",
            "hat trick", "home run", "touchdown", "three pointer", "slam dunk"], 8),

        ("Events", ["concert", "show", "festival", "conference", "expo", "recital", "performance", "gala", "ceremony", "graduation", "prom", "meetup", "gathering", "networking", "keynote", "panel", "workshop", "seminar", "opening night", "premiere", "launch event", "happy hour", "cocktail party", "wedding", "engagement", "baby shower", "retirement party",
            // additions
            "tickets", "venue", "sold out", "general admission", "vip", "backstage",
            "meet and greet", "autograph", "setlist", "tour", "residency",
            "broadway", "opera", "ballet performance", "comedy show", "stand up",
            "art show", "gallery opening", "museum", "exhibit", "auction",
            "fundraiser", "charity event", "benefit", "gala dinner",
            "housewarming", "anniversary party", "gender reveal", "bridal shower"], 9),

        ("Shopping", ["price", "store", "coupon", "sale", "amazon", "size", "return", "shipping", "discount", "brand", "mall", "target", "walmart", "costco", "online order", "tracking number", "out of stock", "waitlist", "sold out", "best buy", "apple store", "wish list", "add to cart", "checkout",
            // additions
            "promo code", "coupon code", "cashback", "rebate", "price match", "price drop",
            "black friday", "cyber monday", "prime day", "flash sale", "clearance",
            "in store", "pickup", "curbside", "same day delivery", "free shipping",
            "subscription box", "membership", "loyalty points", "rewards",
            "ebay", "etsy", "poshmark", "mercari", "facebook marketplace",
            "nordstrom rack", "tj maxx", "marshall's", "homegoods"], 10),

        ("Home", ["plumber", "electrician", "repair", "mortgage", "rent", "landlord", "furniture", "paint", "garden", "lawn", "roof", "garage", "basement", "kitchen", "bathroom", "renovate", "move", "handyman", "contractor", "lease", "hoa", "property tax", "homeowners", "pest control", "hvac", "water heater", "dishwasher", "washer", "dryer", "cleaning service", "deep clean",
            // additions
            "air filter", "smoke detector", "carbon monoxide", "circuit breaker", "fuse",
            "caulk", "grout", "tile", "hardwood", "carpet", "flooring",
            "window", "door", "lock", "key", "deadbolt", "alarm system",
            "moving boxes", "storage unit", "declutter", "donate", "dump run",
            "ikea", "home depot", "lowes", "wayfair", "west elm", "restoration hardware",
            "interior design", "staging", "curb appeal", "appraisal", "inspection",
            "closing costs", "down payment", "refinance", "home equity", "heloc"], 11),

        ("School", ["class", "exam", "test", "study", "professor", "lecture", "semester", "tuition", "campus", "assignment", "essay", "grade", "gpa", "syllabus", "textbook", "homework", "school", "finals", "midterm", "thesis", "dissertation", "graduation", "financial aid", "fafsa", "scholarship", "college", "university", "degree", "major", "minor", "internship", "student loan",
            // additions
            "quiz", "project", "group project", "lab", "office hours", "tutoring",
            "study group", "flashcards", "notes", "transcript", "diploma",
            "application", "common app", "recommendation letter", "essay prompt",
            "waitlist", "acceptance", "dorm", "roommate", "meal plan", "greek life",
            "rush", "fraternity", "sorority", "club", "student government",
            "research", "thesis advisor", "dissertation committee", "defense"], 12),

        ("Work", ["meeting", "deadline", "project", "email", "boss", "coworker", "presentation", "report", "salary", "interview", "client", "office", "standup", "promotion", "review", "slack", "zoom", "teams", "onboarding", "offboarding", "performance review", "quarterly", "sprint", "backlog", "jira", "confluence", "okr", "kpi", "pipeline", "forecast", "proposal", "contract", "invoice", "expense report", "reimbursement", "travel approval",
            // additions
            "one on one", "1:1", "all hands", "town hall", "offsite", "retreat",
            "hire", "hiring", "job posting", "candidate", "offer letter", "counter offer",
            "raise", "bonus", "equity", "stock options", "vesting", "401k match",
            "pto", "vacation days", "sick day", "parental leave", "maternity", "paternity",
            "remote", "hybrid", "in office", "work from home", "wfh",
            "linkedin", "resume", "cover letter", "reference", "background check",
            "layoff", "severance", "resignation", "two weeks notice"], 13),

        ("Pets", ["vet", "dog", "cat", "puppy", "kitten", "pet food", "grooming", "walk", "collar", "leash", "litter", "treats", "adoption", "vaccine", "flea", "heartworm", "tick", "microchip", "spay", "neuter", "boarding", "pet sitter", "aquarium", "fish", "bird", "hamster", "rabbit",
            // additions
            "dog park", "dog walker", "doggy daycare", "kennel", "crate", "harness",
            "training", "obedience", "behavioral", "separation anxiety",
            "wet food", "dry food", "raw diet", "grain free", "dental treat",
            "flea collar", "frontline", "nexgard", "bravecto", "apoquel",
            "shots", "booster", "annual exam", "emergency vet", "specialist",
            "turtle", "snake", "lizard", "gecko", "ferret", "guinea pig"], 14),

        ("Finance", ["bank", "savings", "investment", "tax", "credit card", "payment", "budget", "insurance", "loan", "interest", "401k", "stocks", "stock", "shares", "share", "trading", "trade", "portfolio", "ticker", "earnings", "dividend", "debt", "refund", "subscription", "venmo", "zelle", "wire transfer", "direct deposit", "w2", "1099", "irs", "audit", "estate planning", "will", "trust", "beneficiary", "premium", "deductible", "copay", "hsa", "fsa", "roth ira", "capital gains", "price alert", "drops below", "rises above", "buy the dip", "puts", "calls", "options", "ipo", "short", "long", "stonks",
            // additions
            "etf", "index fund", "mutual fund", "hedge fund", "crypto", "bitcoin", "ethereum",
            "brokerage", "schwab", "fidelity", "vanguard", "robinhood", "webull",
            "net worth", "asset allocation", "rebalance", "diversify",
            "credit score", "credit report", "freeze credit", "identity theft",
            "mortgage rate", "refinance", "home equity", "heloc",
            "life insurance", "term life", "whole life", "umbrella policy",
            "quarterly tax", "estimated tax", "write off", "deduction", "itemize",
            "paycheck", "gross pay", "net pay", "withholding", "w4"], 15),

        ("Holidays", ["christmas", "thanksgiving", "easter", "halloween", "new year", "valentine", "fourth of july", "independence day", "labor day", "memorial day", "hanukkah", "kwanzaa", "diwali", "mothers day", "fathers day", "presidents day", "martin luther king", "columbus day", "veterans day", "passover", "ramadan", "eid",
            // additions
            "holiday party", "holiday shopping", "holiday travel", "holiday cards",
            "decorations", "lights", "tree", "wreath", "ornaments", "tinsel",
            "candy corn", "trick or treat", "costume", "pumpkin", "carve",
            "turkey", "stuffing", "cranberry", "pie", "feast", "family dinner",
            "new years eve", "countdown", "resolution", "champagne",
            "easter egg", "basket", "menorah", "dreidel", "advent"], 16),

        ("To-Do", ["laundry", "vacuum", "dishes", "clean", "trash", "recycle", "mop", "dust", "organize", "declutter", "iron", "sweep", "garbage", "errands", "chores", "errand", "pick up", "drop off", "run", "stop by", "swing by", "grab", "need to", "have to", "got to", "gotta", "don't forget", "dont forget", "reminder", "task", "to-do", "todo", "checklist", "errand run", "dry cleaning", "post office", "bank", "hardware store", "pharmacy", "drugstore", "gas station", "car wash", "oil change", "DMV", "MVA", "returns", "exchange", "package", "mail", "ups", "fedex", "usps",
            // additions
            "call back", "follow up", "respond", "reply", "rsvp",
            "schedule", "book appointment", "cancel appointment", "reschedule",
            "renew", "registration", "license", "permit", "inspection",
            "pay bill", "autopay", "due date", "overdue", "late fee",
            "grocery run", "shopping list", "stock up", "reorder",
            "fix", "repair", "replace", "install", "set up", "update"], 17),

        ("Games", ["xbox", "playstation", "nintendo", "switch", "steam", "gaming", "controller", "multiplayer", "level", "quest", "raid", "download", "dlc", "console", "pc gaming", "esports", "twitch", "speedrun", "achievements", "trophy", "walkthrough", "patch", "update", "early access", "game pass", "ps5", "ps4", "xbox series",
            // additions
            "rpg", "fps", "mmorpg", "battle royale", "open world", "sandbox",
            "fortnite", "minecraft", "call of duty", "warzone", "apex legends",
            "league of legends", "valorant", "overwatch", "destiny", "halo",
            "zelda", "mario", "pokemon", "final fantasy", "elden ring",
            "new release", "pre-order", "launch day", "server",
            "headset", "keyboard", "mouse", "gaming chair", "monitor refresh",
            "frame rate", "fps", "resolution", "graphics card", "gpu", "build"], 18),

        ("Movies", ["movie", "film", "cinema", "theater", "theatre", "netflix", "hulu",
            "disney+", "hbo", "prime video", "streaming", "watch", "director", "actor",
            "actress", "sequel", "trailer", "blockbuster", "documentary", "series",
            "episode", "season", "binge", "screenplay", "imdb", "rotten tomatoes",
            "apple tv", "peacock", "paramount", "showtime", "starz", "criterion",
            "4k", "blu-ray", "short film", "indie film",
            "tv show", "tv shows", "television", "show", "shows", "watching",
            "currently watching", "finished watching", "want to watch", "to watch",
            "sitcom", "drama", "miniseries", "mini series", "limited series",
            "finale", "premiere", "pilot", "rewatch", "binged", "binging",
            // additions
            "max", "paramount+", "discovery+", "fubo", "sling", "youtube tv",
            "now watching", "just finished", "just watched", "recommend watching",
            "true crime", "reality tv", "reality show", "game show", "talk show",
            "late night", "saturday night live", "snl", "animation", "anime",
            "oscar", "emmy", "golden globe", "academy award",
            "box office", "opening weekend", "limited release", "wide release",
            "casting", "showrunner", "writer", "producer", "cinematography"], 19),

        ("Books", ["book", "read", "reading", "novel", "author", "chapter", "kindle", "audible", "library", "bookstore", "fiction", "nonfiction", "memoir", "biography", "audiobook", "bestseller", "hardcover", "paperback", "goodreads", "page", "plot", "genre", "publisher", "literature", "ebook", "book club", "book review", "recommended reading", "sequel", "trilogy", "series", "graphic novel", "comic book",
            // additions
            "currently reading", "just finished", "want to read", "reading list",
            "page turner", "couldn't put it down", "beach read", "book recommendation",
            "new york times bestseller", "oprah book club", "reese book club",
            "thriller", "mystery", "romance", "sci fi", "fantasy", "horror",
            "self help", "business book", "leadership", "productivity",
            "kindle unlimited", "scribd", "libby", "overdrive",
            "signed copy", "first edition", "book store", "barnes and noble",
            "short story", "essay collection", "poetry", "anthology"], 20),

        ("Clothes", ["shirt", "pants", "shoes", "dress", "jacket", "coat", "outfit", "wear", "wearing", "clothes", "clothing", "jeans", "sweater", "hoodie", "socks", "underwear", "suit", "tie", "hat", "scarf", "gloves", "boots", "sneakers", "dry clean", "tailored", "alterations", "wardrobe", "fashion", "style", "nordstrom", "zara", "h&m", "uniqlo", "lululemon", "nike", "adidas", "size medium", "size large", "size small",
            // additions
            "t-shirt", "button down", "polo", "blouse", "skirt", "shorts", "leggings",
            "activewear", "athleisure", "swimsuit", "bikini", "wetsuit",
            "puffer", "trench coat", "peacoat", "windbreaker", "vest",
            "loafers", "heels", "flats", "sandals", "slides", "running shoes",
            "bag", "purse", "handbag", "backpack", "tote", "clutch",
            "belt", "watch", "jewelry", "necklace", "bracelet", "earrings", "ring",
            "capsule wardrobe", "outfit of the day", "ootd", "inspo",
            "asos", "revolve", "ssense", "matches fashion", "farfetch",
            "thrift", "vintage", "consignment", "resale", "depop"], 21),

        ("Workout", ["bench press", "bench", "squat", "squats", "deadlift", "deads",
            "overhead press", "ohp", "pull up", "pushup", "push up", "curl", "curls",
            "lunge", "plank", "dumbbell", "barbell", "kettlebell", "rep", "reps",
            "pr", "personal record", "personal best", "1rm", "one rep max",
            "lifted", "pressed", "incline", "decline", "lat pulldown", "leg press",
            "chest fly", "tricep", "triceps", "bicep", "biceps",
            "back day", "leg day", "chest day", "push day", "pull day", "arms day",
            "superset", "drop set", "max out", "sets and reps", "working out", "gym", "workout", "lifting", "volume", "hit the gym", "ran", "running", "miles", "kilometers", "treadmill", "elliptical",
            "cycling", "swim", "swam", "rowing", "hiit", "circuit", "cardio",
            "peloton", "crossfit", "wod", "spin class", "personal trainer",
            "5k", "10k", "half marathon", "marathon", "pace", "race time",
            "sauna", "steam room", "steam bath", "cold plunge", "ice bath",
            "cold shower", "cold tub", "cold water immersion",
            "foam rolling", "foam roll", "stretching", "stretch",
            "mobility", "mobility work", "breathwork", "meditation",
            "massage", "sports massage", "deep tissue",
            "orangetheory", "orange theory", "otf",
            "corepower", "core power",
            "f45", "solidcore", "solid core",
            "barrys", "barry's bootcamp",
            "soulcycle", "soul cycle",
            "barre", "pure barre",
            "pilates", "reformer pilates", "reformer",
            "hot yoga", "bikram", "vinyasa", "power yoga", "yoga",
            "boxing class", "kickboxing", "title boxing", "rumble boxing",
            "bootcamp", "boot camp", "zumba",
            "class today", "workout class", "fitness class",
            // additions
            "weight loss", "bulk", "cut", "lean", "shred", "gains",
            "protein", "creatine", "pre workout", "bcaa", "whey",
            "rest day", "recovery", "deload", "periodization",
            "body fat", "body composition", "body weight", "weigh in",
            "steps", "active calories", "apple watch", "garmin", "whoop",
            "heart rate zone", "vo2 max", "lactate threshold",
            "strava", "nike run club", "couch to 5k",
            "gym membership", "planet fitness", "equinox", "lifetime",
            "home gym", "resistance band", "pull up bar", "rings"], 22),
    ]
    private let reminderKeywords = ["remind", "remember", "don't forget", "dont forget", "every monday", "every tuesday", "every wednesday", "every thursday", "every friday", "every saturday", "every sunday", "every week", "every month", "every year", "every day", "daily", "weekly", "monthly", "yearly", "annually", "appointment", "deadline", "due date"]

    private let actionKeywords = ["buy", "get", "pick up", "pickup", "call", "email", "send", "schedule", "book", "cancel", "return", "fix", "clean", "make", "order", "pay", "finish", "submit", "renew", "sign up", "signup", "register", "drop off", "dropoff", "mail", "ship", "text", "message", "contact", "set up", "setup", "install", "update", "replace", "check", "review", "prepare", "plan", "arrange", "confirm", "reschedule", "refill", "restock", "wash", "take", "bring", "move", "file", "print", "scan", "deposit", "transfer", "apply", "complete", "grab", "find", "look into", "follow up", "respond", "reply", "game", "concert", "show", "match", "party", "dinner", "event", "appointment", "meeting", "flight", "reservation", "practice", "class", "exam", "recital", "performance"]

    private let negativePatterns = ["don't order", "dont order", "never order", "don't get", "dont get", "never get", "avoid", "never again", "don't go", "dont go", "never go", "skip the", "not worth", "wouldn't recommend", "don't recommend", "dont recommend", "stay away", "worst", "terrible", "awful", "disgusting", "overpriced"]

    private let autoYearlyKeywords = ["birthday", "bday", "anniversary", "christmas", "thanksgiving", "easter", "halloween", "new year", "valentine", "hanukkah", "kwanzaa", "diwali", "independence day", "fourth of july", "memorial day", "labor day"]

    private let weekdayMap: [(String, Int)] = [
        ("sunday", 1), ("sundays", 1),
        ("monday", 2), ("mondays", 2),
        ("tuesday", 3), ("tuesdays", 3),
        ("wednesday", 4), ("wednesdays", 4),
        ("thursday", 5), ("thursdays", 5),
        ("friday", 6), ("fridays", 6),
        ("saturday", 7), ("saturdays", 7),
    ]

    private let diningContextWords = [
        "eat", "ate", "food", "dish", "order", "menu", "lunch", "dinner", "brunch",
        "breakfast", "taste", "flavor", "delicious", "portions", "service", "waiter",
        "try", "tried", "trying", "dining", "restaurant", "reservations", "takeout",
        "delivery", "cuisine", "spot", "place", "eats"
    ]

    private let restaurantCommonWords = Set([
        "the", "a", "an", "for", "at", "in", "on", "to", "of", "and", "with",
        "from", "by", "i", "we", "my", "our", "is", "are", "was", "were",
        "tomorrow", "today", "tonight", "dinner", "lunch", "brunch", "breakfast",
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        "pm", "am", "next", "this", "going", "want", "lets", "let"
    ])

    // MARK: - Main Process

    func process(text: String, echos: [Echo]) -> SonarResult {
        let lower = text.lowercased()

        let entities = extractEntities(text: text)
        let echoResult = assignEcho(text: lower, originalText: text, echos: echos, entities: entities)
        let detectedSportsTeam = ESPNService.shared.detectTeam(in: text)
        let dateResults = detectDates(text: text)
        let tags = generateTags(text: text, echoName: echoResult.name, entities: entities)
        let actionable = detectAction(text: lower)
        let pingSuggestions = buildPingSuggestions(text: lower, dates: dateResults)

        let primary = pingSuggestions.first

        let detectedURL = detectURL(text: text)
        let isCookingEcho = echoResult.name.lowercased().contains("cook") ||
                            echoResult.name.lowercased().contains("recipe")
        let shouldOfferRecipeFetch = isCookingEcho && detectedURL != nil

        let hasDiningContext = diningContextWords.contains { lower.contains($0) }
        let hasRestaurantSignal = !entities.organizations.isEmpty && hasDiningContext

        return SonarResult(
            echoId: echoResult.id,
            echoName: echoResult.name,
            echoConfidence: echoResult.confidence,
            detectedDate: dateResults.eventDate,
            endDate: dateResults.endDate,
            dateConfidence: dateResults.eventConfidence,
            tags: tags,
            shouldCreatePing: !pingSuggestions.isEmpty,
            pingRecurrence: primary?.recurrence ?? Ping.Recurrence.none,
            isActionable: actionable,
            pingFireDate: primary?.fireDate,
            pingFireTime: primary?.fireTime,
            pingSuggestions: pingSuggestions,
            shouldOfferRecipeFetch: shouldOfferRecipeFetch,
            suggestedLocationName: entities.organizations.first,
            hasRestaurantSignal: hasRestaurantSignal,
            detectedSportsTeam: detectedSportsTeam,
            detectedPeople: entities.people.map { $0.capitalized }
        )
    }

    // MARK: - Named Entity Recognition

    private func extractEntities(text: String) -> (people: [String], places: [String], organizations: [String]) {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var people: [String] = []
        var places: [String] = []
        var organizations: [String] = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: [.omitWhitespace, .omitPunctuation, .joinNames]) { tag, range in
            let entity = String(text[range])
            switch tag {
            case .personalName: people.append(entity.lowercased())
            case .placeName: places.append(entity.lowercased())
            case .organizationName: organizations.append(entity.lowercased())
            default: break
            }
            return true
        }
            // Fallback — catch names NLP missed (e.g. "Miles" without possessive)
        let commonNonNames = Set([
            // Months
            "january", "february", "march", "april", "may", "june", "july",
            "august", "september", "october", "november", "december",
            // Days
            "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
            // Cities/places
            "new", "york", "los", "san", "las",
            // Occasions
            "birthday", "christmas", "holiday", "anniversary", "halloween",
            "thanksgiving", "valentine", "easter",
            // Common sentence starters / action verbs
            "get", "got", "getting", "buy", "bought", "buying", "find", "found",
            "pick", "order", "ordered", "grab", "grabbed", "need", "want",
            "make", "take", "give", "send", "bring", "call", "tell", "ask",
            "remind", "remember", "check", "look", "try", "let", "put",
            // Time words
            "today", "tomorrow", "tonight", "morning", "afternoon", "evening",
            "this", "next", "last"
        ])
            let words = text.components(separatedBy: .whitespaces)
            for word in words {
                let clean = word.trimmingCharacters(in: .punctuationCharacters)
                guard clean.count > 2,
                      clean.first?.isUppercase == true,
                      !commonNonNames.contains(clean.lowercased()),
                      !people.contains(clean.lowercased()),
                      !places.contains(clean.lowercased()),
                      !organizations.contains(clean.lowercased()) else { continue }
                people.append(clean.lowercased())
            }

            return (people, places, organizations)
        }

    // MARK: - Action Detection

    private func detectAction(text: String) -> Bool {
        let lower = text.lowercased()
        if negativePatterns.contains(where: { lower.contains($0) }) { return false }
        let observationPatterns = ["was great", "was amazing", "was terrible", "was good", "was bad", "is great", "is amazing", "tasted", "loved the", "hated the", "tried the"]
        if observationPatterns.contains(where: { lower.contains($0) }) { return false }
        return actionKeywords.contains { keyword in lower.contains(keyword) }
    }

    // MARK: - Echo Assignment

    private func assignEcho(text: String, originalText: String, echos: [Echo], entities: (people: [String], places: [String], organizations: [String])) -> (id: UUID?, name: String, confidence: Double) {
        var scores: [(name: String, score: Double, priority: Int)] = []

        for entry in keywordMap {
            let matchCount = entry.keywords.filter { text.contains($0) }.count
            if matchCount > 0 {
                scores.append((entry.echo, Double(matchCount), entry.priority))
            }
        }
        let normalizedText = WorkoutParser.shared.normalizeSpokenNumbers(text)
        let hasDiningContext = diningContextWords.contains { text.contains($0) }

        // NL Entity boosting
        for org in entities.organizations {
            let orgLower = org.lowercased()
            let foodIndicators = ["restaurant", "cafe", "kitchen", "grill", "bar", "bistro", "eatery", "diner", "brasserie", "tavern", "pub", "house", "garden", "table", "shanghai", "tokyo", "thai", "sushi", "pizza", "burger", "taco", "bbq", "noodle", "dumpling"]

            if foodIndicators.contains(where: { orgLower.contains($0) }) {
                if let idx = scores.firstIndex(where: { $0.name == "Dining" }) {
                    scores[idx].score += 2.0
                } else {
                    scores.append(("Dining", 2.0, 7))
                }
            } else if hasDiningContext {
                if let idx = scores.firstIndex(where: { $0.name == "Dining" }) {
                    scores[idx].score += 1.5
                } else {
                    scores.append(("Dining", 1.5, 7))
                }
            }
        }

        if !entities.organizations.isEmpty && hasDiningContext {
            if let idx = scores.firstIndex(where: { $0.name == "Dining" }) {
                scores[idx].score += 1.0
            }
        }

        // Proper noun dining boost
        let words = originalText.components(separatedBy: .whitespaces)
        let properNouns = words.filter { word in
            let clean = word.trimmingCharacters(in: .punctuationCharacters)
            return clean.count > 2 &&
                   clean.first?.isUppercase == true &&
                   !restaurantCommonWords.contains(clean.lowercased())
        }
        let likelyRestaurantName = !properNouns.isEmpty && properNouns.count <= 3
        if likelyRestaurantName && hasDiningContext {
            let boost = properNouns.count == 1 ? 2.5 : 2.0
            if let idx = scores.firstIndex(where: { $0.name == "Dining" }) {
                scores[idx].score += boost
            } else {
                scores.append(("Dining", boost, 7))
            }
        }

        // People names with health context
        let healthContextWords = ["doctor", "dr.", "appointment", "prescription", "diagnosis", "symptoms", "hospital", "clinic", "therapy"]
        let hasHealthContext = healthContextWords.contains { text.contains($0) }
        if !entities.people.isEmpty && hasHealthContext {
            if let idx = scores.firstIndex(where: { $0.name == "Health" }) {
                scores[idx].score += 1.0
            }
        }

        // People names with work context
        let workContextWords = ["meeting", "call", "email", "project", "deadline", "client", "office", "zoom", "slack", "presentation"]
        let hasWorkContext = workContextWords.contains { text.contains($0) }
        if !entities.people.isEmpty && hasWorkContext {
            if let idx = scores.firstIndex(where: { $0.name == "Work" }) {
                scores[idx].score += 1.0
            }
        }

        // Learned keywords pass
        for echo in echos where !echo.learnedKeywords.isEmpty {
            let matchCount = echo.learnedKeywords.filter { text.contains($0) }.count
            if matchCount > 0 {
                let boost = Double(matchCount) * 2.0
                if let idx = scores.firstIndex(where: { $0.name == echo.name }) {
                    scores[idx].score += boost
                } else {
                    scores.append((echo.name, boost, 0))
                }
            }
        }

        // Sports team boost
        let detectedTeam = ESPNService.shared.detectTeam(in: originalText)
        if detectedTeam != nil {
            if let idx = scores.firstIndex(where: { $0.name == "Sports" }) {
                scores[idx].score += 3.0
            } else {
                scores.append(("Sports", 3.0, 8))
            }
        }
        // Workout parser boost
        let detectedWorkout = WorkoutParser.shared.detectWorkout(in: originalText)
        if detectedWorkout != nil {
            if let idx = scores.firstIndex(where: { $0.name == "Workout" }) {
                scores[idx].score += 3.0
            } else {
                scores.append(("Workout", 3.0, 22))
            }
        }

        // Exercise name + NxM pattern — very strong Workout signal
        // Prevents "arm curl 4x50" or "bench 135 6 times" routing to Finance
        let exerciseNxMPattern = #"(?:bench|squat|deadlift|curl|press|row|pull|push|lunge|plank|fly|extension|raise|dip|shrug|crunch|deads|ohp)\w*\s+\d+"#
        if normalizedText.range(of: exerciseNxMPattern, options: .regularExpression) != nil {
            if let idx = scores.firstIndex(where: { $0.name == "Workout" }) {
                scores[idx].score += 5.0
            } else {
                scores.append(("Workout", 5.0, 22))
            }
            // Dampen Finance so it cannot win over a clear exercise pattern
            if let fidx = scores.firstIndex(where: { $0.name == "Finance" }) {
                scores[fidx].score = max(0, scores[fidx].score - 3.0)
            }
        }

        // Distance + time with no explicit exercise → cardio
        let cardioPattern = #"\d+(?:\.\d+)?\s*(?:miles?|km|kilometers?|meters?|k)\b.{0,30}\d+\s*(?:minutes?|mins?|hours?|hr)"#
        if normalizedText.range(of: cardioPattern, options: .regularExpression) != nil {
            if let idx = scores.firstIndex(where: { $0.name == "Workout" }) {
                scores[idx].score += 4.0
            } else {
                scores.append(("Workout", 4.0, 22))
            }
        }
        // Fitness class + duration → Workout signal
                let classPattern = #"(?:orangetheory|orange theory|otf|f45|corepower|solidcore|barrys|soulcycle|barre|pilates|yoga|boxing|bootcamp|zumba|crossfit)\w*\s+\d+"#
                if normalizedText.range(of: classPattern, options: [.regularExpression, .caseInsensitive]) != nil {
                    if let idx = scores.firstIndex(where: { $0.name == "Workout" }) {
                        scores[idx].score += 5.0
                    } else {
                        scores.append(("Workout", 5.0, 22))
                    }
                }
        // Finance ticker boost — if a known ticker is detected alongside financial language,
        // strongly route to Finance echo. Uses same pattern as sports team boost.
        let detectedTicker = FinanceService.shared.detectTicker(in: originalText)
        if detectedTicker != nil {
            if let idx = scores.firstIndex(where: { $0.name == "Finance" }) {
                scores[idx].score += 3.0
            } else {
                scores.append(("Finance", 3.0, 15))
            }
        }
        // Gift-giving pattern — "get/got/getting/buy/bought [name] [item] for [occasion]"
        let giftGivingPattern = #"(?:get|got|getting|buy|bought|buying|picked up|ordered|found|grabbed)\s+\w+\s+(?:a|an|the|some)?\s*\w+"#
        if normalizedText.range(of: giftGivingPattern, options: [.regularExpression, .caseInsensitive]) != nil {
            let giftContextWords = ["birthday", "christmas", "anniversary", "holiday", "gift", "present", "surprise"]
            if giftContextWords.contains(where: { normalizedText.contains($0) }) {
                if let idx = scores.firstIndex(where: { $0.name == "Gifts" }) {
                    scores[idx].score += 4.0
                } else {
                    scores.append(("Gifts", 4.0, 4))
                }
                // Dampen Birthday so it doesn't win over a clear gift-giving pattern
                if let idx = scores.firstIndex(where: { $0.name == "Birthday" }) {
                    scores[idx].score = max(0, scores[idx].score - 2.0)
                }
            }
        }
        if let best = scores.max(by: { a, b in
            a.score < b.score || (a.score == b.score && a.priority > b.priority)
        }) {
            let echo = echos.first { $0.name == best.name }
            let confidence = best.score >= 2.0 ? 0.9 : 0.65
            return (echo?.id, best.name, confidence)
        }

        let notesEcho = echos.first { $0.name == "Notes" }
        return (notesEcho?.id, "Notes", 0.3)
    }

    // MARK: - Date Detection

    private func detectDates(text: String) -> (eventDate: Date?, endDate: Date?, eventConfidence: Double?, reminderDate: Date?, reminderTime: Date?) {
        let lower = text.lowercased()
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)

        let rangeKeywords = [" through ", " until ", " thru ", " to ", " - ", "–", "—"]
        for keyword in rangeKeywords {
            if lower.contains(keyword), let splitRange = lower.range(of: keyword) {
                var firstHalf = String(text[text.startIndex..<splitRange.lowerBound])
                let secondHalf = String(text[splitRange.upperBound...])

                if firstHalf.lowercased().hasPrefix("from ") {
                    firstHalf = String(firstHalf.dropFirst(5))
                }
                if let fromRange = firstHalf.range(of: " from ", options: .caseInsensitive) {
                    firstHalf = String(firstHalf[fromRange.upperBound...])
                }

                let range1 = NSRange(firstHalf.startIndex..<firstHalf.endIndex, in: firstHalf)
                let range2 = NSRange(secondHalf.startIndex..<secondHalf.endIndex, in: secondHalf)

                let dates1 = detector?.matches(in: firstHalf, range: range1).compactMap { $0.date } ?? []
                let dates2 = detector?.matches(in: secondHalf, range: range2).compactMap { $0.date } ?? []

                if let startDate = dates1.first, let endDate = dates2.first {
                    return (startDate, endDate, 0.9, nil, nil)
                }
            }
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = detector?.matches(in: text, range: range) ?? []
        let dates = matches.compactMap { $0.date }

        let hasAbsoluteDate = text.contains(where: { $0.isNumber })
        let confidence = hasAbsoluteDate ? 0.9 : 0.6

        guard !dates.isEmpty else { return (nil, nil, nil, nil, nil) }

        if dates.count == 1 {
            let hasReminderPhrase = lower.contains("remind") || lower.contains("don't forget") || lower.contains("dont forget")
            if hasReminderPhrase, let offset = detectRelativeOffset(text: lower) {
                let eventDate = dates[0]
                let reminderDate = eventDate.addingTimeInterval(offset)
                return (eventDate, nil, confidence, reminderDate, reminderDate)
            }
            return (dates[0], nil, confidence, nil, nil)
        }

        let sorted = dates.sorted { abs($0.timeIntervalSinceNow) < abs($1.timeIntervalSinceNow) }
        let nearest = sorted.first!
        let furthest = sorted.last!

        let hasReminderPhrase = lower.contains("remind") || lower.contains("don't forget") || lower.contains("dont forget")
        if hasReminderPhrase && nearest != furthest {
            return (furthest, nil, confidence, nearest, nearest)
        }

        return (furthest, nil, confidence, nil, nil)
    }

    // MARK: - Relative Offset Detection

    private func detectRelativeOffset(text: String) -> TimeInterval? {
        let patterns: [(String, TimeInterval)] = [
            ("(an?|1|one)\\s+hours?\\s+before", -3600),
            ("(2|two)\\s+hours?\\s+before", -7200),
            ("(3|three)\\s+hours?\\s+before", -10800),
            ("(4|four)\\s+hours?\\s+before", -14400),
            ("half\\s+(an?\\s+)?hours?\\s+before", -1800),
            ("(30|thirty)\\s+minutes?\\s+before", -1800),
            ("(15|fifteen)\\s+minutes?\\s+before", -900),
            ("(45|forty.?five)\\s+minutes?\\s+before", -2700),
            ("(a|1|one)\\s+days?\\s+before", -86400),
            ("(2|two)\\s+days?\\s+before", -172800),
            ("(a|1|one)\\s+weeks?\\s+before", -604800),
        ]
        for (pattern, offset) in patterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return offset
            }
        }
        return nil
    }

    // MARK: - Extract All Times

    private func extractAllTimes(from text: String) -> [Date] {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = detector?.matches(in: text, range: range) ?? []
        let dates = matches.compactMap { $0.date }

        let calendar = Calendar.current
        var seen = Set<String>()
        return dates.filter { date in
            let h = calendar.component(.hour, from: date)
            let m = calendar.component(.minute, from: date)
            let key = "\(h):\(m)"
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }.sorted()
    }

    // MARK: - Ping Suggestions Builder

    private func buildPingSuggestions(text: String, dates: (eventDate: Date?, endDate: Date?, eventConfidence: Double?, reminderDate: Date?, reminderTime: Date?)) -> [PingSuggestion] {
        var suggestions: [PingSuggestion] = []
        let calendar = Calendar.current
        let hasEvery = text.contains("every")

        let hasSpecificTime = text.range(of: #"\bat\s+\d"#, options: .regularExpression) != nil ||
                              text.range(of: #"\d+\s*(am|pm)"#, options: .regularExpression) != nil

        let weekdays = detectWeekdays(text: text)
        if !weekdays.isEmpty {
            let recurrence: Ping.Recurrence = (hasEvery || weekdays.count >= 2) ? .weekly : .none
            for weekday in weekdays {
                let nextDate = nextOccurrence(of: weekday)
                var fireTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())
                if let eventDate = dates.eventDate {
                    let components = calendar.dateComponents([.hour, .minute], from: eventDate)
                    if components.hour != 0 || components.minute != 0 { fireTime = eventDate }
                }
                suggestions.append(PingSuggestion(fireDate: nextDate, fireTime: fireTime, recurrence: recurrence))
            }
            return suggestions
        }

        let isAutoYearly = autoYearlyKeywords.contains { text.contains($0) }
        if isAutoYearly, let eventDate = dates.eventDate {
            let defaultTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: eventDate)
            suggestions.append(PingSuggestion(
                fireDate: eventDate,
                fireTime: hasSpecificTime ? eventDate : defaultTime,
                recurrence: .yearly
            ))
            if let reminderDate = dates.reminderDate {
                suggestions.append(PingSuggestion(
                    fireDate: reminderDate,
                    fireTime: dates.reminderTime ?? (hasSpecificTime ? eventDate : nil),
                    recurrence: Ping.Recurrence.none
                ))
            }
            return suggestions
        }

        if text.contains("every day") || text.contains("everyday") || text.contains("daily") {
            let allTimes = extractAllTimes(from: text)
            if allTimes.count > 1 {
                for time in allTimes {
                    suggestions.append(PingSuggestion(fireDate: time, fireTime: time, recurrence: .daily))
                }
                return suggestions
            }
            let fireDate = dates.eventDate ?? Date()
            suggestions.append(PingSuggestion(fireDate: fireDate, fireTime: dates.eventDate, recurrence: .daily))
            return suggestions
        }

        if text.contains("every week") || text.contains("weekly") {
            let fireDate = dates.eventDate ?? Date()
            suggestions.append(PingSuggestion(fireDate: fireDate, fireTime: dates.eventDate, recurrence: .weekly))
            return suggestions
        }
        if text.contains("every month") || text.contains("monthly") {
            let fireDate = dates.eventDate ?? Date()
            suggestions.append(PingSuggestion(fireDate: fireDate, fireTime: dates.eventDate, recurrence: .monthly))
            return suggestions
        }
        if text.contains("every year") || text.contains("yearly") || text.contains("annually") {
            let fireDate = dates.eventDate ?? Date()
            suggestions.append(PingSuggestion(fireDate: fireDate, fireTime: dates.eventDate, recurrence: .yearly))
            return suggestions
        }

        guard let eventDate = dates.eventDate else { return [] }

        let hasReminderIntent = reminderKeywords.contains { text.contains($0) }
        let isActionable = detectAction(text: text)
        guard hasReminderIntent || hasSpecificTime || isActionable else { return [] }

        if let reminderDate = dates.reminderDate {
            suggestions.append(PingSuggestion(
                fireDate: reminderDate,
                fireTime: dates.reminderTime ?? (hasSpecificTime ? eventDate : nil),
                recurrence: Ping.Recurrence.none
            ))
        } else {
            suggestions.append(PingSuggestion(
                fireDate: eventDate,
                fireTime: hasSpecificTime ? eventDate : nil,
                recurrence: Ping.Recurrence.none
            ))
        }
        return suggestions
    }

    // MARK: - Weekday Detection

    private func detectWeekdays(text: String) -> [Int] {
        var weekdays: [Int] = []
        for (name, number) in weekdayMap {
            if text.contains(name) {
                if !weekdays.contains(number) { weekdays.append(number) }
            }
        }
        if weekdays.count >= 2 { return weekdays }
        else if weekdays.count == 1 && text.contains("every") { return weekdays }
        return []
    }

    private func nextOccurrence(of weekday: Int) -> Date {
        let calendar = Calendar.current
        let today = Date()
        let todayWeekday = calendar.component(.weekday, from: today)
        var daysUntil = (weekday - todayWeekday + 7) % 7
        if daysUntil == 0 { daysUntil = 7 }
        return calendar.date(byAdding: .day, value: daysUntil, to: today) ?? today
    }

    // MARK: - URL Detection

    func detectURL(text: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let matches = detector?.matches(in: text, range: range),
              let firstMatch = matches.first,
              let url = firstMatch.url else { return nil }
        return url.absoluteString
    }

    // MARK: - Checklist Detection

    func detectChecklist(text: String) -> [String]? {
        // Strip common intro phrases before the list
        // e.g. "things to buy at the grocery store: milk, eggs" → ["milk", "eggs"]
        let introPatterns = [
            #"^.{0,60}(?:to buy|to get|to watch|to read|to do|grocery|shopping|list|need|want|shows?|movies?|books?)[\s:,]+(.+)$"#,
        ]

        var cleanedText = text
        for pattern in introPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                cleanedText = String(text[range])
                break
            }
        }

        // Also handle colon separator — everything after the colon is the list
        if let colonRange = cleanedText.range(of: ": ") {
            let afterColon = String(cleanedText[colonRange.upperBound...])
            if afterColon.contains(",") || afterColon.components(separatedBy: .newlines).count >= 2 {
                cleanedText = afterColon
            }
        }

        let lines = cleanedText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if lines.count >= 3 { return lines }

        let commaItems = cleanedText.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if commaItems.count >= 3 { return commaItems }

        return nil
    }
    // MARK: - Tag Generation

    private func generateTags(text: String, echoName: String, entities: (people: [String], places: [String], organizations: [String])) -> [String] {
        var tags: [String] = []

        for person in entities.people { if !tags.contains(person) && person.count > 2 { tags.append(person) } }
        for place in entities.places { if !tags.contains(place) && place.count > 2 { tags.append(place) } }
        for org in entities.organizations { if !tags.contains(org) && org.count > 2 { tags.append(org) } }

        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            if tags.count >= 6 { return false }
            if let tag = tag, tag == .noun {
                let word = String(text[range]).lowercased()
                if !tags.contains(word) && word.count > 3 { tags.append(word) }
            }
            return true
        }

        if !tags.contains(echoName.lowercased()) { tags.append(echoName.lowercased()) }
        return Array(tags.prefix(6))
    }

    // MARK: - Learn Keywords from Confirmed Memory

    static func learnKeywords(from text: String, echo: Echo) {
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = text
        var keywords: [String] = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word,
                             scheme: .nameType,
                             options: [.omitWhitespace, .omitPunctuation, .joinNames]) { tag, range in
            if tag != nil {
                let word = String(text[range]).lowercased()
                if word.count > 2 { keywords.append(word) }
            }
            return true
        }

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word,
                             scheme: .lexicalClass,
                             options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            if tag == .noun {
                let word = String(text[range]).lowercased()
                if word.count > 3 { keywords.append(word) }
            }
            return true
        }

        for keyword in keywords where !echo.learnedKeywords.contains(keyword) {
            echo.learnedKeywords.append(keyword)
        }
    }
}
