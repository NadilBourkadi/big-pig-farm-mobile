/// Contracts — Breeding contract generation and fulfillment.
/// Maps from: economy/contracts.py
import Foundation

// MARK: - ContractDifficulty

/// Contract difficulty tier, determines trait requirements and reward range.
enum ContractDifficulty: String, Codable, CaseIterable, Sendable {
    case easy        // Color only
    case medium      // Color + pattern
    case hard        // Color + pattern + intensity
    case expert      // All 4 traits
    case legendary   // All 4 traits + roan
}

// MARK: - Stubs (implemented in later tasks)

/// Generates and tracks breeding contracts for the player.
struct Contracts: Sendable {
    // TODO: Implement in doc 04
}
