/// SharedComponents — Reusable UI components (currency display, rarity badges, need bars).
/// Maps from: ui/components/
import SwiftUI

// MARK: - Free Functions

/// Format a pig's breeding status as a short string (or verbose full reason).
///
/// Maps from: ui/utils.py format_breeding_status()
func formatBreedingStatus(_ pig: GuineaPig, verbose: Bool = false) -> String {
    // Special case: baby marked for auto-sell
    if pig.isBaby && pig.markedForSale {
        return verbose ? "Marked for auto-sell at adulthood" : "Sell@Adult"
    }
    if pig.canBreed { return "Ready" }
    guard let reason = pig.breedingBlockReason else { return "Not ready" }
    if verbose { return reason }
    if reason.hasPrefix("Breeding locked") { return "LOCKED" }
    if reason.hasPrefix("Too young") { return "Baby" }
    if reason.hasPrefix("Too old") { return "Senior" }
    if reason.hasPrefix("Unhappy") { return "Not ready" }
    if reason.hasPrefix("Pregnant") { return "Pregnant" }
    if reason.hasPrefix("Recovering") { return "Recovering" }
    return "Not ready"
}

/// Format facility bonuses as a comma-separated summary string.
///
/// Maps from: ui/utils.py format_facility_bonuses()
func formatFacilityBonuses(_ facilityType: FacilityType) -> String {
    guard let info = facilityInfo[facilityType] else { return "" }
    var parts: [String] = []
    if info.healthBonus > 0 { parts.append("+\(Int((info.healthBonus * 100).rounded()))% health") }
    if info.happinessBonus > 0 { parts.append("+\(Int((info.happinessBonus * 100).rounded()))% happiness") }
    if info.socialBonus > 0 { parts.append("+\(Int((info.socialBonus * 100).rounded()))% social") }
    if info.breedingBonus > 0 { parts.append("+\(Int((info.breedingBonus * 100).rounded()))% breeding") }
    if info.growthBonus > 0 { parts.append("+\(Int((info.growthBonus * 100).rounded()))% growth") }
    if info.saleBonus > 0 { parts.append("+\(Int((info.saleBonus * 100).rounded()))% sale value") }
    if info.foodProduction > 0 { parts.append("produces \(info.foodProduction) food") }
    return parts.joined(separator: ", ")
}

/// Map a BaseColor to the nearest SwiftUI Color for display.
func pigColorSwiftUI(_ baseColor: BaseColor) -> Color {
    switch baseColor {
    // RGB 0,0,0 is invisible on dark material backgrounds (.ultraThinMaterial, .regularMaterial).
    // 0.15 brightness reads as "black" phenotypically while having enough contrast against
    // the ~30% brightness dark-grey materials used in list rows and detail panels.
    case .black: return Color(white: 0.15)
    case .chocolate: return .brown
    case .golden: return .yellow
    case .cream: return Color(red: 1.0, green: 0.95, blue: 0.8)
    case .blue: return Color(red: 0.4, green: 0.5, blue: 0.6)
    case .lilac: return Color(red: 0.7, green: 0.5, blue: 0.7)
    case .saffron: return .orange
    case .smoke: return .gray
    }
}

// MARK: - CurrencyLabel

/// Displays a formatted currency amount with the Squeaks prefix.
///
/// Used in StatusBarView, ShopView, PigListView, PigDetailView.
struct CurrencyLabel: View {
    let amount: Int

    var body: some View {
        Text(Currency.formatCurrency(amount))
            .font(.caption.bold())
            .foregroundStyle(.yellow)
    }
}

// MARK: - NeedBar

/// A horizontal bar visualizing a pig need level (value: 0.0–1.0).
///
/// **Precondition:** `value` must be in 0.0–1.0. Callers must normalize from the
/// 0–100 need range: `pig.needs.hunger / 100.0`. Passing an un-normalized value
/// (e.g. 75.0 for hunger) triggers a precondition failure in debug builds.
/// Used in PigDetailView needs section and PigListView rows.
struct NeedBar: View {
    let value: Double
    let label: String

    init(value: Double, label: String) {
        precondition(
            value >= 0.0 && value <= 1.0,
            "NeedBar value must be 0.0–1.0; got \(value). Normalize with e.g. pig.needs.hunger / 100.0"
        )
        self.value = value
        self.label = label
    }

    var body: some View {
        HStack(spacing: 4) {
            if !label.isEmpty {
                Text(label)
                    .font(.caption)
                    .frame(width: 60, alignment: .leading)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.secondary.opacity(0.2))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(needColor)
                        .frame(width: max(0, geometry.size.width * min(1, max(0, value))))
                }
            }
            .frame(height: 8)
            Text("\(Int(min(1, max(0, value)) * 100))%")
                .font(.caption2)
                .frame(width: 30, alignment: .trailing)
        }
    }

    private var needColor: Color {
        if value >= 0.7 { return .green }
        if value >= 0.4 { return .yellow }
        return .red
    }
}

