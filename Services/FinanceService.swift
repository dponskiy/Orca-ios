//
//  FinanceService.swift
//  Orca
//
//  Created by David Piliponskiy on 3/27/26.
//

import Foundation
import SwiftUI
import UserNotifications

// MARK: - Models

struct FinanceQuote {
    let symbol: String
    let companyName: String
    let price: Double
    let previousClose: Double
    let high52w: Double?
    let low52w: Double?
    let dayHigh: Double?
    let dayLow: Double?
    let exchange: String
    let sparklinePoints: [Double]
    let fetchedAt: Date

    var change: Double { price - previousClose }
    var changePercent: Double {
        guard previousClose > 0 else { return 0 }
        return (change / previousClose) * 100
    }
    var isPositive: Bool { change >= 0 }

    var formattedPrice: String { String(format: "$%.2f", price) }
    var formattedChange: String {
        let sign = change >= 0 ? "+" : ""
        return String(format: "\(sign)$%.2f", change)
    }
    var formattedChangePercent: String {
        let sign = changePercent >= 0 ? "+" : ""
        return String(format: "\(sign)%.2f%%", changePercent)
    }
}

struct FinanceTicker {
    let symbol: String
    let companyName: String
}

enum AlertDirection: String {
    case above, below
}

struct FinanceAlert {
    let ticker: String
    let threshold: Double
    let direction: AlertDirection

    var formattedThreshold: String { String(format: "$%.2f", threshold) }
}

// MARK: - Chart Range

enum FinanceRange: String, CaseIterable {
    case oneWeek    = "1W"
    case oneMonth   = "1M"
    case threeMonth = "3M"
    case sixMonth   = "6M"
    case oneYear    = "1Y"

    var yahooRange: String {
        switch self {
        case .oneWeek:    return "5d"
        case .oneMonth:   return "1mo"
        case .threeMonth: return "3mo"
        case .sixMonth:   return "6mo"
        case .oneYear:    return "1y"
        }
    }

    var yahooInterval: String {
        switch self {
        case .oneWeek, .oneMonth, .threeMonth: return "1d"
        case .sixMonth, .oneYear:              return "1wk"
        }
    }
}

// MARK: - Service

class FinanceService {
    static let shared = FinanceService()
    private init() {}

    private var cache: [String: FinanceQuote] = [:]
    private let cacheDuration: TimeInterval = 300

    // MARK: - Ticker Dictionary

