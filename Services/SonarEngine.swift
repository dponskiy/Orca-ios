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
    let detectedPeople: [String]
    let estimatedMinutes: Int?
    let checklistItems: [String]
}

class SonarEngine {
    
    private let keywordMap: [(echo: String, keywords: [String], priority: Int)] = [
        ("Health", ["doctor", "medicine", "prescription", "appointment", "dentist", "therapy", "vitamin", "hospital", "symptoms", "allergy", "medication", "pharmacy", "sick", "pain", "blood pressure", "checkup", "nurse", "clinic", "urgent care", "specialist", "surgeon", "physical", "lab results", "diagnosis", "chronic", "inflammation", "fever", "nausea", "injury", "rehab", "physical therapy",
                    "mental health", "anxiety", "depression", "therapist", "psychiatrist", "psychologist",
                    "dermatologist", "ophthalmologist", "optometrist", "chiropractor", "acupuncture",
                    "blood work", "mri", "xray", "x-ray", "ultrasound", "scan", "biopsy",
                    "insurance claim", "copay", "deductible", "referral", "prior authorization",
                    "cholesterol", "diabetes", "thyroid", "migraine", "headache", "back pain",
                    "sleep", "insomnia", "melatonin", "supplement", "probiotic", "omega",
                    "colonoscopy", "mammogram", "annual physical", "flu shot", "vaccine", "booster",
                    "stitches", "cast", "crutches", "the er", "went to er", "emergency room", "prescription refill", "second opinion"], 1),
        
        ("Kids", ["daycare", "teacher", "parent", "pediatrician", "baby", "child", "kid", "daughter", "son", "playground", "soccer practice", "ballet", "tutor", "school pickup", "drop off kids", "nanny", "babysitter", "kindergarten", "preschool", "school project",
                  "homework", "report card", "parent teacher", "pta", "field trip", "school supplies",
                  "playdate", "birthday party", "after school", "summer camp", "swim lessons",
                  "pediatric", "growth", "formula", "diaper", "stroller", "car seat",
                  "teenager", "teen", "college prep", "sat", "act", "extracurricular"], 2),
        
        ("Birthday", ["birthday", "bday", "turning", "birthday party", "birthday gift", "birthday present", "happy birthday", "years old", "born",
                      "birth date", "date of birth", "age", "celebrate", "celebration", "party planning",
                      "birthday cake", "birthday dinner", "surprise party", "birthday trip"], 3),
        
        ("Gifts", ["present", "gift", "christmas gift", "anniversary gift", "wishes", "wants", "wish list", "registry", "surprise", "wrapping", "send gift", "gift card",
                   "white elephant", "secret santa", "stocking stuffer", "hostess gift",
                   "thank you gift", "graduation gift", "baby gift", "wedding gift",
                   "gift idea", "gift ideas", "gifting", "amazon wishlist", "birthday list",
                   "mothers day gift", "fathers day gift", "wants for", "getting for",
                   "buying for", "got for", "ordered for", "received for",
                   "buy for", "get for", "bought for", "pick up for", "grabbing for",
                   "headphones", "airpods", "beats", "jewelry", "perfume", "cologne",
                   "flowers", "chocolates", "candle", "purse", "wallet",
                   "mothers day", "mother's day", "fathers day", "father's day"], 4),
        
        ("Travel", ["flight", "hotel", "airport", "vacation", "trip", "booking", "passport", "luggage", "airbnb", "rental car", "itinerary", "resort", "cruise", "destination", "departure", "arrival", "layover", "boarding", "check-in", "check in", "visa", "packing", "suitcase", "travel insurance", "jet lag", "timezone",
                    "vrbo", "hostel", "bed and breakfast", "motel", "road trip", "staycation",
                    "travel credit", "miles", "points", "lounge access", "global entry", "tsa precheck",
                    "carry on", "checked bag", "seat upgrade", "aisle seat", "window seat",
                    "travel adapter", "travel size", "packing list", "travel day",
                    "train", "amtrak", "eurostar", "bullet train", "ferry", "cruise ship",
                    "excursion", "tour", "guided tour", "day trip",
                    "uber", "lyft", "taxi", "airport transfer", "connecting flight",
                    "travel pillow", "noise cancelling", "departure gate", "boarding pass"], 5),
        
        ("Cooking", ["recipe", "ingredient", "cook", "bake", "tablespoon", "teaspoon", "oven", "stove", "marinade", "seasoning", "prep", "simmer", "saute", "roast", "grill", "homemade", "meal prep", "leftovers", "slow cooker", "instant pot", "air fryer", "degrees fahrenheit", "degrees celsius", "preheat", "chop", "dice", "mince", "boil", "fry", "whisk", "fold", "knead",
                     "dutch oven", "cast iron", "wok", "sheet pan", "baking dish", "mixing bowl",
                     "food processor", "blender", "stand mixer", "thermometer",
                     "meal plan", "weekly meals", "batch cook", "freezer meal",
                     "gluten free", "dairy free", "vegan", "vegetarian", "keto", "paleo",
                     "sous vide", "smoke", "smoker", "bbq sauce", "dry rub", "brine",
                     "flour", "butter", "olive oil", "garlic", "onion", "pasta", "rice",
                     "cuisine", "italian", "mexican", "thai", "japanese", "french"], 6),
        
        ("Dining", ["restaurant", "reservation", "menu", "waiter", "takeout", "delivery", "brunch", "lunch", "cafe", "appetizer", "entree", "dessert", "cocktail", "bar", "don't order", "dont order", "avoid ordering", "never order", "skip the", "dish was", "food was", "place was", "ate at", "eating at", "tried at", "recommend", "good at", "bad at", "overrated", "underrated", "must try", "never again", "great spot", "good spot", "yelp", "opentable", "resy", "uber eats", "doordash", "grubhub", "table for", "outdoor seating", "happy hour", "prix fixe", "tasting menu", "michelin", "omakase", "want to try", "looking to try", "have to try", "need to try", "heard about", "been meaning to", "wanna try", "dying to try", "check out this place", "great place", "this place",
                    "sushi", "pizza", "burger", "ramen", "tacos", "steakhouse", "seafood", "italian",
                    "wine bar", "speakeasy", "rooftop", "patio", "brunch spot", "coffee shop",
                    "bakery", "food truck", "pop up", "tasting", "chef", "sommelier",
                    "corkage", "byob", "dress code", "valet", "parking", "wait list",
                    "splurge", "date night", "business dinner", "group dinner",
                    "dinner reservation", "lunch reservation", "book a table", "walk in",
                    "james beard", "farm to table", "locally sourced",
                    "charcuterie", "bottomless", "bottomless brunch",
                    "chipotle", "mcdonalds", "mcdonald's", "starbucks", "chick-fil-a", "chick fil a",
                    "chickfila", "subway", "dominos", "domino's", "pizza hut", "taco bell", "wendy's",
                    "wendys", "burger king", "five guys", "shake shack", "sweetgreen", "cava", "panera",
                    "panda express", "in-n-out", "in n out", "raising cane's", "raising canes", "wingstop",
                    "popeyes", "dunkin", "dunkin donuts", "krispy kreme", "sonic", "whataburger",
                    "jack in the box", "del taco", "el pollo loco", "habit burger", "smashburger",
                    "freddy's", "culver's", "culvers", "cook out", "cookout", "zaxby's", "zaxbys",
                    "bojangles", "hardee's", "hardees", "carl's jr", "carls jr", "arby's", "arbys",
                    "dairy queen", "baskin robbins", "cold stone", "jamba juice", "tropical smoothie",
                    "jersey mike's", "jersey mikes", "jimmy john's", "jimmy johns", "firehouse subs",
                    "potbelly", "which wich", "mcalister's", "mcalisters", "jason's deli", "jasons deli",
                    "noodles", "pei wei", "yoshinoya", "halal guys", "halal cart",
                    "olive garden", "cheesecake factory", "applebee's", "applebees", "outback",
                    "red lobster", "texas roadhouse", "ihop", "denny's", "dennys", "waffle house",
                    "cracker barrel", "bob evans", "perkins", "friendly's", "friendlys",
                    "red robin", "tgi fridays", "tgi friday's", "chili's", "chilis", "buffalo wild wings",
                    "bww", "hooters", "dave and busters", "dave & buster's", "yard house", "yardhouse",
                    "bj's restaurant", "bjs restaurant", "seasons 52",
                    "longhorn steakhouse", "ruth's chris", "ruths chris", "flemings", "morton's",
                    "mortons", "capital grille", "mastro's", "mastros", "nobu", "benihana",
                    "maggiano's", "maggianos", "carrabba's", "carrabbas", "bonefish grill",
                    "bahama breeze", "mimi's cafe", "mimis cafe", "first watch",
                    "papa john's", "papa johns", "little caesars", "mod pizza", "blaze pizza",
                    "california pizza kitchen", "cpk", "round table", "godfather's", "godfathers",
                    "jet's pizza", "jets pizza", "marcos pizza", "hungry howie's", "hungry howies",
                    "sbarro", "cicis", "cici's",
                    "peet's", "peets", "blue bottle", "intelligentsia", "philz", "dutch bros",
                    "caribou coffee", "tim hortons", "la madeleine", "corner bakery", "einstein bagels",
                    "bruegger's", "brueggers", "noah's bagels", "great harvest", "nothing bundt cakes",
                    "p.f. chang's", "pf changs", "kura sushi", "ra sushi", "genghis grill",
                    "wagamama", "ippudo", "ichiran", "jinya ramen", "marugame udon",
                    "moe's", "moes", "qdoba", "baja fresh", "rubio's", "rubios", "cafe rio",
                    "costa vida", "on the border", "tijuana flats", "torchy's tacos", "torchys tacos",
                    "steak n shake", "steak 'n shake", "white castle", "krystal", "checkers", "rally's",
                    "quiznos", "blimpie", "penn station", "charley's",
                    "bdubs", "native wings", "pluckers",
                    "ben & jerry's", "ben and jerrys", "haagen dazs", "marble slab", "orange julius",
                    "auntie anne's", "auntie annes", "cinnabon", "wetzel's pretzels",
                    "nobu", "carbone", "eleven madison", "per se", "le bernardin", "spago",
                    "bazaar", "minibar", "alinea", "girl and the goat", "the french laundry",
                    "whole foods", "trader joe's", "trader joes", "wegmans", "erewhon",
                    "sprouts", "fresh market"], 7),
        
        ("Sports", ["game", "score", "team", "season", "ticket", "stadium", "coach",
                    "player", "league", "tournament", "playoffs", "match", "sports bar",
                    "fantasy league", "draft", "standings", "highlights", "broadcast",
                    "watch party", "betting", "odds", "spread", "parlay", "espn",
                    "monday night", "sunday night", "playoff race", "division",
                    "championship", "super bowl", "world series", "nba finals",
                    "stanley cup", "trade deadline", "roster", "starting lineup",
                    "mvp", "hall of fame", "draft pick", "free agent", "trade", "signing",
                    "injury report", "depth chart", "over under", "prop bet", "moneyline",
                    "sportsbook", "fanduel", "draftkings", "prizepicks", "underdog",
                    "nfl", "nba", "mlb", "nhl", "mls", "ncaa", "sec", "big ten",
                    "college football", "march madness", "bracket", "bowl game",
                    "hat trick", "home run", "touchdown", "three pointer", "slam dunk",
                    // NFL
                    "cowboys", "eagles", "patriots", "chiefs", "49ers", "ravens", "bills",
                    "bengals", "steelers", "texans", "colts", "jaguars", "titans", "broncos",
                    "raiders", "chargers", "rams", "seahawks", "cardinals", "giants", "jets",
                    "commanders", "bears", "lions", "packers", "vikings", "falcons", "panthers",
                    "saints", "buccaneers", "dolphins",
                    // NBA
                    "lakers", "celtics", "warriors", "bulls", "heat", "knicks", "nets", "bucks",
                    "suns", "nuggets", "clippers", "76ers", "sixers", "mavericks", "mavs",
                    "grizzlies", "timberwolves", "thunder", "pelicans", "kings", "jazz",
                    "raptors", "hawks", "hornets", "magic", "wizards", "cavaliers", "cavs",
                    "pacers", "pistons", "rockets", "spurs", "blazers",
                    // MLB
                    "yankees", "red sox", "dodgers", "cubs", "astros", "braves", "mets",
                    "phillies", "blue jays", "padres", "nationals", "orioles", "rays",
                    "mariners", "angels", "rangers", "twins", "white sox", "royals",
                    "guardians", "brewers", "pirates", "reds", "rockies", "diamondbacks",
                    // NHL
                    "bruins", "penguins", "capitals", "lightning", "maple leafs", "canadiens",
                    "blackhawks", "flyers", "rangers", "devils", "islanders", "oilers",
                    "flames", "canucks", "avalanche", "golden knights", "predators", "blues",
                    // Soccer
                    "arsenal", "chelsea", "liverpool", "man city", "man united", "tottenham",
                    "spurs", "barcelona", "real madrid", "psg", "juventus", "bayern",
                    "dortmund", "wrexham"], 8),
        
        ("Events", ["concert", "show", "festival", "conference", "expo", "recital", "performance", "gala", "ceremony", "graduation", "prom", "meetup", "gathering", "networking", "keynote", "panel", "workshop", "seminar", "opening night", "premiere", "launch event", "happy hour", "cocktail party", "wedding", "engagement", "baby shower", "retirement party",
                    "tickets", "venue", "sold out", "general admission", "vip", "backstage",
                    "meet and greet", "autograph", "setlist", "tour", "residency",
                    "broadway", "opera", "ballet performance", "comedy show", "stand up",
                    "art show", "gallery opening", "museum", "exhibit", "auction",
                    "fundraiser", "charity event", "benefit", "gala dinner",
                    "housewarming", "anniversary party", "gender reveal", "bridal shower"], 9),
        
        ("Shopping", ["price", "store", "coupon", "sale", "amazon", "size", "return", "shipping", "discount", "brand", "mall", "target", "walmart", "costco", "online order", "tracking number", "out of stock", "waitlist", "sold out", "best buy", "apple store", "wish list", "add to cart", "checkout",
                      "promo code", "coupon code", "cashback", "rebate", "price match", "price drop",
                      "black friday", "cyber monday", "prime day", "flash sale", "clearance",
                      "in store", "pickup", "curbside", "same day delivery", "free shipping",
                      "subscription box", "membership", "loyalty points", "rewards",
                      "ebay", "etsy", "poshmark", "mercari", "facebook marketplace",
                      "nordstrom rack", "tj maxx", "marshall's", "homegoods",
                      "deal", "receipt", "store credit", "gift receipt", "buy now"], 10),
        
        ("Home", ["plumber", "electrician", "repair", "mortgage", "rent", "landlord", "furniture", "paint", "garden", "lawn", "roof", "garage", "basement", "kitchen", "bathroom", "renovate", "move", "handyman", "contractor", "lease", "hoa", "property tax", "homeowners", "pest control", "hvac", "water heater", "dishwasher", "washer", "dryer", "cleaning service", "deep clean",
                  "air filter", "smoke detector", "carbon monoxide", "circuit breaker", "fuse",
                  "caulk", "grout", "tile", "hardwood", "carpet", "flooring",
                  "window", "door", "lock", "key", "deadbolt", "alarm system",
                  "moving boxes", "storage unit", "declutter", "donate", "dump run",
                  "ikea", "home depot", "lowes", "wayfair", "west elm", "restoration hardware",
                  "interior design", "staging", "curb appeal", "appraisal", "inspection",
                  "closing costs", "down payment", "refinance", "home equity", "heloc",
                  "light bulb", "battery", "extension cord", "power strip", "outlet",
                  "thermostat", "humidifier", "dehumidifier", "air purifier", "vacuum filter"], 11),
        
        ("School", ["class", "exam", "test", "study", "professor", "lecture", "semester", "tuition", "campus", "assignment", "essay", "grade", "gpa", "syllabus", "textbook", "homework", "school", "finals", "midterm", "thesis", "dissertation", "graduation", "financial aid", "fafsa", "scholarship", "college", "university", "degree", "major", "minor", "internship", "student loan",
                    "quiz", "project", "group project", "lab", "office hours", "tutoring",
                    "study group", "flashcards", "notes", "transcript", "diploma",
                    "application", "common app", "recommendation letter", "essay prompt",
                    "waitlist", "acceptance", "dorm", "roommate", "meal plan", "greek life",
                    "rush", "fraternity", "sorority", "club", "student government",
                    "research", "thesis advisor", "dissertation committee", "defense"], 12),
        
        ("Work", ["meeting", "deadline", "project", "email", "boss", "coworker", "presentation", "report", "salary", "interview", "client", "office", "standup", "promotion", "review", "slack", "zoom", "teams", "onboarding", "offboarding", "performance review", "quarterly", "sprint", "backlog", "jira", "confluence", "okr", "kpi", "pipeline", "forecast", "proposal", "contract", "invoice", "expense report", "reimbursement", "travel approval",
                  "one on one", "1:1", "all hands", "town hall", "offsite", "retreat",
                  "hire", "hiring", "job posting", "candidate", "offer letter", "counter offer",
                  "raise", "bonus", "equity", "stock options", "vesting", "401k match",
                  "pto", "vacation days", "sick day", "parental leave", "maternity", "paternity",
                  "remote", "hybrid", "in office", "work from home", "wfh",
                  "linkedin", "resume", "cover letter", "reference", "background check",
                  "layoff", "severance", "resignation", "two weeks notice",
                  "timesheet", "time sheet", "time entry", "log hours", "billable hours",
                  "punch in", "punch out", "clock in", "clock out", "overtime",
                  "payroll", "paystub", "pay stub", "direct deposit", "w2", "w-2",
                  "standup meeting", "scrum", "agile", "deliverable", "milestone", "stakeholder", "powerpoint", "ppt", "keynote", "google slides", "deck", "slide deck",  "presentation slides", "slides", "presentation deck", "spreadsheet", "excel", "google docs", "power point",
                  "google sheets", "word doc", "notion", "figma", "canva",
                  "action item", "sync", "async", "bandwidth", "capacity"], 13),
        
        ("Pets", ["vet", "dog", "cat", "puppy", "kitten", "pet food", "grooming", "walk", "collar", "leash", "litter", "treats", "adoption", "vaccine", "flea", "heartworm", "tick", "microchip", "spay", "neuter", "boarding", "pet sitter", "aquarium", "fish", "bird", "hamster", "rabbit",
                  "dog park", "dog walker", "doggy daycare", "kennel", "crate", "harness",
                  "training", "obedience", "behavioral", "separation anxiety",
                  "wet food", "dry food", "raw diet", "grain free", "dental treat",
                  "flea collar", "frontline", "nexgard", "bravecto", "apoquel",
                  "shots", "booster", "annual exam", "emergency vet", "specialist",
                  "turtle", "snake", "lizard", "gecko", "ferret", "guinea pig",
                  "pet insurance", "pet friendly", "leash training", "puppy training",
                  "raw food", "kibble", "vet bill", "pet prescription"], 14),
        
        ("Finance", ["bank", "savings", "investment", "tax", "credit card", "payment", "budget", "insurance", "loan", "interest", "401k", "stocks", "stock", "shares", "share", "trading", "trade", "portfolio", "ticker", "earnings", "dividend", "debt", "refund", "subscription", "venmo", "zelle", "wire transfer", "direct deposit", "w2", "1099", "irs", "audit", "estate planning", "will", "trust", "beneficiary", "premium", "deductible", "copay", "hsa", "fsa", "roth ira", "capital gains", "price alert", "drops below", "rises above", "buy the dip", "puts", "calls", "options", "ipo", "short", "long", "stonks",
                     "etf", "index fund", "mutual fund", "hedge fund", "crypto", "bitcoin", "ethereum",
                     "brokerage", "schwab", "fidelity", "vanguard", "robinhood", "webull",
                     "net worth", "asset allocation", "rebalance", "diversify",
                     "credit score", "credit report", "freeze credit", "identity theft",
                     "mortgage rate", "refinance", "home equity", "heloc",
                     "life insurance", "term life", "whole life", "umbrella policy",
                     "quarterly tax", "estimated tax", "write off", "deduction", "itemize",
                     "paycheck", "gross pay", "net pay", "withholding", "w4"], 15),
        
        ("Holidays", ["christmas", "thanksgiving", "easter", "halloween", "new year", "valentine", "fourth of july", "independence day", "labor day", "memorial day", "hanukkah", "kwanzaa", "diwali", "mothers day", "fathers day", "presidents day", "martin luther king", "columbus day", "veterans day", "passover", "ramadan", "eid",
                      "holiday party", "holiday shopping", "holiday travel", "holiday cards",
                      "decorations", "lights", "tree", "wreath", "ornaments", "tinsel",
                      "candy corn", "trick or treat", "costume", "pumpkin", "carve",
                      "turkey", "stuffing", "cranberry", "pie", "feast", "family dinner",
                      "new years eve", "countdown", "resolution", "champagne",
                      "easter egg", "basket", "menorah", "dreidel", "advent"], 16),
        
        ("To-Do", ["laundry", "vacuum", "dishes", "clean", "trash", "recycle", "mop", "dust", "organize", "declutter", "iron", "sweep", "garbage", "errands", "chores", "errand", "pick up", "drop off", "run", "stop by", "swing by", "grab", "need to", "have to", "got to", "gotta", "don't forget", "dont forget", "reminder", "task", "to-do", "todo", "checklist", "errand run", "dry cleaning", "post office", "bank", "hardware store", "pharmacy", "drugstore", "gas station", "car wash", "oil change", "DMV", "MVA", "returns", "exchange", "package", "mail", "ups", "fedex", "usps",
                   "call back", "follow up", "respond", "reply", "rsvp",
                   "schedule", "book appointment", "cancel appointment", "reschedule",
                   "renew", "registration", "license", "permit", "inspection",
                   "pay bill", "autopay", "due date", "overdue", "late fee",
                   "grocery run", "shopping list", "stock up", "reorder",
                   "fix", "repair", "replace", "install", "set up", "update",
                   // Action phrases for reminders
                   "remind me", "remember to", "don't forget to", "dont forget to",
                   "make sure to", "make sure i", "need to remember",
                   // Cleaning / chore verbs missing from original list
                   "wash", "wipe", "scrub", "rinse", "refill", "restock",
                   "charge", "empty", "take out", "put away", "clean out"], 17),
        
        ("Games", ["xbox", "playstation", "nintendo", "switch", "steam", "gaming", "controller", "multiplayer", "level", "quest", "raid", "download", "dlc", "console", "pc gaming", "esports", "twitch", "speedrun", "achievements", "trophy", "walkthrough", "patch", "update", "early access", "game pass", "ps5", "ps4", "xbox series",
                   "rpg", "fps", "mmorpg", "battle royale", "open world", "sandbox",
                   "fortnite", "minecraft", "call of duty", "warzone", "apex legends",
                   "league of legends", "valorant", "overwatch", "destiny", "halo",
                   "zelda", "mario", "pokemon", "final fantasy", "elden ring",
                   "new release", "pre-order", "launch day", "server",
                   "headset", "keyboard", "mouse", "gaming chair", "monitor refresh",
                   "frame rate", "resolution", "graphics card", "gpu", "build",
                   "save file", "mod", "modding", "gaming pc", "clip", "highlight"], 18),
        
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
                    "max", "paramount+", "discovery+", "fubo", "sling", "youtube tv",
                    "now watching", "just finished", "just watched", "recommend watching",
                    "true crime", "reality tv", "reality show", "game show", "talk show",
                    "late night", "saturday night live", "snl", "animation", "anime",
                    "oscar", "emmy", "golden globe", "academy award",
                    "box office", "opening weekend", "limited release", "wide release",
                    "casting", "showrunner", "writer", "producer", "cinematography",
                    "letterboxd", "directors cut", "extended cut", "dubbed", "subtitles",
                    "foreign film", "arthouse", "midnight screening"], 19),
        
        ("Books", ["book", "read", "reading", "novel", "author", "chapter", "kindle", "audible", "library", "bookstore", "fiction", "nonfiction", "memoir", "biography", "audiobook", "bestseller", "hardcover", "paperback", "goodreads", "page", "plot", "genre", "publisher", "literature", "ebook", "book club", "book review", "recommended reading", "sequel", "trilogy", "series", "graphic novel", "comic book",
                   "currently reading", "just finished", "want to read", "reading list",
                   "page turner", "couldn't put it down", "beach read", "book recommendation",
                   "new york times bestseller", "oprah book club", "reese book club",
                   "thriller", "mystery", "romance", "sci fi", "fantasy", "horror",
                   "self help", "business book", "leadership", "productivity",
                   "kindle unlimited", "scribd", "libby", "overdrive",
                   "signed copy", "first edition", "book store", "barnes and noble",
                   "short story", "essay collection", "poetry", "anthology",
                   "ya", "young adult", "middle grade", "self improvement", "page count"], 20),
        
        ("Clothes", ["shirt", "pants", "shoes", "dress", "jacket", "coat", "outfit", "wear", "wearing", "clothes", "clothing", "jeans", "sweater", "hoodie", "socks", "underwear", "suit", "tie", "hat", "scarf", "gloves", "boots", "sneakers", "dry clean", "tailored", "alterations", "wardrobe", "fashion", "style", "nordstrom", "zara", "h&m", "uniqlo", "lululemon", "nike", "adidas", "size medium", "size large", "size small",
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
                     "superset", "drop set", "max out", "sets and reps", "working out", "gym", "workout", "lifting", "volume", "hit the gym",
                     "i ran", "we ran", "just ran", "ran today", "ran this morning", "ran for", "ran a mile", "ran a 5k", "went for a run",
                     "running", "miles", "kilometers", "treadmill", "elliptical",
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
                     "weight loss", "bulk", "cut", "lean", "shred", "gains",
                     "protein", "creatine", "pre workout", "bcaa", "whey",
                     "rest day", "recovery", "deload", "periodization",
                     "body fat", "body composition", "body weight", "weigh in",
                     "steps", "active calories", "apple watch", "garmin", "whoop",
                     "heart rate zone", "vo2 max", "lactate threshold",
                     "strava", "nike run club", "couch to 5k",
                     "gym membership", "planet fitness", "equinox", "lifetime",
                     "home gym", "resistance band", "pull up bar"], 22),
    ]
    
    private let reminderKeywords = ["remind", "remember", "don't forget", "dont forget", "every monday", "every tuesday", "every wednesday", "every thursday", "every friday", "every saturday", "every sunday", "every week", "every month", "every year", "every day", "daily", "weekly", "monthly", "yearly", "annually", "appointment", "deadline", "due date"]
    
    private let actionKeywords = [
        // Voice-natural intent phrases ("I need to call...", "gotta pick up...", "have to send...")
        "need to", "have to", "got to", "gotta", "gonna", "i should", "should probably",
        "don't forget to", "dont forget to", "make sure to", "make sure i",
        "i have an", "i have a", // "I have an appointment", "I have a meeting"

        // Getting / acquiring
        "buy", "get", "pick up", "pickup", "grab", "order", "purchase", "stock up", "reorder",

        // Communication
        "call", "email", "send", "text", "message", "contact", "reach out", "follow up",
        "respond", "reply", "rsvp", "invite", "notify", "ping", "remind",

        // Scheduling
        "schedule", "book", "reserve", "arrange", "set up", "setup", "plan", "organize",
        "confirm", "reschedule", "cancel", "register",

        // Work / creation
        "work", "work on", "finish", "complete", "submit", "file", "draft", "write",
        "prepare", "present", "build", "create", "design", "develop", "code", "record",
        "edit", "review", "proofread", "publish", "launch", "release", "ship", "deploy",
        "outline", "research", "study", "practice", "train", "learn", "read",

        // Tasks / errands
        "fix", "repair", "replace", "install", "update", "upgrade", "reset", "set",
        "clean", "wash", "iron", "fold", "vacuum", "organize", "declutter", "donate",
        "return", "exchange", "drop off", "dropoff", "mail", "ship", "print", "scan",
        "deposit", "transfer", "pay", "apply", "renew", "sign", "sign up", "signup",

        // Physical / active
        "run", "go", "start", "begin", "head", "drive", "walk", "take", "bring", "move",
        "pack", "unpack", "load", "unload",

        // Health
        "take", "refill", "restock", "fill", "pick up prescription",

        // Social / events
        "meet", "see", "visit", "attend", "join", "host", "throw", "plan",

        // Financial
        "pay", "charge", "invoice", "bill", "transfer", "deposit",

        // Finding / checking
        "find", "look into", "check", "look up", "search", "compare", "test",

        // Events / appointments (treat presence as action)
        "game", "concert", "show", "match", "party", "dinner", "event",
        "appointment", "meeting", "flight", "reservation", "practice",
        "class", "exam", "recital", "performance", "interview",
    ]
    
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
        // "eat" and "ate" removed — "eat" matches "feature"/"meat"/"heat", "ate" matches "date"/"state"/"create"
        "eating out", "eating at", "let's eat", "going to eat", "want to eat",
        "we ate", "i ate", "just ate", "ate at", "ate there", "ate here",
        "food", "dish", "menu", "lunch", "dinner", "brunch",
        "breakfast", "taste", "flavor", "delicious", "portions", "service", "waiter",
        "tried", "dining", "restaurant", "reservations", "takeout",
        "delivery", "cuisine", "spot", "eats"
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
        let dateResults = detectDates(text: text)
        let tags = generateTags(text: text, echoName: echoResult.name, entities: entities)
        var actionable = detectAction(text: lower)
        let pingSuggestions = buildPingSuggestions(text: lower, dates: dateResults)

        // If ping was created AND text has action intent, ensure it's marked as a task
        let hasActionVerb = actionKeywords.contains { lower.contains($0) }
        if !pingSuggestions.isEmpty && hasActionVerb { actionable = true }
        
        let primary = pingSuggestions.first
        
        let detectedURL = detectURL(text: text)
        let isCookingEcho = echoResult.name.lowercased().contains("cook") ||
        echoResult.name.lowercased().contains("recipe")
        let shouldOfferRecipeFetch = isCookingEcho && detectedURL != nil
        
        let hasDiningContext = diningContextWords.contains { lower.contains($0) }
        let hasRestaurantSignal = !entities.organizations.isEmpty && hasDiningContext

        let checklistItems = detectChecklistItems(text: text)

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
            detectedPeople: entities.people.map { $0.capitalized },
            estimatedMinutes: DurationParser.shared.parse(text: text),
            checklistItems: checklistItems
        )
    }

    // Detects comma/and separated action items after trigger phrases like "need to", "have to", etc.
    private func detectChecklistItems(text: String) -> [String] {
        let lower = text.lowercased()

        // Action verbs that signal a task item
        let actionVerbs = ["pick up", "pickup", "buy", "get", "grab", "prep", "prepare", "clean",
                           "call", "email", "text", "book", "reserve", "order", "return", "drop off",
                           "dropoff", "send", "print", "pack", "unpack", "fix", "repair", "check",
                           "confirm", "schedule", "remind", "bring", "take", "make", "cook", "bake",
                           "wash", "iron", "wrap", "charge", "download", "install", "cancel", "pay",
                           "register", "sign up", "review", "finish", "complete", "submit", "upload",
                           "clear", "tidy", "sweep", "mop", "mow", "dust", "wipe", "scrub", "set out",
                           "put away", "gather", "throw", "set up", "pick", "move", "fold"]

        // Trigger phrases that introduce a list
        let triggerPhrases = [
            // Direct intent
            "need to", "needs to", "have to", "has to", "gotta", "got to", "gonna",
            "want to", "wants to", "plan to", "planning to", "going to",
            "trying to", "hoping to", "supposed to", "i should", "we should",

            // Memory / reminder framing
            "remind me to", "remind me i need to", "remind us to", "reminder to",
            "remember to", "remember i need to", "don't forget to", "dont forget to",
            "don't forget", "dont forget", "before i forget", "note to self",
            "make sure to", "make sure i", "make sure we",
            "need to make sure", "just a reminder", "set a reminder to",

            // Casual spoken forms
            "i gotta", "i've gotta", "ive gotta", "i got to", "i need to",
            "we gotta", "we've gotta", "we need to", "we have to",
            "i have to", "i've got to", "ive got to",
            "can you remind me to", "can you remind us to",
            "don't let me forget", "dont let me forget",
            "i keep forgetting to", "keep forgetting to",
            "add to my list", "add to the list", "put on my list",
            "on my list", "on the list",

            // Obligation / necessity
            "must", "should", "need:", "i must",

            // List framing
            "to do:", "todo:", "tasks:", "items:", "checklist:", "list:",
            "action items:", "things to", "stuff to", "things i need",
            "few things", "a few things", "couple things", "some things",
            "a couple of things", "few things i need", "some stuff i need",
            "bunch of things", "a bunch of things",

            // Event prep framing
            "before the", "before we", "before i", "for the party", "for the trip",
            "for the event", "for the dinner", "for the meeting", "for the weekend",
            "for tomorrow", "for today", "this week i need to",
        ]

        // Find the position after the trigger phrase
        var listStart: String.Index? = nil
        for phrase in triggerPhrases {
            if let range = lower.range(of: phrase) {
                listStart = range.upperBound
                break
            }
        }

        guard let start = listStart else { return [] }

        let remainder = String(text[start...]).trimmingCharacters(in: .whitespaces)

        // Split on comma, "and", semicolon
        var rawItems = remainder
            .components(separatedBy: ",")
            .flatMap { $0.components(separatedBy: " and ") }
            .flatMap { $0.components(separatedBy: ";") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Second pass: split on embedded action verbs for voice input (no commas spoken)
        let sortedVerbs = actionVerbs.sorted { $0.count > $1.count }
        rawItems = rawItems.flatMap { item -> [String] in
            var results: [String] = []
            var current = item
            while current.count > 1 {
                let searchFrom = current.index(after: current.startIndex)
                let searchRange = searchFrom..<current.endIndex
                var splitFound = false
                for verb in sortedVerbs {
                    let pattern = " \(verb) "
                    if let range = current.range(of: pattern, options: .caseInsensitive, range: searchRange) {
                        let before = String(current[current.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                        let afterSpace = current.index(after: range.lowerBound)
                        current = String(current[afterSpace...]).trimmingCharacters(in: .whitespaces)
                        if !before.isEmpty { results.append(before) }
                        splitFound = true
                        break
                    }
                }
                if !splitFound { break }
            }
            if !current.isEmpty { results.append(current) }
            return results
        }

        // For items that don't start with a verb (e.g. "tomorrow at 4pm call the vet"),
        // extract the verb-starting portion so the task isn't lost to a date prefix.
        let rescued = rawItems.flatMap { item -> [String] in
            let itemLower = item.lowercased()
            if actionVerbs.contains(where: { itemLower.hasPrefix($0) }) {
                return [item]
            }
            for verb in sortedVerbs {
                if let range = item.range(of: " \(verb)", options: .caseInsensitive) {
                    let extracted = String(item[item.index(after: range.lowerBound)...]).trimmingCharacters(in: .whitespaces)
                    if !extracted.isEmpty { return [extracted] }
                }
            }
            return []
        }

        // Only keep items that start with an action verb and are short enough to be a clear task
        let filtered = rescued.filter { item in
            let itemLower = item.lowercased()
            let startsWithVerb = actionVerbs.contains { itemLower.hasPrefix($0) }
            let isShortTask = item.split(separator: " ").count <= 8
            return startsWithVerb && isShortTask
        }

        // Need at least 2 items to auto-create a checklist
        if filtered.count >= 2 {
            return filtered.map { item in item.prefix(1).uppercased() + item.dropFirst() }
        }

        // Fallback: colon-separated list style ("to buy: milk, eggs, bread")
        let colonPatterns = [
            #"(?:to buy|to get|to watch|to read|to do|grocery|shopping list|need|want)[\s:,]+(.+)$"#
        ]
        for pattern in colonPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range(at: 1), in: text) else { continue }
            let listText = String(text[range])
            let colonItems = listText.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if colonItems.count >= 2 {
                return colonItems.map { item in item.prefix(1).uppercased() + item.dropFirst() }
            }
        }

        return []
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
        
        let commonNonNames = Set([
            "january", "february", "march", "april", "may", "june", "july",
            "august", "september", "october", "november", "december",
            "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
            "new", "york", "los", "san", "las",
            "birthday", "christmas", "holiday", "anniversary", "halloween",
            "thanksgiving", "valentine", "easter",
            "get", "got", "getting", "buy", "bought", "buying", "find", "found",
            "pick", "order", "ordered", "grab", "grabbed", "need", "want",
            "make", "take", "give", "send", "bring", "call", "tell", "ask",
            "remind", "remember", "check", "look", "try", "let", "put",
            "today", "tomorrow", "tonight", "morning", "afternoon", "evening",
            "this", "next", "last"
        ])
        
        let personIndicators = Set(["for", "with", "tell", "ask", "remind", "call",
                                    "text", "email", "invite", "get", "buy", "give", "send", "show"])
        let words = text.components(separatedBy: .whitespaces)
        for (i, word) in words.enumerated() {
            let clean = word.trimmingCharacters(in: .punctuationCharacters)
            guard clean.count > 2,
                  clean.first?.isUppercase == true,
                  !commonNonNames.contains(clean.lowercased()),
                  !people.contains(clean.lowercased()),
                  !places.contains(clean.lowercased()),
                  !organizations.contains(clean.lowercased()) else { continue }
            guard i > 0 else { continue }
            let prevWord = words[i - 1].trimmingCharacters(in: .punctuationCharacters).lowercased()
            guard personIndicators.contains(prevWord) else { continue }
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
        
        let words = originalText.components(separatedBy: .whitespaces)
        let properNouns = words.filter { word in
            let clean = word.trimmingCharacters(in: .punctuationCharacters)
            return clean.count > 2 &&
            clean.first?.isUppercase == true &&
            !restaurantCommonWords.contains(clean.lowercased())
        }
        let nonPersonProperNouns = properNouns.filter { noun in
            !entities.people.contains(noun.lowercased())
        }
        // Prevent Books from winning when legal/work context is present
        let legalWords = ["contract", "agreement", "document", "signing", "sign", "lease", "terms", "policy", "waiver", "deed"]
        let hasLegalContext = legalWords.contains { text.contains($0) }
        if hasLegalContext {
            if let idx = scores.firstIndex(where: { $0.name == "Books" }) {
                scores[idx].score = max(0, scores[idx].score - 3.0)
            }
            if let idx = scores.firstIndex(where: { $0.name == "Work" }) {
                scores[idx].score += 2.0
            } else {
                scores.append(("Work", 2.0, 13))
            }
        }
        // Prevent productivity tools from landing in wrong echo
        let productivityTools = ["powerpoint", "excel", "google slides", "google sheets",
                                 "google docs", "keynote", "notion", "figma", "canva",
                                 "word doc", "airtable", "spreadsheet", "slide deck", "ppt"]
        let hasProductivityTool = productivityTools.contains { text.contains($0) }
        if hasProductivityTool {
            if let idx = scores.firstIndex(where: { $0.name == "Work" }) {
                scores[idx].score += 2.0
            } else {
                scores.append(("Work", 2.0, 13))
            }
            // Suppress dining specifically since it's the false positive
            if let idx = scores.firstIndex(where: { $0.name == "Dining" }) {
                scores[idx].score = max(0, scores[idx].score - 3.0)
            }
        }
        // Prevent Sports from winning when clothing/chores context is present
        let clothingChoreWords = ["shirt", "dress shirt", "iron", "ironing", "pants", "suit", "jacket", "outfit", "wear", "laundry", "wash", "dry clean"]
        let hasClothingContext = clothingChoreWords.contains { text.contains($0) }
        if hasClothingContext {
            if let idx = scores.firstIndex(where: { $0.name == "Sports" }) {
                scores[idx].score = max(0, scores[idx].score - 3.0)
            }
        }
        // Prevent Dining from winning on chore/cleaning reminders
        // e.g. "wash water bottle", "wipe down counter", "clean the fridge"
        let choreActionWords = ["wash", "wipe", "scrub", "rinse", "clean", "mop", "vacuum",
                                "sweep", "dust", "declutter", "organize", "refill", "empty",
                                "take out", "put away", "remind me", "remember to"]
        let hasChoreContext = choreActionWords.contains { text.contains($0) }
        if hasChoreContext {
            if let idx = scores.firstIndex(where: { $0.name == "Dining" }) {
                scores[idx].score = max(0, scores[idx].score - 3.0)
            }
            // Boost To-Do if it already has some score, or add it
            if let idx = scores.firstIndex(where: { $0.name == "To-Do" }) {
                scores[idx].score += 1.5
            } else {
                scores.append(("To-Do", 1.5, 17))
            }
        }
        // Prevent Health from winning when clear cooking context is present
        let cookingContextWords = ["sourdough", "recipe", "bake", "cook", "oven", "simmer", "saute", "roast", "ingredient", "flour", "dough", "starter", "knead"]
        let hasCookingContext = cookingContextWords.contains { text.contains($0) }
        if hasCookingContext {
            if let idx = scores.firstIndex(where: { $0.name == "Cooking" }) {
                scores[idx].score += 2.0
            } else {
                scores.append(("Cooking", 2.0, 6))
            }
            if let idx = scores.firstIndex(where: { $0.name == "Health" }) {
                scores[idx].score = max(0, scores[idx].score - 2.0)
            }
        }
        // Prevent Dining/Cooking from winning when tech/device context is present
        let techContextWords = ["dash cam", "dashcam", "camera", "firmware", "settings", "wifi", "bluetooth", "router", "device", "update settings", "app update", "software", "reset"]
        let hasTechContext = techContextWords.contains { text.contains($0) }
        if hasTechContext {
            if let idx = scores.firstIndex(where: { $0.name == "Dining" }) {
                scores[idx].score = max(0, scores[idx].score - 3.0)
            }
            if let idx = scores.firstIndex(where: { $0.name == "Cooking" }) {
                scores[idx].score = max(0, scores[idx].score - 3.0)
            }
        }
        let likelyRestaurantName = !nonPersonProperNouns.isEmpty && nonPersonProperNouns.count <= 3
        if likelyRestaurantName && hasDiningContext {
            let boost = nonPersonProperNouns.count == 1 ? 2.5 : 2.0
            if let idx = scores.firstIndex(where: { $0.name == "Dining" }) {
                scores[idx].score += boost
            } else {
                scores.append(("Dining", boost, 7))
            }
        }
        
        let healthContextWords = ["doctor", "dr.", "appointment", "prescription", "diagnosis", "symptoms", "hospital", "clinic", "therapy"]
        let hasHealthContext = healthContextWords.contains { text.contains($0) }
        if !entities.people.isEmpty && hasHealthContext {
            if let idx = scores.firstIndex(where: { $0.name == "Health" }) {
                scores[idx].score += 1.0
            }
        }
        
        let workContextWords = ["meeting", "call", "email", "project", "deadline", "client", "office", "zoom", "slack", "presentation"]
        let hasWorkContext = workContextWords.contains { text.contains($0) }
        if !entities.people.isEmpty && hasWorkContext {
            if let idx = scores.firstIndex(where: { $0.name == "Work" }) {
                scores[idx].score += 1.0
            }
        }
        
        for echo in echos where !echo.learnedKeywords.isEmpty {
            let matchCount = echo.learnedKeywords.filter { text.contains($0) }.count
            if matchCount > 0 {
                let boost = Double(matchCount) * 0.1
                if let idx = scores.firstIndex(where: { $0.name == echo.name }) {
                    scores[idx].score += boost
                } else {
                    scores.append((echo.name, boost, 0))
                }
            }
        }
        
        let detectedWorkout = WorkoutParser.shared.detectWorkout(in: originalText)
        if detectedWorkout != nil {
            if let idx = scores.firstIndex(where: { $0.name == "Workout" }) {
                scores[idx].score += 3.0
            } else {
                scores.append(("Workout", 3.0, 22))
            }
        }
        
        let exerciseNxMPattern = #"(?:bench|squat|deadlift|curl|press|row|pull|push|lunge|plank|fly|extension|raise|dip|shrug|crunch|deads|ohp)\w*\s+\d+"#
        if normalizedText.range(of: exerciseNxMPattern, options: .regularExpression) != nil {
            if let idx = scores.firstIndex(where: { $0.name == "Workout" }) {
                scores[idx].score += 5.0
            } else {
                scores.append(("Workout", 5.0, 22))
            }
            if let fidx = scores.firstIndex(where: { $0.name == "Finance" }) {
                scores[fidx].score = max(0, scores[fidx].score - 3.0)
            }
        }
        
        let cardioPattern = #"\d+(?:\.\d+)?\s*(?:miles?|km|kilometers?|meters?|k)\b.{0,30}\d+\s*(?:minutes?|mins?|hours?|hr)"#
        if normalizedText.range(of: cardioPattern, options: .regularExpression) != nil {
            if let idx = scores.firstIndex(where: { $0.name == "Workout" }) {
                scores[idx].score += 4.0
            } else {
                scores.append(("Workout", 4.0, 22))
            }
        }
        
        let classPattern = #"(?:orangetheory|orange theory|otf|f45|corepower|solidcore|barrys|soulcycle|barre|pilates|yoga|boxing|bootcamp|zumba|crossfit)\w*\s+\d+"#
        if normalizedText.range(of: classPattern, options: [.regularExpression, .caseInsensitive]) != nil {
            if let idx = scores.firstIndex(where: { $0.name == "Workout" }) {
                scores[idx].score += 5.0
            } else {
                scores.append(("Workout", 5.0, 22))
            }
        }
        
        let detectedTicker = FinanceService.shared.detectTicker(in: originalText)
        if detectedTicker != nil {
            if let idx = scores.firstIndex(where: { $0.name == "Finance" }) {
                scores[idx].score += 3.0
            } else {
                scores.append(("Finance", 3.0, 15))
            }
        }
        
        if text.contains("travel") || text.contains("trip") {
            if let idx = scores.firstIndex(where: { $0.name == "Travel" }) {
                scores[idx].score += 3.0
            } else {
                scores.append(("Travel", 3.0, 5))
            }
        }
        
        let giftGivingPattern = #"(?:get|got|getting|buy|bought|buying|picked up|ordered|found|grabbed)\s+\w+\s+(?:a|an|the|some)?\s*\w+"#
        if normalizedText.range(of: giftGivingPattern, options: [.regularExpression, .caseInsensitive]) != nil {
            let giftContextWords = ["birthday", "christmas", "anniversary", "holiday", "gift", "present", "surprise"]
            if giftContextWords.contains(where: { normalizedText.contains($0) }) {
                if let idx = scores.firstIndex(where: { $0.name == "Gifts" }) {
                    scores[idx].score += 4.0
                } else {
                    scores.append(("Gifts", 4.0, 4))
                }
                if let idx = scores.firstIndex(where: { $0.name == "Birthday" }) {
                    scores[idx].score = max(0, scores[idx].score - 2.0)
                }
            }
        }
        
        if let best = scores.max(by: { a, b in
            a.score < b.score || (a.score == b.score && a.priority > b.priority)
        }) {
            let isActionableText = actionKeywords.contains { text.contains($0) }
            let weakScore = best.score < 1.5
            let suspectEcho = ["Birthday", "Holidays", "Movies", "Books", "Games", "Clothes", "Notes"].contains(best.name)
            
            if isActionableText && weakScore && suspectEcho {
                let todoEcho = echos.first { $0.name == "To-Do" }
                return (todoEcho?.id, "To-Do", 0.65)
            }
            
            let echo = echos.first { $0.name == best.name }
            let confidence = best.score >= 2.0 ? 0.9 : 0.65
            return (echo?.id, best.name, confidence)
        }
        
        let notesEcho = echos.first { $0.name == "Notes" }
        return (notesEcho?.id, "Notes", 0.3)
    }

    // MARK: - Relative Date Detection (runs before NSDataDetector)

    private func detectRelativeDate(text: String) -> Date? {
        let lower = text.lowercased()
        let now = Date()
        let calendar = Calendar.current

        let patterns: [(String, () -> Date?)] = [
            // Minutes
            (#"in\s+(a\s+)?(\d+|one|two|three|four|five|ten|fifteen|twenty|thirty|forty|forty.five|forty five|forty-five|forty five|45|30|20|15|10|5)\s*min(?:utes?)?"#, {
                let nums = ["one":1,"two":2,"three":3,"four":4,"five":5,"ten":10,"fifteen":15,"twenty":20,"thirty":30,"forty":40,"forty-five":45,"forty five":45]
                for (word, val) in nums { if lower.contains("in \(word) min") { return calendar.date(byAdding: .minute, value: val, to: now) } }
                if let match = lower.range(of: #"in\s+(\d+)\s*min"#, options: .regularExpression),
                   let numRange = lower.range(of: #"\d+"#, options: .regularExpression, range: match),
                   let val = Int(lower[numRange]) { return calendar.date(byAdding: .minute, value: val, to: now) }
                return nil
            }),
            // Hours
            (#"in\s+(an?\s+|one\s+|two\s+|three\s+|four\s+|five\s+|six\s+|\d+\s+)hours?"#, {
                let nums = ["an":1,"a":1,"one":1,"two":2,"three":3,"four":4,"five":5,"six":6]
                for (word, val) in nums { if lower.contains("in \(word) hour") { return calendar.date(byAdding: .hour, value: val, to: now) } }
                if let match = lower.range(of: #"in\s+(\d+)\s*hours?"#, options: .regularExpression),
                   let numRange = lower.range(of: #"\d+"#, options: .regularExpression, range: match),
                   let val = Int(lower[numRange]) { return calendar.date(byAdding: .hour, value: val, to: now) }
                return nil
            }),
            // Days
            (#"in\s+(a\s+|one\s+|two\s+|three\s+|four\s+|five\s+|six\s+|seven\s+|\d+\s+)days?"#, {
                let nums = ["a":1,"one":1,"two":2,"three":3,"four":4,"five":5,"six":6,"seven":7]
                for (word, val) in nums { if lower.contains("in \(word) day") { return calendar.date(byAdding: .day, value: val, to: now) } }
                if let match = lower.range(of: #"in\s+(\d+)\s*days?"#, options: .regularExpression),
                   let numRange = lower.range(of: #"\d+"#, options: .regularExpression, range: match),
                   let val = Int(lower[numRange]) { return calendar.date(byAdding: .day, value: val, to: now) }
                return nil
            }),
            // Weeks
            (#"in\s+(a\s+|one\s+|two\s+|three\s+|four\s+|\d+\s+)weeks?"#, {
                let nums = ["a":1,"one":1,"two":2,"three":3,"four":4]
                for (word, val) in nums { if lower.contains("in \(word) week") { return calendar.date(byAdding: .weekOfYear, value: val, to: now) } }
                if let match = lower.range(of: #"in\s+(\d+)\s*weeks?"#, options: .regularExpression),
                   let numRange = lower.range(of: #"\d+"#, options: .regularExpression, range: match),
                   let val = Int(lower[numRange]) { return calendar.date(byAdding: .weekOfYear, value: val, to: now) }
                return nil
            }),
            // Months
            (#"in\s+(a\s+|one\s+|two\s+|three\s+|\d+\s+)months?"#, {
                let nums = ["a":1,"one":1,"two":2,"three":3]
                for (word, val) in nums { if lower.contains("in \(word) month") { return calendar.date(byAdding: .month, value: val, to: now) } }
                if let match = lower.range(of: #"in\s+(\d+)\s*months?"#, options: .regularExpression),
                   let numRange = lower.range(of: #"\d+"#, options: .regularExpression, range: match),
                   let val = Int(lower[numRange]) { return calendar.date(byAdding: .month, value: val, to: now) }
                return nil
            }),
        ]

        for (pattern, resolver) in patterns {
            if lower.range(of: pattern, options: .regularExpression) != nil {
                if let date = resolver() { return date }
            }
        }

        // End of month
        let endOfMonthPhrases = ["end of the month", "end of month", "eom", "last day of the month"]
        if endOfMonthPhrases.contains(where: { lower.contains($0) }) {
            if let endOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)).flatMap({
                calendar.date(byAdding: DateComponents(month: 1, day: -1), to: $0)
            }) {
                return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: endOfMonth)
            }
        }

        // End of week (Friday)
        let endOfWeekPhrases = ["end of the week", "end of week", "eow"]
        if endOfWeekPhrases.contains(where: { lower.contains($0) }) {
            let todayWeekday = calendar.component(.weekday, from: now)
            let daysUntilFriday = (6 - todayWeekday + 7) % 7
            let friday = calendar.date(byAdding: .day, value: daysUntilFriday == 0 ? 7 : daysUntilFriday, to: now) ?? now
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: friday)
        }

        // Beginning of next month
        let nextMonthPhrases = ["beginning of next month", "start of next month", "first of next month", "first of the month"]
        if nextMonthPhrases.contains(where: { lower.contains($0) }) {
            if let firstOfNext = calendar.date(from: calendar.dateComponents([.year, .month], from: calendar.date(byAdding: .month, value: 1, to: now) ?? now)) {
                return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: firstOfNext)
            }
        }

        return nil
    }

    // MARK: - Date Detection
    
    private func detectDates(text: String) -> (eventDate: Date?, endDate: Date?, eventConfidence: Double?, reminderDate: Date?, reminderTime: Date?) {
        let lower = text.lowercased()
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)

        // Check for relative dates first — "remind me in 3 days", "in a week", etc.
        let hasReminderIntent = lower.contains("remind") || lower.contains("don't forget") || lower.contains("dont forget")
        let hasRelativePhrase = lower.range(of: #"in\s+(\d+|a|an|one|two|three|four|five|six|seven)\s+(minute|hour|day|week|month)s?"#, options: .regularExpression) != nil
        let hasEndPhrase = ["end of the month", "end of month", "eom", "end of the week", "end of week", "eow", "beginning of next month", "start of next month", "first of next month", "first of the month"].contains { lower.contains($0) }
        let hasActionIntent = hasReminderIntent || actionKeywords.contains { lower.contains($0) }

        if hasActionIntent && (hasRelativePhrase || hasEndPhrase), let relativeDate = detectRelativeDate(text: lower) {
            return (relativeDate, nil, 0.9, relativeDate, relativeDate)
        }
        
        // Bare-hyphen shorthand: "May 3-5", "June 14-16" — month shared, numeric end day
        let bareHyphenPattern = #"((?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+\d{1,2})-(\d{1,2})"#
        if let match = lower.range(of: bareHyphenPattern, options: [.regularExpression, .caseInsensitive]) {
            let matchStr = String(lower[match])
            // Split on the hyphen between the two day numbers
            if let hyphen = matchStr.range(of: #"(?<=\d)-(?=\d)"#, options: .regularExpression) {
                let startPart = String(matchStr[matchStr.startIndex..<hyphen.lowerBound])
                let endDay   = String(matchStr[hyphen.upperBound...])
                // Extract the month word to reconstruct the end part
                let monthPattern = #"^((?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?)"#
                if let monthMatch = startPart.range(of: monthPattern, options: [.regularExpression, .caseInsensitive]) {
                    let monthWord = String(startPart[monthMatch])
                    let endPart = "\(monthWord) \(endDay)"
                    let currentYear = Calendar.current.component(.year, from: Date())
                    let startFull = "\(startPart) \(currentYear)"
                    let endFull   = "\(endPart) \(currentYear)"
                    let r1 = NSRange(startFull.startIndex..<startFull.endIndex, in: startFull)
                    let r2 = NSRange(endFull.startIndex..<endFull.endIndex, in: endFull)
                    let d1 = detector?.matches(in: startFull, range: r1).compactMap { $0.date } ?? []
                    let d2 = detector?.matches(in: endFull,   range: r2).compactMap { $0.date } ?? []
                    if let s = d1.first, let e = d2.first {
                        return (s, e, 0.9, nil, nil)
                    }
                }
            }
        }

        let rangeKeywords = [" through ", " until ", " thru ", " to ", " - ", "–", "—"]
        for keyword in rangeKeywords {
            guard lower.contains(keyword) else { continue }

            var searchRange = lower.startIndex..<lower.endIndex
            var splitRanges: [Range<String.Index>] = []
            while let found = lower.range(of: keyword, range: searchRange) {
                splitRanges.append(found)
                searchRange = found.upperBound..<lower.endIndex
            }

            for splitRange in splitRanges {
                var firstHalf = String(text[text.startIndex..<splitRange.lowerBound])
                var secondHalf = String(text[splitRange.upperBound...])

                if firstHalf.lowercased().hasPrefix("from ") {
                    firstHalf = String(firstHalf.dropFirst(5))
                }
                if let fromRange = firstHalf.range(of: " from ", options: .caseInsensitive) {
                    firstHalf = String(firstHalf[fromRange.upperBound...])
                }

                let currentYear = Calendar.current.component(.year, from: Date())
                let yearString = " \(currentYear)"
                let hasYear1 = firstHalf.contains("202") || firstHalf.contains("203")
                let hasYear2 = secondHalf.contains("202") || secondHalf.contains("203")
                if !hasYear1 { firstHalf = firstHalf + yearString }
                if !hasYear2 { secondHalf = secondHalf + yearString }

                let range1 = NSRange(firstHalf.startIndex..<firstHalf.endIndex, in: firstHalf)
                let range2 = NSRange(secondHalf.startIndex..<secondHalf.endIndex, in: secondHalf)

                let dates1 = detector?.matches(in: firstHalf, range: range1).compactMap { $0.date } ?? []
                let dates2 = detector?.matches(in: secondHalf, range: range2).compactMap { $0.date } ?? []

                if var startDate = dates1.first, var endDate = dates2.first {
                    // Bug fix: if range spans year boundary (e.g. Dec 30 - Jan 2), bump endDate by 1 year
                    if endDate < startDate {
                        endDate = Calendar.current.date(byAdding: .year, value: 1, to: endDate) ?? endDate
                    }
                    return (startDate, endDate, 0.9, nil, nil)
                }
            }
        }
        
        // Guard: if text looks like a measurement/size context with no real date words, skip NSDataDetector
        // to prevent bare numbers like "11" in "shoe size 11" being parsed as times/dates.
        let measurementWords = ["size", " oz", " lb", " lbs", " kg", " cm", " mm", " ml", " mph", "serving", "qty", "count", "grade", "psig", "psi"]
        let hasMeasurementContext = measurementWords.contains { lower.contains($0) }
        let hasDateContext = lower.contains("today") || lower.contains("tomorrow") || lower.contains("tonight") ||
            lower.range(of: #"\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\w*"#, options: [.regularExpression, .caseInsensitive]) != nil ||
            lower.range(of: #"\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b"#, options: [.regularExpression, .caseInsensitive]) != nil ||
            lower.contains(" am") || lower.contains(" pm") || lower.contains("o'clock") ||
            lower.contains("morning") || lower.contains("afternoon") || lower.contains("evening") ||
            lower.contains("noon") || lower.contains("midnight") || lower.contains("next week") || lower.contains("this week") ||
            lower.contains("at ") || lower.contains("remind") || lower.contains("appointment")
        if hasMeasurementContext && !hasDateContext { return (nil, nil, nil, nil, nil) }

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
            ("(a|1|one|the)\\s+days?\\s+before", -86400),
            ("the\\s+day\\s+before", -86400),
            ("night\\s+before", -43200),
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
        
        let lower = text.lowercased()
        // Spoken time words from voice transcription (e.g. "at three pm", "three thirty", "three o'clock")
        let spokenTimeWords = ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"]
        let hasSpokenTime = spokenTimeWords.contains { lower.contains("at \($0)") || lower.contains("\($0) o'clock") || lower.contains("\($0) oclock") }
        let hasSpecificTime = text.range(of: #"\bat\s+\d"#, options: .regularExpression) != nil ||
        text.range(of: #"\d+\s*(am|pm)"#, options: .regularExpression) != nil ||
        lower.range(of: #"\b(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\s*(am|pm)\b"#, options: .regularExpression) != nil ||
        text.contains("noon") ||
        text.contains("midnight") ||
        text.contains("midday") ||
        hasSpokenTime
        
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

        // Require explicit date/time vocabulary — bare numbers (sizes, quantities, prices)
        // are parsed as dates by NSDataDetector but should never produce pings.
        let hasExplicitDateVocab =
            text.range(of: #"\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\w*"#, options: [.regularExpression, .caseInsensitive]) != nil ||
            text.range(of: #"\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\b"#, options: [.regularExpression, .caseInsensitive]) != nil ||
            text.contains("today") || text.contains("tomorrow") || text.contains("tonight") ||
            text.contains("next week") || text.contains("this week") || text.contains("next month") ||
            text.contains("morning") || text.contains("afternoon") || text.contains("evening") ||
            text.contains("noon") || text.contains("midnight") || text.contains("o'clock") ||
            text.contains(" am") || text.contains(" pm") ||
            text.contains("remind") || text.contains("appointment") || text.contains("deadline") ||
            text.range(of: #"\bat\s+\d"#, options: .regularExpression) != nil ||
            text.range(of: #"\d+\s*(am|pm)"#, options: [.regularExpression, .caseInsensitive]) != nil ||
            text.range(of: #"\d{1,2}/\d{1,2}"#, options: .regularExpression) != nil ||
            hasSpecificTime
        guard hasExplicitDateVocab else { return [] }

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

    static func detectStreamingService(from text: String) -> String? {
        let lower = text.lowercased()
        if lower.contains("hbo max") || lower.contains("hbomax") { return "HBO Max" }
        if lower.contains("apple tv+") || lower.contains("apple tv plus") || lower.contains("apple tv") { return "Apple TV+" }
        if lower.contains("disney+") || lower.contains("disney plus") { return "Disney+" }
        if lower.contains("prime video") || lower.contains("amazon prime") { return "Prime Video" }
        if lower.contains("paramount+") || lower.contains("paramount plus") { return "Paramount+" }
        if lower.contains("netflix") { return "Netflix" }
        if lower.contains("hulu") { return "Hulu" }
        if lower.contains("peacock") { return "Peacock" }
        if lower.contains("showtime") { return "Showtime" }
        if lower.contains("starz") { return "Starz" }
        if lower.contains("crunchyroll") { return "Crunchyroll" }
        if lower.contains("youtube") { return "YouTube" }
        if lower.contains("audible") { return "Audible" }
        if lower.contains("kindle") { return "Kindle" }
        if lower.contains("libby") || lower.contains("library") { return "Library" }
        if lower.contains("spotify") { return "Spotify" }
        return nil
    }

    static func learnKeywords(from text: String, echo: Echo) {
        let stopwords = Set([
            "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
            "of", "with", "by", "from", "up", "about", "into", "through", "during",
            "this", "that", "these", "those", "is", "are", "was", "were", "be",
            "been", "being", "have", "has", "had", "do", "does", "did", "will",
            "would", "could", "should", "may", "might", "shall", "can", "need",
            "today", "tonight", "tomorrow", "morning", "afternoon", "evening",
            "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
            "january", "february", "march", "april", "may", "june", "july",
            "august", "september", "october", "november", "december",
            "clean", "get", "got", "go", "going", "make", "take", "need", "want",
            "time", "day", "week", "month", "year", "night", "hour", "minute",
            "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
            "just", "also", "now", "then", "here", "there", "when", "where", "how", "what"
        ])
        
        let allGlobalKeywords = Set([
            "doctor", "recipe", "restaurant", "flight", "birthday", "game", "meeting",
            "workout", "gym", "movie", "book", "shirt", "bank", "concert", "buy",
            "clean", "laundry", "vacuum", "garage", "repair", "store", "price", "iron", "wash", "fold", "dust", "sweep", "mop", "scrub"
        ])
        
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = text
        var keywords: [String] = []
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word,
                             scheme: .nameType,
                             options: [.omitWhitespace, .omitPunctuation, .joinNames]) { tag, range in
            if tag != nil {
                let word = String(text[range]).lowercased()
                if word.count > 2 && !stopwords.contains(word) && !allGlobalKeywords.contains(word) {
                    keywords.append(word)
                }
            }
            return true
        }
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word,
                             scheme: .lexicalClass,
                             options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            if tag == .noun {
                let word = String(text[range]).lowercased()
                if word.count > 3 && !stopwords.contains(word) && !allGlobalKeywords.contains(word) {
                    keywords.append(word)
                }
            }
            return true
        }
        
        for keyword in keywords where !echo.learnedKeywords.contains(keyword) {
            echo.learnedKeywords.append(keyword)
        }
    }
}
