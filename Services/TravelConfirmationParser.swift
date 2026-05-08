//
//  TravelConfirmationParser.swift
//  Orca
//
//  Created by David Piliponskiy on 3/24/26.
//

import Foundation

struct TravelParseResult {
    var type: TravelType = .unknown
    var airline: String?
    var flightNumber: String?
    var departureAirport: String?
    var arrivalAirport: String?
    var departureDate: Date?
    var departureTime: String?
    var returnDate: Date?        // ← this line must be present
    var confirmationCode: String?
    var gateNumber: String?
    var hotelName: String?
    var hotelAddress: String?
    var checkInDate: Date?
    var checkOutDate: Date?
    var formattedMemory: String
    var pingDate: Date?

    enum TravelType {
        case flight, hotel, unknown
    }
}

class TravelConfirmationParser {
    static let shared = TravelConfirmationParser()

    private let airlineCodes: [String: String] = [
        "AA": "American Airlines", "DL": "Delta Air Lines", "UA": "United Airlines",
        "WN": "Southwest Airlines", "B6": "JetBlue Airways", "AS": "Alaska Airlines",
        "F9": "Frontier Airlines", "NK": "Spirit Airlines", "G4": "Allegiant Air",
        "HA": "Hawaiian Airlines", "SY": "Sun Country Airlines", "AC": "Air Canada",
        "BA": "British Airways", "LH": "Lufthansa", "AF": "Air France", "KL": "KLM",
        "EK": "Emirates", "QR": "Qatar Airways", "SQ": "Singapore Airlines",
        "CX": "Cathay Pacific", "JL": "Japan Airlines", "NH": "ANA",
        "TK": "Turkish Airlines", "IB": "Iberia", "AZ": "ITA Airways",
        "SK": "Scandinavian Airlines", "LX": "Swiss International", "OS": "Austrian Airlines",
        "VS": "Virgin Atlantic", "MX": "Mexicana", "AM": "Aeromexico",
        "LA": "LATAM Airlines", "CM": "Copa Airlines", "AV": "Avianca",
    ]

    private let airlineNames: [String: String] = [
        "american": "American Airlines", "delta": "Delta Air Lines",
        "united": "United Airlines", "southwest": "Southwest Airlines",
        "jetblue": "JetBlue Airways", "alaska": "Alaska Airlines",
        "frontier": "Frontier Airlines", "spirit": "Spirit Airlines",
        "allegiant": "Allegiant Air", "hawaiian": "Hawaiian Airlines",
        "sun country": "Sun Country Airlines", "air canada": "Air Canada",
        "british airways": "British Airways", "lufthansa": "Lufthansa",
        "air france": "Air France", "klm": "KLM", "emirates": "Emirates",
        "qatar": "Qatar Airways", "singapore": "Singapore Airlines",
        "cathay": "Cathay Pacific", "japan airlines": "Japan Airlines",
        "ana": "ANA", "turkish": "Turkish Airlines", "iberia": "Iberia",
        "swiss": "Swiss International", "virgin atlantic": "Virgin Atlantic",
        "aeromexico": "Aeromexico", "latam": "LATAM Airlines",
        "copa": "Copa Airlines", "avianca": "Avianca",
    ]

    // MARK: - Main parse function

    func parse(text: String) -> TravelParseResult? {
        let lower = text.lowercased()

        let isHotel = lower.contains("check-in") || lower.contains("check in") ||
                      lower.contains("check-out") || lower.contains("checkout") ||
                      lower.contains("hotel") || lower.contains("reservation") ||
                      lower.contains("room") || lower.contains("nights")

        let isFlight = lower.contains("flight") || lower.contains("boarding") ||
                       lower.contains("departure") || lower.contains("arrival") ||
                       lower.contains("gate") || lower.contains("terminal") ||
                       detectFlightNumber(text: text) != nil

        guard isHotel || isFlight else { return nil }

        if isFlight { return parseFlight(text: text) }
        else { return parseHotel(text: text) }
    }