    let knownTickers: [String: String] = [
        // Big Tech
        "AAPL": "Apple Inc.", "MSFT": "Microsoft Corp.", "GOOGL": "Alphabet Inc.",
        "GOOG": "Alphabet Inc.", "META": "Meta Platforms", "AMZN": "Amazon.com Inc.",
        "NVDA": "Nvidia Corp.", "TSLA": "Tesla Inc.", "NFLX": "Netflix Inc.",
        "AMD": "AMD Inc.", "INTC": "Intel Corp.", "CRM": "Salesforce Inc.",
        "ORCL": "Oracle Corp.", "ADBE": "Adobe Inc.", "QCOM": "Qualcomm Inc.",
        "AVGO": "Broadcom Inc.", "IBM": "IBM Corp.", "TXN": "Texas Instruments",
        "CSCO": "Cisco Systems", "AMAT": "Applied Materials", "MU": "Micron Technology",
        "NOW": "ServiceNow Inc.", "INTU": "Intuit Inc.", "PANW": "Palo Alto Networks",
        "CRWD": "CrowdStrike Holdings", "DDOG": "Datadog Inc.", "ZS": "Zscaler Inc.",
        "OKTA": "Okta Inc.", "TWLO": "Twilio Inc.", "DOCN": "DigitalOcean",
        "HPQ": "HP Inc.", "HPE": "Hewlett Packard Enterprise", "DELL": "Dell Technologies",
        "ANET": "Arista Networks", "FTNT": "Fortinet Inc.", "ZBRA": "Zebra Technologies",
        "ACN": "Accenture PLC", "SAP": "SAP SE", "TEAM": "Atlassian Corp.",

        // Finance & Banking
        "JPM": "JPMorgan Chase", "BAC": "Bank of America", "GS": "Goldman Sachs",
        "MS": "Morgan Stanley", "WFC": "Wells Fargo", "BLK": "BlackRock Inc.",
        "V": "Visa Inc.", "MA": "Mastercard Inc.", "AXP": "American Express",
        "PYPL": "PayPal Holdings", "SQ": "Block Inc.", "COIN": "Coinbase Global",
        "C": "Citigroup Inc.", "USB": "U.S. Bancorp", "PNC": "PNC Financial",
        "TFC": "Truist Financial", "SCHW": "Charles Schwab",
        "BX": "Blackstone Inc.", "KKR": "KKR & Co.", "APO": "Apollo Global",
        "ICE": "Intercontinental Exchange", "CME": "CME Group", "NDAQ": "Nasdaq Inc.",
        "HOOD": "Robinhood Markets", "SOFI": "SoFi Technologies", "AFRM": "Affirm Holdings",
        "UPST": "Upstart Holdings", "LC": "LendingClub Corp.",
        "AIG": "American International Group", "MET": "MetLife Inc.", "PRU": "Prudential Financial",
        "AFL": "Aflac Inc.", "ALL": "Allstate Corp.", "TRV": "Travelers Companies",

        // Consumer & Retail
        "WMT": "Walmart Inc.", "TGT": "Target Corp.", "COST": "Costco Wholesale",
        "HD": "Home Depot", "LOW": "Lowe's Cos.", "NKE": "Nike Inc.",
        "MCD": "McDonald's Corp.", "SBUX": "Starbucks Corp.", "KO": "Coca-Cola Co.",
        "PEP": "PepsiCo Inc.", "PG": "Procter & Gamble", "DIS": "Walt Disney Co.",
        "ETSY": "Etsy Inc.", "EBAY": "eBay Inc.", "BBY": "Best Buy Co.",
        "KR": "Kroger Co.", "WBA": "Walgreens Boots Alliance",
        "CVS": "CVS Health Corp.", "DLTR": "Dollar Tree Inc.", "DG": "Dollar General",
        "TJX": "TJX Companies", "ROST": "Ross Stores", "GPS": "Gap Inc.",
        "ANF": "Abercrombie & Fitch", "AEO": "American Eagle Outfitters",
        "LULU": "Lululemon Athletica", "UAA": "Under Armour", "VFC": "VF Corp.",
        "RL": "Ralph Lauren Corp.", "PVH": "PVH Corp.", "HBI": "Hanesbrands Inc.",
        "YUM": "Yum! Brands", "QSR": "Restaurant Brands", "CMG": "Chipotle Mexican Grill",
        "DPZ": "Domino's Pizza", "PZZA": "Papa John's", "WING": "Wingstop Inc.",
        "DASH": "DoorDash Inc.", "UBER": "Uber Technologies", "LYFT": "Lyft Inc.",
        "ABNB": "Airbnb Inc.", "BKNG": "Booking Holdings", "EXPE": "Expedia Group",
        "MAR": "Marriott International", "HLT": "Hilton Worldwide", "H": "Hyatt Hotels",
        "CCL": "Carnival Corp.", "RCL": "Royal Caribbean", "NCLH": "Norwegian Cruise Line",
        "LVS": "Las Vegas Sands", "MGM": "MGM Resorts", "WYNN": "Wynn Resorts",
        "PENN": "PENN Entertainment", "DKNG": "DraftKings Inc.",

        // Healthcare & Pharma
        "JNJ": "Johnson & Johnson", "PFE": "Pfizer Inc.", "MRNA": "Moderna Inc.",
        "ABBV": "AbbVie Inc.", "MRK": "Merck & Co.", "UNH": "UnitedHealth Group",
        "LLY": "Eli Lilly Co.", "AMGN": "Amgen Inc.", "BMY": "Bristol-Myers Squibb",
        "GILD": "Gilead Sciences", "REGN": "Regeneron Pharmaceuticals",
        "BIIB": "Biogen Inc.", "VRTX": "Vertex Pharmaceuticals", "ISRG": "Intuitive Surgical",
        "BSX": "Boston Scientific", "MDT": "Medtronic PLC", "SYK": "Stryker Corp.",
        "ZBH": "Zimmer Biomet", "EW": "Edwards Lifesciences", "BAX": "Baxter International",
        "HCA": "HCA Healthcare", "THC": "Tenet Healthcare", "CNC": "Centene Corp.",
        "MOH": "Molina Healthcare", "HUM": "Humana Inc.", "CI": "Cigna Group",
        "RAD": "Rite Aid Corp.", "DXCM": "Dexcom Inc.", "PODD": "Insulet Corp.",
        "TDOC": "Teladoc Health", "HIMS": "Hims & Hers Health", "DOCS": "Doximity Inc.",

        // Energy & Utilities
        "XOM": "ExxonMobil Corp.", "CVX": "Chevron Corp.", "COP": "ConocoPhillips",
        "SLB": "SLB (Schlumberger)", "HAL": "Halliburton Co.", "BKR": "Baker Hughes",
        "OXY": "Occidental Petroleum", "MPC": "Marathon Petroleum", "PSX": "Phillips 66",
        "VLO": "Valero Energy", "PXD": "Pioneer Natural Resources", "EOG": "EOG Resources",
        "DVN": "Devon Energy", "FANG": "Diamondback Energy", "APA": "APA Corp.",
        "NEE": "NextEra Energy", "DUK": "Duke Energy", "SO": "Southern Co.",
        "D": "Dominion Energy", "EXC": "Exelon Corp.", "PCG": "PG&E Corp.",
        "SRE": "Sempra Energy", "AEP": "American Electric Power", "ED": "Consolidated Edison",
        "ENPH": "Enphase Energy", "SEDG": "SolarEdge Technologies", "FSLR": "First Solar",
        "RUN": "Sunrun Inc.", "BE": "Bloom Energy",

        // Automotive
        "F": "Ford Motor Co.", "GM": "General Motors", "STLA": "Stellantis NV",
        "TM": "Toyota Motor Corp.", "HMC": "Honda Motor Co.", "NSANY": "Nissan Motor",
        "RIVN": "Rivian Automotive", "LCID": "Lucid Group", "NIO": "NIO Inc.",
        "XPEV": "XPeng Inc.", "LI": "Li Auto Inc.", "RACE": "Ferrari NV",
        "PAG": "Penske Automotive", "AN": "AutoNation",

        // Media & Entertainment
        "SNAP": "Snap Inc.", "SPOT": "Spotify Technology", "PINS": "Pinterest Inc.",
        "RDDT": "Reddit Inc.", "MTCH": "Match Group", "BMBL": "Bumble Inc.",
        "TTWO": "Take-Two Interactive", "EA": "Electronic Arts", "ATVI": "Activision Blizzard",
        "RBLX": "Roblox Corp.", "U": "Unity Software",
        "LYV": "Live Nation Entertainment", "WBD": "Warner Bros. Discovery",
        "PARA": "Paramount Global", "FOX": "Fox Corp.", "NYT": "New York Times",
        "IAC": "IAC Inc.", "YELP": "Yelp Inc.",

        // Industrial & Defense
        "BA": "Boeing Co.", "GE": "GE Aerospace", "CAT": "Caterpillar Inc.",
        "DE": "Deere & Co.", "MMM": "3M Co.", "HON": "Honeywell International",
        "RTX": "RTX Corp.", "LMT": "Lockheed Martin", "NOC": "Northrop Grumman",
        "GD": "General Dynamics", "UPS": "United Parcel Service", "FDX": "FedEx Corp.",
        "CHRW": "C.H. Robinson", "XPO": "XPO Inc.", "JBHT": "J.B. Hunt Transport",
        "ODFL": "Old Dominion Freight", "DAL": "Delta Air Lines", "UAL": "United Airlines",
        "AAL": "American Airlines", "LUV": "Southwest Airlines", "ALK": "Alaska Air Group",

        // Real Estate
        "AMT": "American Tower Corp.", "PLD": "Prologis Inc.", "CCI": "Crown Castle Inc.",
        "EQIX": "Equinix Inc.", "O": "Realty Income Corp.", "SPG": "Simon Property Group",
        "VICI": "VICI Properties", "WELL": "Welltower Inc.", "AVB": "AvalonBay Communities",
        "EQR": "Equity Residential", "MAA": "Mid-America Apartment",
        "Z": "Zillow Group", "RDFN": "Redfin Corp.",

        // ETFs & Indices
        "SPY": "SPDR S&P 500 ETF", "QQQ": "Invesco QQQ ETF", "DIA": "SPDR Dow Jones ETF",
        "IWM": "iShares Russell 2000", "VTI": "Vanguard Total Market", "VOO": "Vanguard S&P 500",
        "GLD": "SPDR Gold ETF", "SLV": "iShares Silver ETF", "TLT": "iShares 20Y Treasury ETF",
        "ARKK": "ARK Innovation ETF", "ARKG": "ARK Genomic Revolution ETF",
        "XLF": "Financial Select Sector SPDR", "XLE": "Energy Select Sector SPDR",
        "XLK": "Technology Select Sector SPDR", "XLV": "Health Care Select Sector SPDR",
        "SQQQ": "ProShares UltraPro Short QQQ", "TQQQ": "ProShares UltraPro QQQ",
        "VNQ": "Vanguard Real Estate ETF", "SCHD": "Schwab US Dividend Equity ETF",

        // Crypto
        "BTC-USD": "Bitcoin", "ETH-USD": "Ethereum", "BNB-USD": "BNB",
        "SOL-USD": "Solana", "XRP-USD": "XRP", "ADA-USD": "Cardano",
        "DOGE-USD": "Dogecoin", "SHIB-USD": "Shiba Inu", "AVAX-USD": "Avalanche",
        "MATIC-USD": "Polygon", "DOT-USD": "Polkadot", "LTC-USD": "Litecoin",

        // Other Popular
        "PLTR": "Palantir Technologies", "SNOW": "Snowflake Inc.", "NET": "Cloudflare Inc.",
        "SHOP": "Shopify Inc.", "ROKU": "Roku Inc.", "GME": "GameStop Corp.",
        "AMC": "AMC Entertainment", "BB": "BlackBerry Ltd.", "NOK": "Nokia Corp.",
        "SPCE": "Virgin Galactic", "RKT": "Rocket Companies", "CLOV": "Clover Health",
        "CPNG": "Coupang Inc.", "SE": "Sea Ltd.", "GRAB": "Grab Holdings",
        "MELI": "MercadoLibre Inc.", "NU": "Nu Holdings", "STNE": "StoneCo Ltd.",
        "BABA": "Alibaba Group", "JD": "JD.com Inc.", "PDD": "PDD Holdings",
        "BIDU": "Baidu Inc.", "TCEHY": "Tencent Holdings", "TME": "Tencent Music",
        "TSM": "Taiwan Semiconductor", "ASML": "ASML Holding", "ARM": "Arm Holdings",
    ]

