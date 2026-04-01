//
//  PeopleView.swift
//  Orca
//
//  Created by David Piliponskiy on 3/29/26.
//

import SwiftUI
import SwiftData

struct PeopleView: View {
    @Query(sort: \Person.name) private var persons: [Person]
    @Query private var giftItems: [GiftItem]
    @Environment(\.modelContext) private var modelContext

    @State private var showAddPerson = false
    @State private var selectedPerson: Person?

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

    private var upcomingBirthdays: [Person] {
        deduplicatedPersons
            .filter { ($0.daysUntilBirthday ?? 999) <= 90 }
            .sorted { ($0.daysUntilBirthday ?? 999) < ($1.daysUntilBirthday ?? 999) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    if deduplicatedPersons.isEmpty {
                        emptyState
                    } else {

                        // Birthdays coming up
                        if !upcomingBirthdays.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("BIRTHDAYS COMING UP")
                                    .font(.custom("DMSans-Medium", size: 11))
                                    .foregroundColor(.gray)
                                    .tracking(0.5)

                                ForEach(upcomingBirthdays) { person in
                                    NavigationLink(destination: PersonProfileView(person: person)) {
                                        birthdayCard(person: person)
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
        }
    }

    // MARK: - Birthday Card

    private func birthdayCard(person: Person) -> some View {
        let days = person.daysUntilBirthday ?? 0
        let currentYear = Calendar.current.component(.year, from: Date())
        let personGifts = giftItems.filter { $0.personId == person.id && $0.year == currentYear }
        let totalSpent = personGifts.filter { $0.isPurchased }.compactMap { $0.price }.reduce(0, +)
        let ideaCount = personGifts.filter { !$0.isPurchased }.count
        let colors = avatarColors(for: person.colorIndex)

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
                        Text(person.name)
                            .font(.custom("DMSans-Medium", size: 14))
                            .foregroundColor(.deepNavy)
                        Spacer()
                        Text(days == 0 ? "Today!" : "\(days) days")
                            .font(.custom("DMSans-Medium", size: 11))
                            .foregroundColor(days <= 7 ? .white : colors.text)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(days <= 7 ? Color.coral : colors.background)
                            .clipShape(Capsule())
                    }
                    HStack(spacing: 4) {
                        if let rel = person.relationship {
                            Text(rel.capitalized)
                                .font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                        }
                        if person.relationship != nil, person.birthdayDisplayString != nil {
                            Text("·").font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                        }
                        if let bd = person.birthdayDisplayString {
                            Text(bd).font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
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
                        if let budget = person.occasionBudgets["Birthday"] {
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
                if let days = person.daysUntilBirthday, days <= 14 {
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
