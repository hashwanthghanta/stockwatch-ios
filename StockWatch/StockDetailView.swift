import SwiftUI
import Charts

struct StockDetailView: View {
    let stock: Stock
    let service: StockService
    let demoSelectedOffset: Int?   // nil in production; used only for screenshot builds
    let onViewed: ((String) -> Void)?

    @State private var quote: StockQuote?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedDate: Date?
    @State private var selectedRange: ChartRange = .oneMonth
    @State private var news: [NewsItem] = []
    @State private var isLoadingNews = false
    @State private var openedArticle: NewsItem?

    private let newsService: NewsService = YahooNewsService()

    init(stock: Stock,
         service: StockService,
         demoSelectedOffset: Int? = nil,
         onViewed: ((String) -> Void)? = nil) {
        self.stock = stock
        self.service = service
        self.demoSelectedOffset = demoSelectedOffset
        self.onViewed = onViewed
    }

    private var isUp: Bool { (quote?.isUp) ?? (stock.fallbackChangePercent >= 0) }

    private var lineColor: Color { isUp ? .green : .red }

    private var displayPrice: String {
        if let q = quote { return q.formattedPrice(q.currentPrice) }
        let sym = stock.fallbackCurrency == "EUR" ? "€" : "$"
        return String(format: "%@%.2f", sym, stock.fallbackPrice)
    }

    private var displayChange: String {
        if let q = quote { return q.formattedChange() }
        return String(format: "%+.2f%%", stock.fallbackChangePercent)
    }

