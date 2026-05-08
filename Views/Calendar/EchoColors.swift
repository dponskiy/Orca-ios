//
//  EchoColors.swift
//  Orca
//
//  Created by David Piliponskiy on 4/19/26.
//

import SwiftUI

struct EchoColors {

    // MARK: - Color Lookup

    static func color(for echoName: String) -> Color {
        switch echoName {
        case "To-Do":    return Color(echoHex: "#1D9E75")
        case "Work":     return Color(echoHex: "#378ADD")
        case "Health":   return Color(echoHex: "#D85A30")
        case "Travel":   return Color(echoHex: "#7F77DD")
        case "Dining":   return Color(echoHex: "#BA7517")
        case "Workout":  return Color(echoHex: "#639922")
        case "Finance":  return Color(echoHex: "#0F6E56")
        case "Sports":   return Color(echoHex: "#E07A2F")
        case "Events":   return Color(echoHex: "#5DCAA5")
        case "Shopping": return Color(echoHex: "#D4537E")
        case "Home":     return Color(echoHex: "#8B6A4E")
        case "School":   return Color(echoHex: "#5B8DD9")
        case "Pets":     return Color(echoHex: "#639922")
        case "Kids":     return Color(echoHex: "#D4537E")
        case "Birthday": return Color(echoHex: "#D85A30")
        case "Gifts":    return Color(echoHex: "#D4537E")
        case "Holidays": return Color(echoHex: "#D85A30")
        case "Games":    return Color(echoHex: "#7F77DD")
        case "Movies":   return Color(echoHex: "#7F77DD")
        case "Books":    return Color(echoHex: "#BA7517")
        case "Clothes":  return Color(echoHex: "#D4537E")
        case "Cooking":  return Color(echoHex: "#BA7517")
        default:         return Color(echoHex: "#888780")
        }
    }

    // MARK: - Heatmap Opacity

    static func heatmapOpacity(for count: Int) -> Double {
        switch count {
        case 1:  return 0.06
        case 2:  return 0.09
        case 3:  return 0.13
        default: return 0.18
        }
    }
}

// MARK: - Hex Color Init
// Named `echoHex` to avoid conflict with any existing Color(hex:) in the project.
// If you already have Color(hex:) defined, replace all Color(echoHex:) calls above
// with Color(hex:) and delete this extension.
extension Color {
    init(echoHex: String) {
        let hex = echoHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
