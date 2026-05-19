import Foundation

struct Stock: Identifiable, Equatable {
    let id: UUID
    let symbol: String          // Yahoo ticker, e.g. "AAPL", "ALV.DE"
    let displaySymbol: String   // Short label shown in UI, e.g. "AAPL", "ALV"
    let name: String
    let summary: String         // 2-sentence company description
    let fallbackPrice: Double
    let fallbackChangePercent: Double
    let fallbackCurrency: String   // "USD" or "EUR"

    init(id: UUID = UUID(),
         symbol: String,
         displaySymbol: String? = nil,
         name: String,
         summary: String,
         fallbackPrice: Double,
         fallbackChangePercent: Double,
         fallbackCurrency: String) {
        self.id = id
        self.symbol = symbol
        self.displaySymbol = displaySymbol ?? symbol
        self.name = name
        self.summary = summary
        self.fallbackPrice = fallbackPrice
        self.fallbackChangePercent = fallbackChangePercent
        self.fallbackCurrency = fallbackCurrency
    }
}
