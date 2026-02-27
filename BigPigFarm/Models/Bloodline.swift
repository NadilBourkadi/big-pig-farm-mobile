/// Bloodline — Bloodline tracking for breeding programs and adoption.
/// Maps from: entities/bloodlines.py
import Foundation

// MARK: - BloodlineType

/// Types of bloodlines available for adoption, gated by farm tier.
/// Raw values match the Python `BloodlineType(str, Enum)` values for JSON compatibility.
enum BloodlineType: String, Codable, CaseIterable, Sendable {
    case spotted
    case chocolate
    case golden
    case silver
    case roan
    case exoticSpotSilver = "exotic_spot_silver"
    case exoticRoanSilver = "exotic_roan_silver"
}

// MARK: - Stubs (implemented in later tasks)

/// A bloodline definition with carrier alleles and tier gating.
/// Identity is `bloodlineType` (no UUID).
struct Bloodline: Codable, Sendable {
    let bloodlineType: BloodlineType
    // TODO: Implement in struct translation task
}
