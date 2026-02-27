/// Protocols — Narrow context protocols decoupling simulation subsystems from GameState.
/// Maps from: game/facades.py
import Foundation

// MARK: - NeedsContext

/// Read-only access to farm grid and upgrades for the needs system.
///
/// `@MainActor` because `GameState` (the sole conformer) is actor-isolated.
/// All simulation runs on `@MainActor` via the tick loop, so this is safe.
@MainActor
protocol NeedsContext: AnyObject {
    var farm: FarmGrid { get }
    func hasUpgrade(_ upgradeID: String) -> Bool
}

// MARK: - BreedingContext

/// Breeding pair management for the breeding system.
@MainActor
protocol BreedingContext: AnyObject {
    // TODO: Implement when Breeding task is claimed
}

// MARK: - BirthContext

/// Birth processing, aging, and pigdex registration.
@MainActor
protocol BirthContext: AnyObject {
    // TODO: Implement when Birth task is claimed
}

// MARK: - CullingContext

/// Surplus pig management and selling.
@MainActor
protocol CullingContext: AnyObject {
    // TODO: Implement when Culling task is claimed
}

// MARK: - GameState Conformance

extension GameState: NeedsContext {}
extension GameState: BreedingContext {}
extension GameState: BirthContext {}
extension GameState: CullingContext {}