    // MARK: - Company Name Map

    private let companyNameMap: [(names: [String], symbol: String)] = [
        (["apple"], "AAPL"),
        (["microsoft"], "MSFT"),
        (["google", "alphabet"], "GOOGL"),
        (["meta", "facebook"], "META"),
        (["amazon"], "AMZN"),
        (["nvidia"], "NVDA"),
        (["tesla"], "TSLA"),
        (["netflix"], "NFLX"),
        (["amd", "advanced micro devices"], "AMD"),
        (["intel"], "INTC"),
        (["salesforce"], "CRM"),
        (["oracle"], "ORCL"),
        (["adobe"], "ADBE"),
        (["qualcomm"], "QCOM"),
        (["broadcom"], "AVGO"),
        (["ibm"], "IBM"),
        (["cisco"], "CSCO"),
        (["servicenow"], "NOW"),
        (["intuit", "turbotax", "quickbooks"], "INTU"),
        (["palo alto", "palo alto networks"], "PANW"),
        (["crowdstrike"], "CRWD"),
        (["datadog"], "DDOG"),
        (["okta"], "OKTA"),
        (["twilio"], "TWLO"),
        (["hp", "hewlett packard"], "HPQ"),
        (["dell"], "DELL"),
        (["accenture"], "ACN"),
        (["atlassian", "jira", "confluence"], "TEAM"),
        (["jpmorgan", "jp morgan", "chase", "chase bank"], "JPM"),
        (["bank of america", "bofa", "boa"], "BAC"),
        (["goldman sachs", "goldman"], "GS"),
        (["morgan stanley"], "MS"),
        (["wells fargo"], "WFC"),
        (["blackrock"], "BLK"),
        (["visa"], "V"),
        (["mastercard"], "MA"),
        (["american express", "amex"], "AXP"),
        (["paypal"], "PYPL"),
        (["block", "square", "cash app"], "SQ"),
        (["coinbase"], "COIN"),
        (["citigroup", "citi", "citibank"], "C"),
        (["charles schwab", "schwab"], "SCHW"),
        (["blackstone"], "BX"),
        (["robinhood"], "HOOD"),
        (["sofi"], "SOFI"),
        (["affirm"], "AFRM"),
        (["draftkings"], "DKNG"),
        (["walmart"], "WMT"),
        (["target"], "TGT"),
        (["costco"], "COST"),
        (["home depot"], "HD"),
        (["lowe's", "lowes"], "LOW"),
        (["nike"], "NKE"),
        (["mcdonald's", "mcdonalds", "mcdonald"], "MCD"),
        (["starbucks"], "SBUX"),
        (["coca cola", "coca-cola", "coke"], "KO"),
        (["pepsi", "pepsico"], "PEP"),
        (["procter and gamble", "procter & gamble", "p&g", "procter gamble"], "PG"),
        (["disney", "walt disney"], "DIS"),
        (["etsy"], "ETSY"),
        (["ebay"], "EBAY"),
        (["best buy"], "BBY"),
        (["kroger"], "KR"),
        (["walgreens"], "WBA"),
        (["dollar tree"], "DLTR"),
        (["dollar general"], "DG"),
        (["lululemon", "lulu"], "LULU"),
        (["under armour"], "UAA"),
        (["ralph lauren"], "RL"),
        (["chipotle"], "CMG"),
        (["domino's", "dominos"], "DPZ"),
        (["doordash"], "DASH"),
        (["uber"], "UBER"),
        (["lyft"], "LYFT"),
        (["airbnb"], "ABNB"),
        (["booking", "booking.com", "priceline"], "BKNG"),
        (["expedia"], "EXPE"),
        (["marriott"], "MAR"),
        (["hilton"], "HLT"),
        (["hyatt"], "H"),
        (["carnival", "carnival cruise"], "CCL"),
        (["royal caribbean"], "RCL"),
        (["mgm", "mgm resorts"], "MGM"),
        (["wynn"], "WYNN"),
        (["johnson and johnson", "johnson & johnson", "j&j"], "JNJ"),
        (["pfizer"], "PFE"),
        (["moderna"], "MRNA"),
        (["abbvie"], "ABBV"),
        (["merck"], "MRK"),
        (["unitedhealth", "united health", "uhc"], "UNH"),
        (["eli lilly", "lilly"], "LLY"),
        (["amgen"], "AMGN"),
        (["bristol myers", "bristol-myers", "bms"], "BMY"),
        (["gilead"], "GILD"),
        (["regeneron"], "REGN"),
        (["biogen"], "BIIB"),
        (["vertex"], "VRTX"),
        (["intuitive surgical", "da vinci"], "ISRG"),
        (["medtronic"], "MDT"),
        (["stryker"], "SYK"),
        (["humana"], "HUM"),
        (["cigna"], "CI"),
        (["teladoc"], "TDOC"),
        (["hims", "hers", "hims and hers"], "HIMS"),
        (["exxon", "exxonmobil"], "XOM"),
        (["chevron"], "CVX"),
        (["conocophillips", "conoco"], "COP"),
        (["schlumberger", "slb"], "SLB"),
        (["halliburton"], "HAL"),
        (["occidental", "oxy"], "OXY"),
        (["marathon", "marathon petroleum"], "MPC"),
        (["phillips 66"], "PSX"),
        (["valero"], "VLO"),
        (["nextera", "nextera energy"], "NEE"),
        (["duke energy", "duke"], "DUK"),
        (["enphase"], "ENPH"),
        (["first solar"], "FSLR"),
        (["sunrun"], "RUN"),
        (["ford"], "F"),
        (["general motors", "gm"], "GM"),
        (["toyota"], "TM"),
        (["honda"], "HMC"),
        (["rivian"], "RIVN"),
        (["lucid"], "LCID"),
        (["nio"], "NIO"),
        (["ferrari"], "RACE"),
        (["snapchat", "snap"], "SNAP"),
        (["spotify"], "SPOT"),
        (["pinterest"], "PINS"),
        (["reddit"], "RDDT"),
        (["tinder", "match", "match group"], "MTCH"),
        (["bumble"], "BMBL"),
        (["electronic arts", "ea sports", "ea games"], "EA"),
        (["roblox"], "RBLX"),
        (["live nation", "ticketmaster"], "LYV"),
        (["warner bros", "warner brothers", "hbo"], "WBD"),
        (["paramount", "cbs"], "PARA"),
        (["fox news", "fox corp"], "FOX"),
        (["new york times", "nyt"], "NYT"),
        (["yelp"], "YELP"),
        (["boeing"], "BA"),
        (["ge", "ge aerospace", "general electric"], "GE"),
        (["caterpillar", "cat"], "CAT"),
        (["deere", "john deere"], "DE"),
        (["3m"], "MMM"),
        (["honeywell"], "HON"),
        (["raytheon", "rtx"], "RTX"),
        (["lockheed martin", "lockheed"], "LMT"),
        (["northrop grumman", "northrop"], "NOC"),
        (["general dynamics"], "GD"),
        (["ups", "united parcel service"], "UPS"),
        (["fedex"], "FDX"),
        (["delta", "delta airlines", "delta air lines"], "DAL"),
        (["united airlines"], "UAL"),
        (["american airlines"], "AAL"),
        (["southwest", "southwest airlines"], "LUV"),
        (["bitcoin", "btc"], "BTC-USD"),
        (["ethereum", "eth"], "ETH-USD"),
        (["solana", "sol"], "SOL-USD"),
        (["xrp", "ripple"], "XRP-USD"),
        (["cardano", "ada"], "ADA-USD"),
        (["dogecoin", "doge"], "DOGE-USD"),
        (["shiba inu", "shiba", "shib"], "SHIB-USD"),
        (["avalanche", "avax"], "AVAX-USD"),
        (["polygon", "matic"], "MATIC-USD"),
        (["litecoin", "ltc"], "LTC-USD"),
        (["palantir"], "PLTR"),
        (["snowflake"], "SNOW"),
        (["cloudflare"], "NET"),
        (["shopify"], "SHOP"),
        (["roku"], "ROKU"),
        (["gamestop"], "GME"),
        (["amc", "amc theaters", "amc entertainment"], "AMC"),
        (["blackberry"], "BB"),
        (["rocket", "rocket mortgage", "rocket companies"], "RKT"),
        (["mercadolibre", "mercado libre"], "MELI"),
        (["alibaba"], "BABA"),
        (["jd.com", "jd"], "JD"),
        (["baidu"], "BIDU"),
        (["tencent"], "TCEHY"),
        (["taiwan semiconductor", "tsmc"], "TSM"),
        (["asml"], "ASML"),
        (["arm", "arm holdings"], "ARM"),
        (["virgin galactic"], "SPCE"),
        (["sea limited", "shopee"], "SE"),
    ]

