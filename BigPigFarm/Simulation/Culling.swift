/// Culling — Surplus pig management and population control.
/// Maps from: simulation/culling.py
import Foundation

/// Record of a single pig sale transaction.
struct SoldPigRecord: Sendable {
    let pigName: String
    let totalValue: Int
    let contractBonus: Int
    let pigID: UUID
}

/// Stateless namespace for population control and auto-sale.
enum Culling {
    /// Remove all pigs marked for sale from state and return sale records.
    @MainActor
    static func sellMarkedAdults(gameState: GameState) -> [SoldPigRecord] {
        // TODO(culling): Implement marked-pig sale with contract bonus calculation
        []
    }

    /// Identify and mark surplus breeders for population control.
    @MainActor
    static func cullSurplusBreeders(gameState: GameState) {
        // TODO(culling): Implement surplus breeder identification and marking
    }
}
