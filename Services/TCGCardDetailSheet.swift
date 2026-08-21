//
//  TCGCardDetailSheet.swift
//  Orca

import SwiftUI
import SwiftData

struct TCGCardDetailSheet: View {
    let card: TCGCard
    // Set when shown as an in-place overlay instead of a modal —
    // @Environment(\.dismiss) is inert outside a presentation.
    var onClose: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Card image — full color or grayscale
                    cardImage

                    VStack(alignment: .leading, spacing: 20) {
                        // Title + set
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.name)
                                .font(.custom("DMSans-Medium", size: 22))
                                .foregroundColor(.deepNavy)
                            HStack(spacing: 8) {
                                Text(card.setName)
                                    .font(.custom("DMMono-Regular", size: 13))
                                    .foregroundColor(.gray)
                                if !card.number.isEmpty {
                                    Text("·").foregroundColor(.gray.opacity(0.4))
                                    Text("#\(card.number)")
                                        .font(.custom("DMMono-Regular", size: 13))
                                        .foregroundColor(.gray)
                                }
                                if let rarity = card.rarity {
                                    Text("·").foregroundColor(.gray.opacity(0.4))
                                    Text(rarity)
                                        .font(.custom("DMMono-Regular", size: 13))
                                        .foregroundColor(.gray)
                                }
                            }
                        }

                        // Price strip
                        if card.marketPrice != nil || card.lowPrice != nil {
                            priceStrip
                        }

                        // Status toggle
                        statusToggle

                        // PSA grading
                        psaSection

                        // Remove button
                        Button {
                            let id = card.id
                            modelContext.delete(card)
                            try? modelContext.save()
                            Task { await SupabaseSyncService.shared.deleteTCGCard(id: id) }
                            close()
                        } label: {
                            Text("Remove from Collection")
                                .font(.custom("DMSans-Medium", size: 15))
                                .foregroundColor(.coral)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.coral.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
            .background(Color.pearl.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { close() }.foregroundColor(.oceanTeal)
                }
            }
        }
    }

    private var cardImage: some View {
        ZStack {
            Color.deepNavy.opacity(0.06)
            if let url = URL(string: card.largeImageURL) {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().aspectRatio(contentMode: .fit)
                            .saturation(card.isOwned ? 1 : 0)
                            .animation(.easeInOut(duration: 0.3), value: card.isOwned)
                    } else {
                        ProgressView().tint(.oceanTeal)
                    }
                }
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 340)
    }

    private var priceStrip: some View {
        HStack(spacing: 0) {
            if let market = card.marketPrice {
                priceCell(label: "Market", value: market, highlight: true)
            }
            if let low = card.lowPrice {
                Divider().frame(height: 36)
                priceCell(label: "Low", value: low, highlight: false)
            }
            if let high = card.highPrice {
                Divider().frame(height: 36)
                priceCell(label: "High", value: high, highlight: false)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    private func priceCell(label: String, value: Double, highlight: Bool) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.custom("DMSans-Medium", size: 11))
                .foregroundColor(.gray)
                .tracking(0.4)
            Text("$\(String(format: "%.2f", value))")
                .font(.custom("DMSans-Medium", size: 18))
                .foregroundColor(highlight ? .oceanTeal : .deepNavy)
        }
        .frame(maxWidth: .infinity)
    }

    private var statusToggle: some View {
        HStack(spacing: 12) {
            statusButton(label: "In Collection", icon: "checkmark.circle.fill",
                         active: card.isOwned, color: .oceanTeal) {
                card.isOwned = true
                try? modelContext.save()
                if let userId = authService.userId {
                    Task { await SupabaseSyncService.shared.pushTCGCard(card, userId: userId) }
                }
            }
            statusButton(label: "Chasing", icon: "sparkle",
                         active: !card.isOwned, color: .coral) {
                card.isOwned = false
                try? modelContext.save()
                if let userId = authService.userId {
                    Task { await SupabaseSyncService.shared.pushTCGCard(card, userId: userId) }
                }
            }
        }
    }

    private var psaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if card.isOwned {
                Text("PSA Grade")
                    .font(.custom("DMSans-Medium", size: 15))
                    .foregroundColor(.deepNavy)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        psaGradeChip(label: "Raw", grade: nil, current: card.psaGrade, color: .gray) {
                            card.psaGrade = nil
                            save()
                        }
                        ForEach([10, 9, 8, 7, 6, 5, 4, 3, 2, 1], id: \.self) { grade in
                            psaGradeChip(label: "PSA \(grade)", grade: grade, current: card.psaGrade, color: psaColor(grade)) {
                                card.psaGrade = grade
                                save()
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
            } else {
                Text("Looking for PSA grade")
                    .font(.custom("DMSans-Medium", size: 15))
                    .foregroundColor(.deepNavy)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        psaGradeChip(label: "Any / Raw", grade: nil, current: card.psaTargetGrade, color: .gray) {
                            card.psaTargetGrade = nil
                            save()
                        }
                        ForEach([10, 9, 8, 7, 6, 5], id: \.self) { grade in
                            psaGradeChip(label: "PSA \(grade)+", grade: grade, current: card.psaTargetGrade, color: psaColor(grade)) {
                                card.psaTargetGrade = grade
                                save()
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func psaGradeChip(label: String, grade: Int?, current: Int?, color: Color, action: @escaping () -> Void) -> some View {
        let active = grade == current
        return Button(action: action) {
            Text(label)
                .font(.custom("DMSans-Medium", size: 13))
                .foregroundColor(active ? .white : color)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(active ? color : color.opacity(0.1))
                .clipShape(Capsule())
        }
    }

    private func psaColor(_ grade: Int) -> Color {
        switch grade {
        case 10: return Color(red: 0.85, green: 0.6, blue: 0.1)   // gold
        case 9:  return Color(red: 0.2, green: 0.6, blue: 0.3)    // green
        case 8:  return Color(red: 0.1, green: 0.5, blue: 0.8)    // blue
        default: return .gray
        }
    }

    private func save() {
        try? modelContext.save()
        if let userId = authService.userId {
            Task { await SupabaseSyncService.shared.pushTCGCard(card, userId: userId) }
        }
    }

    private func statusButton(label: String, icon: String, active: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.custom("DMSans-Medium", size: 14))
            }
            .foregroundColor(active ? .white : color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(active ? color : color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }
}
