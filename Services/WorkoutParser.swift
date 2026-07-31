//
//  WorkoutParser.swift
//  Orca
//
//  Created by David Piliponskiy on 3/28/26.
//

import Foundation

// MARK: - Models

struct WorkoutSet {
    let setNumber: Int
    let weight: Double?
    let reps: Int?
    let unit: String
}

struct ParsedExercise {
    let name: String
    let muscleGroup: String
    let sets: [WorkoutSet]
    let isPR: Bool
    let totalVolume: Double?
    let isCardio: Bool
    let durationMinutes: Double?
    let distanceValue: Double?
    let distanceUnit: String?
    let pace: String?
    let calories: Int?
    let heartRate: Int?

    var setSummary: String {
        guard !sets.isEmpty else { return "" }
        let reps = sets.compactMap { $0.reps }
        guard !reps.isEmpty else { return "\(sets.count) sets" }
        let allSame = reps.allSatisfy { $0 == reps[0] }
        return allSame ? "\(sets.count)×\(reps[0])" : "\(sets.count) sets"
    }
}

struct WorkoutParseResult {
    let exercises: [ParsedExercise]
    let effortNote: String?
    let sessionType: String?
    let hasPR: Bool
    let totalVolume: Double
}

// MARK: - Parser

class WorkoutParser {
    static let shared = WorkoutParser()
    private init() {}

    private typealias ExerciseEntry = (aliases: [String], canonical: String, muscleGroup: String, isCardio: Bool)

