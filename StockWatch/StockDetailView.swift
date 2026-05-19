import SwiftUI

struct StockDetailView: View {
    let stock: Stock

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(stock.name).font(.title2).bold()
                Text(stock.symbol).font(.subheadline).foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(stock.formattedPrice).font(.system(size: 44, weight: .bold))
                HStack(spacing: 4) {
                    Image(systemName: stock.isUp ? "arrow.up.right" : "arrow.down.right")
                        .font(.title3.weight(.bold))
                    Text(stock.formattedChange).font(.title3)
                }
                .foregroundStyle(stock.isUp ? .green : .red)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(stock.accessibilityDescription)

            // Placeholder "chart" — decorative bars, ignored by VoiceOver.
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<14, id: \.self) { _ in
                    Capsule()
                        .fill(stock.isUp ? .green : .red)
                        .frame(width: 14, height: CGFloat.random(in: 20...120))
                        .opacity(0.6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityHidden(true)

            Spacer()
        }
        .padding()
        .navigationTitle(stock.symbol)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        StockDetailView(stock: MockData.stocks[0])
    }
}
