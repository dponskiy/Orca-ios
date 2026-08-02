//
//  SharedSpaceView.swift
//  Orca
//

import SwiftUI
import SwiftData

struct SharedSpaceView: View {
    let space: SharedSpace

    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Query private var allEvents: [SharedEvent]
    @Query private var allItems: [SharedChecklistItem]

    @State private var showAddEvent = false
    @State private var selectedEvent: SharedEvent? = nil
    @State private var isRefreshing = false
    @State private var pastExpanded = false

    private var events: [SharedEvent] {
        allEvents.filter { $0.spaceId == space.id }
    }

    private var upcomingEvents: [SharedEvent] {
        let today = Calendar.current.startOfDay(for: Date())
        return events.filter { event in
            guard let start = event.date else { return false }
            let effectiveEnd = event.endDate.map { Calendar.current.startOfDay(for: $0) } ?? Calendar.current.startOfDay(for: start)
            return start >= today || effectiveEnd >= today
        }
        .sorted { $0.date! < $1.date! }
    }

    private var pastEvents: [SharedEvent] {
        let today = Calendar.current.startOfDay(for: Date())
        return events.filter { event in
            guard let start = event.date else { return false }
            let effectiveEnd = event.endDate.map { Calendar.current.startOfDay(for: $0) } ?? Calendar.current.startOfDay(for: start)
            return start < today && effectiveEnd < today
        }
        .sorted { $0.date! > $1.date! }
    }

    private var undatedCards: [SharedEvent] {
        events.filter { $0.date == nil }.sorted { $0.createdAt > $1.createdAt }
    }

