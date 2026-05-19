import Foundation

enum StockServiceError: LocalizedError {
    case noData
    case badStatus(Int)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .noData:               return "The service returned no data."
        case .badStatus(let code):  return "Server responded with status \(code)."
        case .decoding(let inner):  return "Could not decode response: \(inner.localizedDescription)"
        }
    }
}

protocol StockService: Sendable {
    func fetchQuote(symbol: String) async throws -> StockQuote
}

/// Live implementation backed by Yahoo Finance's unauthenticated chart endpoint.
/// Endpoint: https://query1.finance.yahoo.com/v8/finance/chart/{symbol}
/// Note: Yahoo blocks requests without a normal browser User-Agent header.
final class YahooStockService: StockService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Try query2 first, fall back to query1 on failure.
    /// Both share the same payload shape; query2 has been more reliable for unauthenticated traffic.
    private static let hosts = ["query2.finance.yahoo.com", "query1.finance.yahoo.com"]

    func fetchQuote(symbol: String) async throws -> StockQuote {
        let escaped = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol

        var lastError: Error = StockServiceError.noData
        var data: Data?
        for host in Self.hosts {
            let url = URL(string: "https://\(host)/v8/finance/chart/\(escaped)?interval=1d&range=1mo&includePrePost=false")!
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 15
            do {
                let (body, response) = try await session.data(for: request)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    lastError = StockServiceError.badStatus(http.statusCode)
                    continue
                }
                data = body
                break
            } catch {
                lastError = error
                continue
            }
        }
        guard let data else { throw lastError }

        let envelope: YahooChartResponse
        do {
            envelope = try JSONDecoder().decode(YahooChartResponse.self, from: data)
        } catch {
            throw StockServiceError.decoding(error)
        }

        guard let result = envelope.chart.result?.first else {
            throw StockServiceError.noData
        }
        let meta = result.meta
        let closes = (result.indicators.quote.first?.close ?? []).compactMap { $0 }
        return StockQuote(
            symbol: symbol,
            currentPrice:     meta.regularMarketPrice ?? closes.last ?? 0,
            previousClose:    meta.chartPreviousClose ?? meta.previousClose ?? closes.last ?? 0,
            dayHigh:          meta.regularMarketDayHigh ?? closes.max() ?? 0,
            dayLow:           meta.regularMarketDayLow  ?? closes.min() ?? 0,
            fiftyTwoWeekHigh: meta.fiftyTwoWeekHigh ?? closes.max() ?? 0,
            fiftyTwoWeekLow:  meta.fiftyTwoWeekLow  ?? closes.min() ?? 0,
            volume:           meta.regularMarketVolume ?? 0,
            currency:         meta.currency ?? "USD",
            historicalCloses: closes
        )
    }
}

/// Test-friendly mock service. Returns deterministic fake data.
final class MockStockService: StockService {
    let delay: TimeInterval
    init(delay: TimeInterval = 0) { self.delay = delay }

    func fetchQuote(symbol: String) async throws -> StockQuote {
        if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
        let base = Double(abs(symbol.hashValue % 500) + 50)
        let history = (0..<30).map { i -> Double in
            base * (1 + sin(Double(i) / 5) * 0.05)
        }
        return StockQuote(
            symbol: symbol,
            currentPrice: history.last ?? base,
            previousClose: history.dropLast().last ?? base,
            dayHigh: (history.last ?? base) * 1.01,
            dayLow:  (history.last ?? base) * 0.99,
            fiftyTwoWeekHigh: base * 1.20,
            fiftyTwoWeekLow:  base * 0.80,
            volume: 1_234_567,
            currency: "USD",
            historicalCloses: history
        )
    }
}

// MARK: - Yahoo response models

private struct YahooChartResponse: Decodable {
    let chart: Chart
    struct Chart: Decodable {
        let result: [Result]?
        let error: YahooError?
    }
    struct YahooError: Decodable {
        let code: String?
        let description: String?
    }
    struct Result: Decodable {
        let meta: Meta
        let timestamp: [Int]?
        let indicators: Indicators
    }
    struct Meta: Decodable {
        let currency: String?
        let symbol: String?
        let regularMarketPrice: Double?
        let chartPreviousClose: Double?
        let previousClose: Double?
        let regularMarketDayHigh: Double?
        let regularMarketDayLow: Double?
        let regularMarketVolume: Int64?
        let fiftyTwoWeekHigh: Double?
        let fiftyTwoWeekLow: Double?
    }
    struct Indicators: Decodable {
        let quote: [Quote]
    }
    struct Quote: Decodable {
        let close: [Double?]?
    }
}