    private let exerciseMap: [ExerciseEntry] = [
        // Chest — specific before generic
        (["bench press", "flat bench", "flat press", "chest press"], "Bench Press", "chest", false),
        (["incline bench", "incline press", "incline dumbbell", "incline"], "Incline Press", "chest", false),
        (["decline bench", "decline press"], "Decline Press", "chest", false),
        (["chest fly", "cable fly", "pec fly", "dumbbell fly", "pec deck"], "Chest Fly", "chest", false),
        (["push up", "pushup", "push-up"], "Push-Up", "chest", false),
        (["dip", "chest dip", "tricep dip"], "Dip", "chest", false),
        (["bench"], "Bench Press", "chest", false),

        // Back
        (["lat pulldown", "lat pull down"], "Lat Pulldown", "back", false),
        (["pull up", "pullup", "pull-up", "chin up", "chinup"], "Pull-Up", "back", false),
        (["bent over row", "barbell row", "dumbbell row", "seated row", "cable row",
           "t-bar row", "tbar row", "chest supported row", "pendlay row"], "Row", "back", false),
        (["romanian deadlift", "rdl", "stiff leg deadlift"], "Romanian Deadlift", "legs", false),
        (["sumo deadlift", "sumo", "trap bar deadlift", "hex bar deadlift",
           "trap bar", "hex bar"], "Deadlift", "back", false),
        (["deadlift", "deads", "dead lift"], "Deadlift", "back", false),
        (["good morning"], "Good Morning", "back", false),
        (["shrug", "farmer carry", "farmer walk", "trap raise"], "Shrug", "traps", false),

        // Legs
        (["leg press", "hack squat"], "Leg Press", "legs", false),
        (["bulgarian split squat", "split squat", "step up", "step ups"], "Split Squat", "legs", false),
        (["walking lunge", "lunge"], "Lunge", "legs", false),
        (["leg curl", "hamstring curl", "nordic curl", "glute ham raise", "ghr"], "Leg Curl", "legs", false),
        (["leg extension"], "Leg Extension", "legs", false),
        (["seated calf", "standing calf", "donkey calf", "calf raise"], "Calf Raise", "legs", false),
        (["hip thrust", "glute bridge", "banded hip thrust"], "Hip Thrust", "glutes", false),
        (["box jump", "jump squat", "broad jump"], "Box Jump", "legs", false),
        (["back squat", "front squat", "goblet squat", "box squat", "squat", "squats"], "Squat", "legs", false),

        // Shoulders
        (["overhead press", "ohp", "shoulder press", "military press",
           "arnold press", "push press", "dumbbell press", "db press"], "Overhead Press", "shoulders", false),
        (["lateral raise", "side raise", "side lateral", "laterals",
           "cable lateral", "db lateral"], "Lateral Raise", "shoulders", false),
        (["rear delt fly", "reverse fly", "rear delt", "rear fly"], "Rear Delt Fly", "shoulders", false),
        (["upright row"], "Upright Row", "shoulders", false),
        (["face pull"], "Face Pull", "shoulders", false),

        // Arms
        (["bicep curl", "barbell curl", "dumbbell curl", "hammer curl", "preacher curl",
           "cable curl", "incline curl", "concentration curl", "zottman",
           "arm curl", "bicep", "biceps", "curls", "curl"], "Bicep Curl", "biceps", false),
        (["tricep pushdown", "tricep extension", "skull crusher", "overhead tricep",
           "rope pushdown", "cable pushdown", "jm press", "tate press",
           "close grip bench", "tricep", "triceps"], "Tricep Extension", "triceps", false),

        // Core
        (["plank"], "Plank", "core", false),
        (["sit up", "situp", "ab crunch", "crunch", "crunches",
           "cable crunch", "ab wheel", "hanging leg raise", "leg raise"], "Core Work", "core", false),

        // Cardio — specific before generic
        (["incline treadmill", "incline walk", "treadmill run", "treadmill"], "Treadmill", "cardio", true),
        (["stairmaster", "stair climber", "stairs"], "Stairmaster", "cardio", true),
        (["jump rope", "skipping"], "Jump Rope", "cardio", true),
        (["spin class", "spinning", "peloton", "stationary bike"], "Cycling", "cardio", true),
        (["swim", "swam", "swimming", "swum", "laps"], "Swim", "cardio", true),
        (["rowing machine", "rower", "erg", "rowed", "rowing"], "Rowing", "cardio", true),
        (["elliptical"], "Elliptical", "cardio", true),
        (["crossfit", "wod"], "CrossFit", "cardio", true),
        (["hiit", "circuit training", "circuit"], "HIIT", "cardio", true),
        (["outdoor bike", "bike ride", "biked", "biking", "cycled", "cycling",
           "on my bike", "road bike", "mountain bike", "bike"], "Cycling", "cardio", true),
        (["hiked", "hiking", "hike", "trail run", "trail running"], "Hike", "cardio", true),
        (["5k", "10k", "half marathon", "marathon", "tempo run", "easy run", "long run",
           "running", "jog", "jogging", "run", "ran", "ran for", "went for a run"], "Run", "cardio", true),
        (["walk", "walking", "walked"], "Walk", "cardio", true),

        // Recovery & Wellness
        (["sauna", "steam room", "steam bath"], "Sauna", "recovery", false),
        (["cold plunge", "ice bath", "cold shower", "cold water immersion", "cold tub"], "Cold Plunge", "recovery", false),
        (["foam roll", "foam rolling", "stretching", "stretch", "mobility work", "mobility"], "Mobility", "recovery", false),
        (["meditation", "breathwork", "breathing exercise"], "Meditation", "recovery", false),
        (["massage", "sports massage", "deep tissue"], "Massage", "recovery", false),

        // Fitness Classes
        (["orangetheory", "orange theory", "otf"], "Orangetheory", "cardio", true),
        (["corepower", "core power"], "CorePower", "cardio", true),
        (["f45"], "F45", "cardio", true),
        (["solidcore", "solid core"], "Solidcore", "cardio", true),
        (["barry's bootcamp", "barrys bootcamp", "barrys"], "Barry's Bootcamp", "cardio", true),
        (["soulcycle", "soul cycle"], "SoulCycle", "cardio", true),
        (["barre", "pure barre"], "Barre", "cardio", true),
        (["pilates", "reformer pilates", "mat pilates"], "Pilates", "cardio", true),
        (["hot yoga", "bikram", "vinyasa", "power yoga", "yoga"], "Yoga", "cardio", true),
        (["boxing class", "kickboxing", "title boxing", "rumble boxing"], "Boxing", "cardio", true),
        (["bootcamp", "boot camp"], "Bootcamp", "cardio", true),
        (["zumba"], "Zumba", "cardio", true),
    ]