    var body: some View {
        scrollContainer {
            VStack(alignment: .leading, spacing: 24) {
                header
                priceBlock
                chartSection
                metricsGrid
                aboutSection
                newsSection
                Spacer(minLength: 24)
            }
            .padding()
        }
        .navigationTitle(stock.displaySymbol)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
            await loadNews()
        }
        .refreshable {
            await load()
            await loadNews()
        }
        .onAppear { onViewed?(stock.symbol) }
        .sheet(item: $openedArticle) { item in
            SafariView(url: item.link)
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func scrollContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        #if SCREENSHOT_NEWS
        ScrollView { content() }.defaultScrollAnchor(.bottom)
        #else
        ScrollView { content() }
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(stock.name).font(.title2).bold()
            Text(stock.displaySymbol).font(.subheadline).foregroundStyle(.secondary)
            if let err = errorMessage {
                Label(err, systemImage: "wifi.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var priceBlock: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(displayPrice).font(.system(size: 38, weight: .bold))
            HStack(spacing: 4) {
                Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                    .font(.title3.weight(.bold))
                Text(displayChange).font(.title3)
            }
            .foregroundStyle(lineColor)
            if isLoading {
                ProgressView().padding(.leading, 6)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stock.name), \(displayPrice), \(isUp ? "up" : "down") \(displayChange)")
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            rangePicker
            if let q = quote, q.historicalCloses.count > 1, q.historicalDates.count == q.historicalCloses.count {
                HStack {
                    Text("\(q.historicalCloses.count) points · \(selectedRange.shortLabel)")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if selectedDate == nil {
                        Text("Touch the chart to inspect a point")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                interactiveChart(quote: q)
            } else if isLoading {
                placeholderChart
            } else {
                Text("Chart unavailable")
                    .font(.caption).foregroundStyle(.secondary)
                placeholderChart
                    .opacity(0.4)
                    .accessibilityHidden(true)
            }
        }
    }

    private var rangePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ChartRange.allCases) { range in
                    let isSelected = range == selectedRange
                    Button {
                        guard range != selectedRange else { return }
                        selectedRange = range
                        selectedDate = nil
                        Task { await load() }
                    } label: {
                        Text(range.shortLabel)
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(isSelected
                                               ? lineColor.opacity(0.18)
                                               : Color.secondary.opacity(0.10))
                            )
                            .overlay(
                                Capsule().stroke(isSelected ? lineColor.opacity(0.55) : .clear,
                                                 lineWidth: 1)
                            )
                            .foregroundStyle(isSelected ? lineColor : .primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(range.shortLabel))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityHint(Text("Shows the chart over the selected period"))
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Chart time range"))
    }

    @ViewBuilder
    private func interactiveChart(quote q: StockQuote) -> some View {
        let pairs = Array(zip(q.historicalDates, q.historicalCloses))
        let selectedPoint: (date: Date, close: Double)? = selectedDate.flatMap { q.nearestPoint(to: $0) }

        Chart {
            ForEach(pairs.indices, id: \.self) { idx in
                let date  = pairs[idx].0
                let close = pairs[idx].1
                AreaMark(
                    x: .value("Date", date),
                    y: .value("Price", close)
                )
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: lineColor.opacity(0.22), location: 0.00),
                            .init(color: lineColor.opacity(0.10), location: 0.35),
                            .init(color: lineColor.opacity(0.03), location: 0.70),
                            .init(color: lineColor.opacity(0.00), location: 1.00),
                        ],
                        startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", date),
                    y: .value("Price", close)
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }

            if let selected = selectedPoint {
                RuleMark(x: .value("Selected", selected.date))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

                PointMark(
                    x: .value("Selected", selected.date),
                    y: .value("Selected", selected.close)
                )
                .foregroundStyle(lineColor)
                .symbolSize(110)
                .annotation(position: .top, alignment: .center, spacing: 6, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                    selectionBubble(date: selected.date, close: selected.close, currency: q.currency)
                }
            }
        }
        .frame(height: 200)
        .chartPlotStyle { plot in
            plot.background(Color.clear)
        }
        .clipped()
        .chartYScale(domain: chartYDomain(for: q))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: xAxisFormat)
            }
        }
        .chartXSelection(value: $selectedDate)
        .accessibilityLabel(Text("Price history chart for \(stock.name), last \(q.historicalCloses.count) days"))
    }

    private var xAxisFormat: Date.FormatStyle {
        switch selectedRange {
        case .oneDay:
            return .dateTime.hour().minute()
        case .oneWeek:
            return .dateTime.weekday(.abbreviated).hour()
        case .oneMonth, .threeMonths, .sixMonths:
            return .dateTime.month(.abbreviated).day()
        case .oneYear:
            return .dateTime.month(.abbreviated)
        case .threeYears, .fiveYears:
            return .dateTime.month(.abbreviated).year(.twoDigits)
        }
    }

    private func selectionBubble(date: Date, close: Double, currency: String) -> some View {
        let sym: String = {
            switch currency {
            case "EUR": return "€"
            case "GBP": return "£"
            case "JPY": return "¥"
            default:    return "$"
            }
        }()
        return VStack(spacing: 1) {
            Text(String(format: "%@%.2f", sym, close))
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundColor(.white)
            Text(date, format: .dateTime.month(.abbreviated).day().year(.twoDigits))
                .font(.caption2)
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.04, green: 0.20, blue: 0.36))
        )
        .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
    }

    /// Pads the Y axis to the actual data range with 10 % headroom on each end,
    /// so a stock trading in 135–160 doesn't get squashed against the top edge
    /// of a 0–200 chart.
    private func chartYDomain(for q: StockQuote) -> ClosedRange<Double> {
        guard let lo = q.historicalCloses.min(),
              let hi = q.historicalCloses.max(), lo < hi else {
            return 0...1
        }
        let pad = (hi - lo) * 0.10
        return (lo - pad)...(hi + pad)
    }

    private var placeholderChart: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<14, id: \.self) { _ in
                Capsule()
                    .fill(lineColor)
                    .frame(width: 14, height: CGFloat.random(in: 20...120))
                    .opacity(0.5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityHidden(true)
    }

    // MARK: - Metrics

    private var metricsGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            metric(label: Text("Day High"),   value: formatMetric(quote?.dayHigh,  currency: quote?.currency))
            metric(label: Text("Day Low"),    value: formatMetric(quote?.dayLow,   currency: quote?.currency))
            metric(label: Text("52w High"),   value: formatMetric(quote?.fiftyTwoWeekHigh, currency: quote?.currency))
            metric(label: Text("52w Low"),    value: formatMetric(quote?.fiftyTwoWeekLow,  currency: quote?.currency))
            metric(label: Text("Prev close"), value: formatMetric(quote?.previousClose,    currency: quote?.currency))
            metric(label: Text("Volume"),     value: formatVolume(quote?.volume))
        }
    }

    private func metric(label: Text, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            label.font(.caption).foregroundStyle(.secondary)
            Text(value).font(.callout).bold().monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(8)
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About").font(.headline)
            Text(stock.summary)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - News

    @ViewBuilder
    private var newsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "newspaper.fill")
                    .foregroundStyle(.tint)
                Text("News")
                    .font(.headline)
                Spacer()
                if isLoadingNews {
                    ProgressView().controlSize(.small)
                }
            }

            if news.isEmpty {
                if isLoadingNews {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.vertical, 12)
                        Spacer()
                    }
                } else {
                    Text("No recent headlines for \(stock.displaySymbol).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(news.prefix(8)) { item in
                        Button { openedArticle = item } label: {
                            newsCard(item: item)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(item.publisher). \(item.title)")
                        .accessibilityHint(Text("Opens the article in an in-app browser"))
                    }
                }
            }
        }
    }

    private func newsCard(item: NewsItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(item.publisher)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                if let date = item.publishedAt {
                    Text(date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Image(systemName: "arrow.up.right.square")
                    .font(.caption2)
                    .foregroundStyle(.tint)
            }
            Text(item.title)
                .font(.callout.weight(.semibold))
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .foregroundStyle(.primary)
            if !item.summary.isEmpty {
                Text(item.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
    }

    private func loadNews() async {
        isLoadingNews = true
        // Use the bare ticker (e.g. "SAP" from "SAP.DE") for Yahoo's news search
        // so we get global coverage, not just the local-exchange listing.
        let baseSymbol = stock.symbol.split(separator: ".").first.map(String.init) ?? stock.symbol
        do {
            let items = try await newsService.fetchNews(symbol: baseSymbol, companyName: stock.name)
            news = items
        } catch {
            news = []
        }
        isLoadingNews = false
    }

    // MARK: - Formatting helpers

    private func formatMetric(_ value: Double?, currency: String?) -> String {
        guard let v = value, v > 0 else { return "—" }
        let sym: String
        switch currency {
        case "EUR": sym = "€"
        case "GBP": sym = "£"
        case "JPY": sym = "¥"
        default:    sym = "$"
        }
        return String(format: "%@%.2f", sym, v)
    }

    private func formatVolume(_ value: Int64?) -> String {
        guard let v = value, v > 0 else { return "—" }
        let d = Double(v)
        if d >= 1_000_000_000 { return String(format: "%.2fB", d / 1_000_000_000) }
        if d >= 1_000_000     { return String(format: "%.2fM", d / 1_000_000) }
        if d >= 1_000         { return String(format: "%.1fK", d / 1_000) }
        return "\(v)"
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let q = try await service.fetchQuote(symbol: stock.symbol, range: selectedRange)
            quote = q
            if let offset = demoSelectedOffset,
               !q.historicalDates.isEmpty {
                let idx = max(0, min(q.historicalDates.count - 1, offset))
                selectedDate = q.historicalDates[idx]
            }
        } catch {
            errorMessage = String(localized: "Live data unavailable — showing last known values.")
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        StockDetailView(stock: MockData.catalog[0], service: MockStockService())
    }
}
