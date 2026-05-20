import Foundation
import ObjectiveC.runtime

/// Swizzles `Bundle.main`'s localized-string lookup so the app can switch language at runtime
/// without restarting. When `apply(_:)` sets an override bundle, every `Text("…")` call
/// (and every `String(localized:)`) routes through that bundle's `.lproj` for the chosen
/// language. Pair with `.id(currentLanguage)` on the root view so SwiftUI re-renders.
enum LanguageManager {

    static let preferredLanguageKey = "preferredLanguage"

    /// Empty string means "follow system locale".
    static var current: String {
        UserDefaults.standard.string(forKey: preferredLanguageKey) ?? ""
    }

    /// Install the swizzle exactly once at app launch.
    static func install() {
        guard !installed else { return }
        installed = true
        object_setClass(Bundle.main, AnyLanguageBundle.self)
        apply(current.isEmpty ? nil : current)
    }

    /// Set the override language. Pass `nil` (or empty) to follow the system.
    static func apply(_ code: String?) {
        if let code, !code.isEmpty,
           let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            AnyLanguageBundle.overrideBundle = bundle
        } else {
            AnyLanguageBundle.overrideBundle = nil
        }
    }

    private static var installed = false
}

/// Subclass of `Bundle` that consults a stored override bundle first.
/// Installed onto `Bundle.main` via `object_setClass` from `LanguageManager.install()`.
private final class AnyLanguageBundle: Bundle, @unchecked Sendable {
    fileprivate static var overrideBundle: Bundle?

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let override = AnyLanguageBundle.overrideBundle {
            return override.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}
