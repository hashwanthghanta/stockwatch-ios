import SwiftUI
import Charts

struct StockDetailView: View {
    let stock: Stock
    let service: StockService
    let demoSelectedOffset: Int?   // nil in production; used only for screenshot builds

    @State private var quote: StockQuote?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedDate: Date?

    init(stock: Stock, service: StockService, demoSelectedOffset: Int? = nil) {
        self.stock = stock
        self.service = service
        self.demoSelectedOffset = demoSelectedOffset
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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                priceBlock
                chartSection
                metricsGrid
                aboutSection
                Spacer(minLength: 24)
            }
            .padding()
        }
        .navigationTitle(stock.displaySymbol)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
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
        if let q = quote, q.historicalCloses.count > 1, q.historicalDates.count == q.historicalCloses.count {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Last \(q.historicalCloses.count) days")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if selectedDate == nil {
                        Text("Touch the chart to inspect a day")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                interactiveChart(quote: q)
            }
        } else if isLoading {
            placeholderChart
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Chart unavailable")
                    .font(.caption).foregroundStyle(.secondary)
                placeholderChart
                    .opacity(0.4)
                    .accessibilityHidden(true)
            }
        }
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
                        colors: [lineColor.opacity(0.30), lineColor.opacity(0.0)],
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
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartXSelection(value: $selectedDate)
        .accessibilityLabel(Text("Price history chart for \(stock.name), last \(q.historicalCloses.count) days"))
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
        return VStack(spacing: 2) {
            Text(String(format: "%@%.2f", sym, close))
                .font(.caption.weight(.bold))
                .monospacedDigit()
            Text(date, format: .dateTime.month(.abbreviated).day().year(.twoDigits))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
        )
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
            let q = try await service.fetchQuote(symbol: stock.symbol)
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