    private let financialKeywords: Set<String> = [
        "stock", "stocks", "shares", "share", "price", "trading", "trade",
        "buy", "bought", "sell", "sold", "invest", "portfolio", "market",
        "earnings", "dividend", "ticker", "position", "options", "dropped",
        "drop", "drops", "rose", "rally", "hit", "target", "alert", "remind",
        "watch", "below", "above", "under", "over", "ipo", "short", "long",
        "puts", "calls", "stonks", "holding", "holds", "crash", "dip",
        "all time high", "ath", "52 week", "52-week"
    ]

    // MARK: - Ticker Detection

    func detectTicker(in text: String) -> FinanceTicker? {
        if let ticker = detectDollarSignTicker(in: text) { return ticker }
        let lower = text.lowercased()
        if let ticker = detectByCompanyName(in: lower) { return ticker }
        let hasFinancialContext = financialKeywords.contains { lower.contains($0) }
        guard hasFinancialContext else { return nil }
        let firstLine = text.components(separatedBy: "\n").first ?? text
        for (sym, name) in knownTickers.sorted(by: { $0.key.count > $1.key.count }) {
            guard sym.count >= 2 else { continue }
            let searchIn = sym.count >= 4 ? text : firstLine
            let escaped = NSRegularExpression.escapedPattern(for: sym)
            if sym.count <= 4 {
                let upperPattern = "(?<![A-Z])\(escaped)(?![A-Z])"
                guard let upperRegex = try? NSRegularExpression(pattern: upperPattern),
                      upperRegex.firstMatch(in: searchIn, range: NSRange(searchIn.startIndex..., in: searchIn)) != nil else {
                    continue
                }
            } else {
                let pattern = "(?<![A-Za-z])\(escaped)(?![A-Za-z])"
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      regex.firstMatch(in: searchIn, range: NSRange(searchIn.startIndex..., in: searchIn)) != nil else {
                    continue
                }
            }
            
            return FinanceTicker(symbol: sym, companyName: name)
        }
        return nil
    }

