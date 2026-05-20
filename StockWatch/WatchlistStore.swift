import Foundation

/// Persists the user's watchlist (an ordered list of symbols) across launches.
/// Designed as a value type with closures so tests can inject an in-memory store.
struct WatchlistStore: Sendable {
    var load: @Sendable () -> [String]?
    var save: @Sendable ([String]) -> Void

    /// UserDefaults-backed production store.
    static let live: WatchlistStore = {
        let key = "watchlist.symbols.v1"
        return WatchlistStore(
            load: {
                UserDefaults.standard.array(forKey: key) as? [String]
            },
            save: { symbols in
                UserDefaults.standard.set(symbols, forKey: key)
            }
        )
    }()

    /// In-memory store for unit tests. Each call creates a fresh box.
    static func ephemeral(initial: [String]? = nil) -> WatchlistStore {
        final class Box: @unchecked Sendable {
            var value: [String]?
            init(_ v: [String]?) { value = v }
        }
        let box = Box(initial)
        return WatchlistStore(
            load: { box.value },
            save: { box.value = $0 }
        )
    }
}
