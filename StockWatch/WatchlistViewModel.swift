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

    /// Ordered list of symbols currently on the user's watchlist.
    /// Persisted to `WatchlistStore` on every mutation.
    private(set) var symbols: [String]

    private(set) var quotes: [String: StockQuote] = [:]
    private(set) var state: WatchlistState = .idle
    private(set) var lastRefreshedAt: Date?

    let service: StockService
    private let store: WatchlistStore

    init(symbols: [String]? = nil,
         service: StockService = YahooStockService(),
         store: WatchlistStore = .live) {
        self.service = service
        self.store = store
        if let symbols {
            self.symbols = symbols
        } else if let saved = store.load(), !saved.isEmpty {
            self.symbols = saved
        } else {
            self.symbols = MockData.defaultWatchlistSymbols
        }
    }

    // MARK: - Derived collections

    /// The full set of `Stock` objects in the watchlist, in the order the user has them.
    var stocks: [Stock] {
        symbols.compactMap { MockData.stock(forSymbol: $0) }
    }

    func stocks(in category: AssetCategory) -> [Stock] {
        stocks.filter { $0.category == category }
    }

    /// Catalog entries the user hasn't added yet — used by the Add sheet.
    var addableStocks: [Stock] {
        MockData.catalog.filter { !symbols.contains($0.symbol) }
    }

    // MARK: - Per-row accessors

    func quote(for stock: Stock) -> StockQuote? { quotes[stock.symbol] }

    func price(for stock: Stock) -> Double {
        quote(for: stock)?.currentPrice ?? stock.fallbackPrice
    }

    func changePercent(for stock: Stock) -> Double {
        quote(for: stock)?.changePercent ?? stock.fallbackChangePercent
    }

    func currency(for stock: Stock) -> String {
        quote(for: stock)?.currency ?? stock.fallbackCurrency
    }

    // MARK: - Mutations

    func add(symbol: String) async {
        guard MockData.stock(forSymbol: symbol) != nil,
              !symbols.contains(symbol) else { return }
        symbols.append(symbol)
        store.save(symbols)
        // Fetch just the new one — don't disturb the others.
        if let q = try? await service.fetchQuote(symbol: symbol) {
            quotes[symbol] = q
        }
    }

    func remove(symbol: String) {
        symbols.removeAll { $0 == symbol }
        quotes.removeValue(forKey: symbol)
        store.save(symbols)
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        symbols.move(fromOffsets: source, toOffset: destination)
        store.save(symbols)
    }

    // MARK: - Refresh

    /// Fetches live quotes for every stock sequentially with a short stagger.
    /// Sequential because the public Yahoo endpoint rate-limits parallel bursts (HTTP 429).
    /// Tolerates partial failure — any symbol whose fetch throws keeps its fallback price.
    func refresh() async {
        state = .loading
        var newQuotes = quotes
        var failures = 0

        for (index, symbol) in symbols.enumerated() {
            if index > 0 {
                try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 s stagger
            }
            do {
                let q = try await service.fetchQuote(symbol: symbol)
                newQuotes[symbol] = q
            } catch {
                failures += 1
            }
        }

        quotes = newQuotes
        lastRefreshedAt = .now

        if newQuotes.isEmpty {
            state = .failed(message: String(localized: "Could not load any quotes. Check your internet connection."))
        } else if failures > 0 {
            state = .partial(failures: failures)
        } else {
            state = .loaded
        }
    }
}
