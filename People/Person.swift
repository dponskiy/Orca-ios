//
//  Person.swift
//  Orca
//
//  Created by David Piliponskiy on 3/29/26.
//

import SwiftData
import Foundation

@Model
class Person {
    var id: UUID = UUID()
    var name: String
    var relationship: String?
    var birthday: Date?
    var notes: String?
    var email: String?
    var linkedMemoryIds: [UUID] = []
    var excludedMemoryIds: [UUID] = []
    var occasionBudgets: [String: Double] = [:]
    var occasionDates: [String: Date] = [:]
    var customOccasions: [String] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(name: String, relationship: String? = nil, birthday: Date? = nil) {
        self.name = name
        self.relationship = relationship
        self.birthday = birthday
    }

    var defaultOccasions: [String] {
        ["Birthday", "Christmas", "Valentine's Day", "Mother's Day",
         "Father's Day", "Anniversary", "Graduation", "Hanukkah", "Wedding"]
    }

    var allOccasions: [String] {
        let all = defaultOccasions + customOccasions.filter { !defaultOccasions.contains($0) }
        return all.sorted { a, b in
            let daysA = daysUntilOccasion(a) ?? Int.max
            let daysB = daysUntilOccasion(b) ?? Int.max
            return daysA < daysB
        }
    }

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1)).uppercased() + String(parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var daysUntilBirthday: Int? {
        guard let birthday = birthday else { return nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var components = cal.dateComponents([.month, .day], from: birthday)
        components.year = cal.component(.year, from: today)
        var next = cal.date(from: components) ?? birthday
        if next < today { next = cal.date(byAdding: .year, value: 1, to: next) ?? next }
        return cal.dateComponents([.day], from: today, to: next).day
    }

    func daysUntilOccasion(_ occasion: String) -> Int? {
        let date: Date?
        if occasion == "Birthday" {
            date = birthday
        } else {
            date = occasionDates[occasion]
        }
        guard let d = date else { return nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var components = cal.dateComponents([.month, .day], from: d)
        components.year = cal.component(.year, from: today)
        var next = cal.date(from: components) ?? d
        if next < today { next = cal.date(byAdding: .year, value: 1, to: next) ?? next }
        return cal.dateComponents([.day], from: today, to: next).day
    }

    func occasionDateDisplay(_ occasion: String) -> String? {
        let date: Date?
        if occasion == "Birthday" {
            date = birthday
        } else {
            date = occasionDates[occasion]
        }
        return date?.formatted(.dateTime.month(.abbreviated).day())
    }

    var birthdayDisplayString: String? {
        guard let birthday = birthday else { return nil }
        return birthday.formatted(.dateTime.month(.abbreviated).day())
    }

    var colorIndex: Int {
        abs(name.unicodeScalars.reduce(0) { $0 + Int($1.value) }) % 5
    }
}
