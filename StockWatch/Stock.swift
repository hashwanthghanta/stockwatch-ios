import Foundation

enum AssetCategory: String, Codable, Sendable, CaseIterable {
    case stock
    case etf

    var localizedSectionTitle: String {
        switch self {
        case .stock: return String(localized: "Stocks")
        case .etf:   return String(localized: "ETFs")
        }
    }
}

struct Stock: Identifiable, Equatable, Sendable {
    var id: String { symbol }
    let symbol: String          // Yahoo ticker, e.g. "AAPL", "ALV.DE", "VWCE.DE"
    let displaySymbol: String   // Short label shown in UI, e.g. "AAPL", "ALV", "VWCE"
    let name: String
    let summary: String         // 2-sentence description
    let category: AssetCategory
    let fallbackPrice: Double
    let fallbackChangePercent: Double
    let fallbackCurrency: String   // "USD" or "EUR"

    init(symbol: String,
         displaySymbol: String? = nil,
         name: String,
         summary: String,
         category: AssetCategory = .stock,
         fallbackPrice: Double,
         fallbackChangePercent: Double,
         fallbackCurrency: String) {
        self.symbol = symbol
        self.displaySymbol = displaySymbol ?? symbol
        self.name = name
        self.summary = summary
        self.category = category
        self.fallbackPrice = fallbackPrice
        self.fallbackChangePercent = fallbackChangePercent
        self.fallbackCurrency = fallbackCurrency
    }
}
