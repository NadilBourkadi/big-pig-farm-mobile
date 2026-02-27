/// BreedingProgram — Targeted breeding strategies for rare phenotypes.
/// Maps from: simulation/breeding_program.py
import Foundation

// MARK: - BreedingStrategy

/// Breeding program strategy for scoring and pig replacement.
enum BreedingStrategy: String, Codable, CaseIterable, Sendable {
    case target      // Breed toward specific phenotype targets
    case diversity   // Maximize phenotype variety
    case money       // Maximize sale value and contract fulfillment
}

// MARK: - Stubs (implemented in later tasks)

/// Manages player-defined breeding goals and pair suggestions.
struct BreedingProgram: Sendable {
    // TODO: Implement in doc 04
}
