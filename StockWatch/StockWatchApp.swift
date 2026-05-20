import SwiftUI

@main
struct StockWatchApp: App {

    init() {
        LanguageManager.install()
    }

    var body: some Scene {
        WindowGroup {
            #if SCREENSHOT_DETAIL
            NavigationStack {
                StockDetailView(
                    stock: MockData.catalog[0],
                    service: YahooStockService(),
                    demoSelectedOffset: 14
                )
            }
            #elseif SCREENSHOT_NEWS
            ScreenshotNewsHost()
            #elseif SCREENSHOT_GRID
            ScreenshotGridHost()
            #elseif SCREENSHOT_ADD
            ScreenshotAddHost()
            #elseif SCREENSHOT_SETTINGS
            ScreenshotSettingsHost()
            #else
            RootView()
            #endif
        }
    }
}

#if SCREENSHOT_NEWS
/// Renders Apple's news cards directly so screenshots show the news section
/// without needing to scroll past the chart and metrics.
private struct ScreenshotNewsHost: View {
    @State private var news: [NewsItem] = []
    @State private var openedArticle: NewsItem?
    private let stock = MockData.catalog[0]   // AAPL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "newspaper.fill").foregroundStyle(.tint)
                        Text("News · \(stock.displaySymbol)").font(.title2.bold())
                    }
                    .padding(.horizontal)

                    VStack(spacing: 10) {
                        ForEach(news.prefix(6)) { item in
                            Button { openedArticle = item } label: {
                                newsCard(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
            }
            .task {
                let svc = YahooNewsService()
                let base = stock.symbol.split(separator: ".").first.map(String.init) ?? stock.symbol
                news = (try? await svc.fetchNews(symbol: base, companyName: stock.name)) ?? []
            }
            .navigationTitle(stock.displaySymbol)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $openedArticle) { SafariView(url: $0.link).ignoresSafeArea() }
        }
    }

    private func newsCard(_ item: NewsItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.publisher)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                if let d = item.publishedAt {
                    Text(d, style: .relative).font(.caption2).foregroundStyle(.tertiary)
                }
                Image(systemName: "arrow.up.right.square").font(.caption2).foregroundStyle(.tint)
            }
            Text(item.title)
                .font(.callout.weight(.semibold))
                .multilineTextAlignment(.leading)
                .lineLimit(3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.secondary.opacity(0.14), lineWidth: 0.5))
    }
}
#endif

#if SCREENSHOT_GRID
/// Forces the watchlist into grid layout on launch by pre-setting the
/// `@AppStorage` key, then renders the normal `RootView`.
private struct ScreenshotGridHost: View {
    init() {
        UserDefaults.standard.set("grid", forKey: "watchlist.layout.v1")
    }
    var body: some View {
        RootView()
    }
}
#endif

/// Wraps `ContentView` so a change in the chosen language forces a re-render
/// of the entire view tree (via `.id(lang)`), picking up the swizzled bundle.
private struct RootView: View {
    @AppStorage(LanguageManager.preferredLanguageKey) private var lang: String = ""
    @AppStorage(ThemeManager.preferredThemeKey) private var themeRaw: String = AppTheme.system.rawValue

    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .system }

    var body: some View {
        ContentView()
            .id(lang)
            .environment(\.locale, lang.isEmpty ? .current : Locale(identifier: lang))
            .preferredColorScheme(theme.colorScheme)
    }
}

#if SCREENSHOT_ADD
private struct ScreenshotAddHost: View {
    @State private var show = true
    var body: some View {
        Color.clear.sheet(isPresented: $show) {
            AddStockView(availableStocks: MockData.catalog, onAdd: { _ in })
                .interactiveDismissDisabled()
        }
    }
}
#endif

#if SCREENSHOT_SETTINGS
private struct ScreenshotSettingsHost: View {
    @State private var show = true
    var body: some View {
        Color.clear.sheet(isPresented: $show) {
            SettingsView()
                .interactiveDismissDisabled()
        }
    }
}
#endif
