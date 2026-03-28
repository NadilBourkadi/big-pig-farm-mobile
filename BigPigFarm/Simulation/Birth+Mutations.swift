/// Birth+Mutations -- Mutation parameter computation for the birth pipeline.
/// Split from Birth+Processing.swift to stay within the file length limit.
import Foundation

extension Birth {

    // MARK: - Mutation Parameters

    /// Compute per-locus mutation rates and directional targets based on biome and perks.
    @MainActor
    static func computeMutationParameters(
        mother: GuineaPig,
        hasLab: Bool,
        hasAccelerator: Bool,
        gameState: GameState
    ) -> MutationParameters {
        let rate = computeBaseMutationRate(
            prestige: gameState.prestigeState, hasLab: hasLab, hasAccelerator: hasAccelerator
        )

        let motherBiome = gameState.farm.getBiomeAt(Int(mother.position.x), Int(mother.position.y))
        let biomeParams = computeBiomeMutationParams(
            biomeType: motherBiome, baseRate: rate,
            prestige: gameState.prestigeState, hasLab: hasLab, hasAccelerator: hasAccelerator
        )

        return MutationParameters(
            mutationRate: rate,
            locusRates: biomeParams.locusRates,
            directionalTargets: biomeParams.directionalTargets,
            directionalRate: biomeParams.directionalRate
        )
    }

    /// Compute the base mutation rate accounting for facilities and prestige upgrades.
    private static func computeBaseMutationRate(
        prestige: PrestigeState, hasLab: Bool, hasAccelerator: Bool
    ) -> Double {
        var rate = hasLab ? GameConfig.Genetics.mutationRateWithLab : GameConfig.Genetics.mutationRate
        if hasAccelerator { rate *= 2.0 }
        if prestige.hasUpgrade(.mutationCatalyst) {
            rate = max(rate, GameConfig.Prestige.mutationCatalystRate)
        }
        if prestige.hasUpgrade(.premiumGenetics) {
            rate *= GameConfig.Prestige.premiumGeneticsRarityMultiplier
        }
        if prestige.hasUpgrade(.legendaryLineage) {
            rate *= GameConfig.Prestige.legendaryLineageMultiplier
        }
        return rate
    }

    /// Biome-specific mutation overrides.
    private struct BiomeMutationResult {
        var locusRates: [String: Double]?
        var directionalTargets: [String: String]?
        var directionalRate: Double
    }

    /// Compute biome-specific locus rate overrides and directional mutation parameters.
    private static func computeBiomeMutationParams(
        biomeType: BiomeType?, baseRate: Double,
        prestige: PrestigeState, hasLab: Bool, hasAccelerator: Bool
    ) -> BiomeMutationResult {
        guard let biomeType, let biomeInfo = biomes[biomeType] else {
            return BiomeMutationResult(locusRates: nil, directionalTargets: nil, directionalRate: 0.0)
        }

        var locusRates: [String: Double]?
        if !biomeInfo.mutationBoostLoci.isEmpty {
            var rates: [String: Double] = [:]
            for (locus, boost) in biomeInfo.mutationBoostLoci where boost > 0 {
                rates[locus] = baseRate + boost
            }
            if prestige.hasUpgrade(.biomeIntuition) {
                for (locus, locusRate) in rates {
                    rates[locus] = baseRate + (locusRate - baseRate)
                        * GameConfig.Prestige.biomeIntuitionMultiplier
                }
            }
            if !rates.isEmpty { locusRates = rates }
        }

        var directionalTargets: [String: String]?
        var directionalRate: Double = 0.0
        if !biomeInfo.directionalAlleles.isEmpty {
            directionalTargets = biomeInfo.directionalAlleles
            directionalRate = hasLab
                ? GameConfig.Genetics.directionalMutationRateWithLab
                : GameConfig.Genetics.directionalMutationRate
            if hasAccelerator { directionalRate *= 2.0 }
            if prestige.hasUpgrade(.biomeIntuition) {
                directionalRate *= GameConfig.Prestige.biomeIntuitionMultiplier
            }
            directionalRate += prestige.biomeMastery.signatureMutationBoost(for: biomeType)
        }

        return BiomeMutationResult(
            locusRates: locusRates,
            directionalTargets: directionalTargets,
            directionalRate: directionalRate
        )
    }
}
