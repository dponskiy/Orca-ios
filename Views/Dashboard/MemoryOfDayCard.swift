//
//  MemoryOfDayCard.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI

struct MemoryOfDayCard: View {
    let memory: Memory
    let echos: [Echo]
    let onDismiss: () -> Void
    
    var echo: Echo? {
        echos.first { $0.id == memory.echoId }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundColor(.oceanTeal)
                Text("MEMORY OF THE DAY")
                    .font(.custom("DMSans-Medium", size: 11))
                    .foregroundColor(.oceanTeal)
                    .tracking(1)
                
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(width: 24, height: 24)
                        .background(Color.pearl)
                        .clipShape(Circle())
                }
            }
            
            Text(memory.text)
                .font(.custom("InstrumentSerif-Regular", size: 18))
                .foregroundColor(.deepNavy)
                .lineLimit(3)
            
            HStack(spacing: 8) {
                if let echo = echo {
                    HStack(spacing: 4) {
                        Text(echo.emoji)
                            .font(.system(size: 12))
                        Text(echo.name)
                            .font(.custom("DMSans-Medium", size: 12))
                            .foregroundColor(.deepNavy)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.mist)
                    .clipShape(Capsule())
                }
                
                if let date = memory.detectedDate {
                    HStack(spacing: 4) {
                        Text("📅")
                            .font(.system(size: 11))
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(.custom("DMMono-Regular", size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Text(memory.createdAt, format: .dateTime.month(.abbreviated).day().year())
                    .font(.custom("DMMono-Regular", size: 11))
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}
