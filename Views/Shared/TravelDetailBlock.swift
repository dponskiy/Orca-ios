//
//  TravelDetailBlock.swift
//  Orca
//
//  Created by David Piliponskiy on 3/28/26.
//

import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct TravelDetailBlock: View {
    @Bindable var memory: Memory
    @Query private var pings: [Ping]

    @State private var hotelCoordinate: CLLocationCoordinate2D? = nil
    @State private var departureCoordinate: CLLocationCoordinate2D? = nil
    @State private var arrivalCoordinate: CLLocationCoordinate2D? = nil
    @State private var showLocationSearch = false

    private var travel: TravelParseResult? { TravelConfirmationParser.shared.parse(text: memory.text) }
    private var memoryPings: [Ping] { pings.filter { $0.memoryId == memory.id && $0.isActive } }

    var body: some View {
        if let travel = travel {
            VStack(spacing: 10) {
                if travel.type == .flight {
                    flightCard(travel: travel)
                    if departureCoordinate != nil && arrivalCoordinate != nil {
                        flightRouteMap(travel: travel)
                    }
                } else if travel.type == .hotel {
                    hotelCard(travel: travel)
                    if let coord = hotelCoordinate {
                        hotelMap(coordinate: coord, name: memory.locationName ?? travel.hotelName ?? "Hotel")
                    }
                }
                if !memoryPings.isEmpty { remindersCard(travel: travel) }
            }
            .onAppear { geocodeLocations(travel: travel) }
            .sheet(isPresented: $showLocationSearch) {
                LocationSearchView(initialQuery: memory.locationName ?? travel.hotelName ?? "") { name, address, lat, lng in
                    memory.locationName = name
                    memory.locationAddress = address
                    memory.latitude = lat
                    memory.longitude = lng
                    hotelCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                }
            }
        }
    }

    // MARK: - Geocoding

    private func geocodeLocations(travel: TravelParseResult) {
        if travel.type == .hotel {
            if let lat = memory.latitude, let lng = memory.longitude {
                hotelCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                return
            }
            let query = [travel.hotelName, travel.hotelAddress].compactMap { $0 }.joined(separator: ", ")
            guard !query.isEmpty else { return }
            CLGeocoder().geocodeAddressString(query) { placemarks, _ in
                if let loc = placemarks?.first?.location {
                    DispatchQueue.main.async { hotelCoordinate = loc.coordinate }
                }
            }
        } else if travel.type == .flight {
            if let dep = travel.departureAirport, let depCoord = airportCoordinate(dep) {
                departureCoordinate = depCoord
            }
            if let arr = travel.arrivalAirport, let arrCoord = airportCoordinate(arr) {
                arrivalCoordinate = arrCoord
            }
        }
    }

    // MARK: - Hotel Map

    private func hotelMap(coordinate: CLLocationCoordinate2D, name: String) -> some View {
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Map(position: .constant(.region(region))) {
                    Marker(name, coordinate: coordinate)
                        .tint(Color(red: 0.847, green: 0.357, blue: 0.278))
                }
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(true)

                Button {
                    showLocationSearch = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .medium))
                        Text("Edit")
                            .font(.custom("DMSans-Medium", size: 12))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Capsule())
                }
                .padding(10)
            }
            .frame(height: 140)

            HStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 16)).foregroundColor(.coral)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.custom("DMSans-Medium", size: 14)).foregroundColor(.deepNavy)
                    if let address = memory.locationAddress ?? travel?.hotelAddress {
                        Text(address)
                            .font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                    }
                }
                Spacer()
                Button {
                    let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                    mapItem.name = name
                    mapItem.openInMaps()
                } label: {
                    Text("Directions")
                        .font(.custom("DMSans-Medium", size: 12)).foregroundColor(.oceanTeal)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.oceanTeal.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - Flight Route Map

    private func flightRouteMap(travel: TravelParseResult) -> some View {
        guard let depCoord = departureCoordinate,
              let arrCoord = arrivalCoordinate else { return AnyView(EmptyView()) }

        let centerLat = (depCoord.latitude + arrCoord.latitude) / 2
        let centerLng = (depCoord.longitude + arrCoord.longitude) / 2
        let spanLat = abs(depCoord.latitude - arrCoord.latitude) * 1.5 + 5
        let spanLng = abs(depCoord.longitude - arrCoord.longitude) * 1.5 + 5

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLng)
        )

        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                Map(position: .constant(.region(region))) {
                    Marker(travel.departureAirport ?? "DEP", coordinate: depCoord)
                        .tint(Color(red: 0.114, green: 0.620, blue: 0.459))
                    Marker(travel.arrivalAirport ?? "ARR", coordinate: arrCoord)
                        .tint(Color(red: 0.847, green: 0.357, blue: 0.278))
                    MapPolyline(coordinates: [depCoord, arrCoord])
                        .stroke(Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(true)

                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(Color(red: 0.114, green: 0.620, blue: 0.459)).frame(width: 8, height: 8)
                        Text(travel.departureAirport ?? "")
                            .font(.custom("DMSans-Medium", size: 13)).foregroundColor(.deepNavy)
                        Text(airportCity(travel.departureAirport))
                            .font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "airplane")
                        .font(.system(size: 12)).foregroundColor(.gray)
                    Spacer()
                    HStack(spacing: 6) {
                        Text(airportCity(travel.arrivalAirport))
                            .font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                        Text(travel.arrivalAirport ?? "")
                            .font(.custom("DMSans-Medium", size: 13)).foregroundColor(.deepNavy)
                        Circle().fill(Color(red: 0.847, green: 0.357, blue: 0.278)).frame(width: 8, height: 8)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
        )
    }

    // MARK: - Flight Card

    @ViewBuilder
    private func flightCard(travel: TravelParseResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                darkIcon(systemName: "airplane")
                VStack(alignment: .leading, spacing: 1) {
                    Text(travel.airline ?? "Flight").font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy)
                    if let fn = travel.flightNumber {
                        Text("Flight \(fn)").font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                    }
                }
                Spacer()
                if let conf = travel.confirmationCode { confirmationBadge(conf) }
            }
            .padding(16)

            Divider()

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(travel.departureAirport ?? "–").font(.custom("DMSans-Medium", size: 32)).foregroundColor(.deepNavy)
                    Text(airportCity(travel.departureAirport)).font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                    if let time = travel.departureTime {
                        Text(time).font(.custom("DMSans-Medium", size: 13)).foregroundColor(.deepNavy).padding(.top, 2)
                    }
                }
                VStack(spacing: 4) {
                    Spacer().frame(height: 6)
                    HStack(spacing: 0) {
                        Circle().stroke(Color.gray.opacity(0.4), lineWidth: 1.5).frame(width: 6, height: 6)
                        Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 0.5)
                        Image(systemName: "airplane").font(.system(size: 12)).foregroundColor(.gray)
                    }
                    Text("Nonstop").font(.custom("DMMono-Regular", size: 11)).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity).padding(.top, 4)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(travel.arrivalAirport ?? "–").font(.custom("DMSans-Medium", size: 32)).foregroundColor(.deepNavy)
                    Text(airportCity(travel.arrivalAirport)).font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)

            Divider()
            HStack(spacing: 4) {
                if let date = travel.departureDate {
                    Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year()))
                        .font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                }
                if let gate = travel.gateNumber {
                    Text("· Gate \(gate)").font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - Hotel Card

    @ViewBuilder
    private func hotelCard(travel: TravelParseResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                darkIcon(systemName: "building.2")
                VStack(alignment: .leading, spacing: 1) {
                    Text(memory.locationName ?? travel.hotelName ?? "Hotel").font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy)
                    if let address = memory.locationAddress ?? travel.hotelAddress {
                        Text(address).font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray).lineLimit(1)
                    } else {
                        Text("Hotel Reservation").font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                    }
                }
                Spacer()
                if let conf = travel.confirmationCode { confirmationBadge(conf) }
            }
            .padding(16)

            Divider()

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Check-in").font(.custom("DMSans-Regular", size: 11)).foregroundColor(.gray)
                    if let date = travel.checkInDate {
                        Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy)
                        Text(date.formatted(.dateTime.year()))
                            .font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.right").font(.system(size: 14)).foregroundColor(.gray.opacity(0.4))
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Check-out").font(.custom("DMSans-Regular", size: 11)).foregroundColor(.gray)
                    if let date = travel.checkOutDate {
                        Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy)
                        Text(date.formatted(.dateTime.year()))
                            .font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - Reminders Card

    @ViewBuilder
    private func remindersCard(travel: TravelParseResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("REMINDERS").font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).tracking(0.5)
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            ForEach(Array(memoryPings.enumerated()), id: \.element.id) { index, ping in
                if index > 0 { Divider().padding(.horizontal, 16) }
                HStack {
                    HStack(spacing: 10) {
                        Circle().fill(Color(red: 0.22, green: 0.55, blue: 0.87)).frame(width: 6, height: 6)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(pingLabel(ping: ping, travel: travel))
                                .font(.custom("DMSans-Regular", size: 14)).foregroundColor(.deepNavy)
                            Text(ping.fireDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                                .font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                        }
                    }
                    Spacer()
                    Text(pingSubLabel(ping: ping, travel: travel))
                        .font(.custom("DMSans-Regular", size: 11)).foregroundColor(.gray)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.mist).clipShape(Capsule())
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
            Spacer().frame(height: 6)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - Shared Helpers

    private func darkIcon(systemName: String) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(red: 0.1, green: 0.1, blue: 0.18)).frame(width: 32, height: 32)
            .overlay(Image(systemName: systemName).font(.system(size: 14)).foregroundColor(.white))
    }

    private func confirmationBadge(_ code: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text("Confirmation").font(.custom("DMSans-Regular", size: 11)).foregroundColor(.gray)
            Text(code).font(.system(.body, design: .monospaced)).fontWeight(.medium).foregroundColor(.deepNavy)
        }
    }

    private func pingLabel(ping: Ping, travel: TravelParseResult) -> String {
        guard let departure = travel.departureDate ?? travel.checkInDate else { return "Reminder" }
        let hours = Int(departure.timeIntervalSince(ping.fireDate) / 3600)
        if travel.type == .flight { return hours >= 20 ? "Check-in opens" : hours <= 4 ? "Head to airport" : "Reminder" }
        return hours >= 20 ? "Check-in tomorrow" : "Reminder"
    }

    private func pingSubLabel(ping: Ping, travel: TravelParseResult) -> String {
        guard let departure = travel.departureDate ?? travel.checkInDate else { return "" }
        let hours = Int(departure.timeIntervalSince(ping.fireDate) / 3600)
        if hours >= 20 { return "24h before" }
        if hours <= 4 { return "3h before" }
        return "\(hours)h before"
    }

    private func airportCoordinate(_ code: String?) -> CLLocationCoordinate2D? {
        guard let code = code else { return nil }
        let coords: [String: (Double, Double)] = [
            // Major US hubs
            "ATL": (33.6407, -84.4277), "LAX": (33.9425, -118.4081), "ORD": (41.9742, -87.9073),
            "DFW": (32.8998, -97.0403), "DEN": (39.8561, -104.6737), "JFK": (40.6413, -73.7781),
            "SFO": (37.6213, -122.3790), "SEA": (47.4502, -122.3088), "LAS": (36.0840, -115.1537),
            "MCO": (28.4312, -81.3081), "EWR": (40.6895, -74.1745), "CLT": (35.2140, -80.9431),
            "PHX": (33.4373, -112.0078), "IAH": (29.9902, -95.3368), "MIA": (25.7959, -80.2870),
            "BOS": (42.3656, -71.0096), "MSP": (44.8848, -93.2223), "FLL": (26.0726, -80.1527),
            "DTW": (42.2124, -83.3534), "PHL": (39.8721, -75.2411), "LGA": (40.7772, -73.8726),
            "BWI": (39.1754, -76.6682), "SLC": (40.7884, -111.9778), "SAN": (32.7338, -117.1933),
            "DCA": (38.8512, -77.0402), "IAD": (38.9531, -77.4565), "TPA": (27.9755, -82.5332),
            "PDX": (45.5898, -122.5951), "HNL": (21.3187, -157.9224), "AUS": (30.1975, -97.6664),
            "MDW": (41.7868, -87.7522), "BNA": (36.1263, -86.6774), "STL": (38.7487, -90.3700),
            "MKE": (42.9472, -87.8966), "OAK": (37.7213, -122.2208), "SJC": (37.3626, -121.9290),
            "RDU": (35.8776, -78.7875), "PIT": (40.4915, -80.2329), "CMH": (39.9980, -82.8919),
            // Florida regional
            "SRQ": (27.3954, -82.5544), "PBI": (26.6832, -80.0956), "PIE": (27.9102, -82.6874),
            "RSW": (26.5362, -81.7552), "OGG": (20.8986, -156.4305), "JAX": (30.4941, -81.6879),
            "TLH": (30.3965, -84.3503), "GNV": (29.6900, -82.2717), "DAB": (29.1799, -81.0581),
            // Northeast regional
            "PWM": (43.6462, -70.3093), "BTV": (44.4719, -73.1533), "ALB": (42.7483, -73.8017),
            "SYR": (43.1112, -76.1063), "ROC": (43.1189, -77.6724), "BUF": (42.9405, -78.7322),
            "PVD": (41.7272, -71.4281), "MHT": (42.9326, -71.4357),
            // Southeast regional
            "GSP": (34.8957, -82.2189), "CHS": (32.8986, -80.0405), "SAV": (32.1276, -81.2021),
            "PNS": (30.4734, -87.1866), "VPS": (30.4835, -86.5254), "MOB": (30.6912, -88.2428),
            "HSV": (34.6372, -86.7751), "BHM": (33.5629, -86.7535), "TYS": (35.8110, -83.9940),
            "GSO": (36.0978, -79.9373), "RIC": (37.5052, -77.3197), "ORF": (36.8976, -76.0132),
            "SHV": (32.4466, -93.8256), "LFT": (30.2053, -91.9876), "BTR": (30.5332, -91.1496),
            "GPT": (30.4073, -89.0701), "JAN": (32.3112, -90.0758),
            // Midwest regional
            "TUL": (36.1984, -95.8881), "OKC": (35.3931, -97.6007), "ICT": (37.6499, -97.4331),
            "DSM": (41.5340, -93.6631), "GRB": (44.4851, -88.1296), "CID": (41.8847, -91.7108),
            "FSD": (43.5820, -96.7419), "BIS": (46.7727, -100.7467), "FAR": (46.9207, -96.8158),
            // Mountain/West regional
            "ABQ": (35.0402, -106.6090), "ELP": (31.8072, -106.3779), "BOI": (43.5644, -116.2228),
            "GEG": (47.6199, -117.5339), "BZN": (45.7777, -111.1531), "MSO": (46.9163, -114.0906),
            "FCA": (48.3105, -114.2560), "JAC": (43.6073, -110.7377), "RNO": (39.4991, -119.7681),
            "FAT": (36.7762, -119.7182), "SBA": (34.4262, -119.8404), "MRY": (36.5870, -121.8428),
            "RDD": (40.5090, -122.2930), "ACV": (40.9781, -124.1087),
            // Canada
            "YYZ": (43.6777, -79.6248), "YVR": (49.1967, -123.1815), "YUL": (45.4706, -73.7408),
            "YYC": (51.1315, -114.0106), "YEG": (53.3097, -113.5797), "YOW": (45.3225, -75.6692),
            "YHZ": (44.8808, -63.5086), "YWG": (49.9100, -97.2398),
            // Mexico/Caribbean
            "CUN": (21.0365, -86.8771), "MEX": (19.4363, -99.0721), "GDL": (20.5218, -103.3110),
            "MTY": (25.7785, -100.1069), "SJD": (23.1518, -109.7210), "PVR": (20.6801, -105.2544),
            "MBJ": (18.5037, -77.9134), "NAS": (25.0390, -77.4662), "SJU": (18.4394, -66.0018),
            // Europe
            "LHR": (51.4700, -0.4543), "CDG": (49.0097, 2.5479), "AMS": (52.3105, 4.7683),
            "FRA": (50.0379, 8.5622), "MUC": (48.3537, 11.7750), "ZRH": (47.4647, 8.5492),
            "MAD": (40.4936, -3.5668), "BCN": (41.2971, 2.0785), "FCO": (41.8003, 12.2389),
            "LGW": (51.1537, -0.1821), "DUB": (53.4213, -6.2701), "CPH": (55.6180, 12.6508),
            "ARN": (59.6519, 17.9186), "OSL": (60.1976, 11.1004), "HEL": (60.3172, 24.9633),
            "VIE": (48.1103, 16.5697), "BRU": (50.9014, 4.4844), "LIS": (38.7756, -9.1354),
            "ATH": (37.9364, 23.9445), "IST": (41.2753, 28.7519), "MAN": (53.3537, -2.2750),
            "EDI": (55.9500, -3.3725), "WAW": (52.1657, 20.9671), "PRG": (50.1008, 14.2600),
            "BUD": (47.4298, 19.2611), "OTP": (44.5722, 26.1020),
            // Asia Pacific
            "DXB": (25.2532, 55.3657), "DOH": (25.2609, 51.6138), "AUH": (24.4330, 54.6511),
            "KWI": (29.2267, 47.9689), "RUH": (24.9578, 46.6989), "SIN": (1.3644, 103.9915),
            "HKG": (22.3080, 113.9185), "NRT": (35.7720, 140.3929), "ICN": (37.4602, 126.4407),
            "PEK": (40.0799, 116.6031), "PVG": (31.1443, 121.8083), "BKK": (13.6811, 100.7472),
            "KUL": (2.7456, 101.7099), "MNL": (14.5086, 121.0194), "CGK": (-6.1256, 106.6558),
            "SYD": (-33.9399, 151.1753), "MEL": (-37.6690, 144.8410),
            // Latin America
            "GRU": (-23.4356, -46.4731), "GIG": (-22.8100, -43.2506), "BSB": (-15.8711, -47.9186),
            "EZE": (-34.8222, -58.5358), "BOG": (4.7016, -74.1469), "LIM": (-12.0219, -77.1143),
            "SCL": (-33.3930, -70.7858), "GUA": (14.5833, -90.5275), "SAL": (13.4409, -89.0557),
        ]
        if let (lat, lng) = coords[code] {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        return nil
    }

    private func airportCity(_ code: String?) -> String {
        guard let code = code else { return "" }
        let cities: [String: String] = [
            // Major US hubs
            "ATL": "Atlanta", "LAX": "Los Angeles", "ORD": "Chicago", "DFW": "Dallas",
            "DEN": "Denver", "JFK": "New York", "SFO": "San Francisco", "SEA": "Seattle",
            "LAS": "Las Vegas", "MCO": "Orlando", "EWR": "Newark", "CLT": "Charlotte",
            "PHX": "Phoenix", "IAH": "Houston", "MIA": "Miami", "BOS": "Boston",
            "MSP": "Minneapolis", "FLL": "Fort Lauderdale", "DTW": "Detroit", "PHL": "Philadelphia",
            "LGA": "New York", "BWI": "Baltimore", "SLC": "Salt Lake City", "SAN": "San Diego",
            "DCA": "Washington", "IAD": "Washington", "TPA": "Tampa", "PDX": "Portland",
            "HNL": "Honolulu", "AUS": "Austin", "STL": "St. Louis", "BNA": "Nashville",
            "MDW": "Chicago", "OAK": "Oakland", "SJC": "San Jose", "RDU": "Raleigh",
            "PIT": "Pittsburgh", "CMH": "Columbus", "MCI": "Kansas City", "SMF": "Sacramento",
            "DAL": "Dallas", "MSY": "New Orleans", "CLE": "Cleveland", "CVG": "Cincinnati",
            "MEM": "Memphis", "IND": "Indianapolis", "SAT": "San Antonio",
            // Florida regional
            "SRQ": "Sarasota", "PBI": "Palm Beach", "PIE": "St. Petersburg",
            "RSW": "Fort Myers", "OGG": "Maui", "JAX": "Jacksonville",
            "TLH": "Tallahassee", "GNV": "Gainesville", "DAB": "Daytona Beach",
            // Northeast regional
            "PWM": "Portland ME", "BTV": "Burlington", "ALB": "Albany",
            "SYR": "Syracuse", "ROC": "Rochester", "BUF": "Buffalo",
            "PVD": "Providence", "MHT": "Manchester",
            // Southeast regional
            "GSP": "Greenville", "CHS": "Charleston", "SAV": "Savannah",
            "PNS": "Pensacola", "VPS": "Fort Walton", "MOB": "Mobile",
            "HSV": "Huntsville", "BHM": "Birmingham", "TYS": "Knoxville",
            "GSO": "Greensboro", "RIC": "Richmond", "ORF": "Norfolk",
            "SHV": "Shreveport", "LFT": "Lafayette", "BTR": "Baton Rouge",
            "GPT": "Gulfport", "JAN": "Jackson",
            // Midwest regional
            "TUL": "Tulsa", "OKC": "Oklahoma City", "ICT": "Wichita",
            "DSM": "Des Moines", "GRB": "Green Bay", "CID": "Cedar Rapids",
            "FSD": "Sioux Falls", "BIS": "Bismarck", "FAR": "Fargo",
            // Mountain/West regional
            "ABQ": "Albuquerque", "ELP": "El Paso", "BOI": "Boise",
            "GEG": "Spokane", "BZN": "Bozeman", "MSO": "Missoula",
            "FCA": "Kalispell", "JAC": "Jackson WY", "RNO": "Reno",
            "FAT": "Fresno", "SBA": "Santa Barbara", "MRY": "Monterey",
            "RDD": "Redding", "ACV": "Arcata",
            // Canada
            "YYZ": "Toronto", "YVR": "Vancouver", "YUL": "Montreal",
            "YYC": "Calgary", "YEG": "Edmonton", "YOW": "Ottawa",
            "YHZ": "Halifax", "YWG": "Winnipeg",
            // Mexico/Caribbean
            "CUN": "Cancun", "MEX": "Mexico City", "GDL": "Guadalajara",
            "MTY": "Monterrey", "SJD": "Los Cabos", "PVR": "Puerto Vallarta",
            "MBJ": "Montego Bay", "NAS": "Nassau", "SJU": "San Juan",
            // Europe
            "LHR": "London", "CDG": "Paris", "AMS": "Amsterdam", "FRA": "Frankfurt",
            "MUC": "Munich", "ZRH": "Zurich", "MAD": "Madrid", "BCN": "Barcelona",
            "FCO": "Rome", "LGW": "London", "DUB": "Dublin", "CPH": "Copenhagen",
            "ARN": "Stockholm", "OSL": "Oslo", "HEL": "Helsinki", "VIE": "Vienna",
            "BRU": "Brussels", "LIS": "Lisbon", "ATH": "Athens", "IST": "Istanbul",
            "MAN": "Manchester", "EDI": "Edinburgh", "WAW": "Warsaw", "PRG": "Prague",
            "BUD": "Budapest", "OTP": "Bucharest",
            // Asia Pacific
            "DXB": "Dubai", "DOH": "Doha", "AUH": "Abu Dhabi", "KWI": "Kuwait City",
            "RUH": "Riyadh", "SIN": "Singapore", "HKG": "Hong Kong", "NRT": "Tokyo",
            "ICN": "Seoul", "PEK": "Beijing", "PVG": "Shanghai", "BKK": "Bangkok",
            "KUL": "Kuala Lumpur", "MNL": "Manila", "CGK": "Jakarta",
            "SYD": "Sydney", "MEL": "Melbourne",
            // Latin America
            "GRU": "São Paulo", "GIG": "Rio de Janeiro", "BSB": "Brasilia",
            "EZE": "Buenos Aires", "BOG": "Bogota", "LIM": "Lima",
            "SCL": "Santiago", "GUA": "Guatemala City", "SAL": "San Salvador",
        ]
        return cities[code] ?? code
    }
}
