//
//  LocationSearchView.swift
//  Orca
//
//  Created by David Piliponskiy on 3/21/26.
//

import SwiftUI
import MapKit

struct LocationSearchView: View {
    let initialQuery: String
    var onSelect: (String, String?, Double, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search places...", text: $query)
                        .font(.custom("DMSans-Regular", size: 16))
                        .autocorrectionDisabled()
                        .onSubmit { runSearch() }
                        .onChange(of: query) { _, new in
                            if new.isEmpty { results = [] }
                            else { runSearch() }
                        }
                    if !query.isEmpty {
                        Button { query = ""; results = [] } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()

                if isSearching {
                    ProgressView().padding()
                    Spacer()
                } else if results.isEmpty && !query.isEmpty {
                    ContentUnavailableView("No results", systemImage: "mappin.slash")
                    Spacer()
                } else {
                    List(results, id: \.self) { item in
                        Button {
                            guard
                                let name = item.name,
                                let coord = item.placemark.location?.coordinate
                            else { return }
                            let address = item.formattedAddress
                            onSelect(name, address, coord.latitude, coord.longitude)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name ?? "Unknown")
                                    .font(.custom("DMSans-Medium", size: 15))
                                    .foregroundStyle(.primary)
                                if let address = item.formattedAddress {
                                    Text(address)
                                        .font(.custom("DMSans-Regular", size: 13))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.custom("DMSans-Regular", size: 16))
                }
            }
        }
        .onAppear {
            query = initialQuery
            if !query.isEmpty { runSearch() }
        }
    }

    private func runSearch() {
        isSearching = true
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = query
        MKLocalSearch(request: req).start { response, _ in
            isSearching = false
            results = response?.mapItems ?? []
        }
    }
}

private extension MKMapItem {
    var formattedAddress: String? {
        let p = placemark
        let streetParts = [p.subThoroughfare, p.thoroughfare]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let parts = [streetParts.isEmpty ? nil : streetParts, p.locality, p.administrativeArea]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        return parts.isEmpty ? nil : parts
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
