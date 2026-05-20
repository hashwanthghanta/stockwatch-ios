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
