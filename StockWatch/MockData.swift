import Foundation

/// The full universe of instruments the app knows about.
/// The user's *watchlist* is a subset of these, persisted across launches.
enum MockData {

    static let catalog: [Stock] = [

        // MARK: Individual stocks

        Stock(
            symbol: "AAPL",
            name: "Apple Inc.",
            summary: "American technology company best known for the iPhone, Mac, iPad and services. Listed on NASDAQ; one of the world's most valuable public companies.",
            category: .stock,
            fallbackPrice: 189.20, fallbackChangePercent:  1.24, fallbackCurrency: "USD"
        ),
        Stock(
            symbol: "TSLA",
            name: "Tesla, Inc.",
            summary: "American electric-vehicle and clean-energy company founded by Elon Musk. Designs and manufactures EVs, battery storage and solar products.",
            category: .stock,
            fallbackPrice: 248.50, fallbackChangePercent: -0.83, fallbackCurrency: "USD"
        ),
        Stock(
            symbol: "MSFT",
            name: "Microsoft Corp.",
            summary: "American software giant behind Windows, Microsoft 365, Azure cloud and Xbox. A trillion-dollar enterprise serving consumers and businesses worldwide.",
            category: .stock,
            fallbackPrice: 415.10, fallbackChangePercent:  0.45, fallbackCurrency: "USD"
        ),
        Stock(
            symbol: "NVDA",
            name: "NVIDIA Corp.",
            summary: "American chip designer dominant in GPUs for gaming, professional visualisation, data-centre compute and the AI workloads driving modern machine learning.",
            category: .stock,
            fallbackPrice: 925.10, fallbackChangePercent:  4.52, fallbackCurrency: "USD"
        ),
        Stock(
            symbol: "ASML",
            name: "ASML Holding",
            summary: "Dutch company that manufactures the photolithography machines used by every leading-edge chip foundry. A critical link in the global semiconductor supply chain.",
            category: .stock,
            fallbackPrice: 712.40, fallbackChangePercent:  3.18, fallbackCurrency: "USD"
        ),
        Stock(
            symbol: "SAP.DE", displaySymbol: "SAP",
            name: "SAP SE",
            summary: "German enterprise-software company based in Walldorf. Europe's largest software firm and the global leader in ERP systems used by most Fortune 500 companies.",
            category: .stock,
            fallbackPrice: 192.30, fallbackChangePercent:  2.10, fallbackCurrency: "EUR"
        ),
        Stock(
            symbol: "ALV.DE", displaySymbol: "ALV",
            name: "Allianz SE",
            summary: "German multinational insurance and asset-management firm headquartered in Munich. One of the world's largest insurers and a major investor in European fixed income.",
            category: .stock,
            fallbackPrice: 263.80, fallbackChangePercent: -1.05, fallbackCurrency: "EUR"
        ),
        Stock(
            symbol: "SIE.DE", displaySymbol: "SIE",
            name: "Siemens AG",
            summary: "German multinational industrial-technology company based in Munich. Active in automation, electrification, mobility and digital industries software.",
            category: .stock,
            fallbackPrice: 175.40, fallbackChangePercent:  0.62, fallbackCurrency: "EUR"
        ),
        Stock(
            symbol: "BMW.DE", displaySymbol: "BMW",
            name: "BMW AG",
            summary: "German luxury-vehicle and motorcycle manufacturer headquartered in Munich. Owns the BMW, MINI and Rolls-Royce brands.",
            category: .stock,
            fallbackPrice:  82.10, fallbackChangePercent: -0.41, fallbackCurrency: "EUR"
        ),
        Stock(
            symbol: "VOW3.DE", displaySymbol: "VOW3",
            name: "Volkswagen AG",
            summary: "German automotive group based in Wolfsburg. One of the largest car manufacturers in the world; owns VW, Audi, Porsche, Škoda, SEAT and Lamborghini.",
            category: .stock,
            fallbackPrice:  96.40, fallbackChangePercent:  1.10, fallbackCurrency: "EUR"
        ),

        // MARK: ETFs popular on Scalable Broker

        Stock(
            symbol: "VWCE.DE", displaySymbol: "VWCE",
            name: "Vanguard FTSE All-World UCITS ETF (Acc)",
            summary: "Globally diversified equity ETF tracking ~3,700 companies across developed and emerging markets. Accumulating share class — dividends reinvested automatically.",
            category: .etf,
            fallbackPrice: 122.50, fallbackChangePercent:  0.85, fallbackCurrency: "EUR"
        ),
        Stock(
            symbol: "EUNL.DE", displaySymbol: "EUNL",
            name: "iShares Core MSCI World UCITS ETF",
            summary: "Tracks the MSCI World index — about 1,500 large- and mid-cap companies across developed markets. One of the most-held ETFs by European retail investors.",
            category: .etf,
            fallbackPrice:  98.40, fallbackChangePercent:  0.72, fallbackCurrency: "EUR"
        ),
        Stock(
            symbol: "SXR8.DE", displaySymbol: "SXR8",
            name: "iShares Core S&P 500 UCITS ETF",
            summary: "Tracks the S&P 500 — the 500 largest US public companies. Popular base layer for European retail investors who want US large-cap exposure without buying ADRs.",
            category: .etf,
            fallbackPrice: 552.10, fallbackChangePercent:  1.05, fallbackCurrency: "EUR"
        ),
        Stock(
            symbol: "IS3N.DE", displaySymbol: "IS3N",
            name: "iShares Core MSCI EM IMI UCITS ETF",
            summary: "Tracks the MSCI Emerging Markets IMI index — ~3,000 large-, mid- and small-cap companies across emerging markets. Common diversifier on top of a MSCI World position.",
            category: .etf,
            fallbackPrice:  31.85, fallbackChangePercent: -0.18, fallbackCurrency: "EUR"
        ),
    ]

    /// The default watchlist a brand-new user starts with on first launch.
    static let defaultWatchlistSymbols: [String] = [
        "AAPL", "TSLA", "MSFT", "NVDA", "ASML", "SAP.DE", "ALV.DE",
        "VWCE.DE", "EUNL.DE", "SXR8.DE",
    ]

    /// Lookup helper.
    static func stock(forSymbol symbol: String) -> Stock? {
        catalog.first { $0.symbol == symbol }
    }
}
