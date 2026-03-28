/// DisplayFormatting — Format functions and color mappings for model types.
/// Split from SharedComponents.swift — no View conformance, but depends on SwiftUI (Color).
import SwiftUI

// MARK: - Breeding Status

/// Format a pig's breeding status as a short string (or verbose full reason).
///
/// Maps from: ui/utils.py format_breeding_status()
func formatBreedingStatus(_ pig: GuineaPig, verbose: Bool = false, prestige: PrestigeState? = nil) -> String {
    // Special case: baby marked for auto-sell
    if pig.isBaby && pig.markedForSale {
        return verbose ? "Marked for auto-sell at adulthood" : "Sell@Adult"
    }
    let blockReason = prestige.map { pig.checkBreedingBlock(prestige: $0) } ?? pig.breedingBlockReason
    guard let reason = blockReason else { return "Ready" }
    if verbose { return reason }
    if reason.hasPrefix("Breeding locked") { return "LOCKED" }
    if reason.hasPrefix("Too young") { return "Baby" }
    if reason.hasPrefix("Too old") { return "Senior" }
    if reason.hasPrefix("Unhappy") { return "Not ready" }
    if reason.hasPrefix("Pregnant") { return "Pregnant" }
    if reason.hasPrefix("Recovering") { return "Recovering" }
    return "Not ready"
}

// MARK: - Facility Bonuses

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

// MARK: - Color Mapping

/// Map a BaseColor to the nearest SwiftUI Color for display.
///
/// Colors are defined as named colorsets in the asset catalog (`Colors/PigColor<Name>`)
/// with light/dark variants. Dark-mode values match `PigPalettes` fur hex colors for
/// visual consistency with sprites; light-mode values are adjusted for contrast on
/// white backgrounds.
func pigColorSwiftUI(_ baseColor: BaseColor) -> Color {
    Color("PigColor\(baseColor.rawValue.capitalized)")
}

// MARK: - Gender Display

extension Gender {
    /// SwiftUI color for gender display (blue for male, pink for female).
    var displayColor: Color {
        switch self {
        case .male: .blue
        case .female: .pink
        }
    }
}
