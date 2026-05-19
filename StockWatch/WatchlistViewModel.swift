import Foundation
import Observation

@Observable
final class WatchlistViewModel {
    private(set) var stocks: [Stock]

    init(stocks: [Stock] = MockData.stocks) {
        self.stocks = stocks
    }

    func refresh() {
        stocks = stocks.map { s in
            var copy = s
            let delta = Double.random(in: -5...5)
            copy.price = max(1, s.price * (1 + delta / 100))
            copy.changePercent = delta
            return copy
        }
    }
}