    private let prKeywords = [
        "new pr", "hit a pr", "pr today", "personal record", "personal best",
        "new best", "new pb", "hit pr", "pb today"
    ]

    private let effortKeywords = [
        "felt great", "felt good", "felt strong", "felt tough", "tough session",
        "great session", "solid session", "brutal session", "crushed it",
        "rough one", "off day", "great pump"
    ]

    private let sessionTypes: [(keywords: [String], name: String)] = [
        (["push day"], "Push day"),
        (["pull day"], "Pull day"),
        (["leg day", "legs day"], "Leg day"),
        (["chest day"], "Chest day"),
        (["back day"], "Back day"),
        (["arms day", "arm day"], "Arms day"),
        (["full body", "full-body"], "Full body"),
        (["upper body", "upper day"], "Upper body"),
        (["lower body", "lower day"], "Lower body"),
    ]

    private let cyclingKeywords = ["bike", "biked", "biking", "cycled", "cycling", "bicycle", "pedal"]
    private let hikingKeywords  = ["hike", "hiked", "hiking", "trail"]
    private let swimKeywords    = ["swim", "swam", "swimming", "swum", "laps", "pool"]
    private let rowKeywords     = ["row", "rowed", "rowing", "erg"]
    private let walkKeywords    = ["walk", "walked", "walking"]

    // MARK: - Spoken Number Normalization

    func normalizeSpokenNumbers(_ text: String) -> String {
        let wordMap: [(String, String)] = [
            ("twenty one", "21"), ("twenty two", "22"), ("twenty three", "23"),
            ("twenty four", "24"), ("twenty five", "25"), ("twenty six", "26"),
            ("twenty seven", "27"), ("twenty eight", "28"), ("twenty nine", "29"),
            ("one fifty", "150"), ("one hundred fifty", "150"),
            ("two fifty", "250"), ("two hundred fifty", "250"),
            ("three fifteen", "315"), ("three hundred fifteen", "315"),
            ("three fifty", "350"), ("three hundred fifty", "350"),
            ("four hundred", "400"), ("three hundred", "300"),
            ("two hundred", "200"), ("one hundred", "100"),
            ("zero", "0"), ("one", "1"), ("two", "2"), ("three", "3"),
            ("four", "4"), ("five", "5"), ("six", "6"), ("seven", "7"),
            ("eight", "8"), ("nine", "9"), ("ten", "10"), ("eleven", "11"),
            ("twelve", "12"), ("thirteen", "13"), ("fourteen", "14"),
            ("fifteen", "15"), ("sixteen", "16"), ("seventeen", "17"),
            ("eighteen", "18"), ("nineteen", "19"), ("twenty", "20"),
            ("thirty", "30"), ("forty", "40"), ("fifty", "50"),
            ("sixty", "60"), ("seventy", "70"), ("eighty", "80"),
            ("ninety", "90"), ("hundred", "100"),
        ]
        var result = text.lowercased()
        for (word, digit) in wordMap {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
            result = result.replacingOccurrences(of: pattern, with: digit, options: .regularExpression)
        }
        return result
    }

    // MARK: - Public API

    func detectWorkout(in text: String) -> WorkoutParseResult? {
        let result = parse(text: text)
        return result.exercises.isEmpty ? nil : result
    }

