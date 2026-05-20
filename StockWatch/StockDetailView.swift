import SwiftUI
import Charts

struct StockDetailView: View {
    let stock: Stock
    let service: StockService

    @State private var quote: StockQuote?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isUp: Bool { (quote?.isUp) ?? (stock.fallbackChangePercent >= 0) }

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
            .foregroundStyle(isUp ? .green : .red)
            if isLoading {
                ProgressView().padding(.leading, 6)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stock.name), \(displayPrice), \(isUp ? "up" : "down") \(displayChange)")
    }

    @ViewBuilder
    private var chartSection: some View {
        if let q = quote, q.historicalCloses.count > 1 {
            VStack(alignment: .leading, spacing: 8) {
                Text("Last \(q.historicalCloses.count) days")
                    .font(.caption).foregroundStyle(.secondary)
                Chart {
                    ForEach(Array(q.historicalCloses.enumerated()), id: \.offset) { idx, close in
                        LineMark(
                            x: .value("Day", idx),
                            y: .value("Price", close)
                        )
                        .foregroundStyle(isUp ? .green : .red)
                        AreaMark(
                            x: .value("Day", idx),
                            y: .value("Price", close)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [(isUp ? Color.green : Color.red).opacity(0.25), .clear],
                                startPoint: .top, endPoint: .bottom)
                        )
                    }
                }
                .frame(height: 180)
                .chartYScale(domain: .automatic(includesZero: false))
                .accessibilityLabel(Text("Price history chart for \(stock.name), last \(q.historicalCloses.count) days"))
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

    private var placeholderChart: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<14, id: \.self) { _ in
                Capsule()
                    .fill(isUp ? Color.green : Color.red)
                    .frame(width: 14, height: CGFloat.random(in: 20...120))
                    .opacity(0.5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityHidden(true)
    }

    private var metricsGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            metric(label: String(localized: "Day High"),
                   value: formatMetric(quote?.dayHigh,  currency: quote?.currency))
            metric(label: String(localized: "Day Low"),
                   value: formatMetric(quote?.dayLow,   currency: quote?.currency))
            metric(label: String(localized: "52w High"),
                   value: formatMetric(quote?.fiftyTwoWeekHigh, currency: quote?.currency))
            metric(label: String(localized: "52w Low"),
                   value: formatMetric(quote?.fiftyTwoWeekLow,  currency: quote?.currency))
            metric(label: String(localized: "Prev close"),
                   value: formatMetric(quote?.previousClose,    currency: quote?.currency))
            metric(label: String(localized: "Volume"),
                   value: formatVolume(quote?.volume))
        }
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.callout).bold().monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About").font(.headline)
            Text(stock.summary)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

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
            quote = try await service.fetchQuote(symbol: stock.symbol)
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
