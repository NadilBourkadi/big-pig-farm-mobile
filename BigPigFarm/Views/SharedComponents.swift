/// SharedComponents — Reusable UI components (currency display, rarity badges, need bars).
/// Maps from: ui/components/
// TODO: Implement in doc 07
import SwiftUI

/// Displays a formatted currency amount.
struct CurrencyLabel: View {
    let amount: Int

    var body: some View {
        Text("\(amount)")
    }
}

/// Displays a colored rarity badge.
struct RarityBadge: View {
    let rarity: Rarity

    var body: some View {
        Text(rarity.rawValue.capitalized)
    }
}

/// Displays a horizontal progress bar for a pig need.
struct NeedBar: View {
    let value: Double
    let label: String

    var body: some View {
        ProgressView(label, value: value, total: 1.0)
    }
}
