import SwiftUI

struct StockRowView: View {
    let stock: Stock
    let price: Double
    let changePercent: Double
    let currency: String

    private var isUp: Bool { changePercent >= 0 }

    private var currencySymbol: String {
        switch currency {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        default:    return currency + " "
        }
    }

    private var formattedPrice: String {
        String(format: "%@%.2f", currencySymbol, price)
    }

    private var formattedChange: String {
        String(format: "%+.2f%%", changePercent)
    }

    private var accessibilityDescription: String {
        let dir = isUp ? "up" : "down"
        return "\(stock.displaySymbol), \(stock.name), \(formattedPrice), \(dir) \(String(format: "%.2f", abs(changePercent))) percent"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(stock.displaySymbol).font(.headline)
                Text(stock.name).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedPrice).font(.headline)
                HStack(spacing: 4) {
                    Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption.weight(.bold))
                    Text(formattedChange).font(.subheadline)
                }
                .foregroundStyle(isUp ? .green : .red)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
}

#Preview {
    List {
        StockRowView(stock: MockData.catalog[0],
                     price: 189.20, changePercent: 1.24, currency: "USD")
        StockRowView(stock: MockData.catalog[4],
                     price: 263.80, changePercent: -1.05, currency: "EUR")
    }
}
