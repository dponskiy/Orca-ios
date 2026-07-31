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
    @State private var estimatedMinutes: Int? = nil

    @State private var pingEntries: [PingEntry] = []
    @State private var isFetchingRecipe = false
    @State private var recipeErrorMessage: String? = nil
    @State private var showRecipeSuccess = false

    // Expand states for inline pickers
    @State private var showDatePicker = false
    @State private var showTimePicker = false
    @State private var showEndDatePicker = false
    @State private var showDurationPicker = false
    @State private var expandedPingId: UUID? = nil

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

    var memoryPings: [Ping] { pings.filter { $0.memoryId == memory.id } }
    var memorySubTasks: [SubTask] {
        subTasks.filter { $0.memoryId == memory.id }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var isCookingEcho: Bool {
        echos.first { $0.id == selectedEchoId }?.name.lowercased().contains("cook") == true ||
        echos.first { $0.id == selectedEchoId }?.name.lowercased().contains("recipe") == true ||
        echos.first { $0.id == selectedEchoId }?.emoji == "🍳" ||
        echos.first { $0.id == selectedEchoId }?.emoji == "🍽️"
    }
    var isTravelEcho: Bool {
        echos.first { $0.id == selectedEchoId }?.name == "Travel"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // MARK: Memory text
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: $editedText)
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(.deepNavy)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 80, maxHeight: 160)

                        if audioEditService.isRecording && !audioEditService.transcription.isEmpty {
                            Text(audioEditService.transcription)
                                .font(.custom("DMSans-Regular", size: 13))
                                .foregroundColor(.oceanTeal)
                        }

                        HStack(spacing: 12) {
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
                                        Circle().fill(Color.coral).frame(width: 7, height: 7)
                                        Text("Stop").font(.custom("DMSans-Medium", size: 13)).foregroundColor(.coral)
                                    } else {
                                        Image(systemName: "mic.fill").font(.system(size: 12)).foregroundColor(.oceanTeal)
                                        Text("Re-record").font(.custom("DMSans-Medium", size: 13)).foregroundColor(.oceanTeal)
                                    }
                                }
                            }
                            .buttonStyle(.plain)

                            if showRerunSonar {
                                Spacer()
                                Button { rerunSonar() } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "waveform.badge.magnifyingglass").font(.system(size: 12))
                                        Text("Re-run Sonar").font(.custom("DMSans-Medium", size: 13))
                                    }
                                    .foregroundColor(.oceanTeal)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Memory")
                        .font(.custom("DMSans-Medium", size: 11))
                        .foregroundColor(.gray)
                        .textCase(nil)
                }

                // MARK: Echo
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(echos.filter { !$0.isSystemEcho }.sorted { e1, e2 in
                                if e1.id == selectedEchoId { return true }
                                if e2.id == selectedEchoId { return false }
                                return e1.sortOrder < e2.sortOrder
                            }) { echo in
                                Button { selectedEchoId = echo.id } label: {
                                    HStack(spacing: 4) {
                                        Text(echo.emoji).font(.system(size: 13))
                                        Text(echo.name)
                                            .font(.custom("DMSans-Medium", size: 12))
                                            .foregroundColor(selectedEchoId == echo.id ? .white : .deepNavy)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(selectedEchoId == echo.id ? Color.oceanTeal : Color.mist)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Echo")
                        .font(.custom("DMSans-Medium", size: 11))
                        .foregroundColor(.gray)
                        .textCase(nil)
                }

                // MARK: Details
                Section {
                    // Task toggle
                    Toggle(isOn: Binding(
                        get: { memory.isActionable },
                        set: { memory.isActionable = $0 }
                    )) {
                        Text("Task")
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(.deepNavy)
                    }
                    .tint(.oceanTeal)

                    // Pin toggle
                    Toggle(isOn: Binding(
                        get: { memory.isPinned },
                        set: { memory.isPinned = $0 }
                    )) {
                        Text("Pin to dashboard")
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(.deepNavy)
                    }
                    .tint(.coral)

                    // Date row
                    Toggle(isOn: $hasDate) {
                        Text("Date")
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(.deepNavy)
                    }
                    .tint(.oceanTeal)
                    .onChange(of: hasDate) { _, newValue in
                        if !newValue {
                            pingEntries.removeAll()
                            hasEndDate = false
                            showDatePicker = false
                            showTimePicker = false
                        }
                    }

                    if hasDate {
                        // Date value row — taps to expand
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showDatePicker.toggle()
                                showTimePicker = false
                            }
                        } label: {
                            HStack {
                                Text("Start date")
                                    .font(.custom("DMSans-Regular", size: 15))
                                    .foregroundColor(.deepNavy)
                                Spacer()
                                Text(selectedDate.map {
                                    $0.formatted(.dateTime.month(.abbreviated).day().year())
                                } ?? "None")
                                .font(.custom("DMSans-Regular", size: 15))
                                .foregroundColor(.oceanTeal)
                            }
                        }
                        .buttonStyle(.plain)

                        if showDatePicker {
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { selectedDate ?? Date() },
                                    set: { selectedDate = $0 }
                                ),
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.graphical)
                            .tint(.oceanTeal)
                        }

                        // Time row
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showTimePicker.toggle()
                                showDatePicker = false
                            }
                        } label: {
                            HStack {
                                Text("Time")
                                    .font(.custom("DMSans-Regular", size: 15))
                                    .foregroundColor(.deepNavy)
                                Spacer()
                                Text(selectedDate.map {
                                    $0.formatted(.dateTime.hour().minute())
                                } ?? "None")
                                .font(.custom("DMSans-Regular", size: 15))
                                .foregroundColor(.oceanTeal)
                            }
                        }
                        .buttonStyle(.plain)

                        if showTimePicker {
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { selectedDate ?? Date() },
                                    set: { selectedDate = $0 }
                                ),
                                displayedComponents: [.hourAndMinute]
                            )
                            .datePickerStyle(.wheel)
                            .tint(.oceanTeal)
                            .frame(maxWidth: .infinity)
                        }

                        // End date toggle
                        Toggle(isOn: $hasEndDate) {
                            Text("End date")
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
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showEndDatePicker.toggle()
                                }
                            } label: {
                                HStack {
                                    Text("End date")
                                        .font(.custom("DMSans-Regular", size: 15))
                                        .foregroundColor(.deepNavy)
                                    Spacer()
                                    Text(selectedEndDate.formatted(.dateTime.month(.abbreviated).day().year()))
                                        .font(.custom("DMSans-Regular", size: 15))
                                        .foregroundColor(.oceanTeal)
                                }
                            }
                            .buttonStyle(.plain)

                            if showEndDatePicker {
                                DatePicker(
                                    "",
                                    selection: $selectedEndDate,
                                    in: (selectedDate ?? Date())...,
                                    displayedComponents: [.date]
                                )
                                .datePickerStyle(.graphical)
                                .tint(.oceanTeal)
                            }
                        }
                    }

                    // Duration row
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showDurationPicker.toggle()
                        }
                    } label: {
                        HStack {
                            Text("Duration")
                                .font(.custom("DMSans-Regular", size: 15))
                                .foregroundColor(.deepNavy)
                            Spacer()
                            if let mins = estimatedMinutes, mins > 0 {
                                Text(DurationParser.shared.format(mins))
                                    .font(.custom("DMMono-Regular", size: 15))
                                    .foregroundColor(.oceanTeal)
                            } else {
                                Text("None")
                                    .font(.custom("DMSans-Regular", size: 15))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    if showDurationPicker {
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                VStack(spacing: 2) {
                                    Text("Hours")
                                        .font(.custom("DMSans-Regular", size: 12))
                                        .foregroundColor(.gray)
                                    Picker("Hours", selection: Binding(
                                        get: { (estimatedMinutes ?? 0) / 60 },
                                        set: { estimatedMinutes = ($0 * 60) + ((estimatedMinutes ?? 0) % 60) }
                                    )) {
                                        ForEach(0..<25, id: \.self) { h in Text("\(h)").tag(h) }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(height: 100)
                                }
                                Text("h")
                                    .font(.custom("DMSans-Medium", size: 16))
                                    .foregroundColor(.deepNavy)
                                    .padding(.top, 18)

                                VStack(spacing: 2) {
                                    Text("Minutes")
                                        .font(.custom("DMSans-Regular", size: 12))
                                        .foregroundColor(.gray)
                                    Picker("Minutes", selection: Binding(
                                        get: { ((estimatedMinutes ?? 0) % 60 / 5) * 5 },
                                        set: { estimatedMinutes = (((estimatedMinutes ?? 0) / 60) * 60) + $0 }
                                    )) {
                                        ForEach([0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55], id: \.self) { m in
                                            Text("\(m)").tag(m)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(height: 100)
                                }
                                Text("m")
                                    .font(.custom("DMSans-Medium", size: 16))
                                    .foregroundColor(.deepNavy)
                                    .padding(.top, 18)
                            }

                            if let mins = estimatedMinutes, mins > 0 {
                                Button {
                                    estimatedMinutes = nil
                                } label: {
                                    Text("Clear duration")
                                        .font(.custom("DMSans-Regular", size: 13))
                                        .foregroundColor(.gray)
                                }
                                .buttonStyle(.plain)
                                .padding(.bottom, 4)
                            }
                        }
                    }

                } header: {
                    Text("Details")
                        .font(.custom("DMSans-Medium", size: 11))
                        .foregroundColor(.gray)
                        .textCase(nil)
                }

                // MARK: Reminders
                if hasDate {
                    Section {
                        ForEach($pingEntries) { $entry in
                            pingRow(entry: $entry)
                        }

                        Button {
                            pingEntries.append(PingEntry())
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.oceanTeal)
                                Text("Add reminder")
                                    .font(.custom("DMSans-Regular", size: 15))
                                    .foregroundColor(.oceanTeal)
                            }
                        }
                        .buttonStyle(.plain)
                    } header: {
                        Text("Reminders")
                            .font(.custom("DMSans-Medium", size: 11))
                            .foregroundColor(.gray)
                            .textCase(nil)
                    }
                }

                // MARK: Link
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        TextField("Add a URL...", text: $editedURL)
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(.deepNavy)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                        if !editedURL.isEmpty || memory.url != nil {
                            Button {
                                editedURL = ""
                                memory.url = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !editedURL.isEmpty || memory.url != nil {
                        let activeURL = editedURL.isEmpty ? (memory.url ?? "") : editedURL
                        HStack(spacing: 12) {
                            if let url = URL(string: activeURL), UIApplication.shared.canOpenURL(url) {
                                Button {
                                    UIApplication.shared.open(url)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.up.right.square").font(.system(size: 12))
                                        Text("Open").font(.custom("DMSans-Medium", size: 13))
                                    }
                                    .foregroundColor(.oceanTeal)
                                }
                                .buttonStyle(.plain)
                            }

                            Button { fetchRecipe(url: activeURL) } label: {
                                HStack(spacing: 4) {
                                    if isFetchingRecipe {
                                        ProgressView().scaleEffect(0.7)
                                    } else {
                                        Image(systemName: showRecipeSuccess ? "checkmark" : "fork.knife")
                                            .font(.system(size: 12))
                                    }
                                    Text(isFetchingRecipe ? "Fetching..." : showRecipeSuccess ? "Imported!" : "Fetch Recipe")
                                        .font(.custom("DMSans-Medium", size: 13))
                                }
                                .foregroundColor(.oceanTeal)
                            }
                            .buttonStyle(.plain)
                            .disabled(isFetchingRecipe)
                        }

                        if let error = recipeErrorMessage {
                            Text(error)
                                .font(.custom("DMSans-Regular", size: 12))
                                .foregroundColor(.coral)
                        }
                    }
                } header: {
                    Text("Link")
                        .font(.custom("DMSans-Medium", size: 11))
                        .foregroundColor(.gray)
                        .textCase(nil)
                }

                // MARK: Location
                if !isTravelEcho {
                    Section {
                        locationRow
                    } header: {
                        Text("Location")
                            .font(.custom("DMSans-Medium", size: 11))
                            .foregroundColor(.gray)
                            .textCase(nil)
                    }
                }

                // MARK: Checklist
                if memory.hasChecklist || !memorySubTasks.isEmpty {
                    Section {
                        ForEach(memorySubTasks) { subTask in
                            HStack(spacing: 10) {
                                Button {
                                    withAnimation(.spring(duration: 0.2)) { subTask.isCompleted.toggle() }
                                } label: {
                                    if subTask.isCompleted {
                                        ZStack {
                                            Circle().fill(Color.oceanTeal).frame(width: 20, height: 20)
                                            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                                        }
                                    } else {
                                        Circle().stroke(Color.oceanTeal, lineWidth: 1.5).frame(width: 20, height: 20)
                                    }
                                }
                                .buttonStyle(.plain)

                                Text(subTask.text)
                                    .font(.custom("DMSans-Regular", size: 15))
                                    .foregroundColor(subTask.isCompleted ? .gray : .deepNavy)
                                    .strikethrough(subTask.isCompleted)

                                Spacer()

                                Button { modelContext.delete(subTask) } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray.opacity(0.4))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 16))
                                .foregroundColor(.oceanTeal)
                            TextField("Add item...", text: $newSubTaskText)
                                .font(.custom("DMSans-Regular", size: 15))
                                .foregroundColor(.deepNavy)
                                .onSubmit { addSubTask() }
                        }
                    } header: {
                        let completed = memorySubTasks.filter { $0.isCompleted }.count
                        let total = memorySubTasks.count
                        HStack {
                            Text("Checklist")
                                .font(.custom("DMSans-Medium", size: 11))
                                .foregroundColor(.gray)
                                .textCase(nil)
                            if total > 0 {
                                Spacer()
                                Text("\(completed)/\(total)")
                                    .font(.custom("DMMono-Regular", size: 11))
                                    .foregroundColor(.gray)
                                    .textCase(nil)
                            }
                        }
                    }
                }

                // MARK: Actions
                Section {
                    if !memory.hasChecklist && memorySubTasks.isEmpty {
                        Button {
                            convertToChecklist()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 14))
                                    .foregroundColor(.oceanTeal)
                                Text("Convert to checklist")
                                    .font(.custom("DMSans-Regular", size: 15))
                                    .foregroundColor(.oceanTeal)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Button(role: .destructive) {
                        let id = memory.id
                        for ping in memoryPings {
                            NotificationService.shared.cancelPing(pingId: ping.id)
                            modelContext.delete(ping)
                            Task { await SupabaseSyncService.shared.deletePing(id: ping.id) }
                        }
                        modelContext.delete(memory)
                        SpotlightService.shared.removeMemory(id: id)
                        SupabaseSyncService.shared.scheduleDelete(id: id)
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "trash").font(.system(size: 14))
                            Text("Delete memory").font(.custom("DMSans-Regular", size: 15))
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.visible)
            .background(Color.pearl)
            .navigationTitle("Edit memory")
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

    // MARK: - Ping Row

    @ViewBuilder
    private func pingRow(entry: Binding<PingEntry>) -> some View {
        let isExpanded = expandedPingId == entry.wrappedValue.id

        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedPingId = isExpanded ? nil : entry.wrappedValue.id
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.wrappedValue.leadTime.rawValue)
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(.deepNavy)
                        HStack(spacing: 6) {
                            Text(entry.wrappedValue.time, format: .dateTime.hour().minute())
                                .font(.custom("DMMono-Regular", size: 12))
                                .foregroundColor(.gray)
                            Text("·")
                                .foregroundColor(.gray)
                                .font(.system(size: 11))
                            Text(entry.wrappedValue.recurrence == .none ? "One time" : entry.wrappedValue.recurrence.rawValue.capitalized)
                                .font(.custom("DMMono-Regular", size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                    Spacer()
                    Button {
                        pingEntries.removeAll { $0.id == entry.wrappedValue.id }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider().padding(.top, 8)

                    // Lead time
                    Text("When")
                        .font(.custom("DMSans-Medium", size: 12))
                        .foregroundColor(.gray)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(PingLeadTime.allCases, id: \.self) { lead in
                                Button { entry.wrappedValue.leadTime = lead } label: {
                                    Text(lead.rawValue)
                                        .font(.custom("DMSans-Medium", size: 12))
                                        .foregroundColor(entry.wrappedValue.leadTime == lead ? .white : .deepNavy)
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(entry.wrappedValue.leadTime == lead ? Color.oceanTeal : Color.mist)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Time
                    DatePicker(
                        "Time",
                        selection: entry.time,
                        displayedComponents: .hourAndMinute
                    )
                    .font(.custom("DMSans-Regular", size: 14))
                    .tint(.oceanTeal)

                    // Recurrence
                    Text("Repeat")
                        .font(.custom("DMSans-Medium", size: 12))
                        .foregroundColor(.gray)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
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
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(entry.wrappedValue.recurrence == recurrence ? Color.oceanTeal : Color.mist)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Fire date preview
                    if let date = selectedDate {
                        let fireDate = Calendar.current.date(byAdding: .day, value: -entry.wrappedValue.leadTime.days, to: date) ?? date
                        HStack(spacing: 5) {
                            Image(systemName: "bell.fill").font(.system(size: 10)).foregroundColor(.oceanTeal)
                            Text("Fires \(fireDate.formatted(.dateTime.month(.abbreviated).day())) at \(entry.wrappedValue.time.formatted(.dateTime.hour().minute()))")
                                .font(.custom("DMMono-Regular", size: 11))
                                .foregroundColor(.gray)
                        }
                        .padding(7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.mist)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Location Row

    @ViewBuilder
    private var locationRow: some View {
        if let name = locationName, let lat = locationLat, let lng = locationLng {
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            let region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            )

            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    Map(position: .constant(.region(region))) {
                        Marker(name, coordinate: coordinate).tint(Color.coral)
                    }
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .disabled(true)
                    Color.clear.contentShape(Rectangle()).onTapGesture { showMapOptions = true }
                }
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

                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.custom("DMSans-Medium", size: 14))
                            .foregroundColor(.deepNavy)
                        if let address = locationAddress {
                            Text(address)
                                .font(.custom("DMSans-Regular", size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                    Spacer()
                    Button {
                        let textToCopy = [name, locationAddress].compactMap { $0 }.joined(separator: ", ")
                        UIPasteboard.general.string = textToCopy
                        withAnimation { addressCopied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { addressCopied = false }
                        }
                    } label: {
                        Image(systemName: addressCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 14))
                            .foregroundColor(addressCopied ? .seafoam : .gray)
                    }
                    .buttonStyle(.plain)

                    Button {
                        locationName = nil; locationAddress = nil
                        locationLat = nil; locationLng = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.gray.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }

                Button { showLocationSearch = true } label: {
                    Text("Change location")
                        .font(.custom("DMSans-Medium", size: 13))
                        .foregroundColor(.oceanTeal)
                }
                .buttonStyle(.plain)
            }
        } else {
            Button { showLocationSearch = true } label: {
                HStack {
                    Text("Add location")
                        .font(.custom("DMSans-Regular", size: 15))
                        .foregroundColor(.gray)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.4))
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Re-run Sonar

    private func rerunSonar() {
        let result = sonarEngine.process(text: editedText, echos: echos)
        if let echoId = result.echoId { selectedEchoId = echoId }
        if let detected = result.detectedDate { selectedDate = detected; hasDate = true }
        if let end = result.endDate { selectedEndDate = end; hasEndDate = true }
        estimatedMinutes = result.estimatedMinutes
        if let suggestion = result.pingSuggestions.first {
            var entry = PingEntry()
            entry.recurrence = suggestion.recurrence
            if let fireTime = suggestion.fireTime { entry.time = fireTime }
            if pingEntries.isEmpty {
                pingEntries.append(entry)
            } else {
                pingEntries[0].recurrence = suggestion.recurrence
                if let fireTime = suggestion.fireTime { pingEntries[0].time = fireTime }
            }
        }
        originalText = editedText
        showRerunSonar = false
    }

    // MARK: - Fetch Recipe

    private func fetchRecipe(url: String? = nil) {
        let urlToFetch = url ?? editedURL
        guard !urlToFetch.isEmpty else { return }
        recipeErrorMessage = nil
        showRecipeSuccess = false
        isFetchingRecipe = true
        Task {
            do {
                let recipe = try await RecipeExtractor.shared.extract(from: urlToFetch)
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
        estimatedMinutes = memory.estimatedMinutes
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
        if !editedURL.isEmpty { memory.url = editedURL }
        // URL is only cleared via the X button which sets memory.url = nil directly
        memory.estimatedMinutes = (estimatedMinutes ?? 0) > 0 ? estimatedMinutes : nil
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
                Task { await SupabaseSyncService.shared.deletePing(id: ping.id) }
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
