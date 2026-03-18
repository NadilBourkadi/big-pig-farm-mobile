/// NotificationCategory+Color — SwiftUI color extension.
///
/// Separated from NotificationCategory.swift because SwiftUI is not available in the
/// BigPigFarmCore SPM target. This file is compiled by the Xcode project only.
import SwiftUI

extension NotificationCategory {
    /// Display color for this category. Aligned with AlmanacView's event color mapping.
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
}