    private func detectByCompanyName(in lower: String) -> FinanceTicker? {
        for entry in companyNameMap {
            for name in entry.names {
                let escaped = NSRegularExpression.escapedPattern(for: name)
                let pattern = "(?<![a-z])\(escaped)(?![a-z])"
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) != nil {
                    let symbol = entry.symbol
                    let companyName = knownTickers[symbol] ?? name.capitalized
                    return FinanceTicker(symbol: symbol, companyName: companyName)
                }
            }
        }
        return nil
    }

    private func detectDollarSignTicker(in text: String) -> FinanceTicker? {
        let pattern = #"\$([A-Z]{2,5}(?:-[A-Z]{3})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        let sym = String(text[range])
        return FinanceTicker(symbol: sym, companyName: knownTickers[sym] ?? sym)
    }

    // MARK: - Alert Parsing

    func parseAlert(from text: String) -> FinanceAlert? {
        guard let ticker = detectTicker(in: text) else { return nil }
        let lower = text.lowercased()
        let belowPattern = #"(?:below|under|drops?\s+(?:to|below)|falls?\s+(?:to|below)|goes?\s+(?:to|below))\s*\$?([\d,]+(?:\.\d+)?)"#
        if let val = extractNumber(pattern: belowPattern, from: lower) {
            return FinanceAlert(ticker: ticker.symbol, threshold: val, direction: .below)
        }
        let abovePattern = #"(?:above|over|rises?\s+(?:to|above)|rallies?\s+to|reaches?\s+|hits?\s+)\s*\$?([\d,]+(?:\.\d+)?)"#
        if let val = extractNumber(pattern: abovePattern, from: lower) {
            return FinanceAlert(ticker: ticker.symbol, threshold: val, direction: .above)
        }
        return nil
    }

    private func extractNumber(pattern: String, from text: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return Double(String(text[range]).replacingOccurrences(of: ",", with: ""))
    }

    // MARK: - Quote Fetching

    func fetchQuote(symbol: String) async -> FinanceQuote? {
        if let cached = cache[symbol], Date().timeIntervalSince(cached.fetchedAt) < cacheDuration {
            return cached
        }

        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        guard let chartURL = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?interval=1d&range=1mo") else { return nil }

        var chartRequest = URLRequest(url: chartURL)
        chartRequest.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        chartRequest.timeoutInterval = 10

        do {
            let (chartData, _) = try await URLSession.shared.data(for: chartRequest)

            guard let json = try? JSONSerialization.jsonObject(with: chartData) as? [String: Any],
                  let chart = json["chart"] as? [String: Any],
                  let results = chart["result"] as? [[String: Any]],
                  let meta = results.first?["meta"] as? [String: Any] else { return nil }

            guard let price = meta["regularMarketPrice"] as? Double else { return nil }

            let prevClose = (meta["previousClose"] as? Double)
                ?? (meta["chartPreviousClose"] as? Double)
                ?? price
            let shortName = (meta["shortName"] as? String)
                ?? (meta["longName"] as? String)
                ?? knownTickers[symbol]
                ?? symbol
            let exchange = (meta["exchangeName"] as? String) ?? "NASDAQ"
            let high52w = meta["fiftyTwoWeekHigh"] as? Double
            let low52w = meta["fiftyTwoWeekLow"] as? Double

            // Day range IS in the chart meta
            let dayHigh = meta["regularMarketDayHigh"] as? Double
            let dayLow  = meta["regularMarketDayLow"] as? Double

            var sparkline: [Double] = []
            if let indicators = results.first?["indicators"] as? [String: Any],
               let quoteIndicator = indicators["quote"] as? [[String: Any]],
               let closes = quoteIndicator.first?["close"] as? [Any] {
                sparkline = closes.compactMap { $0 as? Double }
            }
            let quote = FinanceQuote(
                symbol: symbol,
                companyName: shortName,
                price: price,
                previousClose: prevClose,
                high52w: high52w,
                low52w: low52w,
                dayHigh: dayHigh,
                dayLow: dayLow,
                exchange: exchange,
                sparklinePoints: sparkline,
                fetchedAt: Date()
            )
            cache[symbol] = quote
            return quote
        } catch {
            print("FinanceService: fetch failed for \(symbol): \(error.localizedDescription)")
            return nil
        }
    }

        func fetchQuotes(symbols: [String]) async -> [String: FinanceQuote] {
            await withTaskGroup(of: (String, FinanceQuote?).self) { group in
                for symbol in symbols {
                    group.addTask {
                        let quote = await FinanceService.shared.fetchQuote(symbol: symbol)
                        return (symbol, quote)
                    }
                }
                var results: [String: FinanceQuote] = [:]
                for await (symbol, quote) in group {
                    if let quote { results[symbol] = quote }
                }
                return results
            }
        }

        func fetchMarketIndices() async -> (dow: FinanceQuote?, sp500: FinanceQuote?, qqq: FinanceQuote?) {
            async let dow = fetchQuote(symbol: "^DJI")
            async let sp500 = fetchQuote(symbol: "^GSPC")
            async let qqq = fetchQuote(symbol: "QQQ")
            return await (dow, sp500, qqq)
        }

        // MARK: - Sparkline by Range

        func fetchSparkline(symbol: String, range: FinanceRange) async -> [Double] {
            let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
            guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?interval=\(range.yahooInterval)&range=\(range.yahooRange)") else { return [] }

            var request = URLRequest(url: url)
            request.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                forHTTPHeaderField: "User-Agent"
            )
            request.timeoutInterval = 10

            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let chart = json["chart"] as? [String: Any],
                      let results = chart["result"] as? [[String: Any]],
                      let indicators = results.first?["indicators"] as? [String: Any],
                      let quoteData = indicators["quote"] as? [[String: Any]],
                      let closes = quoteData.first?["close"] as? [Any] else { return [] }
                return closes.compactMap { $0 as? Double }
            } catch {
                return []
            }
        }

        // MARK: - Price Alert Check

        func checkPriceAlerts(memories: [Memory]) async {
            let financeMemories = memories.filter { detectTicker(in: $0.text) != nil }
            for memory in financeMemories {
                guard let alert = parseAlert(from: memory.text),
                      let quote = await fetchQuote(symbol: alert.ticker) else { continue }
                let triggered: Bool
                switch alert.direction {
                case .below: triggered = quote.price <= alert.threshold
                case .above: triggered = quote.price >= alert.threshold
                }
                if triggered { await fireAlertNotification(alert: alert, quote: quote) }
            }
        }

        // MARK: - Notification

        private func fireAlertNotification(alert: FinanceAlert, quote: FinanceQuote) async {
            let content = UNMutableNotificationContent()
            let dirWord = alert.direction == .below ? "dropped below" : "risen above"
            content.title = "\(alert.ticker) Price Alert"
            content.body = "\(quote.companyName) has \(dirWord) \(alert.formattedThreshold). Now at \(quote.formattedPrice)."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let id = "finance-alert-\(alert.ticker)-\(alert.direction.rawValue)"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            try? await UNUserNotificationCenter.current().add(request)
        }

        // MARK: - UI Helpers

        func color(for symbol: String) -> Color {
            let palette: [Color] = [
                Color(red: 0.1, green: 0.55, blue: 0.47),
                Color(red: 0.15, green: 0.40, blue: 0.75),
                Color(red: 0.82, green: 0.35, blue: 0.18),
                Color(red: 0.52, green: 0.28, blue: 0.72),
                Color(red: 0.12, green: 0.55, blue: 0.28),
                Color(red: 0.7, green: 0.15, blue: 0.15),
            ]
            let hash = symbol.unicodeScalars.reduce(0) { $0 + Int($1.value) }
            return palette[hash % palette.count]
        }

        func formattedIndexPrice(_ quote: FinanceQuote) -> String {
            if quote.symbol.hasPrefix("^") {
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                formatter.maximumFractionDigits = 0
                return formatter.string(from: NSNumber(value: quote.price)) ?? "\(Int(quote.price))"
            }
            return String(format: "%.2f", quote.price)
        }
    }
