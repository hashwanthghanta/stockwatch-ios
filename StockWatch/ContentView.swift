import SwiftUI

struct ContentView: View {
    @State private var vm = WatchlistViewModel()

    var body: some View {
        NavigationStack {
            List(vm.stocks) { stock in
                NavigationLink(value: stock.id) {
                    StockRowView(stock: stock)
                }
            }
            .navigationTitle("Watchlist")
            .navigationDestination(for: UUID.self) { id in
                if let stock = vm.stocks.first(where: { $0.id == id }) {
                    StockDetailView(stock: stock)
                }
            }
            .toolbar {
                Button("Refresh") { vm.refresh() }
                    .accessibilityHint("Randomises prices to simulate live data")
            }
        }
    }
}

#Preview {
    ContentView()
}
