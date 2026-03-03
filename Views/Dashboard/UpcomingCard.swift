//
//  MemoryOfDayCard.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI

struct UpcomingCard: View {
    let memory: Memory
    let echos: [Echo]
    let isPinned: Bool
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    var echo: Echo? {
        echos.first { $0.id == memory.echoId }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.coral)
                    Text("PINNED")
                        .font(.custom("DMSans-Medium", size: 11))
                        .foregroundColor(.coral)
                        .tracking(1)
                } else {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundColor(.oceanTeal)
                    Text("COMING UP")
                        .font(.custom("DMSans-Medium", size: 11))
                        .foregroundColor(.oceanTeal)
                        .tracking(1)
                }
                
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
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
                        Text(date, format: .dateTime.month(.abbreviated).day().hour().minute())
                            .font(.custom("DMMono-Regular", size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    UpcomingCard(
        memory: Memory(text: "Liverpool game at 10am", echoId: UUID()),
        echos: [],
        isPinned: false,
        onTap: {},
        onDismiss: {}
    )
    .padding()
    .background(Color.pearl)
}
