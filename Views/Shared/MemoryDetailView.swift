//
//  MemoryDetailView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI
import SwiftData
import MapKit

struct MemoryDetailView: View {
    @Bindable var memory: Memory  // FIX: was `let` — now reactive to location saves
    @Query private var subTasks: [SubTask]
    @Query private var echos: [Echo]
    @Query private var pings: [Ping]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var editingMemory: Memory?
    @State private var showMapOptions = false
    @State private var addressCopied = false

    var memorySubTasks: [SubTask] {
        subTasks.filter { $0.memoryId == memory.id }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var echo: Echo? {
        echos.first { $0.id == memory.echoId }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Echo + date header
                    HStack(spacing: 8) {
                        if let echo = echo {
                            HStack(spacing: 4) {
                                Text(echo.emoji).font(.system(size: 14))
                                Text(echo.name)
                                    .font(.custom("DMSans-Medium", size: 13))
                                    .foregroundColor(.deepNavy)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.mist)
                            .clipShape(Capsule())
                        }

                        if let date = memory.detectedDate {
                            HStack(spacing: 4) {
                                Text("📅").font(.system(size: 13))
                                if let endDate = memory.endDate {
                                    Text("\(date.formatted(.dateTime.month(.abbreviated).day())) – \(endDate.formatted(.dateTime.month(.abbreviated).day()))")
                                        .font(.custom("DMMono-Regular", size: 12))
                                        .foregroundColor(.gray)
                                } else {
                                    Text(date, format: .dateTime.month(.abbreviated).day().year())
                                        .font(.custom("DMMono-Regular", size: 12))
                                        .foregroundColor(.gray)
                                }
                            }
                        }

                        Spacer()

                        if memory.wasEdited {
                            Text("edited")
                                .font(.custom("DMMono-Regular", size: 11))
                                .foregroundColor(.seafoam)
                        }
                    }

                    // Memory text
                    Text(memory.text)
                        .font(.custom("DMSans-Regular", size: 16))
                        .foregroundColor(.deepNavy)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Link
                    if let url = memory.url, !url.isEmpty, let link = URL(string: url) {
                        Button {
                            UIApplication.shared.open(link)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 13))
                                Text("Open Link")
                                    .font(.custom("DMSans-Medium", size: 13))
                            }
                            .foregroundColor(.oceanTeal)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.oceanTeal.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }

                    // Location block
                    if let name = memory.locationName,
                       let lat = memory.latitude,
                       let lng = memory.longitude {
                        locationBlock(name: name, lat: lat, lng: lng)
                    }

                    // Checklist / Ingredients
                    if !memorySubTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(echo?.name.lowercased().contains("cook") == true ? "INGREDIENTS" : "CHECKLIST")
                                    .font(.custom("DMSans-Medium", size: 13))
                                    .foregroundColor(.oceanTeal)
                                    .tracking(1)
                                Spacer()
                                let completed = memorySubTasks.filter { $0.isCompleted }.count
                                Text("\(completed)/\(memorySubTasks.count)")
                                    .font(.custom("DMMono-Regular", size: 12))
                                    .foregroundColor(.gray)
                            }

                            VStack(spacing: 0) {
                                ForEach(memorySubTasks) { subTask in
                                    Button {
                                        withAnimation(.spring(duration: 0.2)) {
                                            subTask.isCompleted.toggle()
                                            memory.updatedAt = Date()
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            ZStack {
                                                Circle()
                                                    .stroke(Color.oceanTeal.opacity(0.4), lineWidth: 1.5)
                                                    .frame(width: 22, height: 22)
                                                if subTask.isCompleted {
                                                    Circle()
                                                        .fill(Color.oceanTeal)
                                                        .frame(width: 22, height: 22)
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundColor(.white)
                                                }
                                            }
                                            Text(subTask.text)
                                                .font(.custom("DMSans-Regular", size: 15))
                                                .foregroundColor(subTask.isCompleted ? .gray : .deepNavy)
                                                .strikethrough(subTask.isCompleted)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                    }
                                    .buttonStyle(.plain)

                                    if subTask.id != memorySubTasks.last?.id {
                                        Divider().padding(.leading, 50)
                                    }
                                }
                            }
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                        }
                    }

                    // Pings
                    let memoryPings = pings.filter { $0.memoryId == memory.id && $0.isActive }
                    if !memoryPings.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("REMINDERS")
                                .font(.custom("DMSans-Medium", size: 13))
                                .foregroundColor(.oceanTeal)
                                .tracking(1)

                            ForEach(memoryPings) { ping in
                                HStack(spacing: 10) {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(.oceanTeal)
                                    Text(ping.fireDate, format: .dateTime.month(.abbreviated).day().hour().minute())
                                        .font(.custom("DMMono-Regular", size: 13))
                                        .foregroundColor(.deepNavy)
                                    if ping.recurrence != .none {
                                        Text("· \(ping.recurrence.rawValue.capitalized)")
                                            .font(.custom("DMMono-Regular", size: 12))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                            }
                        }
                    }

                    Spacer().frame(height: 40)
                }
                .padding(20)
            }
            .background(Color.pearl)
            .navigationTitle(echo?.name ?? "Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.oceanTeal)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { editingMemory = memory } label: {
                        Image(systemName: "pencil").foregroundColor(.oceanTeal)
                    }
                }
            }
            .sheet(item: $editingMemory) { memory in
                MemoryEditView(memory: memory)
            }
        }
    }

    // MARK: - Location Block
    @ViewBuilder
    private func locationBlock(name: String, lat: Double, lng: Double) -> some View {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )

        VStack(alignment: .leading, spacing: 10) {
            // Mini map
            ZStack {
                Map(position: .constant(.region(region))) {
                    Marker(name, coordinate: coordinate)
                        .tint(Color.coral)
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(true)

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { showMapOptions = true }
            }
            .frame(height: 160)

            // Place name + address + copy
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.coral)

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.custom("DMSans-Medium", size: 15))
                        .foregroundColor(.deepNavy)
                    if let address = memory.locationAddress {
                        Text(address)
                            .font(.custom("DMSans-Regular", size: 13))
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                // Copy button
                Button {
                    let textToCopy = [name, memory.locationAddress]
                        .compactMap { $0 }
                        .joined(separator: ", ")
                    UIPasteboard.general.string = textToCopy
                    withAnimation(.easeInOut(duration: 0.2)) { addressCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeInOut(duration: 0.2)) { addressCopied = false }
                    }
                } label: {
                    Image(systemName: addressCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 15))
                        .foregroundColor(addressCopied ? .seafoam : .gray)
                }
            }

            // Open in Maps
            Button { showMapOptions = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "map").font(.system(size: 13))
                    Text("Open in Maps").font(.custom("DMSans-Medium", size: 13))
                }
                .foregroundColor(.oceanTeal)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.oceanTeal.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .confirmationDialog("Open in Maps", isPresented: $showMapOptions, titleVisibility: .hidden) {
            Button("Apple Maps") {
                let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate, addressDictionary: nil))
                item.name = name
                item.openInMaps()
            }
            if UIApplication.shared.canOpenURL(URL(string: "comgooglemaps://")!) {
                Button("Google Maps") {
                    if let url = URL(string: "comgooglemaps://?q=\(lat),\(lng)&zoom=15") {
                        UIApplication.shared.open(url)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

#Preview {
    MemoryDetailView(memory: Memory(text: "🍽 Pasta\nInstructions:\n1. Boil water\n2. Cook pasta", echoId: UUID()))
        .modelContainer(for: [Memory.self, Echo.self, Ping.self, SubTask.self], inMemory: true)
}