    // MARK: - Flight Parser

    private func parseFlight(text: String) -> TravelParseResult? {
        let airline = detectAirline(text: text)
        let flightNumber = detectFlightNumber(text: text)
        let airports = detectAirports(text: text)
        let confirmation = detectConfirmationCode(text: text)
        let gate = detectGate(text: text)
        let dates = detectDates(text: text)
        let departureTime = detectTime(text: text)

        guard flightNumber != nil || airports.count >= 2 else { return nil }

        let departureAirport = airports.first
        let arrivalAirport = airports.count > 1 ? airports[1] : nil

        var fullDepartureDate: Date? = dates.first
        if let depDate = dates.first, let timeStr = departureTime {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US")
            let calendar = Calendar.current
            let dayComponents = calendar.dateComponents([.year, .month, .day], from: depDate)
            for format in ["h:mm a", "h:mm", "HH:mm"] {
                formatter.dateFormat = format
                if let parsedTime = formatter.date(from: timeStr.trimmingCharacters(in: .whitespaces)) {
                    let timeComponents = calendar.dateComponents([.hour, .minute], from: parsedTime)
                    var combined = DateComponents()
                    combined.year = dayComponents.year
                    combined.month = dayComponents.month
                    combined.day = dayComponents.day
                    combined.hour = timeComponents.hour
                    combined.minute = timeComponents.minute
                    if let full = calendar.date(from: combined) {
                        fullDepartureDate = full
                        break
                    }
                }
            }
        }

        var lines: [String] = []
        if let airline = airline {
            lines.append("✈️ \(airline) · Flight \(flightNumber ?? "")")
        } else {
            lines.append("✈️ Flight \(flightNumber ?? "")")
        }
        if let dep = departureAirport, let arr = arrivalAirport {
            lines.append("\(dep) → \(arr)")
        }
        var detailParts: [String] = []
        if let date = fullDepartureDate {
            detailParts.append(date.formatted(.dateTime.month(.abbreviated).day().year()))
        }
        if let time = departureTime { detailParts.append("at \(time)") }
        if !detailParts.isEmpty { lines.append("Departure: \(detailParts.joined(separator: " "))") }
        if let gate = gate { lines.append("Gate: \(gate)") }
        if let conf = confirmation { lines.append("Confirmation: \(conf)") }

        var pingDate: Date? = nil
        if let dep = fullDepartureDate {
            pingDate = Calendar.current.date(byAdding: .hour, value: -3, to: dep)
        }

        return TravelParseResult(
            type: .flight,
            airline: airline,
            flightNumber: flightNumber,
            departureAirport: departureAirport,
            arrivalAirport: arrivalAirport,
            departureDate: fullDepartureDate,
            departureTime: departureTime,
            confirmationCode: confirmation,
            gateNumber: gate,
            formattedMemory: lines.joined(separator: "\n"),
            pingDate: pingDate
        )
    }

    // MARK: - Hotel Parser

    private func parseHotel(text: String) -> TravelParseResult? {
        let hotelName = detectHotelName(text: text)
        let hotelAddress = detectHotelAddress(text: text)
        let dates = detectDates(text: text)
        let confirmation = detectConfirmationCode(text: text)

        let checkIn = dates.first
        let checkOut = dates.count > 1 ? dates[1] : nil

        guard hotelName != nil || checkIn != nil else { return nil }

        var lines: [String] = []
        lines.append("🏨 \(hotelName ?? "Hotel Reservation")")
        if let addr = hotelAddress { lines.append(addr) }

        if let checkIn = checkIn {
            var checkInStr = "Check-in: \(checkIn.formatted(.dateTime.month(.abbreviated).day().year()))"
            if let checkOut = checkOut {
                checkInStr += " → \(checkOut.formatted(.dateTime.month(.abbreviated).day().year()))"
            }
            lines.append(checkInStr)
        }
        if let conf = confirmation { lines.append("Confirmation: \(conf)") }

        var pingDate: Date? = nil
        if let checkIn = checkIn {
            pingDate = Calendar.current.date(byAdding: .day, value: -1, to: checkIn)
        }

        return TravelParseResult(
            type: .hotel,
            confirmationCode: confirmation,
            hotelName: hotelName,
            hotelAddress: hotelAddress,
            checkInDate: checkIn,
            checkOutDate: checkOut,
            formattedMemory: lines.joined(separator: "\n"),
            pingDate: pingDate
        )
    }

