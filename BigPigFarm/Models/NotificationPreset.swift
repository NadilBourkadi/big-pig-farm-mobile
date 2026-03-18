/// NotificationPreset — Predefined notification filter configurations.
///
/// Each preset defines which NotificationCategory values are enabled, forming a
/// superset chain: minimal ⊂ standard ⊂ detailed ⊂ all. Users pick a preset
/// for quick configuration, then optionally toggle individual categories.
import Foundation

// MARK: - NotificationPreset

enum NotificationPreset: String, CaseIterable, Sendable {
    case minimal
    case standard
    case detailed
    case all

    /// Human-readable display name.
    var displayName: String {
        rawValue.capitalized
    }

    /// Short summary of what this preset shows.
    var summary: String {
        switch self {
        case .minimal: "Deaths and system alerts only"
        case .standard: "Births, deaths, sales, contracts, and system"
        case .detailed: "Standard plus breeding and discoveries"
        case .all: "All notification categories"
        }
    }

    /// The set of categories enabled by this preset.
    ///
    /// Each preset is a strict superset of the one below it:
    /// minimal (2) ⊂ standard (5) ⊂ detailed (7) ⊂ all (8).
    var enabledCategories: Set<NotificationCategory> {
        switch self {
        case .minimal:
            [.deaths, .system]
        case .standard:
            [.births, .deaths, .sales, .contracts, .system]
        case .detailed:
            [.births, .deaths, .sales, .contracts, .system,
             .breeding, .discoveries]
        case .all:
            Set(NotificationCategory.allCases)
        }
    }

    /// Returns the preset that matches the given category toggles, or nil if custom.
    static func matching(categoryEnabled: [NotificationCategory: Bool]) -> Self? {
        let enabled = Set(
            NotificationCategory.allCases.filter { categoryEnabled[$0] ?? true }
        )
        return allCases.first { $0.enabledCategories == enabled }
    }
}