    private var displayTitle: String {
        space.spaceName.isEmpty ? "Shared Space" : space.spaceName
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Status banner if pending
                if space.status == .pending {
                    pendingBanner
                }

                // Upcoming events
                if !upcomingEvents.isEmpty {
                    eventSection(title: "UPCOMING", events: upcomingEvents)
                }

                // Undated cards
                if !undatedCards.isEmpty {
                    eventSection(title: "NOTES & MISC", events: undatedCards)
                }

                // Past events — collapsible
                if !pastEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) { pastExpanded.toggle() }
                        } label: {
                            HStack(spacing: 6) {
                                Text("PAST")
                                    .font(.custom("DMSans-Medium", size: 11))
                                    .foregroundColor(.gray)
                                    .tracking(0.5)
                                Text("(\(pastEvents.count))")
                                    .font(.custom("DMSans-Regular", size: 11))
                                    .foregroundColor(.gray.opacity(0.6))
                                Spacer()
                                Image(systemName: pastExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                        }
                        .buttonStyle(.plain)

                        if pastExpanded {
                            eventSection(title: "", events: pastEvents)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }

                // Empty state
                if events.isEmpty {
                    emptyState
                }

                Spacer().frame(height: 60)
            }
            .padding(20)
        }
        .background(Color.pearl)
        .navigationTitle(displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                HStack(spacing: 16) {
                    Button {
                        guard let userId = authService.userId else { return }
                        isRefreshing = true
                        Task {
                            await SharedSpaceSyncService.shared.syncAll(userId: userId)
                            await MainActor.run { isRefreshing = false }
                        }
                    } label: {
                        if isRefreshing {
                            ProgressView().tint(.oceanTeal).scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.oceanTeal)
                        }
                    }
                    Button {
                        showAddEvent = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.oceanTeal)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddEvent) {
            AddSharedEventView(space: space) { newEvent in
                selectedEvent = newEvent
            }
        }
        .sheet(item: $selectedEvent) { event in
            SharedEventDetailView(event: event, space: space)
        }
    }

    // MARK: - Pending Banner

    private var pendingBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.system(size: 14))
                .foregroundColor(.oceanTeal)
            VStack(alignment: .leading, spacing: 2) {
                Text("Invite pending")
                    .font(.custom("DMSans-Medium", size: 14))
                    .foregroundColor(.deepNavy)
                Text("Waiting for someone to accept your invite")
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.oceanTeal.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.oceanTeal.opacity(0.15), lineWidth: 0.5))
    }

    // MARK: - Event Section

    private func eventSection(title: String, events: [SharedEvent]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.custom("DMSans-Medium", size: 11))
                .foregroundColor(.gray)
                .tracking(0.5)

            VStack(spacing: 0) {
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    if index > 0 { Divider().padding(.horizontal, 16) }
                    eventRow(event: event)
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
        }
    }

    // MARK: - Event Row

    private func eventRow(event: SharedEvent) -> some View {
        let items = allItems.filter { $0.eventId == event.id }
        let completedCount = items.filter { $0.isCompleted }.count

        return Button {
            selectedEvent = event
        } label: {
            HStack(spacing: 14) {
                // Date badge or card icon
                if let date = event.date {
                    if let end = event.endDate {
                        // Multi-day: show "May 3–5" style
                        VStack(spacing: 1) {
                            Text(date.formatted(.dateTime.month(.abbreviated)))
                                .font(.custom("DMMono-Regular", size: 10))
                                .foregroundColor(.oceanTeal)
                            Text("\(date.formatted(.dateTime.day()))–\(end.formatted(.dateTime.day()))")
                                .font(.custom("DMSans-Medium", size: 14))
                                .foregroundColor(.deepNavy)
                        }
                        .frame(width: 44)
                    } else {
                        VStack(spacing: 1) {
                            Text(date.formatted(.dateTime.month(.abbreviated)))
                                .font(.custom("DMMono-Regular", size: 10))
                                .foregroundColor(.oceanTeal)
                            Text(date.formatted(.dateTime.day()))
                                .font(.custom("DMSans-Medium", size: 18))
                                .foregroundColor(.deepNavy)
                        }
                        .frame(width: 36)
                    }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.mist)
                            .frame(width: 36, height: 36)
                        Image(systemName: "note.text")
                            .font(.system(size: 14))
                            .foregroundColor(.oceanTeal)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.custom("DMSans-Medium", size: 15))
                        .foregroundColor(.deepNavy)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if let date = event.date {
                            Text(relativeDate(date))
                                .font(.custom("DMMono-Regular", size: 12))
                                .foregroundColor(.gray)
                        }
                        if !items.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: completedCount == items.count ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 10))
                                    .foregroundColor(completedCount == items.count ? .oceanTeal : .gray.opacity(0.5))
                                Text("\(completedCount)/\(items.count)")
                                    .font(.custom("DMMono-Regular", size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.2")
                .font(.system(size: 40))
                .foregroundColor(.oceanTeal.opacity(0.25))
            Text("Nothing here yet")
                .font(.custom("DMSans-Medium", size: 17))
                .foregroundColor(.deepNavy)
            Text("Tap + to add your first shared event or note")
                .font(.custom("DMSans-Regular", size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Helpers

    private func relativeDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
        if days > 0 && days < 7 { return "in \(days) days" }
        if days < 0 { return date.formatted(.dateTime.month(.abbreviated).day()) }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

// MARK: - Add Shared Event Sheet

struct AddSharedEventView: View {
    let space: SharedSpace
    var onCreated: ((SharedEvent) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService

    @State private var title = ""
    @State private var hasDate = false
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var hasTime = false
    @State private var startTime = Date()
    @State private var isLoading = false
    @State private var saveError: String? = nil
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title — e.g. Smith Wedding", text: $title)
                        .font(.custom("DMSans-Regular", size: 16))
                        .focused($titleFocused)
                }

                Section(footer:
                    Text("Date is optional — this can just be a note or shared info")
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundColor(.gray)
                ) {
                    Toggle(isOn: $hasDate.animation()) {
                        Label("Add a date", systemImage: "calendar")
                            .font(.custom("DMSans-Regular", size: 15))
                    }
                    .tint(.oceanTeal)

                    if hasDate {
                        DatePicker("Start", selection: $startDate, displayedComponents: [.date])
                            .font(.custom("DMSans-Regular", size: 15))
                            .datePickerStyle(.compact)
                            .onChange(of: startDate) { _, newStart in
                                if endDate <= newStart {
                                    endDate = Calendar.current.date(byAdding: .day, value: 1, to: newStart) ?? newStart
                                }
                            }

                        Toggle(isOn: $hasTime.animation()) {
                            Text("Add a time")
                                .font(.custom("DMSans-Regular", size: 15))
                        }
                        .tint(.oceanTeal)

                        if hasTime {
                            DatePicker("Time", selection: $startTime, displayedComponents: [.hourAndMinute])
                                .font(.custom("DMSans-Regular", size: 15))
                                .datePickerStyle(.compact)
                        }

                        Toggle(isOn: $hasEndDate.animation()) {
                            Text("Multi-day event")
                                .font(.custom("DMSans-Regular", size: 15))
                        }
                        .tint(.oceanTeal)

                        if hasEndDate {
                            DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: [.date])
                                .font(.custom("DMSans-Regular", size: 15))
                                .datePickerStyle(.compact)
                        }

                        if !hasTime {
                            Text("No time set — this will show as an all-day event")
                                .font(.custom("DMSans-Regular", size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("New Event / Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .font(.custom("DMSans-Medium", size: 16))
                        .foregroundColor(title.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .oceanTeal)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
            }
            .onAppear { titleFocused = true }
        }
        .presentationDetents([.medium])
        .alert("Couldn't Add Event", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    private func combine(date: Date, time: Date) -> Date {
        let cal = Calendar.current
        var merged = cal.dateComponents([.year, .month, .day], from: date)
        let timeComps = cal.dateComponents([.hour, .minute], from: time)
        merged.hour = timeComps.hour
        merged.minute = timeComps.minute
        return cal.date(from: merged) ?? date
    }

    private func save() {
        guard let userId = authService.userId else { return }
        isLoading = true

        let finalStartDate = hasTime ? combine(date: startDate, time: startTime) : Calendar.current.startOfDay(for: startDate)

        Task {
            do {
                let event = try await SharedSpaceSyncService.shared.createEvent(
                    spaceId: space.id,
                    title: title.trimmingCharacters(in: .whitespaces),
                    date: hasDate ? finalStartDate : nil,
                    endDate: (hasDate && hasEndDate) ? endDate : nil,
                    userId: userId
                )
                // Shared space events — add if sync enabled, or trigger one-time prompt
                if hasDate {
                    if CalendarService.shared.syncEnabled && CalendarService.shared.isAuthorized {
                        CalendarService.shared.addEvent(
                            title: event.title,
                            startDate: finalStartDate,
                            endDate: (hasDate && hasEndDate) ? endDate : nil,
                            isAllDay: !hasTime
                        )
                    } else if !CalendarService.shared.promptShown {
                        NotificationCenter.default.post(
                            name: .calendarSyncCheck,
                            object: nil,
                            userInfo: ["sharedEventTitle": event.title, "sharedEventDate": finalStartDate]
                        )
                    }
                }
                await MainActor.run {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onCreated?(event)
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    saveError = "Couldn't add event. The shared space may still be syncing — try again in a moment."
                }
            }
        }
    }
}
