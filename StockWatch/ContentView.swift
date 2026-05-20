import SwiftUI
import Charts

enum WatchlistLayout: String, CaseIterable, Identifiable, Sendable {
    case list, grid
    var id: String { rawValue }
    var localizedLabel: String {
        switch self {
        case .list: return String(localized: "List")
        case .grid: return String(localized: "Grid")
        }
    }
    var symbol: String { self == .list ? "list.bullet" : "square.grid.2x2" }
}

struct ContentView: View {
    @State private var vm = WatchlistViewModel()
    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var showSettings = false
    @State private var editMode: EditMode = .inactive
    @AppStorage("watchlist.layout.v1") private var layoutRaw: String = WatchlistLayout.list.rawValue

    private var layout: WatchlistLayout {
        WatchlistLayout(rawValue: layoutRaw) ?? .list
    }
    private func setLayout(_ new: WatchlistLayout) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            layoutRaw = new.rawValue
            if new == .grid { editMode = .inactive }
        }
    }

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
            Group {
                if layout == .list {
                    listView
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    gridView
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .navigationTitle(Text("Watchlist"))
            .navigationDestination(for: String.self) { symbol in
                if let stock = MockData.stock(forSymbol: symbol) {
                    StockDetailView(stock: stock, service: vm.service,
                                    onViewed: { vm.markViewed(symbol: $0) })
                }
            }
            .toolbar { toolbarContent }
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

    // MARK: - List layout

    @ViewBuilder
    private var listView: some View {
        List {
                if !stocks.isEmpty {
                    Section(AssetCategory.stock.localizedSectionTitle) {
                        ForEach(stocks) { stock in
                            rowLink(for: stock)
                                .draggable(stock.symbol)
                                .dropDestination(for: String.self) { items, _ in
                                    guard let dragged = items.first else { return false }
                                    withAnimation { vm.moveSymbol(dragged, onto: stock.symbol) }
                                    return true
                                }
                        }
                        .onMove { offsets, destination in
                            vm.move(in: .stock, fromOffsets: offsets, toOffset: destination)
                        }
                    }
                }
                if !etfs.isEmpty {
                    Section(AssetCategory.etf.localizedSectionTitle) {
                        ForEach(etfs) { stock in
                            rowLink(for: stock)
                                .draggable(stock.symbol)
                                .dropDestination(for: String.self) { items, _ in
                                    guard let dragged = items.first else { return false }
                                    withAnimation { vm.moveSymbol(dragged, onto: stock.symbol) }
                                    return true
                                }
                        }
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

                // Tap-to-finish editing: invisible footer area below the list
                // content. Tapping it exits edit mode without using the menu.
                if editMode == .active {
                    Section {
                        Color.clear
                            .frame(height: 220)
                            .contentShape(Rectangle())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .onTapGesture {
                                withAnimation { editMode = .inactive }
                            }
                            .accessibilityLabel(Text("Finish editing"))
                            .accessibilityHint(Text("Double tap to exit edit mode"))
                    }
                }
            }
        .listStyle(.insetGrouped)
        .environment(\.editMode, $editMode)
        .searchable(text: $searchText, prompt: Text("Search watchlist"))
        .refreshable { await vm.refresh() }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: 8) {
                DateBadge(date: .now)
                statusBadge
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 12) {
                Button {
                    Task { await vm.refresh() }
                } label: {
                    if vm.state == .loading {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .symbolEffect(.bounce, value: vm.lastRefreshedAt)
                    }
                }
                .disabled(vm.state == .loading)
                .accessibilityLabel(Text("Refresh"))
                .accessibilityHint(Text("Fetches the latest live quotes"))

                Button {
                    showAddSheet = true
                } label: { Image(systemName: "plus") }
                    .accessibilityLabel(Text("Add stock"))

                // When editing, swap the ⋯ menu for a prominent blue
                // checkmark that exits edit mode in one tap.
                if editMode == .active {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            editMode = .inactive
                        }
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.blue)
                            .font(.title3)
                            .symbolEffect(.bounce, value: editMode == .active)
                    }
                    .accessibilityLabel(Text("Done editing"))
                    .accessibilityHint(Text("Exits the edit watchlist mode"))
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Menu {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                editMode = .active
                                if layout == .grid { layoutRaw = WatchlistLayout.list.rawValue }
                            }
                        } label: {
                            Label(String(localized: "Edit watchlist"), systemImage: "pencil")
                        }
                        Divider()
                        Picker(String(localized: "Layout"), selection: Binding(
                            get: { layout },
                            set: { setLayout($0) })
                        ) {
                            Label(WatchlistLayout.list.localizedLabel, systemImage: WatchlistLayout.list.symbol).tag(WatchlistLayout.list)
                            Label(WatchlistLayout.grid.localizedLabel, systemImage: WatchlistLayout.grid.symbol).tag(WatchlistLayout.grid)
                        }
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
                            showSettings = true
                        } label: {
                            Label(String(localized: "Settings"), systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel(Text("More options"))
                    .accessibilityHint(Text("Edit list, change layout, sort, settings"))
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Grid layout

    private var gridColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
    }

    @ViewBuilder
    private var gridView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if !stocks.isEmpty {
                    gridSection(title: AssetCategory.stock.localizedSectionTitle, items: stocks)
                }
                if !etfs.isEmpty {
                    gridSection(title: AssetCategory.etf.localizedSectionTitle, items: etfs)
                }
                if stocks.isEmpty && etfs.isEmpty {
                    emptyState
                        .padding(.top, 60)
                }
                if let updatedAt = vm.lastRefreshedAt {
                    Text("Updated \(updatedAt, style: .time)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.05), Color.clear],
                startPoint: .top, endPoint: .center
            )
            .ignoresSafeArea()
        )
        .searchable(text: $searchText, prompt: Text("Search watchlist"))
        .refreshable { await vm.refresh() }
    }

    @ViewBuilder
    private func gridSection(title: String, items: [Stock]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)
            LazyVGrid(columns: gridColumns, spacing: 14) {
                ForEach(items) { stock in
                    NavigationLink(value: stock.symbol) {
                        gridCard(for: stock)
                    }
                    .buttonStyle(PressableCardStyle())
                    .contextMenu {
                        Button(role: .destructive) {
                            withAnimation { vm.remove(symbol: stock.symbol) }
                        } label: {
                            Label(String(localized: "Remove"), systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func gridCard(for stock: Stock) -> some View {
        let pct = vm.changePercent(for: stock)
        let up = pct >= 0
        let tint: Color = up ? .green : .red
        let price = vm.price(for: stock)
        let currency = vm.currency(for: stock)
        let symbolStr: String = {
            switch currency {
            case "EUR": return "€"
            case "GBP": return "£"
            case "JPY": return "¥"
            case "CHF": return "CHF "
            default:    return "$"
            }
        }()
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(stock.displaySymbol)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
            }
            Text(stock.name)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            sparkline(for: stock, tint: tint)
                .frame(height: 36)

            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%@%.2f", symbolStr, price))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                Spacer()
                Text(String(format: "%+.2f%%", pct))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(tint.opacity(0.18), lineWidth: 0.8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stock.displaySymbol), \(stock.name), \(String(format: "%@%.2f", symbolStr, price)), \(up ? "up" : "down") \(String(format: "%.2f", abs(pct))) percent")
    }

    @ViewBuilder
    private func sparkline(for stock: Stock, tint: Color) -> some View {
        if let q = vm.quote(for: stock), q.historicalCloses.count > 1 {
            let pts = Array(zip(q.historicalDates, q.historicalCloses))
            Chart {
                ForEach(pts.indices, id: \.self) { i in
                    LineMark(
                        x: .value("d", pts[i].0),
                        y: .value("c", pts[i].1)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(tint)
                    .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round))

                    AreaMark(
                        x: .value("d", pts[i].0),
                        y: .value("c", pts[i].1)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(
                        stops: [
                            .init(color: tint.opacity(0.18), location: 0.00),
                            .init(color: tint.opacity(0.06), location: 0.55),
                            .init(color: tint.opacity(0.00), location: 1.00),
                        ],
                        startPoint: .top, endPoint: .bottom))
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: sparkDomain(q.historicalCloses))
            .chartPlotStyle { plot in plot.background(Color.clear) }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(tint.opacity(0.10))
                .accessibilityHidden(true)
        }
    }

    private func sparkDomain(_ closes: [Double]) -> ClosedRange<Double> {
        guard let lo = closes.min(), let hi = closes.max(), lo < hi else { return 0...1 }
        let pad = (hi - lo) * 0.10
        return (lo - pad)...(hi + pad)
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

/// Subtle scale-down on press for grid cards.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: configuration.isPressed)
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
