//
//  ThoughtsView.swift
//  Orca
//

import SwiftUI
import SwiftData
import Speech
import AVFoundation

struct ThoughtsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ThoughtTab.sortOrder) private var tabs: [ThoughtTab]
    @Query(sort: \Memory.createdAt, order: .reverse) private var allMemories: [Memory]
    @Query private var allEchos: [Echo]

    @State private var selectedTabId: UUID? = nil
    @State private var inputText = ""
    @State private var isListening = false
    @State private var showAddTab = false
    @State private var newTabName = ""
    @State private var renamingTab: ThoughtTab? = nil
    @State private var renameText = ""
    @State private var editingEntry: Memory? = nil
    @FocusState private var inputFocused: Bool

    /// One-time swipe hint: shows a brief label the first time the list has entries
    @AppStorage("thoughtsSwipeHintShown") private var swipeHintShown = false
    @State private var showSwipeHint = false

    private let speechManager = ThoughtsSpeechManager()

    // MARK: - Data

    private var thoughtsEcho: Echo? {
        // Look up by fixed UUID first; fall back to name for safety
        allEchos.first { $0.id == Echo.thoughtsEchoId }
            ?? allEchos.first { $0.name == "Thoughts" }
    }

    private var selectedTab: ThoughtTab? {
        if let id = selectedTabId {
            return tabs.first { $0.id == id }
        }
        return tabs.first
    }

    private var entriesForSelectedTab: [Memory] {
        guard let echo = thoughtsEcho, let tab = selectedTab else { return [] }
        let isDefaultTab = tab.sortOrder == 0
        return allMemories.filter { memory in
            guard memory.echoId == echo.id else { return false }
            // Memories with no tab (e.g. after reinstall sync) fall back to the default tab
            if memory.thoughtTabId == nil { return isDefaultTab }
            return memory.thoughtTabId == tab.id
        }
    }

    /// Entries grouped by calendar day, newest group first
    private var entriesByDate: [(key: Date, entries: [Memory])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: entriesForSelectedTab) { entry in
            cal.startOfDay(for: entry.createdAt)
        }
        return grouped.keys.sorted(by: >).map { date in
            (key: date, entries: (grouped[date] ?? []).sorted { $0.createdAt > $1.createdAt })
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabStrip
                Divider()
                thoughtsInfoBanner
                Divider()

                if entriesForSelectedTab.isEmpty {
                    emptyState
                } else {
                    ZStack(alignment: .top) {
                        entryList
                        if showSwipeHint {
                            swipeHintBanner
                        }
                    }
                }

                inputBar
            }
            .background(Color.pearl)
            .navigationTitle("Thoughts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.oceanTeal)
                }
            }
            .sheet(isPresented: $showAddTab) { addTabSheet }
            .sheet(item: $renamingTab) { tab in renameTabSheet(tab: tab) }
            .sheet(item: $editingEntry) { entry in EditThoughtView(entry: entry) }
            .onAppear {
                // Seed Thoughts echo + default tab only when the feature is first opened
                Echo.seedThoughtsEchoIfNeeded(context: modelContext)
                ThoughtTab.seedDefaultIfNeeded(context: modelContext)
                if selectedTabId == nil { selectedTabId = tabs.first?.id }
                reassignOrphanedThoughts()
                maybeShowSwipeHint()
            }
            .onChange(of: tabs.count) { _, _ in
                if selectedTabId == nil || !tabs.contains(where: { $0.id == selectedTabId }) {
                    selectedTabId = tabs.first?.id
                }
            }
            .onChange(of: entriesForSelectedTab.count) { _, count in
                if count > 0 { maybeShowSwipeHint() }
            }
        }
    }

    private func maybeShowSwipeHint() {
        guard !swipeHintShown, !entriesForSelectedTab.isEmpty else { return }
        swipeHintShown = true
        withAnimation(.easeIn(duration: 0.3)) { showSwipeHint = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.4)) { showSwipeHint = false }
        }
    }

    // MARK: - Swipe Hint Banner

    private var swipeHintBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.left")
                .font(.system(size: 11, weight: .medium))
            Text("Swipe left to edit or delete")
                .font(.custom("DMSans-Regular", size: 13))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.deepNavy.opacity(0.75))
        .clipShape(Capsule())
        .padding(.top, 10)
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Tab Strip

    private var tabStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tabs) { tab in tabPill(tab) }
                Button {
                    newTabName = ""
                    showAddTab = true
                } label: {
                    HStack(spacing: 4) {
                        Text("New Tab")
                            .font(.custom("DMSans-Regular", size: 13))
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.oceanTeal)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.mist)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color.white)
    }

    @ViewBuilder private func tabPill(_ tab: ThoughtTab) -> some View {
        let isSelected = tab.id == (selectedTabId ?? tabs.first?.id)
        Button {
            withAnimation(.easeOut(duration: 0.18)) { selectedTabId = tab.id }
        } label: {
            Text(tab.name)
                .font(.custom(isSelected ? "DMSans-Medium" : "DMSans-Regular", size: 14))
                .foregroundColor(isSelected ? .white : .deepNavy)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(isSelected ? Color.oceanTeal : Color.mist)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                renameText = tab.name
                renamingTab = tab
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            if tab.sortOrder != 0 || tabs.count == 1 || tab.name != "Thoughts" {
                if tabs.count > 1 {
                    Button(role: .destructive) { deleteTab(tab) } label: {
                        Label("Delete Tab", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Thoughts Info Banner

    private var thoughtsInfoBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 13))
                .foregroundColor(.oceanTeal.opacity(0.7))
            Text("Thoughts is your free-form notebook. Notes here aren't categorized into Echoes or turned into reminders — just write freely.")
                .font(.custom("DMSans-Regular", size: 12))
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.mist.opacity(0.6))
    }

    // MARK: - Flat list items (avoids Section animation warnings)

    private enum ThoughtListItem: Identifiable {
        case dateDivider(Date)
        case entry(Memory)

        var id: String {
            switch self {
            case .dateDivider(let d): return "div-\(d.timeIntervalSince1970)"
            case .entry(let m):       return "entry-\(m.id.uuidString)"
            }
        }
    }

    private var flatListItems: [ThoughtListItem] {
        var items: [ThoughtListItem] = []
        for group in entriesByDate {
            items.append(.dateDivider(group.key))
            for entry in group.entries {
                items.append(.entry(entry))
            }
        }
        return items
    }

    // MARK: - Entry List

    private var entryList: some View {
        List {
            ForEach(flatListItems) { item in
                switch item {
                case .dateDivider(let date):
                    dateDividerRow(date)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowBackground(Color.pearl)
                        .listRowSeparator(.hidden)

                case .entry(let entry):
                    entryRow(entry: entry)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowBackground(Color.pearl)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                let id = entry.id
                                modelContext.delete(entry)
                                SupabaseSyncService.shared.scheduleDelete(id: id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                editingEntry = entry
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.oceanTeal)
                        }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.pearl)
    }

    private func dateDividerRow(_ date: Date) -> some View {
        HStack {
            Rectangle().fill(Color.black.opacity(0.06)).frame(height: 0.5)
            Text(formatDateHeader(date))
                .font(.custom("DMMono-Regular", size: 11))
                .foregroundColor(.gray.opacity(0.5))
                .fixedSize()
            Rectangle().fill(Color.black.opacity(0.06)).frame(height: 0.5)
        }
        .padding(.vertical, 6)
    }

    private func formatDateHeader(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "M/d/yy"
        return f.string(from: date)
    }

    private func entryRow(entry: Memory) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.oceanTeal.opacity(0.35))
                .frame(width: 6, height: 6)
                .padding(.top, 7)

            Text(entry.text)
                .font(.custom("DMSans-Regular", size: 15))
                .foregroundColor(.deepNavy)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Button { toggleListening() } label: {
                    ZStack {
                        Circle()
                            .fill(isListening ? Color.coral : Color.oceanTeal)
                            .frame(width: 40, height: 40)
                        Image(systemName: isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)

                TextField(isListening ? "Listening..." : "Add a thought...", text: $inputText, axis: .vertical)
                    .font(.custom("DMSans-Regular", size: 15))
                    .foregroundColor(.deepNavy)
                    .focused($inputFocused)
                    .lineLimit(1...4)
                    .onSubmit { logEntry() }

                if !inputText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button { logEntry() } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.oceanTeal)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Spacer()
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.oceanTeal.opacity(0.2))
                    Text("Nothing here yet")
                        .font(.custom("DMSans-Medium", size: 17))
                        .foregroundColor(.deepNavy)
                    Text("Speak or type a thought below")
                        .font(.custom("DMSans-Regular", size: 14))
                        .foregroundColor(.gray)
                }
            )
    }

    // MARK: - Add Tab Sheet

    private var addTabSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Tab name", text: $newTabName)
                        .font(.custom("DMSans-Regular", size: 16))
                }
            }
            .navigationTitle("New Tab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddTab = false }.foregroundColor(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let name = newTabName.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty else { return }
                        let tab = ThoughtTab(name: name, sortOrder: tabs.count)
                        modelContext.insert(tab)
                        selectedTabId = tab.id
                        showAddTab = false
                    }
                    .font(.custom("DMSans-Medium", size: 16))
                    .foregroundColor(newTabName.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .oceanTeal)
                    .disabled(newTabName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }

    // MARK: - Rename Tab Sheet

    private func renameTabSheet(tab: ThoughtTab) -> some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Tab name", text: $renameText)
                        .font(.custom("DMSans-Regular", size: 16))
                }
            }
            .navigationTitle("Rename Tab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { renamingTab = nil }.foregroundColor(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let name = renameText.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty else { return }
                        tab.name = name
                        renamingTab = nil
                    }
                    .font(.custom("DMSans-Medium", size: 16))
                    .foregroundColor(renameText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .oceanTeal)
                    .disabled(renameText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }

    // MARK: - Actions

    /// After a reinstall, Thoughts memories come back from Supabase with thoughtTabId = nil.
    /// Stamp them with the default tab's ID so they're permanently homed.
    private func reassignOrphanedThoughts() {
        guard let echo = thoughtsEcho,
              let defaultTab = tabs.first(where: { $0.sortOrder == 0 }) else { return }
        let orphans = allMemories.filter { $0.echoId == echo.id && $0.thoughtTabId == nil }
        guard !orphans.isEmpty else { return }
        for memory in orphans { memory.thoughtTabId = defaultTab.id }
        try? modelContext.save()
    }

    private func logEntry() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let echo = thoughtsEcho, let tab = selectedTab else { return }

        let memory = Memory(text: text, echoId: echo.id, captureType: .typed)
        memory.thoughtTabId = tab.id
        memory.isActionable = false
        modelContext.insert(memory)
        try? modelContext.save()   // explicit save so data isn't lost on force-quit

        inputText = ""
        speechManager.stop()
        isListening = false
    }

    private func toggleListening() {
        if isListening {
            speechManager.stop()
            isListening = false
        } else {
            speechManager.start { text in inputText = text }
            isListening = true
        }
    }

    private func deleteTab(_ tab: ThoughtTab) {
        if let echo = thoughtsEcho {
            let entriesToMove = allMemories.filter { $0.echoId == echo.id && $0.thoughtTabId == tab.id }
            let fallback = tabs.first { $0.id != tab.id }
            for entry in entriesToMove {
                if let fallback = fallback {
                    entry.thoughtTabId = fallback.id
                } else {
                    let id = entry.id
                    modelContext.delete(entry)
                    SupabaseSyncService.shared.scheduleDelete(id: id)
                }
            }
        }
        modelContext.delete(tab)
        try? modelContext.save()
    }
}

