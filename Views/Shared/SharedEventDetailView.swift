//
//  SharedEventDetailView.swift
//  Orca
//

import SwiftUI
import SwiftData

struct SharedEventDetailView: View {
    @Bindable var event: SharedEvent
    let space: SharedSpace

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Query private var allItems: [SharedChecklistItem]

    @State private var newItemText = ""
    @State private var showDeleteConfirm = false
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var checklistExpanded = true
    @State private var notesText: String = ""
    @State private var editingItemId: UUID? = nil
    @State private var editingItemText: String = ""
    @FocusState private var newItemFocused: Bool
    @FocusState private var notesFocused: Bool
    @FocusState private var editingItemFocused: Bool

    private var items: [SharedChecklistItem] {
        allItems.filter { $0.eventId == event.id }.sorted { $0.createdAt < $1.createdAt }
    }

    private var completedItems: [SharedChecklistItem] { items.filter { $0.isCompleted } }
    private var pendingItems: [SharedChecklistItem] { items.filter { !$0.isCompleted } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Event header card
                    headerCard

                    // Checklist
                    checklistCard

                    // Notes
                    if event.notes != nil || true {
                        notesCard
                    }

                    Spacer().frame(height: 60)
                }
                .padding(20)
            }
            .background(Color.pearl)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { notesText = event.notes ?? "" }
            .onChange(of: notesFocused) { _, focused in
                if !focused { saveNotes() }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        if let item = items.first(where: { $0.id == editingItemId }) {
                            saveEditingItem(item)
                        }
                        newItemFocused = false
                        notesFocused = false
                        editingItemFocused = false
                        saveNotes()
                    }
                    .font(.custom("DMSans-Medium", size: 15))
                    .foregroundColor(.oceanTeal)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.oceanTeal)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                }
            }
            .confirmationDialog("Delete this event?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    Task {
                        try? await SharedSpaceSyncService.shared.deleteEvent(event)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the event and all its checklist items for both of you.")
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            if isEditingTitle {
                TextField("Event title", text: $editedTitle)
                    .font(.custom("DMSans-Medium", size: 20))
                    .foregroundColor(.deepNavy)
                    .onSubmit { saveTitle() }
                    .submitLabel(.done)
            } else {
                Button {
                    editedTitle = event.title
                    isEditingTitle = true
                } label: {
                    HStack(spacing: 6) {
                        Text(event.title)
                            .font(.custom("DMSans-Medium", size: 20))
                            .foregroundColor(.deepNavy)
                            .multilineTextAlignment(.leading)
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.4))
                    }
                }
                .buttonStyle(.plain)
            }

            // Date row
            HStack(spacing: 16) {
                if let date = event.date {
                    let dateLabel: String = {
                        if let end = event.endDate {
                            let fmt = DateFormatter()
                            fmt.dateFormat = "MMM d"
                            let endFmt = DateFormatter()
                            endFmt.dateFormat = Calendar.current.isDate(date, equalTo: end, toGranularity: .month) ? "d, yyyy" : "MMM d, yyyy"
                            return "\(fmt.string(from: date)) – \(endFmt.string(from: end))"
                        }
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                        let hasTime = comps.hour != 0 || comps.minute != 0
                        let base = date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
                        return hasTime ? "\(base) · \(date.formatted(.dateTime.hour().minute()))" : base
                    }()
                    Label(dateLabel, systemImage: "calendar")
                        .font(.custom("DMSans-Regular", size: 14))
                        .foregroundColor(.gray)
                }

                // URL
                if let urlStr = event.url, let url = URL(string: urlStr) {
                    Link(destination: url) {
                        Label("Open link", systemImage: "link")
                            .font(.custom("DMSans-Regular", size: 14))
                            .foregroundColor(.oceanTeal)
                    }
                }
            }

            // URL input
            urlInput

            // Progress
            if !items.isEmpty {
                let pct = Double(completedItems.count) / Double(items.count)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(completedItems.count) of \(items.count) done")
                            .font(.custom("DMMono-Regular", size: 12))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(Int(pct * 100))%")
                            .font(.custom("DMMono-Regular", size: 12))
                            .foregroundColor(.oceanTeal)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.mist).frame(height: 4)
                            RoundedRectangle(cornerRadius: 3).fill(Color.oceanTeal)
                                .frame(width: geo.size.width * pct, height: 4)
                                .animation(.easeOut(duration: 0.3), value: pct)
                        }
                    }
                    .frame(height: 4)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - URL Input

    @State private var urlInput_text: String = ""
    @State private var showUrlField = false

    private var urlInput: some View {
        Group {
            if event.url == nil {
                if showUrlField {
                    HStack(spacing: 8) {
                        TextField("Paste a link...", text: $urlInput_text)
                            .font(.custom("DMSans-Regular", size: 14))
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(10)
                            .background(Color.mist)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Button("Save") {
                            let trimmed = urlInput_text.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            event.url = trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)"
                            event.updatedAt = Date()
                            Task { try? await SharedSpaceSyncService.shared.updateEvent(event) }
                            showUrlField = false
                            urlInput_text = ""
                        }
                        .font(.custom("DMSans-Medium", size: 14))
                        .foregroundColor(.oceanTeal)
                    }
                } else {
                    Button {
                        showUrlField = true
                    } label: {
                        Label("Add link", systemImage: "link.badge.plus")
                            .font(.custom("DMSans-Regular", size: 13))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Checklist Card

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Collapsible header
            Button {
                withAnimation(.easeOut(duration: 0.2)) { checklistExpanded.toggle() }
            } label: {
                HStack {
                    Text("CHECKLIST")
                        .font(.custom("DMSans-Medium", size: 11))
                        .foregroundColor(.gray)
                        .tracking(0.5)
                    Spacer()
                    if !items.isEmpty {
                        Text("\(completedItems.count)/\(items.count)")
                            .font(.custom("DMMono-Regular", size: 11))
                            .foregroundColor(.gray)
                    }
                    Image(systemName: checklistExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)
            }
            .buttonStyle(.plain)

            if checklistExpanded {
                // Pending items
                ForEach(pendingItems) { item in
                    checklistRow(item: item)
                    Divider().padding(.horizontal, 16)
                }

                // Completed items (dimmed)
                ForEach(completedItems) { item in
                    checklistRow(item: item)
                    if item.id != completedItems.last?.id {
                        Divider().padding(.horizontal, 16)
                    }
                }

                // Add item field
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.oceanTeal.opacity(0.5))

                    TextField("Add item...", text: $newItemText)
                        .font(.custom("DMSans-Regular", size: 15))
                        .foregroundColor(.deepNavy)
                        .focused($newItemFocused)
                        .onSubmit { addItem() }
                        .submitLabel(.done)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    private func checklistRow(item: SharedChecklistItem) -> some View {
        HStack(spacing: 12) {
            Button {
                guard let userId = authService.userId else { return }
                Task { try? await SharedSpaceSyncService.shared.toggleChecklistItem(item, userId: userId) }
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(item.isCompleted ? .oceanTeal : .gray.opacity(0.35))
            }
            .buttonStyle(.plain)

            if editingItemId == item.id {
                TextField("", text: $editingItemText)
                    .font(.custom("DMSans-Regular", size: 15))
                    .foregroundColor(.deepNavy)
                    .focused($editingItemFocused)
                    .onSubmit { saveEditingItem(item) }
                    .submitLabel(.done)
                    .onChange(of: editingItemFocused) { _, focused in
                        if !focused { saveEditingItem(item) }
                    }
            } else {
                Text(item.text)
                    .font(.custom("DMSans-Regular", size: 15))
                    .foregroundColor(item.isCompleted ? .gray : .deepNavy)
                    .strikethrough(item.isCompleted, color: .gray.opacity(0.5))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingItemId = item.id
                        editingItemText = item.text
                        editingItemFocused = true
                    }
            }

            Spacer()

            Button {
                Task { try? await SharedSpaceSyncService.shared.deleteChecklistItem(item) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray.opacity(0.3))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private func saveEditingItem(_ item: SharedChecklistItem) {
        let trimmed = editingItemText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && trimmed != item.text {
            Task { try? await SharedSpaceSyncService.shared.updateChecklistItem(item, text: trimmed) }
        }
        editingItemId = nil
        editingItemText = ""
    }

    // MARK: - Notes Card

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("NOTES")
                .font(.custom("DMSans-Medium", size: 11))
                .foregroundColor(.gray)
                .tracking(0.5)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            TextField("Add notes...", text: $notesText, axis: .vertical)
                .font(.custom("DMSans-Regular", size: 15))
                .foregroundColor(.deepNavy)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .focused($notesFocused)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - Helpers

    private func saveTitle() {
        let trimmed = editedTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { isEditingTitle = false; return }
        event.title = trimmed
        event.updatedAt = Date()
        isEditingTitle = false
        Task { try? await SharedSpaceSyncService.shared.updateEvent(event) }
    }

    private func saveNotes() {
        let trimmed = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
        event.notes = trimmed.isEmpty ? nil : trimmed
        event.updatedAt = Date()
        Task { try? await SharedSpaceSyncService.shared.updateEvent(event) }
    }

    private func addItem() {
        let text = newItemText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, let userId = authService.userId else { return }
        newItemText = ""
        Task { try? await SharedSpaceSyncService.shared.addChecklistItem(eventId: event.id, text: text, userId: userId) }
    }
}
