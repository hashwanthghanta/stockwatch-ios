import SwiftUI

struct StockRowView: View {
    let stock: Stock

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(stock.symbol).font(.headline)
                Text(stock.name).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(stock.formattedPrice).font(.headline)
                HStack(spacing: 4) {
                    Image(systemName: stock.isUp ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption.weight(.bold))
                    Text(stock.formattedChange).font(.subheadline)
                }
                .foregroundStyle(stock.isUp ? .green : .red)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(stock.accessibilityDescription)
    }
}

#Preview {
    List {
        StockRowView(stock: MockData.stocks[0])
        StockRowView(stock: MockData.stocks[1])
    }
}
