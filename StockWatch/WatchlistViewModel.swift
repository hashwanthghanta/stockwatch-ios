import Foundation
import Observation

enum WatchlistState: Equatable {
    case idle
    case loading
    case loaded
    case partial(failures: Int)
    case failed(message: String)
}

@MainActor
@Observable
final class WatchlistViewModel {
    private(set) var stocks: [Stock]
    private(set) var quotes: [String: StockQuote] = [:]
    private(set) var state: WatchlistState = .idle

    let service: StockService

    init(stocks: [Stock] = MockData.stocks,
         service: StockService = YahooStockService()) {
        self.stocks = stocks
        self.service = service
    }

    /// Returns the live quote for a stock if one has been fetched, otherwise `nil`.
    func quote(for stock: Stock) -> StockQuote? {
        quotes[stock.symbol]
    }

    /// Current price for the row — live if available, otherwise the hardcoded fallback.
    func price(for stock: Stock) -> Double {
        quote(for: stock)?.currentPrice ?? stock.fallbackPrice
    }

    func changePercent(for stock: Stock) -> Double {
        quote(for: stock)?.changePercent ?? stock.fallbackChangePercent
    }

    func currency(for stock: Stock) -> String {
        quote(for: stock)?.currency ?? stock.fallbackCurrency
    }

    func isUp(_ stock: Stock) -> Bool {
        changePercent(for: stock) >= 0
    }

    /// Fetches live quotes for every stock sequentially with a short stagger.
    /// Sequential because the public Yahoo endpoint rate-limits parallel bursts (HTTP 429).
    /// Tolerates partial failure — any symbol whose fetch throws keeps its fallback price.
    func refresh() async {
        state = .loading
        var newQuotes = quotes
        var failures = 0

        for (index, stock) in stocks.enumerated() {
            if index > 0 {
                try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 s stagger
            }
            do {
                let q = try await service.fetchQuote(symbol: stock.symbol)
                newQuotes[stock.symbol] = q
            } catch {
                failures += 1
            }
        }

        quotes = newQuotes
        if newQuotes.isEmpty {
            state = .failed(message: "Could not load any quotes. Check your internet connection.")
        } else if failures > 0 {
            state = .partial(failures: failures)
        } else {
            state = .loaded
        }
    }
}
