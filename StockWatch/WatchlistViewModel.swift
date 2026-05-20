import Foundation
import Observation

enum WatchlistState: Equatable {
    case idle
    case loading
    case loaded
    case partial(failures: Int)
    case failed(message: String)
}

enum SortMode: String, CaseIterable, Identifiable, Sendable {
    case manual
    case name
    case lastViewed
    var id: String { rawValue }

    var localizedLabel: String {
        switch self {
        case .manual:     return String(localized: "Manual order")
        case .name:       return String(localized: "By name")
        case .lastViewed: return String(localized: "Last viewed")
        }
    }
}

@MainActor
@Observable
final class WatchlistViewModel {

    private(set) var symbols: [String]
    private(set) var quotes: [String: StockQuote] = [:]
    private(set) var state: WatchlistState = .idle
    private(set) var lastRefreshedAt: Date?
    private(set) var lastViewedAt: [String: Date]
    var sortMode: SortMode {
        didSet { UserDefaults.standard.set(sortMode.rawValue, forKey: Self.sortKey) }
    }

    let service: StockService
    private let store: WatchlistStore

    private static let sortKey       = "watchlist.sortMode.v1"
    private static let lastViewedKey = "watchlist.lastViewed.v1"

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
        let rawSort = UserDefaults.standard.string(forKey: Self.sortKey) ?? SortMode.manual.rawValue
        self.sortMode = SortMode(rawValue: rawSort) ?? .manual
        let dict = UserDefaults.standard.dictionary(forKey: Self.lastViewedKey) as? [String: TimeInterval] ?? [:]
        self.lastViewedAt = dict.mapValues { Date(timeIntervalSince1970: $0) }
    }

    // MARK: - Derived collections

    /// User's watchlist as `Stock` objects in the order they were added (manual order).
    var stocks: [Stock] {
        symbols.compactMap { MockData.stock(forSymbol: $0) }
    }

    /// Watchlist sorted according to the current `sortMode`.
    var displayedStocks: [Stock] {
        switch sortMode {
        case .manual:
            return stocks
        case .name:
            return stocks.sorted {
                $0.displaySymbol.localizedCaseInsensitiveCompare($1.displaySymbol) == .orderedAscending
            }
        case .lastViewed:
            return stocks.sorted {
                (lastViewedAt[$0.symbol] ?? .distantPast) > (lastViewedAt[$1.symbol] ?? .distantPast)
            }
        }
    }

    func stocks(in category: AssetCategory) -> [Stock] {
        displayedStocks.filter { $0.category == category }
    }

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
        if let q = try? await service.fetchQuote(symbol: symbol) {
            quotes[symbol] = q
        }
    }

    func remove(symbol: String) {
        symbols.removeAll { $0 == symbol }
        quotes.removeValue(forKey: symbol)
        lastViewedAt.removeValue(forKey: symbol)
        persistLastViewed()
        store.save(symbols)
    }

    /// Reorder symbols within a single category (so drag in Stocks section doesn't move ETFs).
    func move(in category: AssetCategory, fromOffsets source: IndexSet, toOffset destination: Int) {
        // Only meaningful in manual mode.
        guard sortMode == .manual else { return }
        // Indices within `symbols` belonging to this category, in current order.
        let categorySymbols = stocks.filter { $0.category == category }.map(\.symbol)
        var reordered = categorySymbols
        reordered.move(fromOffsets: source, toOffset: destination)
        // Rebuild full symbols list keeping the *other* category's order intact.
        var newSymbols: [String] = []
        var idxInCategory = 0
        for sym in symbols {
            guard let s = MockData.stock(forSymbol: sym) else { continue }
            if s.category == category {
                newSymbols.append(reordered[idxInCategory])
                idxInCategory += 1
            } else {
                newSymbols.append(sym)
            }
        }
        symbols = newSymbols
        store.save(symbols)
    }

    /// Mark a stock's detail screen as just viewed — used by `.lastViewed` sort.
    func markViewed(symbol: String) {
        lastViewedAt[symbol] = .now
        persistLastViewed()
    }

    private func persistLastViewed() {
        let dict = lastViewedAt.mapValues { $0.timeIntervalSince1970 }
        UserDefaults.standard.set(dict, forKey: Self.lastViewedKey)
    }

    // MARK: - Refresh

    func refresh() async {
        state = .loading
        var newQuotes = quotes
        var failures = 0

        for (index, symbol) in symbols.enumerated() {
            if index > 0 {
                try? await Task.sleep(nanoseconds: 250_000_000)
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
