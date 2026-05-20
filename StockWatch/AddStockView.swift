import SwiftUI

struct AddStockView: View {
    @Environment(\.dismiss) private var dismiss

    let availableStocks: [Stock]
    let onAdd: (String) -> Void

    @State private var searchText = ""

    private var filtered: [Stock] {
        guard !searchText.isEmpty else { return availableStocks }
        return availableStocks.filter {
            $0.displaySymbol.localizedCaseInsensitiveContains(searchText) ||
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var stocks: [Stock]  { filtered.filter { $0.category == .stock } }
    private var etfs:   [Stock]  { filtered.filter { $0.category == .etf } }

    var body: some View {
        NavigationStack {
            Group {
                if availableStocks.isEmpty {
                    ContentUnavailableView(
                        String(localized: "Watchlist is full"),
                        systemImage: "checkmark.seal",
                        description: Text(String(localized: "You already track every available symbol."))
                    )
                } else {
                    List {
                        if !stocks.isEmpty {
                            Section(AssetCategory.stock.localizedSectionTitle) {
                                ForEach(stocks) { row(for: $0) }
                            }
                        }
                        if !etfs.isEmpty {
                            Section(AssetCategory.etf.localizedSectionTitle) {
                                ForEach(etfs) { row(for: $0) }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: Text("Search symbols"))
                }
            }
            .navigationTitle(Text("Add to watchlist"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
            }
        }
    }

    private func row(for stock: Stock) -> some View {
        Button {
            onAdd(stock.symbol)
            dismiss()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stock.displaySymbol).font(.headline)
                    Text(stock.name).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stock.displaySymbol), \(stock.name)")
        .accessibilityHint(Text("Adds this symbol to your watchlist"))
    }
}

#Preview {
    AddStockView(
        availableStocks: MockData.catalog,
        onAdd: { _ in }
    )
}
