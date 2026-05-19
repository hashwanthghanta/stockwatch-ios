import Foundation

enum MockData {
    static let stocks: [Stock] = [
        Stock(symbol: "AAPL", name: "Apple Inc.",      price: 189.20, changePercent:  1.24),
        Stock(symbol: "TSLA", name: "Tesla Inc.",      price: 248.50, changePercent: -0.83),
        Stock(symbol: "MSFT", name: "Microsoft Corp.", price: 415.10, changePercent:  0.45),
        Stock(symbol: "SAP",  name: "SAP SE",          price: 192.30, changePercent:  2.10),
        Stock(symbol: "ALV",  name: "Allianz SE",      price: 263.80, changePercent: -1.05),
        Stock(symbol: "ASML", name: "ASML Holding",    price: 712.40, changePercent:  3.18),
        Stock(symbol: "NVDA", name: "NVIDIA Corp.",    price: 925.10, changePercent:  4.52),
    ]
}
