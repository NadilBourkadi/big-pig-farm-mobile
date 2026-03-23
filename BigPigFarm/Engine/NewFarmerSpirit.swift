/// NewFarmerSpirit — First-run boosters that accelerate the early game on Farm #1.
///
/// Four boosters activate only when PrestigeState.farmCount == 1:
/// - Beginner's Luck: 3× breeding chance for first 48 game hours
/// - Welcome Gift: 3× first pig sale value (one-shot)
/// - Eager Learners: starter pigs begin with 85 happiness
/// - Natural Talent: -20% perk costs for first 48 game hours
///
/// Booster state lives on GameState (resets with the farm).
/// This enum is a stateless namespace — all methods are pure functions.
import Foundation

// MARK: - BoosterState

/// Persistent state for one-shot boosters. Time-limited boosters are evaluated
/// live from GameTime and need no flag here.
struct BoosterState: Codable, Sendable {
    /// Whether the Welcome Gift (3× first pig sale) has been consumed.
    var welcomeGiftUsed: Bool = false

    enum CodingKeys: String, CodingKey {
        case welcomeGiftUsed = "welcome_gift_used"
    }
}

// MARK: - NewFarmerSpirit

enum NewFarmerSpirit {

    /// Whether first-run boosters are active (Farm #1 only).
    static func isFirstFarm(_ prestige: PrestigeState) -> Bool {
        prestige.farmCount == 1
    }

    // MARK: - Beginner's Luck (3× breeding chance, first 48 game hours)

    static func isBeginnersLuckActive(prestige: PrestigeState, gameTime: GameTime) -> Bool {
        isFirstFarm(prestige) && gameTime.totalGameMinutes < GameConfig.NewFarmer.boosterDurationGameMinutes
    }

    /// Returns 3.0 on Farm #1 within 48 game hours, otherwise 1.0.
    static func breedingChanceMultiplier(prestige: PrestigeState, gameTime: GameTime) -> Double {
        isBeginnersLuckActive(prestige: prestige, gameTime: gameTime)
            ? GameConfig.NewFarmer.beginnersLuckMultiplier : 1.0
    }

    // MARK: - Natural Talent (-20% perk costs, first 48 game hours)

    static func isNaturalTalentActive(prestige: PrestigeState, gameTime: GameTime) -> Bool {
        isFirstFarm(prestige) && gameTime.totalGameMinutes < GameConfig.NewFarmer.boosterDurationGameMinutes
    }

    /// Returns the perk cost after Natural Talent discount, or the original cost.
    static func adjustedPerkCost(_ baseCost: Int, prestige: PrestigeState, gameTime: GameTime) -> Int {
        guard isNaturalTalentActive(prestige: prestige, gameTime: gameTime) else { return baseCost }
        return max(1, Int(Double(baseCost) * (1.0 - GameConfig.NewFarmer.naturalTalentDiscount)))
    }

    // MARK: - Welcome Gift (3× first pig sale, one-shot)

    static func isWelcomeGiftAvailable(prestige: PrestigeState, boosterState: BoosterState) -> Bool {
        isFirstFarm(prestige) && !boosterState.welcomeGiftUsed
    }

    /// Returns 3.0 when the Welcome Gift is available, otherwise 1.0.
    /// Does NOT consume the gift — the caller must set `boosterState.welcomeGiftUsed = true`.
    static func saleMultiplier(prestige: PrestigeState, boosterState: BoosterState) -> Double {
        isWelcomeGiftAvailable(prestige: prestige, boosterState: boosterState)
            ? GameConfig.NewFarmer.welcomeGiftSaleMultiplier : 1.0
    }
}