    // MARK: - Detection Helpers

    private func detectAirline(text: String) -> String? {
        let lower = text.lowercased()
        for (key, value) in airlineNames {
            if lower.contains(key) { return value }
        }
        if let match = text.range(of: #"\b([A-Z]{2})\d{1,4}\b"#, options: .regularExpression) {
            let code = String(text[match].prefix(2))
            if let airline = airlineCodes[code] { return airline }
        }
        return nil
    }

    private func detectFlightNumber(text: String) -> String? {
        // Pattern 1: Standard IATA format — "AA1234"
        let pattern = #"\b[A-Z]{2}\d{1,4}\b"#
        if let range = text.range(of: pattern, options: .regularExpression) {
            return String(text[range])
        }

        // Pattern 2: "Flight # 3005" or "Flight #3005" or "Flight 3005"
        let flightPattern = #"[Ff]light\s+#?\s*(\d{1,4})"#
        if let regex = try? NSRegularExpression(pattern: flightPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }

        // Pattern 3: Bare fallback — "Flight #" followed by digits with any spacing
        let bareFlightPattern = #"[Ff]light\s*#\s*(\d{1,4})"#
        if let regex = try? NSRegularExpression(pattern: bareFlightPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        // Pattern 4: number on next line after "Flight #" label
        let tableFlightPattern = #"[Ff]light\s*#?\s*[\n\r]+\s*(\d{3,4})"#
        if let regex = try? NSRegularExpression(pattern: tableFlightPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        return nil
    }

    private func detectAirports(text: String) -> [String] {
        let pattern = #"\b([A-Z]{3})\b"#
        let commonAirports = Set([
            // Major US hubs
            "ATL","LAX","ORD","DFW","DEN","JFK","SFO","SEA","LAS","MCO",
            "EWR","CLT","PHX","IAH","MIA","BOS","MSP","FLL","DTW","PHL",
            "LGA","BWI","SLC","SAN","MDW","DCA","IAD","TPA","PDX","HNL",
            "AUS","STL","BNA","OAK","MCI","SMF","RDU","SJC","DAL","MSY",
            "PIT","CLE","CVG","MEM","IND","CMH","SAT","JAX","RSW","OGG",
            // Regional US — East
            "SRQ","PBI","PIE","EYW","GNV","TLH","DAB","MLB","PGD","SFB",
            "PWM","BTV","ALB","SYR","ROC","BUF","PVD","MHT","ACK","MVY",
            "HPN","ISP","SWF","ABE","AVP","MDT","IPT","ERI","CAK","TOL",
            "GSP","CHS","SAV","ILM","OAJ","AVL","ROA","LYH","CHO","ORF",
            "RIC","SHD","HHH","HTS","CRW","EKN","MRB","PKB",
            // Regional US — South
            "PNS","VPS","MOB","HSV","BHM","MGM","DHN","GPT","JAN","MEI",
            "TYS","TRI","CHA","BNA","SHV","LFT","BTR","AEX","MLU","GTR",
            "TUP","HSV","HSP","ROW","FAY","ILG","ACY","TTN","ABE",
            // Regional US — Midwest
            "TUL","OKC","ICT","SPI","BMI","MLI","DBQ","CID","DSM","SUX",
            "FSD","BIS","FAR","GFK","MOT","ISN","DIK","ABR","PIR","HON",
            "MKE","GRB","ATW","LSE","RST","DLH","HIB","INL","IMT","ESC",
            // Regional US — West
            "ABQ","ELP","LBB","AMA","MAF","CRP","HRL","MFE","SPS","ABI",
            "SJT","BOI","GEG","BZN","MSO","FCA","JAC","SUN","TWF","PIH",
            "IDA","GTF","HLN","BIL","RAP","FSD","GJT","DRO","PUB","COS",
            "FAT","SBA","SBP","MRY","RDD","CIC","ACV","STS","MMH","SMX",
            "RNO","LMT","MFR","EUG","RDM","PDT","ALW","YKM","BFI","PAE",
            // Canada
            "YYZ","YVR","YUL","YYC","YEG","YOW","YHZ","YWG","YXE","YQR",
            // Mexico
            "MEX","CUN","GDL","MTY","TLC","SJD","PVR","ZIH","MID","OAX",
            // Caribbean
            "MBJ","KIN","NAS","GGT","ELH","FPO","POS","BGI","ANU","SXM",
            "STT","STX","SJU","BQN","PSE","VQS","CPX","SKB","NEV","SVD",
            // Europe
            "LHR","CDG","AMS","FRA","MUC","ZRH","MAD","BCN","FCO","LGW",
            "DUB","CPH","ARN","OSL","HEL","VIE","BRU","LIS","ATH","IST",
            "MAN","EDI","GLA","BHX","LPL","NCL","BRS","LTN","STN","LCY",
            "ORY","LYS","NCE","MRS","TLS","BOD","NTE","BES","SXB","GVA",
            "BSL","BRN","ACE","TFS","LPA","PMI","IBZ","MAH","VLC","SVQ",
            "AGP","ALC","SDR","SCQ","OVD","VGO","BIO","ZAZ","GRX","MXP",
            "LIN","VCE","BLQ","FLR","PSA","NAP","CTA","PMO","CAG","BRI",
            "WAW","KRK","WRO","GDN","KTW","LCJ","POZ","SZZ","BZG","RZE",
            "PRG","BUD","OTP","SOF","TXL","SXF","HAM","DUS","CGN","STR",
            "NUE","HAJ","BRE","LEJ","FKB","ERF","DRS","PAD","FMO","HHN",
            // Asia Pacific
            "DXB","DOH","AUH","KWI","BAH","RUH","JED","MED","DMM","ADE",
            "SIN","HKG","NRT","ICN","PEK","PVG","BKK","KUL","MNL","CGK",
            "SYD","MEL","BNE","PER","ADL","OOL","HBA","CNS","TSV","MKY",
            "NAN","SUV","APW","PPT","IPC","GUM","SPN","ROR","MAJ","TRW",
            // Latin America
            "GRU","GIG","CGH","BSB","SSA","FOR","REC","BEL","MCZ","CWB",
            "EZE","AEP","COR","MDZ","BRC","IGR","UYU","MVO","GUA","SAL",
            "BOG","MDE","CLO","BAQ","CTG","ADZ","SMR","LIM","CUZ","AQP",
            "SCL","PMC","IQQ","ARI","ANF","CCP","ZCO","MHC","PMQ","USH",
        ])
        var airports: [String] = []
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex?.matches(in: text, range: range) ?? []
        for match in matches {
            if let range = Range(match.range(at: 1), in: text) {
                let code = String(text[range])
                if commonAirports.contains(code) && !airports.contains(code) {
                    airports.append(code)
                }
            }
        }
        return airports
    }

    private func detectConfirmationCode(text: String) -> String? {
        let keywords = ["confirmation", "booking", "record locator", "pnr", "reservation"]
        let lower = text.lowercased()
        for keyword in keywords {
            if let keyRange = lower.range(of: keyword) {
                let afterKeyword = String(text[keyRange.upperBound...])
                let pattern = #"[A-Z0-9]{5,8}"#
                if let codeRange = afterKeyword.range(of: pattern, options: .regularExpression) {
                    return String(afterKeyword[codeRange])
                }
            }
        }
        let pattern = #"\b[A-Z0-9]{6}\b"#
        if let range = text.range(of: pattern, options: .regularExpression) {
            return String(text[range])
        }
        return nil
    }

    private func detectGate(text: String) -> String? {
        let pattern = #"[Gg]ate\s+([A-Z]?\d{1,3}[A-Z]?)"#
        if let range = text.range(of: pattern, options: .regularExpression) {
            let match = String(text[range])
            return match.components(separatedBy: .whitespaces).last
        }
        return nil
    }

    private func detectTime(text: String) -> String? {
        let amPmPattern = #"\b\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)\b"#
        if let range = text.range(of: amPmPattern, options: .regularExpression) {
            return String(text[range]).trimmingCharacters(in: .whitespaces)
        }
        let pattern = #"\b\d{1,2}:\d{2}\b"#
        if let range = text.range(of: pattern, options: .regularExpression) {
            return String(text[range]).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private func detectDates(text: String) -> [Date] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        var explicitDates: [Date] = []
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)

        // Priority 1: "Thursday, April 16, 2026" with weekday
        let weekdayPattern = #"\b(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),?\s+(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},?\s+20\d{2}\b"#
        if let regex = try? NSRegularExpression(pattern: weekdayPattern, options: .caseInsensitive) {
            for match in regex.matches(in: text, range: nsRange) {
                if let range = Range(match.range, in: text) {
                    let raw = String(text[range])
                    let dateStr = raw.trimmingCharacters(in: .whitespaces)
                    for format in ["EEEE, MMMM d, yyyy", "EEEE MMMM d yyyy", "EEEE, MMMM d yyyy"] {
                        formatter.dateFormat = format
                        if let date = formatter.date(from: dateStr) {
                            explicitDates.append(date); break
                        }
                    }
                }
            }
        }
        if !explicitDates.isEmpty { return explicitDates.sorted() }

        // Priority 2: "April 16, 2026" month-first with year
        let monthFirstPattern = #"\b(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},?\s+20\d{2}\b"#
        if let regex = try? NSRegularExpression(pattern: monthFirstPattern, options: .caseInsensitive) {
            for match in regex.matches(in: text, range: nsRange) {
                if let range = Range(match.range, in: text) {
                    let raw = String(text[range])
                    for format in ["MMMM d, yyyy", "MMMM d yyyy"] {
                        formatter.dateFormat = format
                        if let date = formatter.date(from: raw.trimmingCharacters(in: .whitespaces)) {
                            explicitDates.append(date); break
                        }
                    }
                }
            }
        }
        if !explicitDates.isEmpty { return explicitDates.sorted() }

        // Priority 3: "16 Apr 2026" or "16 April 2026" — day first
        let dayFirstPattern = #"\b\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|January|February|March|April|June|July|August|September|October|November|December)\s+20\d{2}\b"#
        if let regex = try? NSRegularExpression(pattern: dayFirstPattern, options: .caseInsensitive) {
            for match in regex.matches(in: text, range: nsRange) {
                if let range = Range(match.range, in: text) {
                    let raw = String(text[range]).trimmingCharacters(in: .whitespaces)
                    for format in ["d MMM yyyy", "d MMMM yyyy"] {
                        formatter.dateFormat = format
                        if let date = formatter.date(from: raw) {
                            explicitDates.append(date); break
                        }
                    }
                }
            }
        }
        if !explicitDates.isEmpty { return explicitDates.sorted() }

        // Priority 4: "Thu, Apr 23, 2026" — abbreviated weekday + month
        let abbrevWeekdayPattern = #"\b(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun),?\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2},?\s+20\d{2}\b"#
        if let regex = try? NSRegularExpression(pattern: abbrevWeekdayPattern, options: .caseInsensitive) {
            for match in regex.matches(in: text, range: nsRange) {
                if let range = Range(match.range, in: text) {
                    let raw = String(text[range]).trimmingCharacters(in: .whitespaces)
                    for format in ["EEE, MMM d, yyyy", "EEE MMM d yyyy", "EEE, MMM d yyyy"] {
                        formatter.dateFormat = format
                        if let date = formatter.date(from: raw) {
                            explicitDates.append(date); break
                        }
                    }
                }
            }
        }
        if !explicitDates.isEmpty { return explicitDates.sorted() }

        // Priority 5: "4/16/2026" or "04/16/2026" numeric formats
        let numericPattern = #"\b(\d{1,2})[/\-](\d{1,2})[/\-](20\d{2})\b"#
        if let regex = try? NSRegularExpression(pattern: numericPattern) {
            for match in regex.matches(in: text, range: nsRange) {
                if let range = Range(match.range, in: text) {
                    let raw = String(text[range])
                    for format in ["MM/dd/yyyy", "M/d/yyyy", "MM-dd-yyyy", "M-d-yyyy"] {
                        formatter.dateFormat = format
                        if let date = formatter.date(from: raw) {
                            explicitDates.append(date); break
                        }
                    }
                }
            }
        }
        if !explicitDates.isEmpty { return explicitDates.sorted() }

        // Fallback: NSDataDetector — only use future dates
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let allDates = detector?.matches(in: text, range: nsRange).compactMap { $0.date }.sorted() ?? []
        let futureDates = allDates.filter { $0 > Calendar.current.startOfDay(for: Date()) }
        return futureDates.isEmpty ? [] : futureDates
    }

    private func detectHotelName(text: String) -> String? {
        let hotelKeywords = ["hotel", "inn", "resort", "suites", "marriott", "hilton",
                             "hyatt", "sheraton", "westin", "courtyard", "hampton",
                             "holiday inn", "best western", "radisson", "doubletree",
                             "four seasons", "ritz", "w hotel", "nobu", "kimpton",
                             "intercontinental", "crowne plaza", "sofitel", "accor",
                             "autograph", "curio", "tapestry", "tribute"]
        let lower = text.lowercased()
        for keyword in hotelKeywords {
            if lower.contains(keyword) {
                let lines = text.components(separatedBy: .newlines)
                for line in lines {
                    if line.lowercased().contains(keyword) {
                        let cleaned = line.trimmingCharacters(in: .whitespaces)
                        if cleaned.count > 3 && cleaned.count < 60 {
                            return cleaned
                        }
                    }
                }
                return keyword.capitalized
            }
        }
        return nil
    }

    private func detectHotelAddress(text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        let addressPattern = #"\d+\s+\w+.*(?:St|Street|Ave|Avenue|Blvd|Boulevard|Dr|Drive|Rd|Road|Way|Ln|Lane|Pkwy|Parkway|Monroe|Michigan|Wacker|State|Market|Main|Broadway)"#
        let cityStatePattern = #"[A-Za-z\s]+,\s*[A-Z]{2}"#

        for (index, line) in lines.enumerated() {
            let cleaned = line.trimmingCharacters(in: .whitespaces)
            if cleaned.range(of: addressPattern, options: [.regularExpression, .caseInsensitive]) != nil {
                if index + 1 < lines.count {
                    let nextLine = lines[index + 1].trimmingCharacters(in: .whitespaces)
                    if nextLine.range(of: cityStatePattern, options: .regularExpression) != nil {
                        let streetCleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: ", "))
                        let cityLine = nextLine.replacingOccurrences(of: " United States", with: "", options: .caseInsensitive)
                        return "\(streetCleaned), \(cityLine.trimmingCharacters(in: .whitespaces))"
                    }
                }
                return cleaned.trimmingCharacters(in: CharacterSet(charactersIn: ", "))
            }
        }
        return nil
    }
}
