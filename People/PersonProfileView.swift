//
//  PersonProfileView.swift
//  Orca
//
//  Created by David Piliponskiy on 3/29/26.
//

import SwiftUI
import SwiftData

struct PersonProfileView: View {
    @Bindable var person: Person
    @Query private var allMemories: [Memory]
    @Query private var allGiftItems: [GiftItem]
    @Environment(\.modelContext) private var modelContext

    @State private var showAddGift = false
    @State private var showEditPerson = false
    @State private var showAddEvent = false
    @State private var showSetDate = false
    @State private var showSetBudget = false
    @State private var newEventName = ""
    @State private var selectedOccasion = "Birthday"
    @State private var detailMemory: Memory?
    @State private var editingGiftItem: GiftItem? = nil
    @State private var budgetText = ""
    @State private var occasionDatePickerDate = Date()

    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }

    private var giftItems: [GiftItem] {
        allGiftItems
            .filter { $0.personId == person.id && $0.occasion == selectedOccasion && $0.year == currentYear }
            .sorted { !$0.isPurchased && $1.isPurchased }
    }

    private var totalSpent: Double {
        giftItems.filter { $0.isPurchased }.compactMap { $0.price }.reduce(0, +)
    }

    private var budgetForOccasion: Double? {
        person.occasionBudgets[selectedOccasion]
    }

    private var linkedMemories: [Memory] {
        let firstName = person.name.split(separator: " ").first.map(String.init) ?? person.name
        guard firstName.count > 2 else { return [] }
        let explicit = allMemories.filter {
            person.linkedMemoryIds.contains($0.id) &&
            !person.excludedMemoryIds.contains($0.id)
        }
        let mentioned = allMemories.filter { memory in
            !person.linkedMemoryIds.contains(memory.id) &&
            !person.excludedMemoryIds.contains(memory.id) &&
            memory.text.localizedCaseInsensitiveContains(firstName)
        }
        return (explicit + mentioned)
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(10).map { $0 }
    }

    private func unlinkMemory(_ memory: Memory) {
        person.linkedMemoryIds.removeAll { $0 == memory.id }
        if !person.excludedMemoryIds.contains(memory.id) {
            person.excludedMemoryIds.append(memory.id)
        }
        person.updatedAt = Date()
    }

    // Auto-set known fixed dates when occasion is selected
    private func autoSetDateIfNeeded(for occasion: String) {
        guard person.occasionDates[occasion] == nil else { return }
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        var components = DateComponents()
        components.year = year

        switch occasion {
        case "Christmas":
            components.month = 12; components.day = 25
        case "New Year's":
            components.month = 1; components.day = 1
        case "Valentine's Day":
            components.month = 2; components.day = 14
        case "Halloween":
            components.month = 10; components.day = 31
        default:
            return
        }

        if let date = cal.date(from: components) {
            // If date already passed this year, set to next year
            let finalDate = date < Date()
                ? cal.date(byAdding: .year, value: 1, to: date) ?? date
                : date
            person.occasionDates[occasion] = finalDate
            person.updatedAt = Date()
        }
    }

    private var colors: (background: Color, text: Color) {
        avatarColors(for: person.colorIndex)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                profileHeader
                giftPlanningCard
                if !linkedMemories.isEmpty { memoriesCard }
                Spacer().frame(height: 40)
            }
            .padding(20)
        }
        .background(Color.pearl)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { showEditPerson = true } label: {
                    Image(systemName: "pencil").foregroundColor(.oceanTeal)
                }
            }
        }
        .sheet(isPresented: $showAddGift) {
            AddGiftItemView(person: person, occasion: selectedOccasion)
        }
        .sheet(item: $editingGiftItem) { item in
            AddGiftItemView(person: person, occasion: selectedOccasion, existingItem: item)
        }
        .sheet(isPresented: $showEditPerson) {
            AddPersonView(person: person)
        }
        .sheet(item: $detailMemory) { MemoryDetailView(memory: $0) }
        .sheet(isPresented: $showAddEvent) { addEventSheet }
        .sheet(isPresented: $showSetDate) { setDateSheet }
        .sheet(isPresented: $showSetBudget) { setBudgetSheet }
        .onAppear {
            selectedOccasion = person.allOccasions.first ?? "Birthday"
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(colors.background).frame(width: 68, height: 68)
                Text(person.initials)
                    .font(.custom("DMSans-Medium", size: 24))
                    .foregroundColor(colors.text)
            }
            VStack(spacing: 4) {
                Text(person.name)
                    .font(.custom("DMSans-Medium", size: 20)).foregroundColor(.deepNavy)
                HStack(spacing: 6) {
                    if let rel = person.relationship {
                        Text(rel.capitalized)
                            .font(.custom("DMSans-Regular", size: 13)).foregroundColor(.gray)
                    }
                    if person.relationship != nil && person.birthday != nil {
                        Text("·").font(.custom("DMSans-Regular", size: 13)).foregroundColor(.gray)
                    }
                    if let bd = person.birthdayDisplayString {
                        Text("Birthday \(bd)")
                            .font(.custom("DMSans-Regular", size: 13)).foregroundColor(.gray)
                    }
                    if let days = person.daysUntilBirthday {
                        Text("· \(days == 0 ? "Today!" : "in \(days)d")")
                            .font(.custom("DMSans-Medium", size: 13))
                            .foregroundColor(days <= 7 ? .coral : .oceanTeal)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - Gift Planning Card

    private var giftPlanningCard: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack {
                Text("GIFT PLANNING")
                    .font(.custom("DMSans-Medium", size: 11))
                    .foregroundColor(.gray).tracking(0.5)
                Spacer()
                Button { showAddEvent = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.plus").font(.system(size: 11))
                        Text("Add event").font(.custom("DMSans-Medium", size: 12))
                    }
                    .foregroundColor(.gray)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.mist)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.gray.opacity(0.2), lineWidth: 0.5))
                }
                .padding(.trailing, 6)
                Button { showAddGift = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 11, weight: .medium))
                        Text("Add idea").font(.custom("DMSans-Medium", size: 12))
                    }
                    .foregroundColor(.oceanTeal)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.oceanTeal.opacity(0.08))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            // Occasion pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(person.allOccasions, id: \.self) { occasion in
                        Button {
                            selectedOccasion = occasion
                            autoSetDateIfNeeded(for: occasion)
                        } label: {
                            VStack(spacing: 2) {
                                Text(occasion)
                                    .font(.custom("DMSans-Medium", size: 12))
                                    .foregroundColor(selectedOccasion == occasion ? .white : .oceanTeal)
                                if let days = person.daysUntilOccasion(occasion),
                                   let dateStr = person.occasionDateDisplay(occasion) {
                                    Text(days == 0 ? "Today!" : "\(dateStr) · \(days)d")
                                        .font(.custom("DMSans-Regular", size: 9))
                                        .foregroundColor(selectedOccasion == occasion ? .white.opacity(0.8) : .oceanTeal.opacity(0.7))
                                }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(selectedOccasion == occasion ? Color.oceanTeal : Color.oceanTeal.opacity(0.08))
                            .clipShape(Capsule())
                        }
                        .contextMenu {
                            if person.customOccasions.contains(occasion) {
                                Button(role: .destructive) {
                                    person.customOccasions.removeAll { $0 == occasion }
                                    person.occasionDates.removeValue(forKey: occasion)
                                    person.occasionBudgets.removeValue(forKey: occasion)
                                    person.updatedAt = Date()
                                    selectedOccasion = person.allOccasions.first ?? "Birthday"
                                } label: {
                                    Label("Delete \(occasion)", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 10)

            // Set date link for non-birthday occasions
            if selectedOccasion != "Birthday" {
                Button {
                    occasionDatePickerDate = person.occasionDates[selectedOccasion] ?? Date()
                    showSetDate = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12)).foregroundColor(.oceanTeal)
                        if let dateStr = person.occasionDateDisplay(selectedOccasion) {
                            Text("Date: \(dateStr)")
                                .font(.custom("DMSans-Regular", size: 12)).foregroundColor(.oceanTeal)
                        } else {
                            Text("Set date for \(selectedOccasion)")
                                .font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 10)
                }
            }

            // Budget strip
            Divider().padding(.horizontal, 16)
            Button {
                budgetText = budgetForOccasion.map {
                    $0.truncatingRemainder(dividingBy: 1) == 0 ? String(Int($0)) : String(format: "%.2f", $0)
                } ?? ""
                showSetBudget = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 16)).foregroundColor(budgetForOccasion != nil ? .oceanTeal : .gray.opacity(0.4))

                    if let budget = budgetForOccasion {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("$\(Int(totalSpent)) of $\(Int(budget)) budget")
                                    .font(.custom("DMSans-Medium", size: 13)).foregroundColor(.deepNavy)
                                if totalSpent >= budget {
                                    Text("· over budget!")
                                        .font(.custom("DMSans-Medium", size: 12)).foregroundColor(.coral)
                                }
                            }
                            // Mini progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2).fill(Color.mist).frame(height: 3)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(totalSpent >= budget ? Color.coral : Color.oceanTeal)
                                        .frame(width: geo.size.width * CGFloat(min(1, totalSpent / budget)), height: 3)
                                }
                            }
                            .frame(height: 3)
                        }
                    } else {
                        Text("Set a budget for \(selectedOccasion)")
                            .font(.custom("DMSans-Regular", size: 13)).foregroundColor(.gray)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11)).foregroundColor(.gray.opacity(0.3))
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            // Gift items
            Divider().padding(.horizontal, 16)
            if giftItems.isEmpty {
                VStack(spacing: 8) {
                    Text("No gift ideas for \(selectedOccasion) yet")
                        .font(.custom("DMSans-Regular", size: 14)).foregroundColor(.gray)
                    Button { showAddGift = true } label: {
                        Text("Add first idea")
                            .font(.custom("DMSans-Medium", size: 13)).foregroundColor(.oceanTeal)
                    }
                }
                .frame(maxWidth: .infinity).padding(20)
            } else {
                ForEach(giftItems) { item in
                    giftItemRow(item: item)
                    if item.id != giftItems.last?.id {
                        Divider().padding(.horizontal, 16)
                    }
                }
                Spacer().frame(height: 8)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - Gift Item Row

    @ViewBuilder
    private func giftItemRow(item: GiftItem) -> some View {
        Button { editingGiftItem = item } label: {
            HStack(spacing: 12) {

                // Purchased toggle
                Button {
                    withAnimation(.spring(duration: 0.2)) {
                        item.status = item.isPurchased ? .idea : .purchased
                    }
                } label: {
                    ZStack {
                        Circle()
                            .stroke(item.isPurchased ? Color.oceanTeal : Color.gray.opacity(0.25), lineWidth: 1.5)
                            .frame(width: 24, height: 24)
                        if item.isPurchased {
                            Circle().fill(Color.oceanTeal).frame(width: 24, height: 24)
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)

                // Name + meta
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.custom("DMSans-Regular", size: 14))
                        .foregroundColor(item.isPurchased ? .gray : .deepNavy)
                        .strikethrough(item.isPurchased)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        if let price = item.price {
                            Text("$\(price.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(price)) : String(format: "%.2f", price))")
                                .font(.custom("DMSans-Medium", size: 12))
                                .foregroundColor(item.isPurchased ? .oceanTeal : .deepNavy)
                        } else {
                            Text("No price")
                                .font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray.opacity(0.6))
                        }
                        if let urlStr = item.url, !urlStr.isEmpty, let link = URL(string: urlStr) {
                            Button { UIApplication.shared.open(link) } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "link").font(.system(size: 10))
                                    Text(link.host ?? "Link").font(.custom("DMSans-Regular", size: 11))
                                }
                                .foregroundColor(.oceanTeal)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer()

                // Status badge
                Text(item.isPurchased ? "purchased" : "idea")
                    .font(.custom("DMSans-Medium", size: 11))
                    .foregroundColor(item.isPurchased ? .oceanTeal : .gray)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(item.isPurchased ? Color.oceanTeal.opacity(0.1) : Color.mist)
                    .clipShape(Capsule())

                Image(systemName: "chevron.right")
                    .font(.system(size: 11)).foregroundColor(.gray.opacity(0.3))
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Set Budget Sheet

    private var setBudgetSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("BUDGET FOR \(selectedOccasion.uppercased())")
                        .font(.custom("DMSans-Medium", size: 11))
                        .foregroundColor(.gray).tracking(0.5)

                    HStack(spacing: 8) {
                        Text("$")
                            .font(.custom("DMSans-Medium", size: 28)).foregroundColor(.gray)
                        TextField("0", text: $budgetText)
                            .font(.custom("DMSans-Medium", size: 28))
                            .foregroundColor(.deepNavy)
                            .keyboardType(.decimalPad)
                    }
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))

                    if totalSpent > 0 {
                        Text("$\(Int(totalSpent)) already spent on purchased items")
                            .font(.custom("DMSans-Regular", size: 13)).foregroundColor(.gray)
                    }
                }
                .padding(20)

                if budgetForOccasion != nil {
                    Button {
                        person.occasionBudgets.removeValue(forKey: selectedOccasion)
                        person.updatedAt = Date()
                        showSetBudget = false
                    } label: {
                        Text("Remove budget")
                            .font(.custom("DMSans-Medium", size: 14)).foregroundColor(.coral)
                    }
                }

                Spacer()
            }
            .background(Color.pearl)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showSetBudget = false }.foregroundColor(.gray)
                }
                ToolbarItem(placement: .principal) {
                    Text("Set Budget")
                        .font(.custom("DMSans-Medium", size: 17)).foregroundColor(.deepNavy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let val = Double(budgetText), val > 0 {
                            person.occasionBudgets[selectedOccasion] = val
                        }
                        person.updatedAt = Date()
                        showSetBudget = false
                    }
                    .font(.custom("DMSans-Medium", size: 16)).foregroundColor(.oceanTeal)
                }
            }
        }
        .presentationDetents([.height(280)])
    }

    // MARK: - Add Event Sheet

    private var addEventSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("EVENT NAME")
                        .font(.custom("DMSans-Medium", size: 11))
                        .foregroundColor(.gray).tracking(0.5)
                    TextField("e.g. Graduation, Wedding, Housewarming", text: $newEventName)
                        .font(.custom("DMSans-Regular", size: 15))
                        .foregroundColor(.deepNavy)
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
                }
                .padding(20)
                Spacer()
            }
            .background(Color.pearl)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newEventName = ""
                        showAddEvent = false
                    }.foregroundColor(.gray)
                }
                ToolbarItem(placement: .principal) {
                    Text("Add Event")
                        .font(.custom("DMSans-Medium", size: 17)).foregroundColor(.deepNavy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = newEventName.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty && !person.allOccasions.contains(trimmed) {
                            person.customOccasions.append(trimmed)
                            person.updatedAt = Date()
                            selectedOccasion = trimmed
                            autoSetDateIfNeeded(for: trimmed)
                        }
                        newEventName = ""
                        showAddEvent = false
                    }
                    .font(.custom("DMSans-Medium", size: 16))
                    .foregroundColor(newEventName.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .oceanTeal)
                    .disabled(newEventName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }

    // MARK: - Set Date Sheet

    private var setDateSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker("", selection: $occasionDatePickerDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(.oceanTeal)
                    .padding(20)
                Spacer()
            }
            .background(Color.pearl)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showSetDate = false }.foregroundColor(.gray)
                }
                ToolbarItem(placement: .principal) {
                    Text("Date for \(selectedOccasion)")
                        .font(.custom("DMSans-Medium", size: 17)).foregroundColor(.deepNavy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        person.occasionDates[selectedOccasion] = occasionDatePickerDate
                        person.updatedAt = Date()
                        showSetDate = false
                    }
                    .font(.custom("DMSans-Medium", size: 16)).foregroundColor(.oceanTeal)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Memories Card

    private var memoriesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("MEMORIES ABOUT \(person.name.uppercased())")
                    .font(.custom("DMSans-Medium", size: 11))
                    .foregroundColor(.gray).tracking(0.5)
                Spacer()
                Text("\(linkedMemories.count)")
                    .font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            ForEach(Array(linkedMemories.enumerated()), id: \.element.id) { index, memory in
                if index > 0 { Divider().padding(.horizontal, 16) }
                HStack(spacing: 10) {
                    Button { detailMemory = memory } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "note.text")
                                .font(.system(size: 12)).foregroundColor(.gray).frame(width: 18)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(memory.text)
                                    .font(.custom("DMSans-Regular", size: 13))
                                    .foregroundColor(.deepNavy).lineLimit(2)
                                Text(memory.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                                    .font(.custom("DMMono-Regular", size: 11)).foregroundColor(.gray)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { unlinkMemory(memory) }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18)).foregroundColor(.gray.opacity(0.35))
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }

            if linkedMemories.isEmpty {
                Text("No memories linked yet")
                    .font(.custom("DMSans-Regular", size: 13)).foregroundColor(.gray)
                    .frame(maxWidth: .infinity).padding(20)
            }

            Spacer().frame(height: 8)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - Color Helper

    private func avatarColors(for index: Int) -> (background: Color, text: Color) {
        let palette: [(Color, Color)] = [
            (Color(red: 0.878, green: 0.961, blue: 0.933), Color(red: 0.059, green: 0.431, blue: 0.337)),
            (Color(red: 0.980, green: 0.933, blue: 0.851), Color(red: 0.522, green: 0.310, blue: 0.043)),
            (Color(red: 0.902, green: 0.945, blue: 0.984), Color(red: 0.094, green: 0.373, blue: 0.647)),
            (Color(red: 0.980, green: 0.925, blue: 0.906), Color(red: 0.600, green: 0.235, blue: 0.110)),
            (Color(red: 0.933, green: 0.929, blue: 0.996), Color(red: 0.325, green: 0.290, blue: 0.718)),
        ]
        return palette[index % palette.count]
    }
}
