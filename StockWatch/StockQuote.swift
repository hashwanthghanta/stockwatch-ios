import Foundation

/// A live quote for a single stock, fetched from a `StockService`.
struct StockQuote: Equatable, Sendable {
    let symbol: String
    let currentPrice: Double
    let previousClose: Double
    let dayHigh: Double
    let dayLow: Double
    let fiftyTwoWeekHigh: Double
    let fiftyTwoWeekLow: Double
    let volume: Int64
    let currency: String           // "USD", "EUR", …
    let historicalCloses: [Double] // recent daily close prices, oldest first

    var changeAbsolute: Double { currentPrice - previousClose }

    var changePercent: Double {
        guard previousClose > 0 else { return 0 }
        return ((currentPrice - previousClose) / previousClose) * 100
    }

    var isUp: Bool { changeAbsolute >= 0 }

    var currencySymbol: String {
        switch currency {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        default:    return currency + " "
        }
    }

    func formattedPrice(_ value: Double) -> String {
        String(format: "%@%.2f", currencySymbol, value)
    }

    func formattedChange() -> String {
        String(format: "%+.2f%%", changePercent)
    }
}
