import Foundation

struct Stock: Identifiable, Equatable {
    let id: UUID
    let symbol: String
    let name: String
    var price: Double
    var changePercent: Double

    init(id: UUID = UUID(),
         symbol: String,
         name: String,
         price: Double,
         changePercent: Double) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.price = price
        self.changePercent = changePercent
    }

    var isUp: Bool { changePercent >= 0 }
    var formattedPrice: String { String(format: "€%.2f", price) }
    var formattedChange: String { String(format: "%+.2f%%", changePercent) }

    var accessibilityDescription: String {
        let direction = isUp ? "up" : "down"
        return "\(symbol), \(name), \(formattedPrice), \(direction) \(String(format: "%.2f", abs(changePercent))) percent"
    }
}
