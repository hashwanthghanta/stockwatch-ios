import SwiftUI

struct ContentView: View {
    @State private var vm = WatchlistViewModel()
    @State private var searchText = ""
    @State private var showAddSheet = false

    private var stocks: [Stock] {
        let s = vm.stocks(in: .stock)
        return filter(s)
    }
    private var etfs: [Stock] {
        let e = vm.stocks(in: .etf)
        return filter(e)
    }

    private func filter(_ list: [Stock]) -> [Stock] {
        guard !searchText.isEmpty else { return list }
        return list.filter {
            $0.displaySymbol.localizedCaseInsensitiveContains(searchText) ||
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !stocks.isEmpty {
                    Section(AssetCategory.stock.localizedSectionTitle) {
                        ForEach(stocks) { rowLink(for: $0) }
                    }
                }
                if !etfs.isEmpty {
                    Section(AssetCategory.etf.localizedSectionTitle) {
                        ForEach(etfs) { rowLink(for: $0) }
                    }
                }
                if stocks.isEmpty && etfs.isEmpty {
                    emptyState
                }

                if let updatedAt = vm.lastRefreshedAt {
                    Section {
                        EmptyView()
                    } footer: {
                        Text("Updated \(updatedAt, style: .time)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: Text("Search watchlist"))
            .refreshable { await vm.refresh() }
            .navigationTitle(Text("Watchlist"))
            .navigationDestination(for: String.self) { symbol in
                if let stock = MockData.stock(forSymbol: symbol) {
                    StockDetailView(stock: stock, service: vm.service)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { statusBadge }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button {
                            showAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel(Text("Add stock"))
                        .accessibilityHint(Text("Opens a list of symbols you can add to your watchlist"))

                        Button {
                            Task { await vm.refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel(Text("Refresh quotes"))
                        .accessibilityHint(Text("Loads the latest live prices"))
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddStockView(
                    availableStocks: vm.addableStocks,
                    onAdd: { sym in Task { await vm.add(symbol: sym) } }
                )
            }
            .task { await vm.refresh() }
        }
    }

    @ViewBuilder
    private func rowLink(for stock: Stock) -> some View {
        NavigationLink(value: stock.symbol) {
            StockRowView(
                stock: stock,
                price: vm.price(for: stock),
                changePercent: vm.changePercent(for: stock),
                currency: vm.currency(for: stock)
            )
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                vm.remove(symbol: stock.symbol)
            } label: {
                Label(String(localized: "Remove"), systemImage: "trash")
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            String(localized: "No matches"),
            systemImage: "magnifyingglass",
            description: Text(String(localized: "Nothing matches “\(searchText)”."))
        )
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch vm.state {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("Loading").font(.caption).foregroundStyle(.secondary)
            }
            .accessibilityLabel(Text("Loading live quotes"))
        case .loaded:
            Label {
                Text("Live")
            } icon: {
                Image(systemName: "dot.radiowaves.left.and.right")
            }
            .labelStyle(.titleAndIcon)
            .font(.caption)
            .foregroundStyle(.green)
            .accessibilityLabel(Text("Live quotes loaded"))
        case .partial(let failures):
            Label {
                Text("\(failures) failed")
            } icon: {
                Image(systemName: "exclamationmark.triangle")
            }
            .font(.caption)
            .foregroundStyle(.orange)
            .accessibilityLabel(Text("\(failures) symbols failed to load — showing fallback prices"))
        case .failed:
            Label {
                Text("Offline")
            } icon: {
                Image(systemName: "wifi.slash")
            }
            .font(.caption)
            .foregroundStyle(.red)
            .accessibilityLabel(Text("Offline — showing fallback prices"))
        }
    }
}

#Preview {
    ContentView()
}