    func parse(text: String) -> WorkoutParseResult {
        let text = normalizeSpokenNumbers(text)
        let lower = text.lowercased()
        let hasPR = prKeywords.contains { lower.contains($0) }
        let effortNote = effortKeywords.first { lower.contains($0) }
        let sessionType = sessionTypes.first { $0.keywords.contains { lower.contains($0) } }?.name

        let segments = extractExerciseSegments(from: text)
        var exercises: [ParsedExercise] = segments.map { seg in
            let isPR = prKeywords.contains { seg.text.lowercased().contains($0) }
            return seg.entry.isCardio
                ? parseCardio(segment: seg.text, entry: seg.entry, isPR: isPR)
                : parseLifting(segment: seg.text, entry: seg.entry, isPR: isPR, canonicalName: seg.canonical)
        }

        if hasPR, !exercises.isEmpty, !exercises.contains(where: { $0.isPR }) {
            let e = exercises[0]
            exercises[0] = ParsedExercise(
                name: e.name, muscleGroup: e.muscleGroup, sets: e.sets,
                isPR: true, totalVolume: e.totalVolume, isCardio: e.isCardio,
                durationMinutes: e.durationMinutes, distanceValue: e.distanceValue,
                distanceUnit: e.distanceUnit, pace: e.pace, calories: e.calories,
                heartRate: e.heartRate
            )
        }

        let total = exercises.compactMap { $0.totalVolume }.reduce(0, +)
        return WorkoutParseResult(
            exercises: exercises,
            effortNote: effortNote,
            sessionType: sessionType,
            hasPR: exercises.contains { $0.isPR },
            totalVolume: total
        )
    }

    // MARK: - Segment Extraction

