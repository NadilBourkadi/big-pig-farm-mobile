/// NotificationCategory+Color — SwiftUI color extension.
///
/// Separated from NotificationCategory.swift because SwiftUI is not available in the
/// BigPigFarmCore SPM target. This file is compiled by the Xcode project only.
import SwiftUI

extension NotificationCategory {
    /// Display color for this category.
    var color: Color {
        switch self {
        case .births: .green
        case .deaths: .red
        case .sales: .yellow
        case .breeding: .pink
        case .discoveries: .purple
        case .purchases: .blue
        case .contracts: .teal
        case .system: .secondary
        }
    }

    // MARK: - Per-Event-Type Display

    /// SF Symbol icon for a raw event type string. Provides per-event-type overrides
    /// where a type needs visual distinction from its category (e.g. pigdex uses book.fill
    /// instead of the discoveries category's sparkles). Falls back to category icon.
    static func icon(for eventType: String) -> String {
        switch eventType {
        case "pigdex": "book.fill"
        case "adoption": "heart.circle.fill"
        default: from(eventType: eventType).iconName
        }
    }

    /// Display color for a raw event type string. Provides per-event-type overrides
    /// where a type needs visual distinction from its category. Falls back to category color.
    static func color(for eventType: String) -> Color {
        switch eventType {
        case "pigdex": .orange
        case "adoption": .indigo
        default: from(eventType: eventType).color
        }
    }
}
