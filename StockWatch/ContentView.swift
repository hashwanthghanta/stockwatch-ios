import SwiftUI

struct ContentView: View {
    @State private var vm = WatchlistViewModel()

    var body: some View {
        NavigationStack {
            List(vm.stocks) { stock in
                NavigationLink(value: stock.symbol) {
                    StockRowView(
                        stock: stock,
                        price: vm.price(for: stock),
                        changePercent: vm.changePercent(for: stock),
                        currency: vm.currency(for: stock)
                    )
                }
            }
            .listStyle(.insetGrouped)
            .refreshable { await vm.refresh() }
            .navigationTitle("Watchlist")
            .navigationDestination(for: String.self) { symbol in
                if let stock = vm.stocks.first(where: { $0.symbol == symbol }) {
                    StockDetailView(stock: stock, service: vm.service)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { statusBadge }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await vm.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh quotes")
                    .accessibilityHint("Loads the latest live prices")
                }
            }
            .task { await vm.refresh() }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch vm.state {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("Loading…").font(.caption).foregroundStyle(.secondary)
            }
            .accessibilityLabel("Loading live quotes")
        case .loaded:
            Label("Live", systemImage: "dot.radiowaves.left.and.right")
                .labelStyle(.titleAndIcon)
                .font(.caption)
                .foregroundStyle(.green)
                .accessibilityLabel("Live quotes loaded")
        case .partial(let failures):
            Label("\(failures) failed", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
                .accessibilityLabel("\(failures) symbols failed to load — showing fallback prices")
        case .failed:
            Label("Offline", systemImage: "wifi.slash")
                .font(.caption)
                .foregroundStyle(.red)
                .accessibilityLabel("Offline — showing fallback prices")
        }
    }
}

#Preview {
    ContentView()
}
