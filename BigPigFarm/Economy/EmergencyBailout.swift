/// EmergencyBailout -- Detects and resolves the zero-pigs-zero-money soft-lock.
///
/// When all pigs die and the player's balance drops below adoption cost,
/// the game is permanently stuck. This module provides the detection logic
/// and generates a free breeding pair (one male, one female) so the player
/// can restart.
import Foundation

enum EmergencyBailout {

    /// True when the player has no pigs and cannot afford the cheapest adoption.
    @MainActor
    static func isSoftLocked(state: GameState) -> Bool {
        state.pigCount == 0 && state.money < GameConfig.Economy.adoptionBaseCost
    }

    /// Generate two free emergency pigs: one male, one female.
    ///
    /// Uses normal adoption rules (bloodlines, genotype, personality) but
    /// forces gender to guarantee a viable breeding pair.
    static func generateEmergencyPigs(
        existingNames: Set<String>,
        farmTier: Int
    ) -> [GuineaPig] {
        let male = Adoption.generateAdoptionPig(
            existingNames: existingNames,
            farmTier: farmTier,
            gender: .male
        )
        var namesWithMale = existingNames
        namesWithMale.insert(male.name)
        let female = Adoption.generateAdoptionPig(
            existingNames: namesWithMale,
            farmTier: farmTier,
            gender: .female
        )
        return [male, female]
    }
}
