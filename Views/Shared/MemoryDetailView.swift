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
    @Bindable var memory: Memory
    @Query private var subTasks: [SubTask]
    @Query private var echos: [Echo]
    @Query private var pings: [Ping]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var editingMemory: Memory?
    @State private var showMapOptions = false
    @State private var addressCopied = false
    @State private var showReminders = true
    @State private var showInstructionEditor = false
    @State private var addedToCalendar = false
    @State private var showQuickLog = false

    var memorySubTasks: [SubTask] {
        subTasks.filter { $0.memoryId == memory.id }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var echo: Echo? { echos.first { $0.id == memory.echoId } }
    var isTravelEcho: Bool { echo?.name.lowercased() == "travel" }
    var isFinanceEcho: Bool { echo?.name.lowercased().contains("finance") == true }
    var isWorkoutEcho: Bool { echo?.name.lowercased().contains("workout") == true }

    private var isCooking: Bool {
        echo?.name.lowercased().contains("cook") == true
    }

    /// Builds a shareable `orca://` deep link for any cooking recipe — URL-sourced or OCR/manual.
    private var recipeShareURL: URL? {
        // Prefer the original source URL (smaller link)
        if let sourceURL = memory.url, !sourceURL.isEmpty,
           let encoded = sourceURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            return URL(string: "orca://recipe?url=\(encoded)")
        }
        // Inline payload for OCR/manual recipes
        let lines = memory.text.components(separatedBy: "\n")
        let titleLine = lines.first.map { $0.hasPrefix("🍽") ? String($0.dropFirst(2)).trimmingCharacters(in: .whitespaces) : $0 } ?? "Recipe"
        let ingredients = memorySubTasks.map { $0.text }
        var instructions: [String] = []
        if let instrRange = memory.text.range(of: "\nInstructions:\n") {
            let instrBlock = String(memory.text[instrRange.upperBound...])
            instructions = instrBlock.components(separatedBy: "\n").compactMap { line -> String? in
                let s = line.trimmingCharacters(in: .whitespaces)
                guard !s.isEmpty else { return nil }
                // Strip leading "N. " numbering
                if let dot = s.firstIndex(of: "."), s[s.startIndex].isNumber {
                    return String(s[s.index(after: dot)...]).trimmingCharacters(in: .whitespaces)
                }
                return s
            }
        }
        // Extract meta from second line if present
        var prep: String? = nil; var cook: String? = nil; var serves: String? = nil
        if lines.count > 1 {
            let meta = lines[1]
            for part in meta.components(separatedBy: " · ") {
                let p = part.trimmingCharacters(in: .whitespaces)
                if p.hasPrefix("Prep:") { prep = String(p.dropFirst(5)).trimmingCharacters(in: .whitespaces) }
                else if p.hasPrefix("Cook:") { cook = String(p.dropFirst(5)).trimmingCharacters(in: .whitespaces) }
                else if p.hasPrefix("Serves:") { serves = String(p.dropFirst(7)).trimmingCharacters(in: .whitespaces) }
            }
        }
        let payload = SharedRecipePayload(title: titleLine, ingredients: ingredients, instructions: instructions,
                                          prepTime: prep, cookTime: cook, servings: serves)
        guard let base64 = payload.toBase64(),
              let encoded = base64.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "orca://recipe?data=\(encoded)")
    }

    private var displayText: String {
        guard isCooking else { return memory.text }
        // Strip instructions block — everything from \nInstructions: onward
        if let range = memory.text.range(of: "\nInstructions:") {
            return String(memory.text[memory.text.startIndex..<range.lowerBound])
        }
        return memory.text
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    echoDateHeader

                    // Photo (if this memory has an attached image)
                    if let data = memory.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                            .frame(maxWidth: .infinity)
                    }

                    Text(displayText)
                        .font(.custom("DMSans-Regular", size: 16))
                        .foregroundColor(.deepNavy)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let url = memory.url, !url.isEmpty, let link = URL(string: url) {
                        linkButton(link)
                    }

                    if let date = memory.detectedDate {
                        calendarButton(date: date)
                    }

                    if !isTravelEcho, let name = memory.locationName, let lat = memory.latitude, let lng = memory.longitude {
                        locationBlock(name: name, lat: lat, lng: lng)
                    }

                    if isTravelEcho  { TravelDetailBlock(memory: memory) }
                    if isFinanceEcho { FinanceDetailBlock(memory: memory) }
                    if isWorkoutEcho { WorkoutDetailBlock(memory: memory) }

                    if isWorkoutEcho && Calendar.current.isDateInToday(memory.createdAt) {
                        Button { showQuickLog = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 16))
                                Text("Continue Workout")
                                    .font(.custom("DMSans-Medium", size: 15))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.oceanTeal)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }

                    if !memorySubTasks.isEmpty { checklistSection }

                    if !isTravelEcho {
                        let memoryPings = pings.filter { $0.memoryId == memory.id && $0.isActive }
                        if !memoryPings.isEmpty { remindersSection(memoryPings) }
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
                    Button("Done") { dismiss() }.foregroundColor(.oceanTeal)
                }
                ToolbarItem(placement: .confirmationAction) {
                    HStack(spacing: 16) {
                        if isCooking, let shareURL = recipeShareURL {
                            ShareLink(
                                item: shareURL,
                                subject: Text("Recipe on Orca"),
                                message: Text("Open in Orca to add this recipe!")
                            ) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.oceanTeal)
                            }
                        }
                        Button { editingMemory = memory } label: {
                            Image(systemName: "pencil").foregroundColor(.oceanTeal)
                        }
                    }
                }
            }
            .onAppear {
                if let date = memory.detectedDate {
                    let title = memory.text.components(separatedBy: "\n").first ?? memory.text
                    addedToCalendar = CalendarService.shared.isAlreadyAdded(title: title, date: date)
                }
            }
            .sheet(item: $editingMemory) { MemoryEditView(memory: $0) }
            .sheet(isPresented: $showInstructionEditor) {
                RecipeInstructionEditorView(memory: memory)
            }
            .sheet(isPresented: $showQuickLog) { QuickLogView() }
        }
    }

    // MARK: - Echo + Date Header

    private var echoDateHeader: some View {
        HStack(spacing: 8) {
            if let echo = echo {
                HStack(spacing: 4) {
                    Text(echo.emoji).font(.system(size: 14))
                    Text(echo.name)
                        .font(.custom("DMSans-Medium", size: 13))
                        .foregroundColor(.deepNavy)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.mist).clipShape(Capsule())
            }
            if let date = memory.detectedDate {
                HStack(spacing: 4) {
                    Text("📅").font(.system(size: 13))
                    if let end = memory.endDate {
                        Text("\(date.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))")
                            .font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                    } else {
                        Text(date, format: .dateTime.month(.abbreviated).day().year())
                            .font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                    }
                }
            }
            Spacer()
            if memory.wasEdited {
                Text("edited").font(.custom("DMMono-Regular", size: 11)).foregroundColor(.seafoam)
            }
        }
    }

    // MARK: - Link Button

    private func linkButton(_ link: URL) -> some View {
        Button { UIApplication.shared.open(link) } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.right.square").font(.system(size: 13))
                Text("Open Link").font(.custom("DMSans-Medium", size: 13))
            }
            .foregroundColor(.oceanTeal)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.oceanTeal.opacity(0.1)).clipShape(Capsule())
        }
    }

    // MARK: - Calendar Button

    private func calendarButton(date: Date) -> some View {
        let title = memory.text.components(separatedBy: "\n").first ?? memory.text
        return Button {
            guard !addedToCalendar else { return }
            Task {
                let granted = CalendarService.shared.isAuthorized
                    ? true
                    : await CalendarService.shared.requestAccess()
                if granted {
                    CalendarService.shared.addEvent(
                        title: title,
                        startDate: date,
                        endDate: memory.endDate
                    )
                    await MainActor.run {
                        withAnimation(.spring(duration: 0.2)) { addedToCalendar = true }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: addedToCalendar ? "calendar.badge.checkmark" : "calendar.badge.plus")
                    .font(.system(size: 13))
                Text(addedToCalendar ? "Added to Calendar ✓" : "Add to Apple Calendar")
                    .font(.custom("DMSans-Medium", size: 13))
            }
            .foregroundColor(addedToCalendar ? .white : .oceanTeal)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(addedToCalendar ? Color.oceanTeal : Color.oceanTeal.opacity(0.1))
            .clipShape(Capsule())
        }
    }

    // MARK: - Checklist

    private var checklistSection: some View {
        let isCooking = echo?.name.lowercased().contains("cook") == true

        // Parse instructions out of memory text
        let instructionSteps: [String] = {
            guard isCooking else { return [] }
            let lines = memory.text.components(separatedBy: "\n")
            var capturing = false
            var steps: [String] = []
            for line in lines {
                if line.trimmingCharacters(in: .whitespaces) == "Instructions:" {
                    capturing = true
                    continue
                }
                if capturing {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty { continue }
                    // Strip leading number like "1. "
                    let stripped = trimmed.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
                    if !stripped.isEmpty { steps.append(stripped) }
                }
            }
            return steps
        }()

        return VStack(alignment: .leading, spacing: 16) {

            // MARK: Ingredients / Checklist
            if !memorySubTasks.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(isCooking ? "INGREDIENTS" : "CHECKLIST")
                            .font(.custom("DMSans-Medium", size: 13)).foregroundColor(.oceanTeal).tracking(1)
                        Spacer()
                        if isCooking {
                            Button { showInstructionEditor = true } label: {
                                Text("Edit")
                                    .font(.custom("DMSans-Medium", size: 13))
                                    .foregroundColor(.oceanTeal)
                            }
                        } else {
                            let completed = memorySubTasks.filter { $0.isCompleted }.count
                            Text("\(completed)/\(memorySubTasks.count)")
                                .font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                        }
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
                                            Circle().fill(Color.oceanTeal).frame(width: 22, height: 22)
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                                        }
                                    }
                                    Text(subTask.text)
                                        .font(.custom("DMSans-Regular", size: 15))
                                        .foregroundColor(subTask.isCompleted ? .gray : .deepNavy)
                                        .strikethrough(subTask.isCompleted)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 12)
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

            // MARK: Instructions (cooking only)
            if !instructionSteps.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("INSTRUCTIONS")
                            .font(.custom("DMSans-Medium", size: 13)).foregroundColor(.oceanTeal).tracking(1)
                        Spacer()
                        Button { showInstructionEditor = true } label: {
                            Text("Edit")
                                .font(.custom("DMSans-Medium", size: 13))
                                .foregroundColor(.oceanTeal)
                        }
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(instructionSteps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.custom("DMMono-Regular", size: 13))
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Color.oceanTeal)
                                    .clipShape(Circle())
                                Text(step)
                                    .font(.custom("DMSans-Regular", size: 14))
                                    .foregroundColor(.deepNavy)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            if index < instructionSteps.count - 1 {
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                }
            }
        }
    }
    // MARK: - Reminders

    private func remindersSection(_ memoryPings: [Ping]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showReminders.toggle() }
            } label: {
                HStack {
                    Text("REMINDERS")
                        .font(.custom("DMSans-Medium", size: 13))
                        .foregroundColor(.oceanTeal).tracking(1)
                    Text("(\(memoryPings.count))")
                        .font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                    Spacer()
                    Image(systemName: showReminders ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12)).foregroundColor(.gray)
                }
            }
            .buttonStyle(.plain)

            if showReminders {
                ForEach(memoryPings) { ping in
                    HStack(spacing: 10) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 13)).foregroundColor(.oceanTeal)
                        Text(ping.fireDate, format: .dateTime.month(.abbreviated).day().hour().minute())
                            .font(.custom("DMMono-Regular", size: 13)).foregroundColor(.deepNavy)
                        if ping.recurrence != .none {
                            Text("· \(ping.recurrence.rawValue.capitalized)")
                                .font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
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
            ZStack {
                Map(position: .constant(.region(region))) {
                    Marker(name, coordinate: coordinate).tint(Color.coral)
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(true)
                Color.clear.contentShape(Rectangle())
                    .onTapGesture { showMapOptions = true }
            }
            .frame(height: 160)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 20)).foregroundColor(.coral)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy)
                    if let address = memory.locationAddress {
                        Text(address).font(.custom("DMSans-Regular", size: 13)).foregroundColor(.gray)
                    }
                }
                Spacer()
                Button {
                    let textToCopy = [name, memory.locationAddress].compactMap { $0 }.joined(separator: ", ")
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

            Button { showMapOptions = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "map").font(.system(size: 13))
                    Text("Open in Maps").font(.custom("DMSans-Medium", size: 13))
                }
                .foregroundColor(.oceanTeal)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.oceanTeal.opacity(0.1)).clipShape(Capsule())
            }
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
    }
}

#Preview {
    MemoryDetailView(memory: Memory(text: "Bench press 185 for 3 sets of 8. New PR!", echoId: UUID()))
        .modelContainer(for: [Memory.self, Echo.self, Ping.self, SubTask.self], inMemory: true)
}