// MARK: - StatusBadge

/// A colored pill badge with configurable label and style.
///
/// Two built-in styles:
/// - `.opaque`: solid-color background with white bold text (rarity, tier, difficulty).
/// - `.tinted`: semi-transparent background with colored text (status, tags).
///
/// Replaces ad-hoc pill constructions in ShopView, AlmanacView,
/// BreedingPairTab, and AdoptionView.
struct StatusBadge: View, Sendable {
    let label: String
    let color: Color
    var style: Style = .opaque

    enum Style: Sendable {
        case opaque
        case tinted
    }

    var body: some View {
        Text(label)
            .font(style == .opaque ? .caption2.bold() : .caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(style == .opaque ? AnyShapeStyle(.white) : AnyShapeStyle(color))
            .background(style == .opaque ? color : color.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - RarityBadge

/// Displays a colored pill badge for a pig's rarity tier.
///
/// Used in PigListView rows, PigDetailView header, ShopView items.
struct RarityBadge: View {
    let rarity: Rarity

    var body: some View {
        StatusBadge(label: rarityDisplayName, color: rarityColor)
    }

    /// Human-readable name; handles "very_rare" → "Very Rare".
    private var rarityDisplayName: String {
        switch rarity {
        case .veryRare: return "Very Rare"
        default: return rarity.rawValue.capitalized
        }
    }

    private var rarityColor: Color {
        switch rarity {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .veryRare: return .purple
        case .legendary: return .orange
        }
    }
}

// MARK: - BreedingStatusLabel

/// Displays a concise breeding status for a pig.
///
/// Maps from: ui/utils.py format_breeding_status()
struct BreedingStatusLabel: View {
    let pig: GuineaPig

    var body: some View {
        Text(formatBreedingStatus(pig))
            .font(.caption2)
            .foregroundStyle(statusColor)
    }

    /// Color reflects urgency: locked → red, pregnant → orange, ready → green, else → secondary.
    private var statusColor: Color {
        if pig.breedingLocked { return .red }
        if pig.isPregnant { return .orange }
        if pig.canBreed { return .green }
        return .secondary
    }
}

// MARK: - FacilityBonusLabel

/// Displays facility bonuses as a compact comma-separated summary.
///
/// Renders nothing (empty view) for facilities with no bonuses (e.g. food bowl, water bottle).
/// Precondition: facilityType must exist in `facilityInfo`. Missing entries silently render
/// empty here; Facility.info crashes — so both will fail loudly at any usage site.
///
/// Maps from: ui/utils.py format_facility_bonuses()
struct FacilityBonusLabel: View {
    let facilityType: FacilityType

    var body: some View {
        let bonuses = formatFacilityBonuses(facilityType)
        if !bonuses.isEmpty {
            Text(bonuses)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - InfoRow

/// A two-column label/value row for dense info panels.
///
/// The label column is fixed at 120pt (secondary colour, .caption font);
/// the value column wraps freely. Used in PigDetailView and AlmanacView.
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.caption)
        }
    }
}

// MARK: - HUDButton

/// Reusable icon-over-label button for HUD toolbars and action panels.
///
/// Unifies the formerly duplicated `toolbarButton` (StatusToolbar) and
/// `panelButton` (EditModeActionPanel) into a single shared component.
struct HUDButton: View {
    let systemImage: String
    let label: String
    var isActive: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 9))
            }
            .foregroundStyle(isActive ? .yellow : .white)
            .opacity(isDisabled ? 0.4 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(label)
    }
}

// MARK: - PigPortraitView

/// Displays a pre-rendered Pigdex portrait image from the asset catalog.
///
/// Maps from: pig_detail.py _build_portrait_text() — iOS loads PNGs
/// exported by the sprite pipeline (Doc 03) instead of rendering at runtime.
///
/// **Asset dependency:** image name is `portrait_<color>_<pattern>_<intensity>_<roan>`.
/// If the portrait is missing from the asset catalog, SwiftUI renders nothing silently.
/// All 483 portrait combinations are committed in the repo (PR #58); this is only a
/// concern if new enum cases are added without re-running the sprite pipeline.
struct PigPortraitView: View {
    let baseColor: BaseColor
    let pattern: Pattern
    let intensity: ColorIntensity
    let roan: RoanType
    /// Identity hint for SwiftUI's diffing algorithm when used in lists.
    let pigID: UUID

    var body: some View {
        Image(imageName)
            .resizable()
            .interpolation(.none)
            .scaledToFit()
    }

    private var imageName: String {
        let parts = [baseColor.rawValue, pattern.rawValue, intensity.rawValue, roan.rawValue]
        return "Sprites/Portraits/portrait_" + parts.joined(separator: "_")
    }
}
