//
//  FinIcon.swift
//  Orca
//
//  Created by David Piliponskiy on 2/24/26.
//

import SwiftUI

struct FinIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        var path = Path()

        // Left base
        path.move(to: CGPoint(x: w * 0.22, y: h))

        // Leading edge — nearly perfectly straight vertical line up to tip
        path.addLine(to: CGPoint(x: w * 0.24, y: 0))

        // Tip — slight rounded point
        path.addCurve(
            to: CGPoint(x: w * 0.32, y: h * 0.08),
            control1: CGPoint(x: w * 0.26, y: 0),
            control2: CGPoint(x: w * 0.30, y: h * 0.03)
        )

        // Trailing edge — long concave sweep back down to right base
        path.addCurve(
            to: CGPoint(x: w * 0.78, y: h),
            control1: CGPoint(x: w * 0.52, y: h * 0.28),
            control2: CGPoint(x: w * 0.68, y: h * 0.65)
        )

        path.closeSubpath()
        return path
    }
}

#Preview {
    FinIcon()
        .fill(Color.oceanTeal)
        .frame(width: 60, height: 72)
}
