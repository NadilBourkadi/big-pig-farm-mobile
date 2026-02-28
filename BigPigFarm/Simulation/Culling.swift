/// Culling -- Surplus pig management and population control.
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
    // Minimum diversity score gap between best and worst adult to trigger
    // active replacement. Prevents oscillation when colors are already
    // balanced (similar scores → gap < threshold → no replacement).
    private static let diversityReplacementGap: Double = 2.0

    // MARK: - Public API

    /// Remove all pigs marked for sale from state and return sale records.
    /// Babies marked for sale are skipped until they reach adulthood.
    /// Delegates valuation and contract fulfillment to Market.sellPig.
    @discardableResult
    @MainActor
    static func sellMarkedAdults(gameState: GameState) -> [SoldPigRecord] {
        var sold: [SoldPigRecord] = []
        for pig in gameState.getPigsList() {
            guard pig.markedForSale && !pig.isBaby else { continue }
            let pigName = pig.name
            let pigId = pig.id
            let saleResult = Market.sellPig(state: gameState, pig: pig)
            sold.append(SoldPigRecord(
                pigName: pigName,
                totalValue: saleResult.total,
                contractBonus: saleResult.contractBonus,
                pigID: pigId
            ))
        }
        return sold
    }

    // swiftlint:disable cyclomatic_complexity
    /// Identify and mark surplus breeders for population control.
    /// When above the stock limit: scores all adults and marks the lowest-scoring
    /// surplus for sale, preserving gender balance.
    /// When exactly at the stock limit: performs active replacement (phases out
    /// one non-matching or low-diversity adult per call).
    @MainActor
    static func cullSurplusBreeders(gameState: GameState) {
        let program = gameState.breedingProgram
        guard program.enabled else { return }
        let hasLab = !gameState.getFacilitiesByType(.geneticsLab).isEmpty
        let adults = gameState.getPigsList().filter { !$0.markedForSale && !$0.isBaby }
        let effectiveLimit = max(program.stockLimit, GameConfig.Breeding.minBreedingPopulation)
        if adults.count < effectiveLimit { return }
        if adults.count == effectiveLimit {
            activeReplacement(
                gameState: gameState, adults: adults,
                program: program, hasLab: hasLab
            )
            return
        }
        // Above limit: score adults best-first, split into kept and surplus.
        let scored = scoreAdults(adults, program: program, hasLab: hasLab, gameState: gameState)
        var kept: [GuineaPig] = []
        var surplus: [GuineaPig] = []
        var hasMale = false
        var hasFemale = false
        for sp in scored {
            if kept.count < effectiveLimit {
                kept.append(sp.pig)
                if sp.pig.gender == .male { hasMale = true } else { hasFemale = true }
            } else {
                surplus.append(sp.pig)
            }
        }
        // Gender balance: if kept set lacks a gender, swap worst kept with best surplus of needed gender.
        if !hasMale || !hasFemale {
            let neededGender: Gender = !hasMale ? .male : .female
            if let surplusIndex = surplus.firstIndex(where: { $0.gender == neededGender }) {
                let neededPig = surplus.remove(at: surplusIndex)
                let demotedPig = kept.removeLast()
                kept.append(neededPig)
                surplus.append(demotedPig)
            }
        }
        // Mark surplus for sale, skipping pregnant pigs.
        var markedCount = 0
        for pig in surplus {
            guard !pig.isPregnant else { continue }
            var updated = pig
            updated.markedForSale = true
            gameState.updateGuineaPig(updated)
            markedCount += 1
        }
        if markedCount > 0 {
            gameState.logEvent(
                "Breeding program: \(markedCount) surplus pig(s) marked for sale",
                eventType: "info"
            )
        }
    }
    // swiftlint:enable cyclomatic_complexity

    // MARK: - Private Helpers

    /// Score adult pigs by strategy-appropriate value, sorted best-first.
    /// Diversity mode uses a two-key sort: primary = diversity score,
    /// secondary = breeding score (mirrors Python's tuple comparison).
    @MainActor
    private static func scoreAdults(
        _ adults: [GuineaPig],
        program: BreedingProgram,
        hasLab: Bool,
        gameState: GameState
    ) -> [ScoredPig] {
        var result: [ScoredPig]
        switch program.strategy {
        case .diversity:
            let (phenotypeCounts, colorCounts) = buildDiversityCounters(pigs: adults)
            result = adults.map { pig in
                ScoredPig(
                    pig: pig,
                    primaryScore: diversityValue(
                        pig: pig,
                        allPigs: adults,
                        phenotypeCounts: phenotypeCounts,
                        colorCounts: colorCounts
                    ),
                    secondaryScore: breedingValue(pig: pig, program: program, hasLab: hasLab)
                )
            }
            result.sort {
                if $0.primaryScore != $1.primaryScore { return $0.primaryScore > $1.primaryScore }
                return $0.secondaryScore > $1.secondaryScore
            }
        case .money:
            result = adults.map { pig in
                ScoredPig(
                    pig: pig,
                    primaryScore: moneyValue(pig: pig, program: program, hasLab: hasLab, gameState: gameState),
                    secondaryScore: 0
                )
            }
            result.sort { $0.primaryScore > $1.primaryScore }
        case .target:
            result = adults.map { pig in
                ScoredPig(
                    pig: pig,
                    primaryScore: breedingValue(pig: pig, program: program, hasLab: hasLab),
                    secondaryScore: 0
                )
            }
            result.sort { $0.primaryScore > $1.primaryScore }
        }
        return result
    }

    /// Phase out the worst adult when at or below the stock limit.
    /// Three modes:
    /// - With targets: sell the worst non-matching adult.
    /// - Diversity (no targets): sell the worst scorer only when the gap exceeds threshold.
    /// - Money / Target (no targets): no-op (surplus culling only).
    /// Marks at most 1 pig per call. Skips pregnant pigs and preserves gender balance.
    @MainActor
    private static func activeReplacement(
        gameState: GameState,
        adults: [GuineaPig],
        program: BreedingProgram,
        hasLab: Bool
    ) {
        let candidates: [GuineaPig]
        let reason: String
        if program.hasTarget {
            candidates = adults.filter { !program.shouldKeepPig($0, hasGeneticsLab: hasLab) }
            reason = "non-matching"
        } else if program.strategy == .diversity {
            let scored = scoreAdults(adults, program: program, hasLab: hasLab, gameState: gameState)
            guard let best = scored.first, let worst = scored.last else { return }
            let gap = best.primaryScore - worst.primaryScore
            guard gap >= diversityReplacementGap else { return }
            candidates = [worst.pig]
            reason = "low diversity, gap \(String(format: "%.1f", gap))"
        } else {
            // Money/target without explicit targets: active replacement would oscillate.
            // Only surplus culling (count > limit) fires in this mode.
            return
        }
        guard !candidates.isEmpty else { return }
        // Score candidates worst-first.
        let worstFirst = scoreAdults(
            candidates, program: program, hasLab: hasLab, gameState: gameState
        ).reversed()
        for sp in worstFirst {
            guard !sp.pig.isPregnant else { continue }
            guard !wouldBreakGenderBalance(sp.pig, adults: adults) else { continue }
            var updated = sp.pig
            updated.markedForSale = true
            gameState.updateGuineaPig(updated)
            gameState.logEvent(
                "Breeding program: replacing \(sp.pig.name) (\(reason))",
                eventType: "info"
            )
            return
        }
    }

    /// Return true if selling this pig would leave zero of its gender among adults.
    private static func wouldBreakGenderBalance(_ pig: GuineaPig, adults: [GuineaPig]) -> Bool {
        !adults.contains { $0.gender == pig.gender && !$0.markedForSale && $0.id != pig.id }
    }

}

// MARK: - ScoredPig

/// Internal scoring result with primary and optional secondary sort keys.
/// Mirrors Python's lexicographic tuple comparison for (primary, secondary) scores.
private struct ScoredPig {
    let pig: GuineaPig
    let primaryScore: Double
    let secondaryScore: Double
}
