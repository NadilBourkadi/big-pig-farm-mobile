/// PigShowCalculator -- Extracts live stats from game state for Rosette scoring.
/// Called once at prestige time to evaluate the Pig Show and determine Rosette awards.

enum PigShowCalculator {
    /// Evaluate the Pig Show and return a full Rosette breakdown.
    @MainActor
    static func evaluate(
        gameState: GameState,
        prestigeState: PrestigeState
    ) -> RosetteBreakdown {
        let input = RosetteInput(
            lifetimeSqueaks: prestigeState.lifetimeStats.totalSqueaksEarned,
            newPigdexEntries: newPigdexEntries(
                currentPigdex: gameState.pigdex,
                previousEntries: prestigeState.previousPigdexEntries
            ),
            uniquePhenotypesInHerd: uniquePhenotypesInHerd(gameState),
            contractsCompleted: gameState.contractBoard.completedContracts,
            hasLegendaryPig: hasLegendaryInHerd(gameState),
            visitStreakBonusRosettes: prestigeState.visitStreak.bonusRosettes
        )
        return RosetteCalculator.breakdown(input)
    }

    /// Count unique phenotypes currently in the herd.
    @MainActor
    static func uniquePhenotypesInHerd(_ gameState: GameState) -> Int {
        var keys = Set<String>()
        for pig in gameState.getPigsList() {
            keys.insert(phenotypeKey(pig.phenotype))
        }
        return keys.count
    }

    /// Check whether any pig in the herd has legendary rarity.
    @MainActor
    static func hasLegendaryInHerd(_ gameState: GameState) -> Bool {
        gameState.getPigsList().contains { $0.phenotype.rarity == .legendary }
    }

    /// Compute new Pigdex entries discovered on this farm.
    static func newPigdexEntries(
        currentPigdex: Pigdex,
        previousEntries: Set<String>
    ) -> Int {
        let currentKeys = Set(currentPigdex.discovered.keys)
        return currentKeys.subtracting(previousEntries).count
    }
}
