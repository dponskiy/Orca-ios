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
        path.move(to: CGPoint(x: w * 0.15, y: h))
        
        // Left curve up to tip
        path.addCurve(
            to: CGPoint(x: w * 0.55, y: 0),
            control1: CGPoint(x: w * 0.18, y: h * 0.6),
            control2: CGPoint(x: w * 0.35, y: h * 0.1)
        )
        
        // Tip curve
        path.addCurve(
            to: CGPoint(x: w * 0.65, y: h * 0.12),
            control1: CGPoint(x: w * 0.6, y: 0),
            control2: CGPoint(x: w * 0.63, y: h * 0.04)
        )
        
        // Right curve down
        path.addCurve(
            to: CGPoint(x: w * 0.85, y: h),
            control1: CGPoint(x: w * 0.72, y: h * 0.35),
            control2: CGPoint(x: w * 0.8, y: h * 0.65)
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
