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

enum ChartRange: String, CaseIterable, Identifiable, Sendable {
    case oneDay, oneWeek, oneMonth, threeMonths, sixMonths, oneYear, threeYears, fiveYears
    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .oneDay:       return "1D"
        case .oneWeek:      return "1W"
        case .oneMonth:     return "1M"
        case .threeMonths:  return "3M"
        case .sixMonths:    return "6M"
        case .oneYear:      return "1Y"
        case .threeYears:   return "3Y"
        case .fiveYears:    return "5Y"
        }
    }

    /// Yahoo `range` query value.
    var yahooRange: String {
        switch self {
        case .oneDay:       return "1d"
        case .oneWeek:      return "5d"
        case .oneMonth:     return "1mo"
        case .threeMonths:  return "3mo"
        case .sixMonths:    return "6mo"
        case .oneYear:      return "1y"
        case .threeYears:   return "3y"
        case .fiveYears:    return "5y"
        }
    }

    /// Yahoo `interval` query value — tuned so each range has ~30–260 data points.
    var yahooInterval: String {
        switch self {
        case .oneDay:       return "5m"
        case .oneWeek:      return "15m"
        case .oneMonth:     return "1d"
        case .threeMonths:  return "1d"
        case .sixMonths:    return "1d"
        case .oneYear:      return "1d"
        case .threeYears:   return "1wk"
        case .fiveYears:    return "1wk"
        }
    }
}

protocol StockService: Sendable {
    func fetchQuote(symbol: String) async throws -> StockQuote
    func fetchQuote(symbol: String, range: ChartRange) async throws -> StockQuote
}

extension StockService {
    /// Default routes range-less calls to the 1-month variant for back-compat.
    func fetchQuote(symbol: String) async throws -> StockQuote {
        try await fetchQuote(symbol: symbol, range: .oneMonth)
    }
}

/// Live implementation backed by Yahoo Finance's unauthenticated chart endpoint.
/// Endpoint: https://query2.finance.yahoo.com/v8/finance/chart/{symbol}
/// Note: Yahoo blocks requests without a normal browser User-Agent header,
/// and query1 frequently 429s — query2 is the primary host with query1 as fallback.
final class YahooStockService: StockService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private static let hosts = ["query2.finance.yahoo.com", "query1.finance.yahoo.com"]

    func fetchQuote(symbol: String, range: ChartRange) async throws -> StockQuote {
        let escaped = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol

        var lastError: Error = StockServiceError.noData
        var data: Data?
        for host in Self.hosts {
            let url = URL(string: "https://\(host)/v8/finance/chart/\(escaped)?interval=\(range.yahooInterval)&range=\(range.yahooRange)&includePrePost=false")!
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
        let timestamps = result.timestamp ?? []
        let dates = timestamps.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        // Trim to the same length in case Yahoo returns mismatched arrays.
        let pairCount = min(closes.count, dates.count)
        let alignedCloses = Array(closes.suffix(pairCount))
        let alignedDates  = Array(dates.suffix(pairCount))

        return StockQuote(
            symbol: symbol,
            currentPrice:     meta.regularMarketPrice ?? alignedCloses.last ?? 0,
            previousClose:    meta.chartPreviousClose ?? meta.previousClose ?? alignedCloses.last ?? 0,
            dayHigh:          meta.regularMarketDayHigh ?? alignedCloses.max() ?? 0,
            dayLow:           meta.regularMarketDayLow  ?? alignedCloses.min() ?? 0,
            fiftyTwoWeekHigh: meta.fiftyTwoWeekHigh ?? alignedCloses.max() ?? 0,
            fiftyTwoWeekLow:  meta.fiftyTwoWeekLow  ?? alignedCloses.min() ?? 0,
            volume:           meta.regularMarketVolume ?? 0,
            currency:         meta.currency ?? "USD",
            historicalCloses: alignedCloses,
            historicalDates:  alignedDates
        )
    }
}

/// Test-friendly mock service. Returns deterministic fake data.
final class MockStockService: StockService {
    let delay: TimeInterval
    init(delay: TimeInterval = 0) { self.delay = delay }

    func fetchQuote(symbol: String, range: ChartRange) async throws -> StockQuote {
        if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
        let base = Double(abs(symbol.hashValue % 500) + 50)
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        let dayCount: Int = {
            switch range {
            case .oneDay:       return 78
            case .oneWeek:      return 35
            case .oneMonth:     return 30
            case .threeMonths:  return 65
            case .sixMonths:    return 130
            case .oneYear:      return 252
            case .threeYears:   return 156
            case .fiveYears:    return 260
            }
        }()
        let history = (0..<dayCount).map { i -> Double in
            base * (1 + sin(Double(i) / 5) * 0.05)
        }
        let dates = (0..<dayCount).map { i in
            calendar.date(byAdding: .day, value: -(dayCount - 1 - i), to: now) ?? now
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
            historicalCloses: history,
            historicalDates: dates
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
