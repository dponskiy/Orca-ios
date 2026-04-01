//
//  MemoryEditView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI
import SwiftData
import MapKit

struct MemoryEditView: View {
    @Bindable var memory: Memory
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var echos: [Echo]
    @Query private var pings: [Ping]
    @Query private var subTasks: [SubTask]
    @Environment(AuthService.self) private var authService

    @State private var editedText: String = ""
    @State private var originalText: String = ""
    @State private var selectedEchoId: UUID = UUID()
    @State private var selectedDate: Date?
    @State private var hasDate: Bool = false
    @State private var hasEndDate: Bool = false
    @State private var selectedEndDate: Date = Date()
    @State private var editedURL: String = ""
    @State private var newSubTaskText: String = ""
    @State private var audioEditService = AudioEditService()
    @State private var showRerunSonar = false
    @State private var locationName: String? = nil
    @State private var locationAddress: String? = nil
    @State private var locationLat: Double? = nil
    @State private var locationLng: Double? = nil
    @State private var showLocationSearch = false
    @State private var showMapOptions = false
    @State private var addressCopied = false

    @State private var pingEntries: [PingEntry] = []
    @State private var isFetchingRecipe = false
    @State private var recipeErrorMessage: String? = nil
    @State private var showRecipeSuccess = false

    private let sonarEngine = SonarEngine()

    struct PingEntry: Identifiable {
        let id: UUID = UUID()
        var existingPingId: UUID? = nil
        var leadTime: PingLeadTime = .dayOf
        var time: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        var recurrence: Ping.Recurrence = .none
    }

    enum PingLeadTime: String, CaseIterable {
        case dayOf = "Day of"
        case dayBefore = "1 day before"
        case threeDays = "3 days before"
        case weekBefore = "1 week before"
        case twoWeeks = "2 weeks before"
        case monthBefore = "1 month before"

        var days: Int {
            switch self {
            case .dayOf: return 0
            case .dayBefore: return 1
            case .threeDays: return 3
            case .weekBefore: return 7
            case .twoWeeks: return 14
            case .monthBefore: return 30
            }
        }
    }

    var memoryPings: [Ping] {
        pings.filter { $0.memoryId == memory.id }
    }

