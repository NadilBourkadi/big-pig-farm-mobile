/// NotificationCategory — User-facing notification groupings for event filtering.
///
/// Groups the 13 raw eventType strings (used by EventLog) into 8 user-facing categories.
/// Each category carries display metadata (icon, display name, importance tier) and a
/// static mapping from raw event type strings.
///
/// The SwiftUI `Color` property lives in NotificationCategory+Color.swift to keep this
/// file Foundation-only (required for BigPigFarmCore SPM target).
import Foundation

// MARK: - NotificationCategory

enum NotificationCategory: String, Codable, CaseIterable, Sendable {
    case births
    case deaths
    case sales
    case breeding
    case discoveries
    case purchases
    case contracts
    case system

    // MARK: - Display Metadata

    /// SF Symbol icon name for this category.
    var iconName: String {
        switch self {
        case .births: "gift.fill"
        case .deaths: "heart.slash.fill"
        case .sales: "dollarsign.circle.fill"
        case .breeding: "heart.fill"
        case .discoveries: "sparkles"
        case .purchases: "cart.fill"
        case .contracts: "doc.text.fill"
        case .system: "bell.fill"
        }
    }

    /// Human-readable display name.
    var displayName: String {
        switch self {
        case .births: "Births"
        case .deaths: "Deaths"
        case .sales: "Sales"
        case .breeding: "Breeding"
        case .discoveries: "Discoveries"
        case .purchases: "Purchases"
        case .contracts: "Contracts"
        case .system: "System"
        }
    }

    /// Default importance tier. Higher values appear in more conservative presets.
    /// 3 = critical (shown in minimal), 2 = standard, 1 = detailed only.
    var defaultImportance: Int {
        switch self {
        case .deaths: 3
        case .system: 3
        case .births: 2
        case .sales: 2
        case .contracts: 2
        case .breeding: 1
        case .discoveries: 1
        case .purchases: 1
        }
    }

    // MARK: - Event Type Mapping

    /// Maps a raw eventType string (as used by EventLog) to its notification category.
    /// Returns `.system` for unrecognized event types.
    static func from(eventType: String) -> Self {
        switch eventType {
        case "birth": .births
        case "death": .deaths
        case "sale": .sales
        case "breeding", "filter": .breeding
        case "pigdex", "mutation": .discoveries
        case "purchase", "adoption": .purchases
        case "contract": .contracts
        case "info", "farm_bell", "acclimation": .system
        default: .system
        }
    }
}
