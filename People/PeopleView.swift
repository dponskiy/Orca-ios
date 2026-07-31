//
//  PeopleView.swift
//  Orca
//
//  Created by David Piliponskiy on 3/29/26.
//

import SwiftUI
import SwiftData

struct UpcomingOccasionEntry: Identifiable {
    let id: String
    let person: Person
    let occasion: String
    let days: Int
}

struct PeopleView: View {
    @Query(sort: \Person.name) private var persons: [Person]
    @Query private var giftItems: [GiftItem]
    @Environment(\.modelContext) private var modelContext

    @State private var showAddPerson = false
    @State private var selectedPerson: Person?
    @State private var showGiftAction = false

    private var deduplicatedPersons: [Person] {
        var seen = Set<UUID>()
        var seenNames = Set<String>()
        return persons.filter { person in
            guard !seen.contains(person.id) else { return false }
            guard !seenNames.contains(person.name.lowercased()) else { return false }
            seen.insert(person.id)
            seenNames.insert(person.name.lowercased())
            return true
        }
    }

    private var upcomingOccasions: [UpcomingOccasionEntry] {
        var results: [UpcomingOccasionEntry] = []
        for person in deduplicatedPersons {
            for occasion in person.allOccasions {
                if let days = person.daysUntilOccasion(occasion), days <= 90 {
                    results.append(UpcomingOccasionEntry(
                        id: "\(person.id.uuidString)-\(occasion)",
                        person: person,
                        occasion: occasion,
                        days: days
                    ))
                }
            }
        }
        return results.sorted { $0.days < $1.days }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // My Wishlist — always visible
                    wishlistCard

                    if deduplicatedPersons.isEmpty {
                        emptyState
                    } else {

                        // Coming up — birthdays + all occasions with dates set
                        if !upcomingOccasions.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("COMING UP")
                                    .font(.custom("DMSans-Medium", size: 11))
                                    .foregroundColor(.gray)
                                    .tracking(0.5)

                                ForEach(upcomingOccasions) { entry in
                                    NavigationLink(destination: PersonProfileView(person: entry.person)) {
                                        occasionCard(person: entry.person, occasion: entry.occasion, days: entry.days)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Your people grid
                        VStack(alignment: .leading, spacing: 10) {
                            Text("YOUR PEOPLE")
                                .font(.custom("DMSans-Medium", size: 11))
                                .foregroundColor(.gray)
                                .tracking(0.5)

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                            ], spacing: 16) {
                                ForEach(deduplicatedPersons) { person in
                                    NavigationLink(destination: PersonProfileView(person: person)) {
                                        personBubble(person: person)
                                    }
                                    .buttonStyle(.plain)
                                }

                                Button { showAddPerson = true } label: {
                                    VStack(spacing: 6) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.mist)
                                                .frame(width: 52, height: 52)
                                            Circle()
                                                .stroke(Color.gray.opacity(0.25),
                                                        style: StrokeStyle(lineWidth: 1, dash: [4]))
                                                .frame(width: 52, height: 52)
                                            Image(systemName: "plus")
                                                .font(.system(size: 18))
                                                .foregroundColor(.gray)
                                        }
                                        Text("Add")
                                            .font(.custom("DMSans-Regular", size: 12))
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                    }

                    Spacer().frame(height: 100)
                }
                .padding(20)
            }
            .background(Color.pearl)
            .navigationTitle("People")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { showAddPerson = true } label: {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(.oceanTeal)
                    }
                }
            }
            .sheet(isPresented: $showAddPerson) {
                AddPersonView()
            }
            .sheet(isPresented: $showGiftAction) {
                GiftQuickActionView(openWishlistDirectly: true)
            }
        }
    }

    // MARK: - My Wishlist Card

    private var wishlistItems: [GiftItem] {
        giftItems.filter { $0.personId == GiftItem.wishlistPersonId }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var wishlistCard: some View {
        Button { showGiftAction = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.oceanTeal.opacity(0.12)).frame(width: 44, height: 44)
                    Image(systemName: "star.fill").font(.system(size: 17)).foregroundColor(.oceanTeal)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("My Wishlist")
                        .font(.custom("DMSans-Medium", size: 15))
                        .foregroundColor(.deepNavy)
                    if wishlistItems.isEmpty {
                        Text("Add things you want")
                            .font(.custom("DMSans-Regular", size: 12))
                            .foregroundColor(.gray)
                    } else {
                        let purchased = wishlistItems.filter { $0.isPurchased }.count
                        let total = wishlistItems.count
                        Text("\(total) \(total == 1 ? "item" : "items")\(purchased > 0 ? " · \(purchased) purchased" : "")")
                            .font(.custom("DMSans-Regular", size: 12))
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray.opacity(0.3))
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Occasion Card

    private func occasionCard(person: Person, occasion: String, days: Int) -> some View {
        let currentYear = Calendar.current.component(.year, from: Date())
        let personGifts = giftItems.filter { $0.personId == person.id && $0.occasion == occasion && $0.year == currentYear }
        let totalSpent = personGifts.filter { $0.isPurchased }.compactMap { $0.price }.reduce(0, +)
        let ideaCount = personGifts.filter { !$0.isPurchased }.count
        let colors = avatarColors(for: person.colorIndex)
        let dateStr = person.occasionDateDisplay(occasion)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(colors.background).frame(width: 40, height: 40)
                    Text(person.initials)
                        .font(.custom("DMSans-Medium", size: 14))
                        .foregroundColor(colors.text)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(person.name)
                                .font(.custom("DMSans-Medium", size: 14))
                                .foregroundColor(.deepNavy)
                            Text(occasion)
                                .font(.custom("DMSans-Regular", size: 11))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(days == 0 ? "Today!" : "\(days)d")
                                .font(.custom("DMSans-Medium", size: 11))
                                .foregroundColor(days <= 7 ? .white : colors.text)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(days <= 7 ? Color.coral : colors.background)
                                .clipShape(Capsule())
                            if let ds = dateStr {
                                Text(ds)
                                    .font(.custom("DMSans-Regular", size: 10))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .padding(14)

            Divider().padding(.horizontal, 14)

            HStack(spacing: 6) {
                if personGifts.isEmpty {
                    Text("No gift ideas yet")
                        .font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                } else {
                    if ideaCount > 0 {
                        Text("\(ideaCount) \(ideaCount == 1 ? "idea" : "ideas")")
                            .font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                    }
                    if totalSpent > 0 {
                        if ideaCount > 0 {
                            Text("·").font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                        }
                        if let budget = person.occasionBudgets[occasion] {
                            Text("$\(Int(totalSpent)) of $\(Int(budget)) spent")
                                .font(.custom("DMSans-Regular", size: 12)).foregroundColor(.oceanTeal)
                        } else {
                            Text("$\(Int(totalSpent)) spent")
                                .font(.custom("DMSans-Regular", size: 12)).foregroundColor(.oceanTeal)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10)).foregroundColor(.gray.opacity(0.4))
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - Person Bubble

    private func personBubble(person: Person) -> some View {
        let colors = avatarColors(for: person.colorIndex)
        let firstName = person.name.split(separator: " ").first.map(String.init) ?? person.name
        return VStack(spacing: 6) {
            ZStack {
                Circle().fill(colors.background).frame(width: 52, height: 52)
                Text(person.initials)
                    .font(.custom("DMSans-Medium", size: 16))
                    .foregroundColor(colors.text)
                let hasUpcoming = person.allOccasions.contains { occ in
                    (person.daysUntilOccasion(occ) ?? 999) <= 14
                }
                if hasUpcoming {
                    Circle()
                        .fill(Color.coral)
                        .frame(width: 10, height: 10)
                        .offset(x: 18, y: -18)
                }
            }
            Text(firstName)
                .font(.custom("DMSans-Regular", size: 12))
                .foregroundColor(.deepNavy)
                .lineLimit(1)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            ZStack {
                Circle().fill(Color.mist).frame(width: 72, height: 72)
                Image(systemName: "person.2")
                    .font(.system(size: 28)).foregroundColor(.oceanTeal)
            }
            Text("Add the people in your life")
                .font(.custom("DMSans-Medium", size: 18)).foregroundColor(.deepNavy)
            Text("Track birthdays, gift ideas, and everything worth remembering about the people who matter.")
                .font(.custom("DMSans-Regular", size: 14)).foregroundColor(.gray)
                .multilineTextAlignment(.center).padding(.horizontal, 20)
            Button { showAddPerson = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.plus").font(.system(size: 14))
                    Text("Add a person").font(.custom("DMSans-Medium", size: 14))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(Color.oceanTeal).clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Color Helper

    func avatarColors(for index: Int) -> (background: Color, text: Color) {
        let colors: [(Color, Color)] = [
            (Color(red: 0.878, green: 0.961, blue: 0.933), Color(red: 0.059, green: 0.431, blue: 0.337)),
            (Color(red: 0.980, green: 0.933, blue: 0.851), Color(red: 0.522, green: 0.310, blue: 0.043)),
            (Color(red: 0.902, green: 0.945, blue: 0.984), Color(red: 0.094, green: 0.373, blue: 0.647)),
            (Color(red: 0.980, green: 0.925, blue: 0.906), Color(red: 0.600, green: 0.235, blue: 0.110)),
            (Color(red: 0.933, green: 0.929, blue: 0.996), Color(red: 0.325, green: 0.290, blue: 0.718)),
        ]
        return colors[index % colors.count]
    }
}
