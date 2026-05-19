import Foundation

enum MockData {
    static let stocks: [Stock] = [
        Stock(
            symbol: "AAPL",
            name: "Apple Inc.",
            summary: "American technology company best known for the iPhone, Mac, iPad, and services like the App Store and iCloud. One of the world's most valuable public companies, listed on NASDAQ.",
            fallbackPrice: 189.20,
            fallbackChangePercent:  1.24,
            fallbackCurrency: "USD"
        ),
        Stock(
            symbol: "TSLA",
            name: "Tesla, Inc.",
            summary: "American electric-vehicle and clean-energy company founded by Elon Musk. Designs and manufactures EVs, battery storage and solar products; listed on NASDAQ.",
            fallbackPrice: 248.50,
            fallbackChangePercent: -0.83,
            fallbackCurrency: "USD"
        ),
        Stock(
            symbol: "MSFT",
            name: "Microsoft Corp.",
            summary: "American software giant behind Windows, Microsoft 365, Azure cloud and Xbox. A trillion-dollar enterprise serving consumers and businesses worldwide.",
            fallbackPrice: 415.10,
            fallbackChangePercent:  0.45,
            fallbackCurrency: "USD"
        ),
        Stock(
            symbol: "SAP.DE",
            displaySymbol: "SAP",
            name: "SAP SE",
            summary: "German enterprise-software company based in Walldorf. Europe's largest software firm and the global leader in ERP systems used by most Fortune 500 companies.",
            fallbackPrice: 192.30,
            fallbackChangePercent:  2.10,
            fallbackCurrency: "EUR"
        ),
        Stock(
            symbol: "ALV.DE",
            displaySymbol: "ALV",
            name: "Allianz SE",
            summary: "German multinational insurance and asset-management firm headquartered in Munich. One of the world's largest insurers and a major investor in European fixed income.",
            fallbackPrice: 263.80,
            fallbackChangePercent: -1.05,
            fallbackCurrency: "EUR"
        ),
        Stock(
            symbol: "ASML",
            name: "ASML Holding",
            summary: "Dutch company that manufactures the photolithography machines used by every leading-edge chip foundry. A critical link in the global semiconductor supply chain.",
            fallbackPrice: 712.40,
            fallbackChangePercent:  3.18,
            fallbackCurrency: "USD"
        ),
        Stock(
            symbol: "NVDA",
            name: "NVIDIA Corp.",
            summary: "American chip designer dominant in GPUs for gaming, professional visualisation, data-centre compute and the AI workloads driving modern machine learning.",
            fallbackPrice: 925.10,
            fallbackChangePercent:  4.52,
            fallbackCurrency: "USD"
        ),
    ]
}
