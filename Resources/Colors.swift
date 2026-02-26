//
//  Colors.swift
//  Orca
//
//  Created by David Piliponskiy on 2/24/26.
//

import SwiftUI

extension Color {
    static let deepNavy  = Color(hex: "0B1D33")
    static let orcaBlue  = Color(hex: "1A3A5C")
    static let oceanTeal = Color(hex: "2E8B9A")
    static let seafoam   = Color(hex: "5BB8C4")
    static let mist      = Color(hex: "E8F4F8")
    static let pearl     = Color(hex: "F7FAFB")
    static let coral     = Color(hex: "E8705A")
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}
