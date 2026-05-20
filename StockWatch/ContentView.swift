import SwiftUI

struct ContentView: View {
    @State private var vm = WatchlistViewModel()
    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var showSettings = false
    @State private var editMode: EditMode = .inactive

    private var stocks: [Stock] { filter(vm.stocks(in: .stock)) }
    private var etfs:   [Stock] { filter(vm.stocks(in: .etf)) }

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
                            .onMove { offsets, destination in
                                vm.move(in: .stock, fromOffsets: offsets, toOffset: destination)
                            }
                    }
                }
                if !etfs.isEmpty {
                    Section(AssetCategory.etf.localizedSectionTitle) {
                        ForEach(etfs) { rowLink(for: $0) }
                            .onMove { offsets, destination in
                                vm.move(in: .etf, fromOffsets: offsets, toOffset: destination)
                            }
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
            .environment(\.editMode, $editMode)
            .searchable(text: $searchText, prompt: Text("Search watchlist"))
            .refreshable { await vm.refresh() }
            .navigationTitle(Text("Watchlist"))
            .navigationDestination(for: String.self) { symbol in
                if let stock = MockData.stock(forSymbol: symbol) {
                    StockDetailView(stock: stock, service: vm.service,
                                    onViewed: { vm.markViewed(symbol: $0) })
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        DateBadge(date: .now)
                        statusBadge
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showAddSheet = true
                        } label: { Image(systemName: "plus") }
                            .accessibilityLabel(Text("Add stock"))

                        Menu {
                            Button {
                                withAnimation {
                                    editMode = (editMode == .active) ? .inactive : .active
                                }
                            } label: {
                                Label(editMode == .active
                                      ? String(localized: "Done editing")
                                      : String(localized: "Edit watchlist"),
                                      systemImage: editMode == .active ? "checkmark" : "pencil")
                            }
                            Divider()
                            Picker(String(localized: "Sort by"), selection: Binding(
                                get: { vm.sortMode },
                                set: { vm.sortMode = $0 })
                            ) {
                                Label(SortMode.manual.localizedLabel,    systemImage: "list.bullet").tag(SortMode.manual)
                                Label(SortMode.name.localizedLabel,      systemImage: "textformat").tag(SortMode.name)
                                Label(SortMode.lastViewed.localizedLabel, systemImage: "clock").tag(SortMode.lastViewed)
                            }
                            Divider()
                            Button {
                                Task { await vm.refresh() }
                            } label: {
                                Label(String(localized: "Refresh"), systemImage: "arrow.clockwise")
                            }
                            Button {
                                showSettings = true
                            } label: {
                                Label(String(localized: "Settings"), systemImage: "gearshape")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel(Text("More options"))
                        .accessibilityHint(Text("Edit list, sort, refresh, settings"))
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddStockView(
                    availableStocks: vm.addableStocks,
                    onAdd: { sym in Task { await vm.add(symbol: sym) } }
                )
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
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

/// Small circular badge in the toolbar showing today's date (weekday + day).
struct DateBadge: View {
    let date: Date

    var body: some View {
        VStack(spacing: -1) {
            Text(date, format: .dateTime.weekday(.abbreviated))
                .font(.system(size: 7).weight(.semibold))
                .textCase(.uppercase)
            Text(date, format: .dateTime.day())
                .font(.system(size: 11).weight(.bold))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .frame(width: 30, height: 30)
        .background(
            Circle()
                .fill(LinearGradient(
                    colors: [Color(red: 0.04, green: 0.20, blue: 0.36),
                             Color(red: 0.06, green: 0.35, blue: 0.55)],
                    startPoint: .top, endPoint: .bottom))
        )
        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
        .accessibilityElement()
        .accessibilityLabel(Text(date, format: .dateTime.weekday(.wide).day().month(.wide)))
    }
}

#Preview {
    ContentView()
}