// MARK: - Edit Thought View

struct EditThoughtView: View {
    @Environment(\.dismiss) private var dismiss
    let entry: Memory

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .font(.custom("DMSans-Regular", size: 16))
                .foregroundColor(.deepNavy)
                .focused($focused)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .scrollContentBackground(.hidden)
                .background(Color.pearl)
                .navigationTitle("Edit Thought")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }.foregroundColor(.gray)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty { entry.text = trimmed }
                            dismiss()
                        }
                        .font(.custom("DMSans-Medium", size: 16))
                        .foregroundColor(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .oceanTeal)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            text = entry.text
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focused = true }
        }
    }
}

// MARK: - Speech Manager

class ThoughtsSpeechManager: NSObject, SFSpeechRecognizerDelegate {
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    func start(onResult: @escaping (String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized, let self else { return }
            DispatchQueue.main.async { self.startRecording(onResult: onResult) }
        }
    }

    private func startRecording(onResult: @escaping (String) -> Void) {
        recognitionTask?.cancel()
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        recognitionTask = recognizer?.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            if let result = result {
                DispatchQueue.main.async { onResult(result.bestTranscription.formattedString) }
            }
            if error != nil || result?.isFinal == true {
                DispatchQueue.main.async { self?.stop() }
            }
        }

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        audioEngine.prepare()
        try? audioEngine.start()
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
