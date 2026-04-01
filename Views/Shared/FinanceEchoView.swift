//
//  FinanceEchoView.swift
//  Orca
//
//  Created by David Piliponskiy on 3/27/26.
//

import SwiftUI
 
struct FinanceEchoView: View {
    let memories: [Memory]
 
    @State private var quotes: [String: FinanceQuote] = [:]
    @State private var tickers: [FinanceTicker] = []
    @State private var dowQuote: FinanceQuote? = nil
    @State private var sp500Quote: FinanceQuote? = nil
    @State private var qqqQuote: FinanceQuote? = nil
    @State private var isLoading = false
 
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7).tint(.oceanTeal)
                    Text("Loading quotes...")
                        .font(.custom("DMSans-Regular", size: 13))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            } else if !tickers.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    // Subtitle — same pattern as SportsEchoView
                    Text("\(tickers.count) \(tickers.count == 1 ? "stock" : "stocks") · updated just now")
                        .font(.custom("DMSans-Regular", size: 13))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
 
                    // Market indices strip
                    if dowQuote != nil || sp500Quote != nil || qqqQuote != nil {
                        HStack(spacing: 8) {
                            if let dow = dowQuote { indexChip(label: "DOW", quote: dow) }
                            if let sp = sp500Quote { indexChip(label: "S&P", quote: sp) }
                            if let qqq = qqqQuote { indexChip(label: "QQQ", quote: qqq) }
                        }
                        .padding(.horizontal, 20)
                    }
 
                    // Tracked Stocks card — mirrors "LIVE & RECENT" card
                    VStack(alignment: .leading, spacing: 0) {
                        Text("TRACKED STOCKS")
                            .font(.custom("DMSans-Medium", size: 11))
                            .foregroundColor(.gray)
                            .tracking(0.5)
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .padding(.bottom, 10)
 
                        ForEach(Array(tickers.enumerated()), id: \.element.symbol) { index, ticker in
                            if index > 0 { Divider().padding(.horizontal, 16) }
                            tickerRow(ticker: ticker, quote: quotes[ticker.symbol])
                        }
                        Spacer().frame(height: 8)
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
                    .padding(.horizontal, 20)
 
                    // Active Alerts card — mirrors "UP NEXT" card
                    let alertMemories = memories.filter {
                        FinanceService.shared.parseAlert(from: $0.text) != nil
                    }
                    if !alertMemories.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("ACTIVE ALERTS")
                                .font(.custom("DMSans-Medium", size: 11))
                                .foregroundColor(.gray)
                                .tracking(0.5)
                                .padding(.horizontal, 16)
                                .padding(.top, 14)
                                .padding(.bottom, 10)
 
                            ForEach(Array(alertMemories.enumerated()), id: \.element.id) { index, memory in
                                if index > 0 { Divider().padding(.horizontal, 16) }
                                if let alert = FinanceService.shared.parseAlert(from: memory.text) {
                                    alertRow(alert: alert, quote: quotes[alert.ticker])
                                }
                            }
                            Spacer().frame(height: 8)
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
                        .padding(.horizontal, 20)
                    }
 
                    Text("Tap a memory to see full quote & alerts")
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                }
                .padding(.bottom, 8)
            }
        }
        .onAppear { loadData() }
    }
 
    // MARK: - Index Chip
 
    private func indexChip(label: String, quote: FinanceQuote) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.custom("DMMono-Regular", size: 11))
                .foregroundColor(.gray)
            Text(FinanceService.shared.formattedIndexPrice(quote))
                .font(.custom("DMSans-Medium", size: 15 ))
                .foregroundColor(.deepNavy)
            Text(quote.formattedChangePercent)
                .font(.custom("DMMono-Regular", size: 12))
                .foregroundColor(quote.isPositive ? Color(red: 0.18, green: 0.49, blue: 0.2) : .coral)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }
 
    // MARK: - Ticker Row (mirrors recentRow in SportsEchoView)
 
    private func tickerRow(ticker: FinanceTicker, quote: FinanceQuote?) -> some View {
        HStack(spacing: 12) {
            // Ticker dot — same pattern as teamDot()
            Circle()
                .fill(FinanceService.shared.color(for: ticker.symbol))
                .frame(width: 24, height: 24)
                .overlay(
                    Text(String(ticker.symbol.prefix(1)).uppercased())
                        .font(.custom("DMSans-Medium", size: 10))
                        .foregroundColor(.white)
                )
 
            VStack(alignment: .leading, spacing: 1) {
                Text(ticker.companyName)
                    .font(.custom("DMSans-Regular", size: 14))
                    .foregroundColor(.deepNavy)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(ticker.symbol)
                        .font(.custom("DMMono-Regular", size: 12))
                        .foregroundColor(.gray)
                    if let exchange = quote?.exchange {
                        Text("· \(exchange)")
                            .font(.custom("DMMono-Regular", size: 12))
                            .foregroundColor(.gray)
                    }
                }
            }
 
            Spacer()
 
            if let quote {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(quote.formattedPrice)
                        .font(.custom("DMSans-Medium", size: 17))
                        .foregroundColor(.deepNavy)
                    Text(quote.formattedChangePercent)
                        .font(.custom("DMSans-Medium", size: 11))
                        .foregroundColor(quote.isPositive ? Color(red: 0.18, green: 0.49, blue: 0.2) : .coral)
                }
            } else {
                ProgressView().scaleEffect(0.6).tint(.oceanTeal)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
 
    // MARK: - Alert Row (mirrors upcomingRow in SportsEchoView)
 
    private func alertRow(alert: FinanceAlert, quote: FinanceQuote?) -> some View {
        let dirLabel = alert.direction == .below ? "below" : "above"
 
        let distanceText: String = {
            guard let price = quote?.price else { return "Checking..." }
            let dist = abs(price - alert.threshold)
            let distStr = String(format: "$%.2f", dist)
            switch alert.direction {
            case .below: return price <= alert.threshold ? "Alert triggered" : "\(distStr) above"
            case .above: return price >= alert.threshold ? "Alert triggered" : "\(distStr) below"
            }
        }()
 
        return HStack(spacing: 12) {
            Circle()
                .fill(FinanceService.shared.color(for: alert.ticker))
                .frame(width: 24, height: 24)
                .overlay(
                    Text(String(alert.ticker.prefix(1)).uppercased())
                        .font(.custom("DMSans-Medium", size: 10))
                        .foregroundColor(.white)
                )
 
            VStack(alignment: .leading, spacing: 1) {
                Text("\(alert.ticker) \(dirLabel) \(alert.formattedThreshold)")
                    .font(.custom("DMSans-Regular", size: 14))
                    .foregroundColor(.deepNavy)
                if let quote {
                    Text("\(quote.formattedPrice) now · \(distanceText)")
                        .font(.custom("DMMono-Regular", size: 12))
                        .foregroundColor(.gray)
                }
            }
 
            Spacer()
 
            // "WATCHING" pill — mirrors the "Nd" upcoming pill in sports
            Text("WATCHING")
                .font(.custom("DMSans-Medium", size: 11))
                .foregroundColor(.oceanTeal)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.oceanTeal.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
 
    // MARK: - Load
 
    private func loadData() {
        let detected = detectTickersFromMemories()
        guard !detected.isEmpty else { return }
        tickers = detected
        isLoading = true
 
        Task {
            let symbols = detected.map { $0.symbol }
 
            // Fetch quotes, indices, and run price alert check concurrently
            async let quotesTask = FinanceService.shared.fetchQuotes(symbols: symbols)
            async let indicesTask = FinanceService.shared.fetchMarketIndices()
            async let alertCheck: () = FinanceService.shared.checkPriceAlerts(memories: memories)
 
            let (fetchedQuotes, indices) = await (quotesTask, indicesTask)
            _ = await alertCheck
 
            await MainActor.run {
                self.quotes = fetchedQuotes
                self.dowQuote = indices.dow
                self.sp500Quote = indices.sp500
                self.qqqQuote = indices.qqq
                self.isLoading = false
            }
        }
    }
 
    private func detectTickersFromMemories() -> [FinanceTicker] {
        var seen = Set<String>()
        var result: [FinanceTicker] = []
        for memory in memories {
            if let ticker = FinanceService.shared.detectTicker(in: memory.text) {
                if !seen.contains(ticker.symbol) {
                    seen.insert(ticker.symbol)
                    result.append(ticker)
                }
            }
        }
        return result
    }
}
 
