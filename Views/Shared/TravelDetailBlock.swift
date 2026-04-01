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
    let memory: Memory
    @Query private var pings: [Ping]

    @State private var hotelCoordinate: CLLocationCoordinate2D? = nil
    @State private var departureCoordinate: CLLocationCoordinate2D? = nil
    @State private var arrivalCoordinate: CLLocationCoordinate2D? = nil

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
                        hotelMap(coordinate: coord, name: travel.hotelName ?? "Hotel")
                    }
                }
                if !memoryPings.isEmpty { remindersCard(travel: travel) }
            }
            .onAppear { geocodeLocations(travel: travel) }
        }
    }

    // MARK: - Geocoding

    private func geocodeLocations(travel: TravelParseResult) {
        if travel.type == .hotel {
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
            ZStack {
                Map(position: .constant(.region(region))) {
                    Marker(name, coordinate: coordinate)
                        .tint(Color(red: 0.847, green: 0.357, blue: 0.278))
                } // ← closes Map content
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(true)

                Color.clear.contentShape(Rectangle())
                    .onTapGesture {
                        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                        mapItem.name = name
                        mapItem.openInMaps()
                    }
            } // ← closes ZStack
            .frame(height: 140)

            HStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 16)).foregroundColor(.coral)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.custom("DMSans-Medium", size: 14)).foregroundColor(.deepNavy)
                    if let address = travel?.hotelAddress {
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
        } // ← closes VStack
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
                    Text(travel.hotelName ?? "Hotel").font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy)
                    if let address = travel.hotelAddress {
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
            "LHR": (51.4700, -0.4543), "CDG": (49.0097, 2.5479), "AMS": (52.3105, 4.7683),
            "FRA": (50.0379, 8.5622), "DXB": (25.2532, 55.3657), "SIN": (1.3644, 103.9915),
            "HKG": (22.3080, 113.9185), "NRT": (35.7720, 140.3929), "ICN": (37.4602, 126.4407),
            "SYD": (-33.9399, 151.1753), "YYZ": (43.6777, -79.6248), "YVR": (49.1967, -123.1815),
            "MDW": (41.7868, -87.7522), "BNA": (36.1263, -86.6774), "STL": (38.7487, -90.3700),
            "MKE": (42.9472, -87.8966), "OAK": (37.7213, -122.2208), "SJC": (37.3626, -121.9290),
            "RDU": (35.8776, -78.7875), "PIT": (40.4915, -80.2329), "CMH": (39.9980, -82.8919),
        ]
        if let (lat, lng) = coords[code] {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        return nil
    }

    private func airportCity(_ code: String?) -> String {
        guard let code = code else { return "" }
        let cities: [String: String] = [
            "ATL": "Atlanta", "LAX": "Los Angeles", "ORD": "Chicago", "DFW": "Dallas",
            "DEN": "Denver", "JFK": "New York", "SFO": "San Francisco", "SEA": "Seattle",
            "LAS": "Las Vegas", "MCO": "Orlando", "EWR": "Newark", "CLT": "Charlotte",
            "PHX": "Phoenix", "IAH": "Houston", "MIA": "Miami", "BOS": "Boston",
            "MSP": "Minneapolis", "FLL": "Fort Lauderdale", "DTW": "Detroit", "PHL": "Philadelphia",
            "LGA": "New York", "BWI": "Baltimore", "SLC": "Salt Lake City", "SAN": "San Diego",
            "DCA": "Washington", "IAD": "Washington", "TPA": "Tampa", "PDX": "Portland",
            "HNL": "Honolulu", "AUS": "Austin", "STL": "St. Louis", "BNA": "Nashville",
            "LHR": "London", "CDG": "Paris", "AMS": "Amsterdam", "FRA": "Frankfurt",
            "DXB": "Dubai", "SIN": "Singapore", "HKG": "Hong Kong", "NRT": "Tokyo",
            "ICN": "Seoul", "SYD": "Sydney", "YYZ": "Toronto", "YVR": "Vancouver",
        ]
        return cities[code] ?? code
    }
}