    var memorySubTasks: [SubTask] {
        subTasks.filter { $0.memoryId == memory.id }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var isCookingEcho: Bool {
        echos.first { $0.id == selectedEchoId }?.name.lowercased().contains("cook") == true ||
        echos.first { $0.id == selectedEchoId }?.name.lowercased().contains("recipe") == true ||
        echos.first { $0.id == selectedEchoId }?.emoji == "🍳" ||
        echos.first { $0.id == selectedEchoId }?.emoji == "🍽️"
    }

    var isDiningOrEvents: Bool {
        let name = echos.first { $0.id == selectedEchoId }?.name ?? ""
        return name == "Dining" || name == "Events"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    textSection

                    if showRerunSonar {
                        Button { rerunSonar() } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "waveform.badge.magnifyingglass")
                                    .font(.system(size: 14))
                                Text("Re-run Sonar")
                                    .font(.custom("DMSans-Medium", size: 14))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.oceanTeal)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    echoSection

                    if memory.hasChecklist || !memorySubTasks.isEmpty {
                        checklistSection
                    }

                    urlSection
                    locationSection

                    Toggle(isOn: Binding(
                        get: { memory.isPinned },
                        set: { memory.isPinned = $0 }
                    )) {
                        HStack(spacing: 6) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.coral)
                            Text("Pin to Dashboard")
                                .font(.custom("DMSans-Regular", size: 15))
                                .foregroundColor(.deepNavy)
                        }
                    }
                    .tint(.coral)

                    Toggle(isOn: Binding(
                        get: { memory.isActionable },
                        set: { memory.isActionable = $0 }
                    )) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 14))
                                .foregroundColor(.oceanTeal)
                            Text("Mark as Task")
                                .font(.custom("DMSans-Regular", size: 15))
                                .foregroundColor(.deepNavy)
                        }
                    }
                    .tint(.oceanTeal)

                    dateSection

                    if hasDate {
                        pingSection
                    }

                    if !memory.hasChecklist && memorySubTasks.isEmpty {
                        Button { convertToChecklist() } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 14))
                                    .foregroundColor(.oceanTeal)
                                Text("Convert to Checklist")
                                    .font(.custom("DMSans-Medium", size: 14))
                                    .foregroundColor(.oceanTeal)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.oceanTeal.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    Button(role: .destructive) {
                        let id = memory.id
                        for ping in memoryPings {
                            NotificationService.shared.cancelPing(pingId: ping.id)
                            modelContext.delete(ping)
                        }
                        modelContext.delete(memory)
                        SpotlightService.shared.removeMemory(id: id)
                        Task { await SupabaseSyncService.shared.deleteMemory(id: id) }
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash").font(.system(size: 14))
                            Text("Delete Memory").font(.custom("DMSans-Medium", size: 14))
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(20)
            }
            .background(Color.white)
            .navigationTitle("Edit Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if audioEditService.isRecording { audioEditService.stopRecording() }
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if audioEditService.isRecording { audioEditService.stopRecording() }
                        saveEdits()
                        dismiss()
                    }
                    .font(.custom("DMSans-Medium", size: 16))
                    .foregroundColor(.oceanTeal)
                }
            }
            .onAppear { loadState() }
            .onChange(of: editedText) { _, newValue in
                showRerunSonar = newValue != originalText
            }
            .sheet(isPresented: $showLocationSearch) {
                LocationSearchView(initialQuery: locationName ?? "") { name, address, lat, lng in
                    locationName = name
                    locationAddress = address
                    locationLat = lat
                    locationLng = lng
                }
            }
        }
    }

    // MARK: - Text Section
    private var textSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Memory")
                    .font(.custom("DMSans-Medium", size: 14))
                    .foregroundColor(.gray)
                Spacer()
                Button {
                    if audioEditService.isRecording {
                        audioEditService.stopRecording()
                        if !audioEditService.transcription.isEmpty {
                            editedText = audioEditService.transcription
                        }
                    } else {
                        audioEditService.startRecording()
                    }
                } label: {
                    HStack(spacing: 4) {
                        if audioEditService.isRecording {
                            Circle().fill(Color.coral).frame(width: 8, height: 8)
                            Text("Stop").font(.custom("DMSans-Medium", size: 13)).foregroundColor(.coral)
                        } else {
                            Image(systemName: "mic.fill").font(.system(size: 13)).foregroundColor(.oceanTeal)
                            Text("Re-record").font(.custom("DMSans-Medium", size: 13)).foregroundColor(.oceanTeal)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(audioEditService.isRecording ? Color.coral.opacity(0.1) : Color.oceanTeal.opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            if audioEditService.isRecording && !audioEditService.transcription.isEmpty {
                Text(audioEditService.transcription)
                    .font(.custom("DMSans-Regular", size: 14))
                    .foregroundColor(.oceanTeal.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.oceanTeal.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            TextEditor(text: $editedText)
                .font(.custom("DMSans-Regular", size: 16))
                .foregroundColor(.deepNavy)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100, maxHeight: 200)
                .padding(12)
                .background(Color.pearl)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.oceanTeal.opacity(0.3), lineWidth: 1))
        }
    }

    // MARK: - Echo Section
    private var echoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Echo").font(.custom("DMSans-Medium", size: 14)).foregroundColor(.gray)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(echos.sorted { e1, e2 in
                        if e1.id == selectedEchoId { return true }
                        if e2.id == selectedEchoId { return false }
                        return e1.sortOrder < e2.sortOrder
                    }) { echo in
                        Button { selectedEchoId = echo.id } label: {
                            HStack(spacing: 4) {
                                Text(echo.emoji).font(.system(size: 14))
                                Text(echo.name)
                                    .font(.custom("DMSans-Medium", size: 13))
                                    .foregroundColor(selectedEchoId == echo.id ? .white : .deepNavy)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedEchoId == echo.id ? Color.oceanTeal : Color.mist)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    // MARK: - Checklist Section
    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Checklist").font(.custom("DMSans-Medium", size: 14)).foregroundColor(.gray)
                Spacer()
                let completed = memorySubTasks.filter { $0.isCompleted }.count
                let total = memorySubTasks.count
                if total > 0 {
                    Text("\(completed)/\(total)").font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                }
            }

            ForEach(memorySubTasks) { subTask in
                HStack(spacing: 10) {
                    Button {
                        withAnimation(.spring(duration: 0.2)) { subTask.isCompleted.toggle() }
                    } label: {
                        if subTask.isCompleted {
                            ZStack {
                                Circle().fill(Color.oceanTeal).frame(width: 22, height: 22)
                                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                            }
                        } else {
                            Circle().stroke(Color.oceanTeal, lineWidth: 1.5).frame(width: 22, height: 22)
                        }
                    }
                    Text(subTask.text)
                        .font(.custom("DMSans-Regular", size: 15))
                        .foregroundColor(subTask.isCompleted ? .gray : .deepNavy)
                        .strikethrough(subTask.isCompleted)
                    Spacer()
                    Button { modelContext.delete(subTask) } label: {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .medium)).foregroundColor(.gray.opacity(0.5))
                    }
                }
                .padding(.vertical, 4)
            }

            HStack(spacing: 10) {
                Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1.5).frame(width: 22, height: 22)
                TextField("Add item...", text: $newSubTaskText)
                    .font(.custom("DMSans-Regular", size: 15))
                    .foregroundColor(.deepNavy)
                    .onSubmit { addSubTask() }
                if !newSubTaskText.isEmpty {
                    Button { addSubTask() } label: {
                        Image(systemName: "plus.circle.fill").font(.system(size: 20)).foregroundColor(.oceanTeal)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .padding(16)
        .background(Color.pearl)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - URL Section
    private var urlSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Link").font(.custom("DMSans-Medium", size: 14)).foregroundColor(.gray)
            HStack(spacing: 8) {
                Image(systemName: "link").font(.system(size: 14)).foregroundColor(.gray)
                TextField("Add a URL...", text: $editedURL)
                    .font(.custom("DMSans-Regular", size: 15))
                    .foregroundColor(.deepNavy)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            }
            .padding(12)
            .background(Color.pearl)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.oceanTeal.opacity(0.3), lineWidth: 1))

            if !editedURL.isEmpty {
                HStack(spacing: 10) {
                    if let url = URL(string: editedURL), UIApplication.shared.canOpenURL(url) {
                        Button { UIApplication.shared.open(url) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.right.square").font(.system(size: 13))
                                Text("Open Link").font(.custom("DMSans-Medium", size: 13))
                            }
                            .foregroundColor(.oceanTeal)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color.oceanTeal.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                    Button { fetchRecipe() } label: {
                        HStack(spacing: 6) {
                            if isFetchingRecipe {
                                ProgressView().scaleEffect(0.75).tint(isCookingEcho ? .white : .oceanTeal)
                            } else {
                                Image(systemName: showRecipeSuccess ? "checkmark" : "fork.knife").font(.system(size: 13))
                            }
                            Text(isFetchingRecipe ? "Fetching..." : showRecipeSuccess ? "Imported!" : "Fetch Recipe")
                                .font(.custom("DMSans-Medium", size: 13))
                        }
                        .foregroundColor(isCookingEcho ? .white : .oceanTeal)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(isCookingEcho ? Color.oceanTeal : Color.oceanTeal.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .disabled(isFetchingRecipe)
                }
                if let error = recipeErrorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle").font(.system(size: 12)).foregroundColor(.coral)
                        Text(error).font(.custom("DMSans-Regular", size: 12)).foregroundColor(.coral)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    // MARK: - Location Section
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location").font(.custom("DMSans-Medium", size: 14)).foregroundColor(.gray)

            if let name = locationName,
               let lat = locationLat,
               let lng = locationLng {
                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                let region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                )

                // Mini map — tap opens Maps
                ZStack {
                    Map(position: .constant(.region(region))) {
                        Marker(name, coordinate: coordinate)
                            .tint(Color.coral)
                    }
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(true)

                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { showMapOptions = true }
                }
                .frame(height: 140)
                .confirmationDialog("Open in Maps", isPresented: $showMapOptions, titleVisibility: .hidden) {
                    Button("Apple Maps") {
                        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
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

                // Name + address + copy
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.coral)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.custom("DMSans-Medium", size: 15))
                            .foregroundColor(.deepNavy)
                        if let address = locationAddress {
                            Text(address)
                                .font(.custom("DMSans-Regular", size: 13))
                                .foregroundColor(.gray)
                        }
                    }

                    Spacer()

                    // Copy button
                    Button {
                        let textToCopy = [name, locationAddress]
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

                    // Clear button
                    Button {
                        locationName = nil
                        locationAddress = nil
                        locationLat = nil
                        locationLng = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.gray.opacity(0.4))
                    }
                }
                .padding(12)
                .background(Color.pearl)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Open in Maps + Change Location row
                HStack(spacing: 12) {
                    Button { showMapOptions = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "map").font(.system(size: 13))
                            Text("Open in Maps").font(.custom("DMSans-Medium", size: 13))
                        }
                        .foregroundColor(.oceanTeal)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.oceanTeal.opacity(0.1))
                        .clipShape(Capsule())
                    }

                    Button { showLocationSearch = true } label: {
                        Text("Change Location")
                            .font(.custom("DMSans-Medium", size: 13))
                            .foregroundColor(.gray)
                    }
                }

            } else {
                Button {
                    showLocationSearch = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        Text("Add Location")
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(.gray)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.4))
                    }
                    .padding(12)
                    .background(Color.pearl)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.oceanTeal.opacity(0.3), lineWidth: 1))
                }
            }
        }
    }
    // MARK: - Date Section
    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date").font(.custom("DMSans-Medium", size: 14)).foregroundColor(.gray)
            Toggle(isOn: $hasDate) {
                Text("Associated date").font(.custom("DMSans-Regular", size: 15)).foregroundColor(.deepNavy)
            }
            .tint(.oceanTeal)
            .onChange(of: hasDate) { _, newValue in
                if !newValue {
                    pingEntries.removeAll()
                    hasEndDate = false
                }
            }
            if hasDate {
                DatePicker(
                    "Start Date",
                    selection: Binding(get: { selectedDate ?? Date() }, set: { selectedDate = $0 }),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .tint(.oceanTeal)

                Toggle(isOn: $hasEndDate) {
                    Text("Has end date (date range)")
                        .font(.custom("DMSans-Regular", size: 15))
                        .foregroundColor(.deepNavy)
                }
                .tint(.oceanTeal)
                .onChange(of: hasEndDate) { _, newValue in
                    if newValue && selectedEndDate <= (selectedDate ?? Date()) {
                        selectedEndDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate ?? Date()) ?? Date()
                    }
                }

                if hasEndDate {
                    DatePicker(
                        "End Date",
                        selection: $selectedEndDate,
                        in: (selectedDate ?? Date())...,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)
                    .tint(.oceanTeal)
                }
            }
        }
    }

    // MARK: - Ping Section
    private var pingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Pings (Reminders)")
                    .font(.custom("DMSans-Medium", size: 14))
                    .foregroundColor(.gray)
                Spacer()
                Button {
                    pingEntries.append(PingEntry())
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 12, weight: .semibold))
                        Text("Add Ping").font(.custom("DMSans-Medium", size: 13))
                    }
                    .foregroundColor(.oceanTeal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.oceanTeal.opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            if pingEntries.isEmpty {
                Button {
                    pingEntries.append(PingEntry())
                } label: {
                    HStack(spacing: 6) {
                        Text("🔔").font(.system(size: 16))
                        Text("Add a reminder")
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(.deepNavy)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                    .padding(14)
                    .background(Color.pearl)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            } else {
                ForEach($pingEntries) { $entry in
                    pingEntryRow(entry: $entry)
                }
            }
        }
        .padding(16)
        .background(Color.pearl)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func pingEntryRow(entry: Binding<PingEntry>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("🔔 Reminder \(pingEntries.firstIndex(where: { $0.id == entry.id }).map { $0 + 1 } ?? 1)")
                    .font(.custom("DMSans-Medium", size: 13))
                    .foregroundColor(.deepNavy)
                Spacer()
                Button {
                    pingEntries.removeAll { $0.id == entry.id }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.gray.opacity(0.4))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PingLeadTime.allCases, id: \.self) { lead in
                        Button { entry.wrappedValue.leadTime = lead } label: {
                            Text(lead.rawValue)
                                .font(.custom("DMSans-Medium", size: 12))
                                .foregroundColor(entry.wrappedValue.leadTime == lead ? .white : .deepNavy)
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(entry.wrappedValue.leadTime == lead ? Color.oceanTeal : Color.mist)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            DatePicker("Time", selection: entry.time, displayedComponents: .hourAndMinute)
                .font(.custom("DMSans-Regular", size: 14))
                .tint(.oceanTeal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([
                        (Ping.Recurrence.none, "One time"),
                        (Ping.Recurrence.daily, "Daily"),
                        (Ping.Recurrence.weekly, "Weekly"),
                        (Ping.Recurrence.monthly, "Monthly"),
                        (Ping.Recurrence.yearly, "Yearly"),
                    ], id: \.0) { recurrence, label in
                        Button { entry.wrappedValue.recurrence = recurrence } label: {
                            Text(label)
                                .font(.custom("DMSans-Medium", size: 12))
                                .foregroundColor(entry.wrappedValue.recurrence == recurrence ? .white : .deepNavy)
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(entry.wrappedValue.recurrence == recurrence ? Color.oceanTeal : Color.mist)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            if let date = selectedDate {
                let fireDate = Calendar.current.date(byAdding: .day, value: -entry.wrappedValue.leadTime.days, to: date) ?? date
                HStack(spacing: 6) {
                    Image(systemName: "bell.fill").font(.system(size: 11)).foregroundColor(.oceanTeal)
                    Text("Will fire: \(fireDate, format: .dateTime.month(.abbreviated).day()) at \(entry.wrappedValue.time, format: .dateTime.hour().minute())")
                        .font(.custom("DMMono-Regular", size: 12))
                        .foregroundColor(.deepNavy)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.mist)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.oceanTeal.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Re-run Sonar
    private func rerunSonar() {
        let result = sonarEngine.process(text: editedText, echos: echos)
        if let echoId = result.echoId { selectedEchoId = echoId }
        if let detected = result.detectedDate { selectedDate = detected; hasDate = true }
        if let end = result.endDate {
            selectedEndDate = end
            hasEndDate = true
        }
        if let suggestion = result.pingSuggestions.first {
            var entry = PingEntry()
            entry.recurrence = suggestion.recurrence
            if let fireTime = suggestion.fireTime { entry.time = fireTime }
            if pingEntries.isEmpty { pingEntries.append(entry) }
        }
        originalText = editedText
        showRerunSonar = false
    }

    // MARK: - Fetch Recipe
    private func fetchRecipe() {
        guard !editedURL.isEmpty else { return }
        recipeErrorMessage = nil
        showRecipeSuccess = false
        isFetchingRecipe = true
        Task {
            do {
                let recipe = try await RecipeExtractor.shared.extract(from: editedURL)
                await MainActor.run {
                    populateFromRecipe(recipe)
                    isFetchingRecipe = false
                    showRecipeSuccess = true
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        showRecipeSuccess = false
                    }
                }
            } catch {
                await MainActor.run {
                    isFetchingRecipe = false
                    recipeErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func populateFromRecipe(_ recipe: RecipeResult) {
        var parts: [String] = []
        parts.append("🍽 \(recipe.title)")
        var meta: [String] = []
        if let prep = recipe.prepTime { meta.append("Prep: \(prep)") }
        if let cook = recipe.cookTime { meta.append("Cook: \(cook)") }
        if let srv = recipe.servings { meta.append("Serves: \(srv)") }
        if !meta.isEmpty { parts.append(meta.joined(separator: " · ")) }
        if !recipe.instructions.isEmpty {
            parts.append("\nInstructions:")
            for (i, step) in recipe.instructions.enumerated() { parts.append("\(i + 1). \(step)") }
        }
        editedText = parts.joined(separator: "\n")
        for subTask in memorySubTasks { modelContext.delete(subTask) }
        if !recipe.ingredients.isEmpty {
            memory.hasChecklist = true
            for (index, ingredient) in recipe.ingredients.enumerated() {
                let subTask = SubTask(memoryId: memory.id, text: ingredient, sortOrder: index)
                modelContext.insert(subTask)
            }
        }
        if !isCookingEcho {
            if let cookingEcho = echos.first(where: {
                $0.name.lowercased().contains("cook") || $0.name.lowercased().contains("recipe") ||
                $0.emoji == "🍳" || $0.emoji == "🍽️"
            }) { selectedEchoId = cookingEcho.id }
        }
    }

    // MARK: - Helpers
    private func addSubTask() {
        guard !newSubTaskText.isEmpty else { return }
        let nextOrder = (memorySubTasks.last?.sortOrder ?? -1) + 1
        let subTask = SubTask(memoryId: memory.id, text: newSubTaskText, sortOrder: nextOrder)
        modelContext.insert(subTask)
        memory.hasChecklist = true
        newSubTaskText = ""
    }

    private func convertToChecklist() {
        let lines = editedText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if lines.count >= 2 {
            for (index, line) in lines.enumerated() {
                let subTask = SubTask(memoryId: memory.id, text: line, sortOrder: index)
                modelContext.insert(subTask)
            }
            memory.hasChecklist = true
        } else {
            let subTask = SubTask(memoryId: memory.id, text: "", sortOrder: 0)
            modelContext.insert(subTask)
            memory.hasChecklist = true
        }
    }

    // MARK: - Load / Save
    private func loadState() {
        editedText = memory.text
        originalText = memory.text
        selectedEchoId = memory.echoId
        selectedDate = memory.detectedDate
        hasDate = memory.detectedDate != nil
        if let end = memory.endDate {
            selectedEndDate = end
            hasEndDate = true
        }
        editedURL = memory.url ?? ""
        locationName = memory.locationName
        locationAddress = memory.locationAddress
        locationLat = memory.latitude
        locationLng = memory.longitude

        pingEntries = memoryPings.map { ping in
            var entry = PingEntry()
            entry.existingPingId = ping.id
            entry.time = ping.fireTime
            entry.recurrence = ping.recurrence
            if let memDate = memory.detectedDate {
                let daysDiff = Calendar.current.dateComponents([.day], from: ping.fireDate, to: memDate).day ?? 0
                entry.leadTime = PingLeadTime.allCases.first { $0.days == daysDiff } ?? .dayOf
            }
            return entry
        }
    }

    private func saveEdits() {
        memory.text = editedText
        memory.echoId = selectedEchoId
        memory.detectedDate = hasDate ? selectedDate : nil
        memory.endDate = (hasDate && hasEndDate) ? selectedEndDate : nil
        memory.wasEdited = true
        memory.updatedAt = Date()
        memory.url = editedURL.isEmpty ? nil : editedURL
        memory.locationName = locationName
        memory.locationAddress = locationAddress
        memory.latitude = locationLat
        memory.longitude = locationLng

        if memory.hasChecklist && !memorySubTasks.isEmpty {
            let allDone = memorySubTasks.allSatisfy { $0.isCompleted }
            if allDone { memory.isCompleted = true; memory.completedAt = Date() }
        }

        let keptIds = Set(pingEntries.compactMap { $0.existingPingId })
        for ping in memoryPings {
            if !keptIds.contains(ping.id) {
                NotificationService.shared.cancelPing(pingId: ping.id)
                modelContext.delete(ping)
            }
        }

        guard hasDate, let date = selectedDate else { return }

        for entry in pingEntries {
            let fireDate = Calendar.current.date(byAdding: .day, value: -entry.leadTime.days, to: date) ?? date
            let calendar = Calendar.current
            let timeComponents = calendar.dateComponents([.hour, .minute], from: entry.time)
            let finalFireDate = calendar.date(
                bySettingHour: timeComponents.hour ?? 9,
                minute: timeComponents.minute ?? 0,
                second: 0,
                of: fireDate
            ) ?? fireDate

            if let existingId = entry.existingPingId,
               let existing = memoryPings.first(where: { $0.id == existingId }) {
                existing.fireDate = finalFireDate
                existing.fireTime = entry.time
                existing.recurrence = entry.recurrence
                existing.isActive = true
                NotificationService.shared.schedulePing(ping: existing, memoryText: editedText)
            } else {
                let ping = Ping(memoryId: memory.id, fireDate: finalFireDate, recurrence: entry.recurrence)
                ping.fireTime = entry.time
                modelContext.insert(ping)
                NotificationService.shared.schedulePing(ping: ping, memoryText: editedText)
            }
        }
    }
}