    private func extractExerciseSegments(from text: String) -> [(text: String, entry: ExerciseEntry, canonical: String)] {
        var normalized = text.components(separatedBy: "\n")
            .filter { !$0.hasPrefix("Workout ·") && !$0.hasPrefix("Workout·") }
            .joined(separator: "\n")

        // Split on sentence boundaries
        for sep in [". ", "! ", "; ", " — ", " – "] {
            normalized = normalized.replacingOccurrences(of: sep, with: "\n")
        }
        for sep in [" then ", " also did ", " also "] {
            normalized = normalized.replacingOccurrences(of: sep, with: "\n", options: .caseInsensitive)
        }

        // Build alias list once for both smart splits
        let allAliases = exerciseMap.flatMap { $0.aliases }

        // Smart comma split — only replace comma with newline if next chunk starts with a known exercise alias
        let commaChunks = normalized.components(separatedBy: ",")
        if commaChunks.count > 1 {
            var rebuilt = ""
            for (i, chunk) in commaChunks.enumerated() {
                let trimmed = chunk.trimmingCharacters(in: .whitespaces).lowercased()
                let startsWithExercise = allAliases.contains { trimmed.contains($0) }
                if i == 0 {
                    rebuilt += chunk
                } else if startsWithExercise {
                    rebuilt += "\n" + chunk
                } else {
                    rebuilt += "," + chunk
                }
            }
            normalized = rebuilt
        }

        // Smart "and" split — only replace " and " with newline if next chunk starts with a known exercise alias
        let andChunks = normalized.components(separatedBy: " and ")
        if andChunks.count > 1 {
            var rebuilt = ""
            for (i, chunk) in andChunks.enumerated() {
                let trimmed = chunk.trimmingCharacters(in: .whitespaces).lowercased()
                let startsWithExercise = allAliases.contains { trimmed.hasPrefix($0) }
                if i == 0 {
                    rebuilt += chunk
                } else if startsWithExercise {
                    rebuilt += "\n" + chunk
                } else {
                    rebuilt += " and " + chunk
                }
            }
            normalized = rebuilt
        }

        let chunks = normalized
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var groups: [(canonical: String, entry: ExerciseEntry, texts: [String])] = []

        for chunk in chunks {
            let lower = chunk.lowercased()
            // Equipment prefix appended to canonical so same exercise on different equipment stays separate
            let equipmentSuffix = lower.hasPrefix("[machine]") ? " (Machine)" : ""
            for entry in exerciseMap {
                if entry.aliases.contains(where: { lower.contains($0) }) {
                    let canonicalWithEquip = entry.canonical + equipmentSuffix
                    // Cardio exercises always get their own group — two runs are two separate sessions
                    // Lifting exercises merge into the same group — multiple sets of the same exercise
                    if !entry.isCardio, let idx = groups.firstIndex(where: { $0.canonical == canonicalWithEquip }) {
                        groups[idx].texts.append(chunk)
                    } else {
                        groups.append((canonicalWithEquip, entry, [chunk]))
                    }
                    break
                }
            }
        }

        // Fallback: distance + time with no explicit exercise match
        let hasDistanceTime =
            text.range(of: #"\d+(?:\.\d+)?\s*(?:miles?|km|meters?)\b"#, options: .regularExpression) != nil &&
            text.range(of: #"\d+\s*(?:minutes?|mins?|hours?|hr)\b"#, options: .regularExpression) != nil

        if hasDistanceTime && !groups.contains(where: { $0.entry.isCardio }) {
            let lower = text.lowercased()
            let fallbackCanonical: String
            if cyclingKeywords.contains(where: { lower.contains($0) }) {
                fallbackCanonical = "Cycling"
            } else if hikingKeywords.contains(where: { lower.contains($0) }) {
                fallbackCanonical = "Hike"
            } else if swimKeywords.contains(where: { lower.contains($0) }) {
                fallbackCanonical = "Swim"
            } else if rowKeywords.contains(where: { lower.contains($0) }) {
                fallbackCanonical = "Rowing"
            } else if walkKeywords.contains(where: { lower.contains($0) }) {
                fallbackCanonical = "Walk"
            } else {
                fallbackCanonical = "Run"
            }
            if let entry = exerciseMap.first(where: { $0.canonical == fallbackCanonical }) {
                groups.append((fallbackCanonical, entry, [text]))
            }
        }

        return groups.map { ($0.texts.joined(separator: "\n"), $0.entry, $0.canonical) }
    }

    // MARK: - Lifting Parser

    private func parseLifting(segment: String, entry: ExerciseEntry, isPR: Bool, canonicalName: String = "") -> ParsedExercise {
        let lines = segment.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var allSets: [WorkoutSet] = []

        if lines.count > 1 {
            for line in lines {
                let lineSets = extractSets(from: line, exerciseName: entry.canonical)
                for s in lineSets {
                    allSets.append(WorkoutSet(
                        setNumber: allSets.count + 1,
                        weight: s.weight,
                        reps: s.reps,
                        unit: s.unit
                    ))
                }
            }
        }

        if allSets.isEmpty {
            allSets = extractSets(from: segment, exerciseName: entry.canonical)
        }

        let volume: Double? = {
            guard !allSets.isEmpty else { return nil }
            let total = allSets.reduce(0.0) { $0 + ($1.weight ?? 0) * Double($1.reps ?? 1) }
            return total > 0 ? total : nil
        }()

        return ParsedExercise(
            name: canonicalName.isEmpty ? entry.canonical : canonicalName, muscleGroup: entry.muscleGroup, sets: allSets,
            isPR: isPR, totalVolume: volume, isCardio: false,
            durationMinutes: nil, distanceValue: nil, distanceUnit: nil,
            pace: nil, calories: nil, heartRate: nil
        )
    }

    // MARK: - Cardio Parser

    private func parseCardio(segment: String, entry: ExerciseEntry, isPR: Bool) -> ParsedExercise {
        let lower = segment.lowercased()
        let duration = extractDuration(from: lower)
        let (distVal, distUnit) = extractDistance(from: lower)
        let pace = calculateMetric(canonical: entry.canonical, dist: distVal, unit: distUnit, minutes: duration)
        let calories = extractInt(pattern: #"(\d+)\s*(?:cal(?:ories?)?|cals?)\b"#, from: lower)
        let hr = extractInt(pattern: #"(\d+)\s*(?:bpm|heart\s*rate)\b"#, from: lower)
        return ParsedExercise(
            name: entry.canonical, muscleGroup: entry.muscleGroup, sets: [],
            isPR: isPR, totalVolume: nil, isCardio: true,
            durationMinutes: duration, distanceValue: distVal, distanceUnit: distUnit,
            pace: pace, calories: calories, heartRate: hr
        )
    }

    // MARK: - Set Extraction

    private let bodyweightExercises: Set<String> = [
        "Push-Up", "Pull-Up", "Core Work", "Plank", "Lunge", "Split Squat",
        "Dip", "Box Jump", "Jump Rope", "Hip Thrust", "Good Morning",
        "Rear Delt Fly", "Upright Row"
    ]

    private func extractSets(from text: String, exerciseName: String = "") -> [WorkoutSet] {
        let text = normalizeSpokenNumbers(text)
        let lower = text.lowercased()
        let unit = lower.contains("kg") || lower.contains("kilo") ? "kg" : "lb"
        let isBodyweight = bodyweightExercises.contains(exerciseName)

        if isBodyweight {
            let reps = extractInt(pattern: #"(\d+)\s*(?:reps?|times?|push[\s\-]?ups?|pull[\s\-]?ups?|crunches?|lunges?|dips?)\b"#, from: lower)
                ?? extractInt(pattern: #"did\s+(\d+)"#, from: lower)
                ?? extractInt(pattern: #"\b(\d+)\s*(?:push[\s\-]?ups?|pull[\s\-]?ups?|sit[\s\-]?ups?|crunches?|dips?|lunges?)"#, from: lower)
                ?? extractInt(pattern: #"\b([1-9]\d+)\b"#, from: lower)
            guard let r = reps else { return [] }
            let setCount = extractSetCountFromText(lower) ?? 1
            return (0..<setCount).map { WorkoutSet(setNumber: $0+1, weight: nil, reps: r, unit: "") }
        }

        let pairs = findAll(pattern: #"(\d+(?:\.\d+)?)\s*[xX×]\s*(\d+)"#, in: text)
        if !pairs.isEmpty {
            var sets: [WorkoutSet] = []
            for (i, pair) in pairs.enumerated() where pair.count >= 2 {
                let a = pair[0], b = pair[1]
                if a >= 5 && b < 100 && a > b {
                    sets.append(WorkoutSet(setNumber: i+1, weight: a, reps: Int(b), unit: unit))
                } else if b >= 5 && a < 100 && b > a {
                    sets.append(WorkoutSet(setNumber: i+1, weight: b, reps: Int(a), unit: unit))
                } else if a < 20 && b < 20 {
                    let setCount = Int(a); let reps = Int(b)
                    let w = findAllSingle(pattern: #"\b(\d{2,3})\b"#, in: text)
                        .filter { $0 >= 5 && $0 < 1500 }.first
                    for j in 0..<setCount {
                        sets.append(WorkoutSet(setNumber: j+1, weight: w, reps: reps, unit: unit))
                    }
                    return sets
                }
            }
            if !sets.isEmpty { return sets }
        }

        if let nums = matchFirst(
            pattern: #"(\d+)\s*sets?\s*of\s*(\d+)(?:\s*reps?)?\s*(?:at|@|with)?\s*(\d+)"#,
            in: text), nums.count >= 3 {
            let n = Int(nums[0]), r = Int(nums[1]), w = nums[2]
            return (0..<n).map { WorkoutSet(setNumber: $0+1, weight: w, reps: r, unit: unit) }
        }

        if let nums = matchFirst(
            pattern: #"(\d+(?:\.\d+)?)\s*(?:lbs?|kg)?\s*for\s*(\d+)\s*sets?\s*of\s*(\d+)"#,
            in: text), nums.count >= 3 {
            let w = nums[0], n = Int(nums[1]), r = Int(nums[2])
            return (0..<n).map { WorkoutSet(setNumber: $0+1, weight: w, reps: r, unit: unit) }
        }

        if let nums = matchFirst(
            pattern: #"(\d+(?:\.\d+)?)\s*(?:lbs?|kg)?\s*for\s*(\d+)\s*(?:reps?)?"#,
            in: text), nums.count >= 2 {
            let n = extractSetCountFromText(lower) ?? 1
            return (0..<n).map { WorkoutSet(setNumber: $0+1, weight: nums[0], reps: Int(nums[1]), unit: unit) }
        }

        if let nums = matchFirst(
            pattern: #"(\d+)\s*(?:reps?|times?|curls?|pushups?|pullups?|squats?|crunches?|lunges?|dips?)\s+(\d+(?:\.\d+)?)\s*(?:lbs?|pounds?|kgs?|kilos?)"#,
            in: text), nums.count >= 2 {
            let reps = Int(nums[0]), w = nums[1]
            let n = extractSetCountFromText(lower) ?? 1
            return (0..<n).map { WorkoutSet(setNumber: $0+1, weight: w, reps: reps, unit: unit) }
        }

        if let nums = matchFirst(
            pattern: #"(\d+(?:\.\d+)?)\s*(?:lbs?|pounds?|kgs?|kilos?)\s+(?:for\s+)?(\d+)\s*(?:times?|reps?)"#,
            in: text), nums.count >= 2 {
            let n = extractSetCountFromText(lower) ?? 1
            return (0..<n).map { WorkoutSet(setNumber: $0+1, weight: nums[0], reps: Int(nums[1]), unit: unit) }
        }

        if let nums = matchFirst(
            pattern: #"(\d+)\s*(?:times?|reps?)\s*(?:at|@|with|of)?\s*(\d+(?:\.\d+)?)\s*(?:lbs?|pounds?|kgs?|kilos?)?"#,
            in: text), nums.count >= 2 {
            let reps = Int(nums[0]), w = nums[1]
            let n = extractSetCountFromText(lower) ?? 1
            return (0..<n).map { WorkoutSet(setNumber: $0+1, weight: w, reps: reps, unit: unit) }
        }

        if let nums = matchFirst(
            pattern: #"(\d{2,3})\s+(\d{1,2})\s*(?:times?|reps?)"#,
            in: text), nums.count >= 2 {
            let w = nums[0], reps = Int(nums[1])
            guard w >= 5 && w < 1500 && reps > 0 && reps < 100 else { return [] }
            let n = extractSetCountFromText(lower) ?? 1
            return (0..<n).map { WorkoutSet(setNumber: $0+1, weight: w, reps: reps, unit: unit) }
        }

        if let nums = matchFirst(
            pattern: #"(\d{1,2})\s*(?:times?|reps?)\s+(\d{2,3})"#,
            in: text), nums.count >= 2 {
            let reps = Int(nums[0]), w = nums[1]
            guard w >= 5 && w < 1500 && reps > 0 && reps < 100 else { return [] }
            let n = extractSetCountFromText(lower) ?? 1
            return (0..<n).map { WorkoutSet(setNumber: $0+1, weight: w, reps: reps, unit: unit) }
        }

        if let repsNums = matchFirst(pattern: #"for\s*(\d+)\s*(?:reps?\s*each|reps?)"#, in: text),
           let reps = repsNums.first {
            let weights = findAllSingle(pattern: #"(\d{2,3})\b"#, in: text)
                .filter { $0 >= 5 && $0 < 1500 }
            if !weights.isEmpty {
                return weights.enumerated().map {
                    WorkoutSet(setNumber: $0.offset+1, weight: $0.element, reps: Int(reps), unit: unit)
                }
            }
        }

        if let nums = matchFirst(
            pattern: #"(\d+(?:\.\d+)?)\s*(?:lbs?|pounds?|kgs?|kilos?)"#,
            in: text) {
            let w = nums[0]
            let reps = extractInt(pattern: #"(\d+)\s*(?:reps?|times?)"#, from: lower)
            return [WorkoutSet(setNumber: 1, weight: w, reps: reps, unit: unit)]
        }

        let heavy = findAllSingle(pattern: #"\b(\d{2,3}(?:\.\d+)?)\b"#, in: text)
            .filter { $0 >= 5 && $0 < 1500 }
        if let w = heavy.first {
            let reps = extractInt(pattern: #"(\d+)\s*(?:reps?|times?)"#, from: lower)
            return [WorkoutSet(setNumber: 1, weight: w, reps: reps, unit: unit)]
        }

        return []
    }

    private func extractSetCountFromText(_ text: String) -> Int? {
        matchFirst(pattern: #"(\d+)\s*sets?"#, in: text).flatMap { Int($0.first ?? 0) }
    }

    // MARK: - Cardio Helpers

    private func extractDuration(from text: String) -> Double? {
        if let n = extractDouble(pattern: #"(\d+(?:\.\d+)?)\s*-?\s*(?:minutes?|mins?)\b"#, from: text) { return n }
        if let nums = matchFirst(
            pattern: #"(\d+)\s*(?:hours?|hr)s?\s*(?:and\s*)?(\d+)\s*(?:minutes?|mins?)"#,
            in: text), nums.count >= 2 { return nums[0] * 60 + nums[1] }
        if let hr = extractDouble(pattern: #"(\d+(?:\.\d+)?)\s*(?:hours?|hr)\b"#, from: text) { return hr * 60 }
        return nil
    }

    private func extractDistance(from text: String) -> (Double?, String?) {
        if let n = extractDouble(pattern: #"(\d+(?:\.\d+)?)\s*(?:miles?|mi)\b"#, from: text) { return (n, "mi") }
        if let n = extractDouble(pattern: #"(\d+(?:\.\d+)?)\s*(?:km|kilometers?)\b"#, from: text) { return (n, "km") }
        if let n = extractDouble(pattern: #"(\d+(?:\.\d+)?)\s*k\b"#, from: text) { return (n, "km") }
        if let n = extractDouble(pattern: #"(\d+(?:\.\d+)?)\s*(?:meters?|m)\b"#, from: text) { return (n, "m") }
        if let n = extractDouble(pattern: #"(\d+(?:\.\d+)?)\s*(?:yards?|yds?)\b"#, from: text) { return (n, "yd") }
        if let n = extractDouble(pattern: #"(\d+)\s*laps?\b"#, from: text) { return (n, "laps") }
        return (nil, nil)
    }

    private func calculateMetric(canonical: String, dist: Double?, unit: String?, minutes: Double?) -> String? {
        guard let d = dist, let m = minutes, d > 0, m > 0 else { return nil }

        switch canonical {
        case "Cycling", "Rowing", "Elliptical":
            var miles = d
            if unit == "km" { miles = d / 1.60934 }
            else if unit == "m" { miles = d / 1609.34 }
            let mph = miles / (m / 60)
            return String(format: "%.1f mph", mph)

        case "Swim":
            if unit == "laps" {
                let pacePerLap = m / d
                let mins = Int(pacePerLap)
                let secs = Int((pacePerLap - Double(mins)) * 60)
                return "\(mins):\(String(format: "%02d", secs))/lap"
            }
            var meters = d
            if unit == "mi" { meters = d * 1609.34 }
            else if unit == "km" { meters = d * 1000 }
            else if unit == "yd" { meters = d * 0.9144 }
            let pacePer100 = (m / meters) * 100
            let mins = Int(pacePer100)
            let secs = Int((pacePer100 - Double(mins)) * 60)
            return "\(mins):\(String(format: "%02d", secs))/100m"

        default:
            var miles = d
            if unit == "km" { miles = d / 1.60934 }
            else if unit == "m" { miles = d / 1609.34 }
            let pace = m / miles
            let mins = Int(pace)
            let secs = Int((pace - Double(mins)) * 60)
            return "\(mins):\(String(format: "%02d", secs))/mi"
        }
    }

    // MARK: - Regex Helpers

    private func findAll(pattern: String, in text: String) -> [[Double]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).map { match in
            (1..<match.numberOfRanges).compactMap { i -> Double? in
                guard let r = Range(match.range(at: i), in: text) else { return nil }
                return Double(String(text[r]))
            }
        }
    }

    private func findAllSingle(pattern: String, in text: String) -> [Double] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match -> Double? in
            guard let r = Range(match.range(at: 1), in: text) else { return nil }
            return Double(String(text[r]))
        }
    }

    private func matchFirst(pattern: String, in text: String) -> [Double]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        let nums = (1..<match.numberOfRanges).compactMap { i -> Double? in
            guard let r = Range(match.range(at: i), in: text) else { return nil }
            return Double(String(text[r]))
        }
        return nums.isEmpty ? nil : nums
    }

    private func extractDouble(pattern: String, from text: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(
                in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return Double(String(text[r]))
    }

    private func extractInt(pattern: String, from text: String) -> Int? {
        extractDouble(pattern: pattern, from: text).map { Int($0) }
    }
}
