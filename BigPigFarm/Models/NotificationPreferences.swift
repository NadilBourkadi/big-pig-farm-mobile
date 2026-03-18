/// NotificationPreferences — Per-category notification toggles with UserDefaults persistence.
///
/// App-level preferences (not per-save). Stored in UserDefaults, not GameState, because
/// notification filtering is a user preference independent of which farm save is loaded.
import Foundation

// MARK: - NotificationPreferences

struct NotificationPreferences: Codable, Sendable, Equatable {
    /// Per-category enabled state. Missing keys default to the standard preset.
    var categoryEnabled: [NotificationCategory: Bool]

    /// Whether notifications for the given category are enabled.
    func isEnabled(_ category: NotificationCategory) -> Bool {
        categoryEnabled[category] ?? true
    }

    /// Toggle a single category on or off.
    mutating func setEnabled(_ category: NotificationCategory, enabled: Bool) {
        categoryEnabled[category] = enabled
    }

    /// Apply a preset, overwriting all category toggles.
    mutating func apply(preset: NotificationPreset) {
        let enabled = preset.enabledCategories
        for category in NotificationCategory.allCases {
            categoryEnabled[category] = enabled.contains(category)
        }
    }

    /// Creates preferences matching the given preset.
    static func from(preset: NotificationPreset) -> Self {
        var prefs = Self(categoryEnabled: [:])
        prefs.apply(preset: preset)
        return prefs
    }

    /// The preset that currently matches the toggle state, or nil if custom.
    var activePreset: NotificationPreset? {
        NotificationPreset.matching(categoryEnabled: categoryEnabled)
    }

    // MARK: - UserDefaults Persistence

    private static let userDefaultsKey = "notificationPreferences"

    /// Load preferences from UserDefaults. Returns standard preset defaults if none saved.
    static func load(from defaults: UserDefaults = .standard) -> Self {
        guard let data = defaults.data(forKey: userDefaultsKey) else {
            return .from(preset: .standard)
        }
        do {
            return try JSONDecoder().decode(Self.self, from: data)
        } catch {
            return .from(preset: .standard)
        }
    }

    /// Save preferences to UserDefaults.
    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.userDefaultsKey)
    }
}
