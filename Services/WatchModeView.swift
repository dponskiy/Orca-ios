//
//  WatchModeView.swift
//  Orca
//
//  Created by David Piliponskiy on 4/30/26.
//

import SwiftUI
import SwiftData

struct WatchModeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WatchlistItem.createdAt, order: .reverse) private var items: [WatchlistItem]

    @State private var selectedTab: Tab = .queue
    @State private var showAddSheet = false
    @State private var ratingItem: WatchlistItem? = nil
    @State private var editItem: WatchlistItem? = nil

    enum Tab { case queue, completed }

    private var queuedItems: [WatchlistItem] { items.filter { $0.status == "queued" } }
    private var completedItems: [WatchlistItem] { items.filter { $0.status == "completed" } }
    private var shows: [WatchlistItem] { queuedItems.filter { $0.itemType == "show" } }
    private var movies: [WatchlistItem] { queuedItems.filter { $0.itemType == "movie" } }
    private var books: [WatchlistItem] { queuedItems.filter { $0.itemType == "book" } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabPicker

                List {
                    if selectedTab == .queue {
                        queueView
                    } else {
                        completedView
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("🍿 Media Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.gray)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.oceanTeal)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddWatchItemSheet { title, type, service in
                let item = WatchlistItem(title: title, itemType: type, streamingService: service)
                modelContext.insert(item)
            }
        }
        .sheet(item: $ratingItem) { item in
            RateWatchItemSheet(item: item)
        }
        .sheet(item: $editItem) { item in
            EditWatchItemSheet(item: item)
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { selectedTab = .queue }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "bookmark.fill").font(.system(size: 12))
                    Text("Queue").font(.custom("DMSans-Medium", size: 14))
                    if !queuedItems.isEmpty {
                        Text("\(queuedItems.count)")
                            .font(.custom("DMMono-Regular", size: 11))
                            .foregroundColor(selectedTab == .queue ? .white.opacity(0.8) : .gray)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(selectedTab == .queue ? Color.white.opacity(0.2) : Color.mist)
                            .clipShape(Capsule())
                    }
                }
                .foregroundColor(selectedTab == .queue ? .white : .deepNavy)
                .padding(.horizontal, 20).padding(.vertical, 8)
                .background(selectedTab == .queue ? Color.oceanTeal : Color.clear)
                .clipShape(Capsule())
            }

            Button {
                withAnimation(.easeOut(duration: 0.2)) { selectedTab = .completed }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 12))
                    Text("Completed").font(.custom("DMSans-Medium", size: 14))
                    if !completedItems.isEmpty {
                        Text("\(completedItems.count)")
                            .font(.custom("DMMono-Regular", size: 11))
                            .foregroundColor(selectedTab == .completed ? .white.opacity(0.8) : .gray)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(selectedTab == .completed ? Color.white.opacity(0.2) : Color.mist)
                            .clipShape(Capsule())
                    }
                }
                .foregroundColor(selectedTab == .completed ? .white : .deepNavy)
                .padding(.horizontal, 20).padding(.vertical, 8)
                .background(selectedTab == .completed ? Color.oceanTeal : Color.clear)
                .clipShape(Capsule())
            }
        }
        .padding(3)
        .background(Color.mist)
        .clipShape(Capsule())
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(Color.white)
    }

    // MARK: - Queue View

    @ViewBuilder
    private var queueView: some View {
        if queuedItems.isEmpty {
            VStack(spacing: 16) {
                Spacer().frame(height: 40)
                Text("🎬").font(.system(size: 48))
                Text("Nothing queued yet")
                    .font(.custom("DMSans-Medium", size: 18)).foregroundColor(.deepNavy)
                Text("Tap + to add a show, movie or book")
                    .font(.custom("DMSans-Regular", size: 14)).foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } else {
            Section {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left").font(.system(size: 9))
                    Text("Swipe to edit or delete")
                        .font(.custom("DMSans-Regular", size: 11))
                }
                .foregroundColor(.gray.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if !shows.isEmpty {
                Section {
                    ForEach(shows) { item in queueRow(item: item) }
                } header: {
                    Text("📺 Shows")
                        .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).textCase(nil)
                }
            }
            if !movies.isEmpty {
                Section {
                    ForEach(movies) { item in queueRow(item: item) }
                } header: {
                    Text("🎬 Movies")
                        .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).textCase(nil)
                }
            }
            if !books.isEmpty {
                Section {
                    ForEach(books) { item in queueRow(item: item) }
                } header: {
                    Text("📚 Books")
                        .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).textCase(nil)
                }
            }
        }
    }

    private func queueRow(item: WatchlistItem) -> some View {
        let title = item.title
        let service = item.streamingService

        return HStack(spacing: 12) {
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    item.status = "completed"
                    item.completedAt = Date()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    ratingItem = item
                }
            } label: {
                Circle()
                    .stroke(Color.oceanTeal, lineWidth: 2)
                    .frame(width: 24, height: 24)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.custom("DMSans-Medium", size: 15))
                    .foregroundColor(.deepNavy)
                    .lineLimit(2)
                if let service = service {
                    streamingPill(service: service)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                modelContext.delete(item)
            } label: { Label("Delete", systemImage: "trash") }

            Button {
                editItem = item
            } label: { Label("Edit", systemImage: "pencil") }
            .tint(.oceanTeal)
        }
    }

    // MARK: - Completed View

    @ViewBuilder
    private var completedView: some View {
        if completedItems.isEmpty {
            VStack(spacing: 16) {
                Spacer().frame(height: 40)
                Text("✅").font(.system(size: 48))
                Text("Nothing completed yet")
                    .font(.custom("DMSans-Medium", size: 18)).foregroundColor(.deepNavy)
                Text("Mark items as done to see them here")
                    .font(.custom("DMSans-Regular", size: 14)).foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } else {
            Section {
                ForEach(completedItems) { item in
                    let title = item.title
                    let rating = item.rating
                    let comment = item.comment
                    let service = item.streamingService

                    Button { ratingItem = item } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(title)
                                    .font(.custom("DMSans-Medium", size: 15))
                                    .foregroundColor(.deepNavy)
                                    .lineLimit(2)
                                HStack(spacing: 8) {
                                    if let service = service {
                                        streamingPill(service: service)
                                    }
                                    if let rating = rating {
                                        HStack(spacing: 2) {
                                            ForEach(1...5, id: \.self) { star in
                                                Image(systemName: star <= rating ? "star.fill" : "star")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(star <= rating ? .coral : .gray.opacity(0.3))
                                            }
                                        }
                                    }
                                }
                                if let comment = comment, !comment.isEmpty {
                                    Text(comment)
                                        .font(.custom("DMSans-Regular", size: 13))
                                        .foregroundColor(.gray)
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11)).foregroundColor(.gray.opacity(0.4))
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading) {
                        Button {
                            item.status = "queued"
                            item.completedAt = nil
                            item.rating = nil
                            item.comment = nil
                        } label: { Label("Re-queue", systemImage: "arrow.uturn.left") }
                        .tint(.oceanTeal)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            modelContext.delete(item)
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
    }

    // MARK: - Streaming Pill

    func streamingPill(service: String) -> some View {
        let color = streamingColor(service)
        return Text(service)
            .font(.custom("DMMono-Regular", size: 11))
            .foregroundColor(color)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    func streamingColor(_ service: String) -> Color {
        switch service {
        case "Netflix": return Color(red: 0.9, green: 0.1, blue: 0.1)
        case "HBO Max", "Max": return Color(red: 0.35, green: 0.1, blue: 0.8)
        case "Apple TV+": return Color(red: 0.15, green: 0.15, blue: 0.15)
        case "Hulu": return Color(red: 0.1, green: 0.7, blue: 0.4)
        case "Disney+": return Color(red: 0.05, green: 0.2, blue: 0.7)
        case "Prime Video": return Color(red: 0.0, green: 0.5, blue: 0.8)
        case "Peacock": return Color(red: 0.1, green: 0.4, blue: 0.85)
        case "Paramount+": return Color(red: 0.05, green: 0.3, blue: 0.75)
        case "Showtime": return Color(red: 0.7, green: 0.05, blue: 0.05)
        case "Starz": return Color(red: 0.3, green: 0.3, blue: 0.3)
        case "Crunchyroll": return Color(red: 0.95, green: 0.4, blue: 0.0)
        case "Kindle", "Audible": return Color(red: 0.95, green: 0.55, blue: 0.0)
        case "Library", "Libby": return Color(red: 0.2, green: 0.5, blue: 0.3)
        case "YouTube": return Color(red: 0.85, green: 0.1, blue: 0.1)
        case "Spotify": return Color(red: 0.1, green: 0.7, blue: 0.3)
        default: return Color.oceanTeal
        }
    }
}

// MARK: - Add Watch Item Sheet

struct AddWatchItemSheet: View {
    let onAdd: (String, String, String?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var itemType = "show"
    @State private var streamingService: String? = nil
    @State private var customService = ""
    @State private var showCustomService = false
    @FocusState private var titleFocused: Bool

    private let showServices = ["Netflix", "HBO Max", "Apple TV+", "Hulu", "Disney+", "Prime Video", "Peacock", "Paramount+", "Showtime", "YouTube", "Other"]
    private let movieServices = ["Netflix", "HBO Max", "Apple TV+", "Hulu", "Disney+", "Prime Video", "Peacock", "Paramount+", "Showtime", "Starz", "YouTube", "Other"]
    private let bookServices = ["Kindle", "Audible", "Library", "Physical", "Other"]

    private var services: [String] {
        switch itemType {
        case "book": return bookServices
        case "movie": return movieServices
        default: return showServices
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Title...", text: $title)
                        .font(.custom("DMSans-Regular", size: 16))
                        .foregroundColor(.deepNavy)
                        .focused($titleFocused)
                } header: {
                    Text("Title").font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).textCase(nil)
                }

                Section {
                    HStack(spacing: 8) {
                        typeButton(label: "📺 Show", type: "show")
                        typeButton(label: "🎬 Movie", type: "movie")
                        typeButton(label: "📚 Book", type: "book")
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } header: {
                    Text("Type").font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).textCase(nil)
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(services, id: \.self) { service in
                                Button {
                                    if service == "Other" {
                                        showCustomService = true
                                        streamingService = nil
                                    } else {
                                        streamingService = service
                                        showCustomService = false
                                        customService = ""
                                    }
                                } label: {
                                    Text(service)
                                        .font(.custom("DMSans-Medium", size: 13))
                                        .foregroundColor(streamingService == service ? .white : .deepNavy)
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(streamingService == service ? Color.oceanTeal : Color.mist)
                                        .clipShape(Capsule())
                                        .fixedSize()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    if showCustomService {
                        TextField("Service name...", text: $customService)
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(.deepNavy)
                            .onChange(of: customService) { _, val in
                                streamingService = val.isEmpty ? nil : val
                            }
                    }
                } header: {
                    Text("Where to watch / read").font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add to queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.gray)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add") {
                        let trimmed = title.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        onAdd(trimmed, itemType, streamingService)
                        dismiss()
                    }
                    .font(.custom("DMSans-Medium", size: 15))
                    .foregroundColor(title.isEmpty ? .gray : .oceanTeal)
                    .disabled(title.isEmpty)
                }
            }
            .onAppear { titleFocused = true }
        }
    }

    private func typeButton(label: String, type: String) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                itemType = type
                streamingService = nil
                showCustomService = false
                customService = ""
            }
        } label: {
            Text(label)
                .font(.custom("DMSans-Medium", size: 13))
                .foregroundColor(itemType == type ? .white : .deepNavy)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(itemType == type ? Color.oceanTeal : Color.mist)
                .clipShape(Capsule())
                .fixedSize()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Edit Watch Item Sheet

struct EditWatchItemSheet: View {
    let item: WatchlistItem
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var itemType = "show"
    @State private var streamingService: String? = nil
    @State private var customService = ""
    @State private var showCustomService = false
    @FocusState private var titleFocused: Bool

    private let showServices = ["Netflix", "HBO Max", "Apple TV+", "Hulu", "Disney+", "Prime Video", "Peacock", "Paramount+", "Showtime", "YouTube", "Other"]
    private let movieServices = ["Netflix", "HBO Max", "Apple TV+", "Hulu", "Disney+", "Prime Video", "Peacock", "Paramount+", "Showtime", "Starz", "YouTube", "Other"]
    private let bookServices = ["Kindle", "Audible", "Library", "Physical", "Other"]

    private var services: [String] {
        switch itemType {
        case "book": return bookServices
        case "movie": return movieServices
        default: return showServices
        }
    }

    private var knownServices: [String] {
        showServices + movieServices + bookServices
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Title...", text: $title)
                        .font(.custom("DMSans-Regular", size: 16))
                        .foregroundColor(.deepNavy)
                        .focused($titleFocused)
                } header: {
                    Text("Title").font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).textCase(nil)
                }

                Section {
                    HStack(spacing: 8) {
                        typeButton(label: "📺 Show", type: "show")
                        typeButton(label: "🎬 Movie", type: "movie")
                        typeButton(label: "📚 Book", type: "book")
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } header: {
                    Text("Type").font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).textCase(nil)
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(services, id: \.self) { service in
                                Button {
                                    if service == "Other" {
                                        showCustomService = true
                                        streamingService = nil
                                    } else {
                                        streamingService = service
                                        showCustomService = false
                                        customService = ""
                                    }
                                } label: {
                                    Text(service)
                                        .font(.custom("DMSans-Medium", size: 13))
                                        .foregroundColor(streamingService == service ? .white : .deepNavy)
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(streamingService == service ? Color.oceanTeal : Color.mist)
                                        .clipShape(Capsule())
                                        .fixedSize()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    if showCustomService {
                        TextField("Service name...", text: $customService)
                            .font(.custom("DMSans-Regular", size: 15))
                            .foregroundColor(.deepNavy)
                            .onChange(of: customService) { _, val in
                                streamingService = val.isEmpty ? nil : val
                            }
                    }
                } header: {
                    Text("Where to watch / read").font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.gray)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        let trimmed = title.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        item.title = trimmed
                        item.itemType = itemType
                        item.streamingService = streamingService
                        dismiss()
                    }
                    .font(.custom("DMSans-Medium", size: 15))
                    .foregroundColor(title.isEmpty ? .gray : .oceanTeal)
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                title = item.title
                itemType = item.itemType
                let existing = item.streamingService
                if let existing {
                    if knownServices.contains(existing) {
                        streamingService = existing
                    } else {
                        streamingService = existing
                        customService = existing
                        showCustomService = true
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func typeButton(label: String, type: String) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                itemType = type
                streamingService = nil
                showCustomService = false
                customService = ""
            }
        } label: {
            Text(label)
                .font(.custom("DMSans-Medium", size: 13))
                .foregroundColor(itemType == type ? .white : .deepNavy)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(itemType == type ? Color.oceanTeal : Color.mist)
                .clipShape(Capsule())
                .fixedSize()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Rate Watch Item Sheet

struct RateWatchItemSheet: View {
    let item: WatchlistItem
    @Environment(\.dismiss) private var dismiss

    @State private var rating: Int = 0
    @State private var comment: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(item.title)
                        .font(.custom("DMSans-Medium", size: 16)).foregroundColor(.deepNavy)
                } header: {
                    Text("Finished").font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).textCase(nil)
                }

                Section {
                    HStack(spacing: 16) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                withAnimation(.spring(duration: 0.2)) { rating = star }
                            } label: {
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.system(size: 34))
                                    .foregroundColor(star <= rating ? .coral : .gray.opacity(0.3))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } header: {
                    Text("Rating").font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).textCase(nil)
                }

                Section {
                    TextField("What did you think? (optional)", text: $comment, axis: .vertical)
                        .font(.custom("DMSans-Regular", size: 15))
                        .foregroundColor(.deepNavy)
                        .lineLimit(4)
                } header: {
                    Text("Comment").font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Rate it")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }.foregroundColor(.gray)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        if rating > 0 { item.rating = rating }
                        if !comment.trimmingCharacters(in: .whitespaces).isEmpty {
                            item.comment = comment
                        }
                        dismiss()
                    }
                    .font(.custom("DMSans-Medium", size: 15))
                    .foregroundColor(.oceanTeal)
                }
            }
            .onAppear {
                rating = item.rating ?? 0
                comment = item.comment ?? ""
            }
        }
        .presentationDetents([.medium])
    }
}
