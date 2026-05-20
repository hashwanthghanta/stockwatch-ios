import Foundation

/// A single news article tied to a stock symbol.
struct NewsItem: Identifiable, Equatable, Sendable {
    let id: String       // article link doubles as a stable id
    let title: String
    let summary: String
    let link: URL
    let publisher: String
    let publishedAt: Date?

    static func == (lhs: NewsItem, rhs: NewsItem) -> Bool { lhs.id == rhs.id }
}

protocol NewsService: Sendable {
    func fetchNews(symbol: String, companyName: String) async throws -> [NewsItem]
}

/// Live implementation that prefers Yahoo Finance's symbol-filtered search-news JSON
/// endpoint, and falls back to a Google News RSS query for the company name if Yahoo
/// returns nothing relevant. The older `feeds.finance.yahoo.com/rss/2.0/headline`
/// endpoint we used previously now returns generic finance headlines regardless of
/// the `s=` parameter, so we no longer rely on it.
final class YahooNewsService: NewsService {
    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func fetchNews(symbol: String, companyName: String) async throws -> [NewsItem] {
        async let primary = fetchYahooSearchNews(symbol: symbol)
        let yahooItems = (try? await primary) ?? []
        if !yahooItems.isEmpty { return yahooItems }
        return (try? await fetchGoogleNewsRSS(symbol: symbol, companyName: companyName)) ?? []
    }

    // MARK: - Primary: Yahoo Finance Search News (JSON, symbol-filtered)

    private func fetchYahooSearchNews(symbol: String) async throws -> [NewsItem] {
        let escapedSymbol = symbol.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? symbol
        let hosts = ["query2.finance.yahoo.com", "query1.finance.yahoo.com"]
        var data: Data?
        for host in hosts {
            guard let url = URL(string: "https://\(host)/v1/finance/search?q=\(escapedSymbol)&quotesCount=0&newsCount=20&enableFuzzyQuery=false&newsQueryId=news_cie_vespa") else { continue }
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 12
            do {
                let (body, response) = try await session.data(for: request)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    data = body
                    break
                }
            } catch { continue }
        }
        guard let data else { return [] }
        let env = try JSONDecoder().decode(YahooSearchEnvelope.self, from: data)

        let upperSymbol = symbol.uppercased()
        // Yahoo's tickers list is the most reliable filter; some stories have no
        // tickers attached so we also keep items whose title or publisher name
        // mention the symbol explicitly.
        return (env.news ?? []).compactMap { article -> NewsItem? in
            guard let link = URL(string: article.link) else { return nil }
            let tickers = (article.relatedTickers ?? []).map { $0.uppercased() }
            let titleMentionsSymbol = article.title.uppercased().contains(upperSymbol)
            guard tickers.contains(upperSymbol) || titleMentionsSymbol || tickers.isEmpty else {
                return nil
            }
            let date = article.providerPublishTime.map { Date(timeIntervalSince1970: TimeInterval($0)) }
            return NewsItem(
                id: article.uuid ?? article.link,
                title: article.title,
                summary: "",
                link: link,
                publisher: article.publisher ?? "Yahoo Finance",
                publishedAt: date
            )
        }
    }

    // MARK: - Fallback: Google News RSS for the company name

    private func fetchGoogleNewsRSS(symbol: String, companyName: String) async throws -> [NewsItem] {
        // Build a query that combines the symbol and a cleaned company name so
        // results stay tightly relevant. e.g. `AAPL OR "Apple Inc."` for AAPL.
        let cleanedName = companyName
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let baseSymbol = symbol.split(separator: ".").first.map(String.init) ?? symbol
        let query = "\(baseSymbol) OR \"\(cleanedName)\" stock"
        guard let escaped = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
        guard let url = URL(string: "https://news.google.com/rss/search?q=\(escaped)&hl=en-US&gl=US&ceid=US:en") else { return [] }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            return []
        }
        let parser = RSSParser()
        return parser.parse(data: data)
    }
}

// MARK: - Yahoo search envelope

private struct YahooSearchEnvelope: Decodable {
    let news: [YahooSearchArticle]?
}

private struct YahooSearchArticle: Decodable {
    let uuid: String?
    let title: String
    let publisher: String?
    let link: String
    let providerPublishTime: Int?
    let type: String?
    let relatedTickers: [String]?
}

// MARK: - RSS parser (Google News fallback)

private final class RSSParser: NSObject, XMLParserDelegate {
    private var items: [NewsItem] = []
    private var currentElement = ""
    private var inItem = false

    private var titleBuf = ""
    private var linkBuf = ""
    private var descBuf = ""
    private var pubBuf  = ""
    private var sourceBuf = ""

    private static let rfc822: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return f
    }()

    func parse(data: Data) -> [NewsItem] {
        let p = XMLParser(data: data)
        p.delegate = self
        p.parse()
        return items
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "item" {
            inItem = true
            titleBuf = ""; linkBuf = ""; descBuf = ""; pubBuf = ""; sourceBuf = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else { return }
        switch currentElement {
        case "title":       titleBuf += string
        case "link":        linkBuf  += string
        case "description": descBuf  += string
        case "pubDate":     pubBuf   += string
        case "source":      sourceBuf += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            inItem = false
            let title = titleBuf.trimmingCharacters(in: .whitespacesAndNewlines)
            let linkStr = linkBuf.trimmingCharacters(in: .whitespacesAndNewlines)
            let summary = descBuf.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty, let url = URL(string: linkStr) {
                let publisher = sourceBuf.trimmingCharacters(in: .whitespacesAndNewlines)
                let published = Self.rfc822.date(from: pubBuf.trimmingCharacters(in: .whitespacesAndNewlines))
                items.append(NewsItem(
                    id: linkStr,
                    title: stripHTML(title),
                    summary: stripHTML(summary),
                    link: url,
                    publisher: publisher.isEmpty ? "Google News" : publisher,
                    publishedAt: published
                ))
            }
        }
        currentElement = ""
    }

    private func stripHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
         .replacingOccurrences(of: "&nbsp;", with: " ")
         .replacingOccurrences(of: "&amp;",  with: "&")
         .replacingOccurrences(of: "&quot;", with: "\"")
         .replacingOccurrences(of: "&#39;",  with: "'")
         .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Test-friendly mock that returns three canned items.
final class MockNewsService: NewsService {
    func fetchNews(symbol: String, companyName: String) async throws -> [NewsItem] {
        let now = Date()
        return [
            NewsItem(id: "https://example.com/\(symbol)/a",
                     title: "\(companyName) rallies on strong earnings",
                     summary: "Sample headline used for previews and tests.",
                     link: URL(string: "https://example.com/\(symbol)/a")!,
                     publisher: "Mock Wire",
                     publishedAt: now.addingTimeInterval(-3600)),
            NewsItem(id: "https://example.com/\(symbol)/b",
                     title: "Analysts raise \(symbol) price target",
                     summary: "Sample headline used for previews and tests.",
                     link: URL(string: "https://example.com/\(symbol)/b")!,
                     publisher: "Mock Wire",
                     publishedAt: now.addingTimeInterval(-7200)),
        ]
    }
}
