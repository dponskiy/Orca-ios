//
//  FinanceDetailBlock.swift
//  Orca
//
//  Created by David Piliponskiy on 3/28/26.
//

import SwiftUI

struct FinanceDetailBlock: View {
    let memory: Memory

    @State private var financeQuote: FinanceQuote? = nil
    @State private var isLoadingFinance = false
    @State private var selectedRange: FinanceRange = .oneMonth
    @State private var rangeSparkline: [Double] = []
    @State private var isLoadingSparkline = false
    @State private var rangeChange: (amount: Double, percent: Double)? = nil

    var body: some View {
        if let ticker = FinanceService.shared.detectTicker(in: memory.text) {
            Group {
                if isLoadingFinance {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.7).tint(.oceanTeal)
                        Text("Loading...").font(.custom("DMSans-Regular", size: 14)).foregroundColor(.gray)
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
                } else {
                    financeCard(ticker: ticker)
                }
            }
            .onAppear { loadFinanceData(ticker: ticker) }
        }
    }

    // MARK: - Finance Card

    @ViewBuilder
    private func financeCard(ticker: FinanceTicker) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Circle().fill(FinanceService.shared.color(for: ticker.symbol)).frame(width: 28, height: 28)
                    .overlay(
                        Text(String(ticker.symbol.prefix(1)))
                            .font(.custom("DMSans-Medium", size: 12)).foregroundColor(.white)
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text(financeQuote?.companyName ?? ticker.companyName)
                        .font(.custom("DMSans-Medium", size: 17)).foregroundColor(.deepNavy)
                    Text(ticker.symbol)
                        .font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                }
                Spacer()
                Text(financeQuote?.exchange ?? "NASDAQ")
                    .font(.custom("DMMono-Regular", size: 11)).foregroundColor(.gray)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.mist).clipShape(Capsule())
            }
            .padding(16)

            if let quote = financeQuote {
                Divider().padding(.horizontal, 16)
                priceSection(quote: quote)
                chartSection(quote: quote, ticker: ticker)
                if let alert = FinanceService.shared.parseAlert(from: memory.text) {
                    alertSection(quote: quote, alert: alert)
                }
                if let high = quote.high52w, let low = quote.low52w, high > low {
                    rangeSection(quote: quote, high: high, low: low)
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - Price Section

    @ViewBuilder
    private func priceSection(quote: FinanceQuote) -> some View {
        let displayAmount = rangeChange?.amount ?? quote.change
        let displayPercent = rangeChange?.percent ?? quote.changePercent
        let positive = displayAmount >= 0
        let rangeLabel = rangeChange != nil ? selectedRange.rawValue : "Today"

        VStack(alignment: .leading, spacing: 6) {
            Text("CURRENT PRICE")
                .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).tracking(0.5)
            Text(quote.formattedPrice)
                .font(.custom("DMSans-Medium", size: 32)).foregroundColor(.deepNavy)
            HStack(spacing: 6) {
                Text("\(positive ? "+" : "")$\(String(format: "%.2f", displayAmount))")
                    .font(.custom("DMSans-Medium", size: 14))
                    .foregroundColor(positive ? Color(red: 0.18, green: 0.49, blue: 0.2) : .coral)
                Text("\(positive ? "+" : "")\(String(format: "%.2f", displayPercent))%")
                    .font(.custom("DMSans-Medium", size: 12))
                    .foregroundColor(positive ? Color(red: 0.18, green: 0.49, blue: 0.2) : .coral)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background((positive ? Color(red: 0.18, green: 0.49, blue: 0.2) : Color.coral).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Text(rangeLabel)
                    .font(.custom("DMMono-Regular", size: 11)).foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 12)
    }

    // MARK: - Chart Section

    @ViewBuilder
    private func chartSection(quote: FinanceQuote, ticker: FinanceTicker) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if isLoadingSparkline {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.6).tint(.oceanTeal)
                        Text("Loading chart...")
                            .font(.custom("DMSans-Regular", size: 12)).foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity).frame(height: 100)
                } else {
                    let points = rangeSparkline.isEmpty ? quote.sparklinePoints : rangeSparkline
                    let positive = (rangeChange?.amount ?? quote.change) >= 0
                    if !points.isEmpty {
                        sparklineView(points: points, isPositive: positive)
                            .frame(maxWidth: .infinity).frame(height: 100)
                    }
                }
            }

            // Range selector
            HStack(spacing: 6) {
                ForEach(FinanceRange.allCases, id: \.self) { range in
                    Button {
                        selectedRange = range
                        loadSparkline(symbol: ticker.symbol, range: range)
                    } label: {
                        Text(range.rawValue)
                            .font(.custom("DMSans-Medium", size: 12))
                            .foregroundColor(selectedRange == range ? .white : .oceanTeal)
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                            .background(selectedRange == range ? Color.oceanTeal : Color.oceanTeal.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 16)
    }

    // MARK: - Alert Section

    @ViewBuilder
    private func alertSection(quote: FinanceQuote, alert: FinanceAlert) -> some View {
        Divider().padding(.horizontal, 16)
        VStack(alignment: .leading, spacing: 6) {
            Text("PRICE ALERT")
                .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).tracking(0.5)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    let dirLabel = alert.direction == .below ? "Drops below" : "Rises above"
                    Text("\(dirLabel) \(alert.formattedThreshold)")
                        .font(.custom("DMSans-Medium", size: 15)).foregroundColor(.deepNavy)
                    let dist = abs(quote.price - alert.threshold)
                    let side: String = {
                        switch alert.direction {
                        case .below: return quote.price > alert.threshold ? "above threshold" : "TRIGGERED"
                        case .above: return quote.price < alert.threshold ? "below threshold" : "TRIGGERED"
                        }
                    }()
                    Text(side == "TRIGGERED" ? "Alert triggered" : "$\(String(format: "%.2f", dist)) \(side)")
                        .font(.custom("DMMono-Regular", size: 12)).foregroundColor(.gray)
                }
                Spacer()
                Text("ACTIVE")
                    .font(.custom("DMSans-Medium", size: 11))
                    .foregroundColor(Color(red: 0.18, green: 0.49, blue: 0.2))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color(red: 0.18, green: 0.49, blue: 0.2).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
    }

    // MARK: - Range Section

    @ViewBuilder
    private func rangeSection(quote: FinanceQuote, high: Double, low: Double) -> some View {
        Divider().padding(.horizontal, 16)
        VStack(alignment: .leading, spacing: 12) {

            // Day range
            if let dayLow = quote.dayLow, let dayHigh = quote.dayHigh {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DAY RANGE")
                        .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).tracking(0.5)
                    Text("\(String(format: "$%.2f", dayLow)) – \(String(format: "$%.2f", dayHigh))")
                        .font(.custom("DMMono-Regular", size: 13)).foregroundColor(.deepNavy)
                }
            }

            // 52W bar
            VStack(alignment: .leading, spacing: 8) {
                Text("52W RANGE")
                    .font(.custom("DMSans-Medium", size: 11)).foregroundColor(.gray).tracking(0.5)
                let position = (quote.price - low) / (high - low)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.mist).frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.oceanTeal)
                            .frame(width: geo.size.width * CGFloat(max(0, min(1, position))), height: 3)
                    }
                }
                .frame(height: 3)
                HStack {
                    Text(String(format: "$%.2f", low))
                        .font(.custom("DMMono-Regular", size: 11)).foregroundColor(.gray)
                    Spacer()
                    Text(String(format: "$%.2f", high))
                        .font(.custom("DMMono-Regular", size: 11)).foregroundColor(.gray)
                }
            }
        }
        .padding(16)
    }

    // MARK: - Sparkline

    private func sparklineView(points: [Double], isPositive: Bool) -> some View {
        Canvas { context, size in
            guard points.count > 1 else { return }
            let minV = points.min()!, maxV = points.max()!
            let range = maxV == minV ? 1.0 : maxV - minV
            let pad: Double = 4

            var fill = Path()
            for (i, pt) in points.enumerated() {
                let x = pad + (size.width - pad * 2) * Double(i) / Double(points.count - 1)
                let y = pad + (size.height - pad * 2) * (1.0 - (pt - minV) / range)
                if i == 0 {
                    fill.move(to: CGPoint(x: x, y: size.height))
                    fill.addLine(to: CGPoint(x: x, y: y))
                } else {
                    fill.addLine(to: CGPoint(x: x, y: y))
                }
            }
            fill.addLine(to: CGPoint(x: pad + (size.width - pad * 2), y: size.height))
            fill.closeSubpath()
            context.fill(fill, with: .color(
                isPositive ? Color(red: 0.18, green: 0.49, blue: 0.2).opacity(0.08) : Color.coral.opacity(0.08)
            ))

            var line = Path()
            for (i, pt) in points.enumerated() {
                let x = pad + (size.width - pad * 2) * Double(i) / Double(points.count - 1)
                let y = pad + (size.height - pad * 2) * (1.0 - (pt - minV) / range)
                let p = CGPoint(x: x, y: y)
                if i == 0 { line.move(to: p) } else { line.addLine(to: p) }
            }
            context.stroke(
                line,
                with: .color(isPositive ? Color(red: 0.18, green: 0.49, blue: 0.2) : .coral),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            )

            // End dot
            let lastPt = points.last!
            let dotX = pad + (size.width - pad * 2)
            let dotY = pad + (size.height - pad * 2) * (1.0 - (lastPt - minV) / range)
            context.fill(
                Path(ellipseIn: CGRect(x: dotX - 3, y: dotY - 3, width: 6, height: 6)),
                with: .color(isPositive ? Color(red: 0.18, green: 0.49, blue: 0.2) : .coral)
            )
        }
    }

    // MARK: - Data Loading

    private func loadFinanceData(ticker: FinanceTicker) {
        isLoadingFinance = true
        Task {
            let quote = await FinanceService.shared.fetchQuote(symbol: ticker.symbol)
            await MainActor.run {
                self.financeQuote = quote
                self.isLoadingFinance = false
            }
            loadSparkline(symbol: ticker.symbol, range: .oneMonth)
        }
    }

    private func loadSparkline(symbol: String, range: FinanceRange) {
        isLoadingSparkline = true
        Task {
            let points = await FinanceService.shared.fetchSparkline(symbol: symbol, range: range)
            await MainActor.run {
                self.rangeSparkline = points
                self.isLoadingSparkline = false
                if let first = points.first,
                   let price = self.financeQuote?.price,
                   first > 0 {
                    let amount = price - first
                    self.rangeChange = (amount, (amount / first) * 100)
                } else {
                    self.rangeChange = nil
                }
            }
        }
    }
}
