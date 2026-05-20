import SwiftUI

/// User-selectable app appearance. `system` defers to the iPhone's setting;
/// `light` and `dark` force a specific `ColorScheme` regardless of system.
enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// Maps to SwiftUI's `preferredColorScheme` value. `nil` means "follow system".
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

/// Persists the user's appearance choice across launches.
enum ThemeManager {
    static let preferredThemeKey = "preferredAppTheme.v1"

    static var current: AppTheme {
        let raw = UserDefaults.standard.string(forKey: preferredThemeKey) ?? AppTheme.system.rawValue
        return AppTheme(rawValue: raw) ?? .system
    }
}
