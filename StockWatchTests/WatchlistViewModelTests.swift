import XCTest
@testable import StockWatch

@MainActor
final class WatchlistViewModelTests: XCTestCase {

    func test_priceFallsBackToHardcoded_whenNoQuoteFetched() {
        let vm = WatchlistViewModel(stocks: [MockData.stocks[0]],
                                    service: MockStockService())
        XCTAssertEqual(vm.price(for: MockData.stocks[0]),
                       MockData.stocks[0].fallbackPrice,
                       "Without a fetched quote, the row must show the fallback price")
    }

    func test_refresh_populatesQuotes_andTransitionsToLoaded() async {
        let vm = WatchlistViewModel(stocks: MockData.stocks,
                                    service: MockStockService())
        XCTAssertEqual(vm.state, .idle)
        await vm.refresh()
        XCTAssertEqual(vm.state, .loaded)
        XCTAssertEqual(vm.quotes.count, MockData.stocks.count,
                       "Every stock must have a fetched quote after refresh")
    }

    func test_refresh_usesFetchedPrice_whenAvailable() async {
        let vm = WatchlistViewModel(stocks: [MockData.stocks[0]],
                                    service: MockStockService())
        let fallback = MockData.stocks[0].fallbackPrice
        await vm.refresh()
        let live = vm.price(for: MockData.stocks[0])
        XCTAssertNotEqual(live, fallback,
                          "After refresh, the row should reflect the live mock price, not the fallback")
    }

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
