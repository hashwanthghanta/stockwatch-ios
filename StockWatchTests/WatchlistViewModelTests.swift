import XCTest
@testable import StockWatch

final class WatchlistViewModelTests: XCTestCase {

    func test_refresh_changesPrice() {
        let vm = WatchlistViewModel(stocks: [
            Stock(symbol: "X", name: "X Co.", price: 100, changePercent: 0)
        ])
        let before = vm.stocks[0].price
        vm.refresh()
        XCTAssertNotEqual(vm.stocks[0].price, before,
                          "Refresh should change the price")
    }

    func test_refresh_keepsPricePositive() {
        let vm = WatchlistViewModel(stocks: [
            Stock(symbol: "X", name: "X Co.", price: 1, changePercent: 0)
        ])
        for _ in 0..<50 { vm.refresh() }
        XCTAssertGreaterThan(vm.stocks[0].price, 0,
                             "Price must never go to zero or negative")
    }

    func test_isUp_reflectsChangePercent() {
        let up   = Stock(symbol: "U", name: "Up",   price: 10, changePercent:  1)
        let down = Stock(symbol: "D", name: "Down", price: 10, changePercent: -1)
        XCTAssertTrue(up.isUp)
        XCTAssertFalse(down.isUp)
    }
}
