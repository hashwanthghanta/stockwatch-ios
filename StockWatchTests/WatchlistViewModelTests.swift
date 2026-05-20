import XCTest
@testable import StockWatch

@MainActor
final class WatchlistViewModelTests: XCTestCase {

    // MARK: - Persistence

    func test_init_usesDefaultWatchlist_whenStoreIsEmpty() {
        let vm = WatchlistViewModel(service: MockStockService(),
                                    store: WatchlistStore.ephemeral())
        XCTAssertEqual(vm.symbols, MockData.defaultWatchlistSymbols)
    }

    func test_init_usesPersistedSymbols_whenStoreHasData() {
        let saved = ["AAPL", "VWCE.DE"]
        let vm = WatchlistViewModel(service: MockStockService(),
                                    store: WatchlistStore.ephemeral(initial: saved))
        XCTAssertEqual(vm.symbols, saved)
    }

    func test_add_appendsSymbol_andPersists() async {
        let store = WatchlistStore.ephemeral(initial: ["AAPL"])
        let vm = WatchlistViewModel(service: MockStockService(), store: store)
        await vm.add(symbol: "VWCE.DE")
        XCTAssertEqual(vm.symbols, ["AAPL", "VWCE.DE"])
        XCTAssertEqual(store.load(), ["AAPL", "VWCE.DE"])
    }

    func test_add_ignoresUnknownAndDuplicateSymbols() async {
        let vm = WatchlistViewModel(symbols: ["AAPL"],
                                    service: MockStockService(),
                                    store: WatchlistStore.ephemeral())
        await vm.add(symbol: "AAPL")          // duplicate
        await vm.add(symbol: "ZZZZ.UNKNOWN")  // not in catalog
        XCTAssertEqual(vm.symbols, ["AAPL"])
    }

    func test_remove_dropsSymbol_andPersists() {
        let store = WatchlistStore.ephemeral(initial: ["AAPL", "TSLA"])
        let vm = WatchlistViewModel(service: MockStockService(), store: store)
        vm.remove(symbol: "AAPL")
        XCTAssertEqual(vm.symbols, ["TSLA"])
        XCTAssertEqual(store.load(), ["TSLA"])
    }

    // MARK: - Categorisation

    func test_stocksInCategory_filtersCorrectly() {
        let vm = WatchlistViewModel(symbols: ["AAPL", "VWCE.DE", "MSFT", "EUNL.DE"],
                                    service: MockStockService(),
                                    store: WatchlistStore.ephemeral())
        XCTAssertEqual(vm.stocks(in: .stock).map(\.symbol), ["AAPL", "MSFT"])
        XCTAssertEqual(vm.stocks(in: .etf).map(\.symbol),   ["VWCE.DE", "EUNL.DE"])
    }

    func test_addableStocks_excludesAlreadyInWatchlist() {
        let vm = WatchlistViewModel(symbols: ["AAPL"],
                                    service: MockStockService(),
                                    store: WatchlistStore.ephemeral())
        let addable = vm.addableStocks.map(\.symbol)
        XCTAssertFalse(addable.contains("AAPL"))
        XCTAssertTrue(addable.contains("TSLA"))
    }

    // MARK: - Quote fallback

    func test_price_fallsBackToHardcoded_whenNoQuoteFetched() {
        let stock = MockData.catalog[0]
        let vm = WatchlistViewModel(symbols: [stock.symbol],
                                    service: MockStockService(),
                                    store: WatchlistStore.ephemeral())
        XCTAssertEqual(vm.price(for: stock), stock.fallbackPrice)
    }

    func test_price_usesFetched_whenAvailable() async {
        let stock = MockData.catalog[0]
        let vm = WatchlistViewModel(symbols: [stock.symbol],
                                    service: MockStockService(),
                                    store: WatchlistStore.ephemeral())
        await vm.refresh()
        XCTAssertNotEqual(vm.price(for: stock), stock.fallbackPrice)
        XCTAssertNotNil(vm.lastRefreshedAt)
    }

    func test_refresh_setsLoadedState_andLastRefreshedAt() async {
        let vm = WatchlistViewModel(symbols: ["AAPL", "TSLA"],
                                    service: MockStockService(),
                                    store: WatchlistStore.ephemeral())
        await vm.refresh()
        XCTAssertEqual(vm.state, .loaded)
        XCTAssertEqual(vm.quotes.count, 2)
        XCTAssertNotNil(vm.lastRefreshedAt)
    }

    // MARK: - Quote math

    func test_changePercent_computedFromPreviousClose() {
        let q = StockQuote(
            symbol: "X",
            currentPrice: 110, previousClose: 100,
            dayHigh: 111, dayLow: 99,
            fiftyTwoWeekHigh: 200, fiftyTwoWeekLow: 50,
            volume: 1, currency: "USD",
            historicalCloses: [100, 105, 110]
        )
        XCTAssertEqual(q.changePercent, 10.0, accuracy: 0.0001)
        XCTAssertTrue(q.isUp)
    }
}
