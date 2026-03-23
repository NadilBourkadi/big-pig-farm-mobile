/// BiomeMasteryTests — Tests for biome mastery threshold, cost reduction, and mutation boost.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Threshold & Progress

@Test func biomeMasteryNotMasteredAtZero() {
    let mastery = BiomeMastery()
    #expect(!mastery.isMastered(.alpine))
    #expect(mastery.pigsBred(in: .alpine) == 0)
    #expect(mastery.masteryProgress(for: .alpine) == 0.0)
}

@Test func biomeMasteryNotMasteredBelowThreshold() {
    var mastery = BiomeMastery()
    let below = GameConfig.Prestige.biomeMasteryThreshold - 1
    for _ in 0..<below {
        mastery.recordBirth(in: .alpine)
    }
    #expect(!mastery.isMastered(.alpine))
    #expect(mastery.pigsBred(in: .alpine) == below)
}

@Test func biomeMasteryMasteredAtExactThreshold() {
    var mastery = BiomeMastery()
    for _ in 0..<GameConfig.Prestige.biomeMasteryThreshold {
        mastery.recordBirth(in: .alpine)
    }
    #expect(mastery.isMastered(.alpine))
    #expect(mastery.masteryProgress(for: .alpine) == 1.0)
}

@Test func biomeMasteryProgressClampsAboveThreshold() {
    var mastery = BiomeMastery()
    for _ in 0..<15 {
        mastery.recordBirth(in: .meadow)
    }
    #expect(mastery.masteryProgress(for: .meadow) == 1.0)
}

@Test func biomeMasteryIndependentPerBiome() {
    var mastery = BiomeMastery()
    for _ in 0..<10 { mastery.recordBirth(in: .alpine) }
    #expect(mastery.isMastered(.alpine))
    #expect(!mastery.isMastered(.tropical))
    #expect(mastery.masteredBiomes == [.alpine])
}

// MARK: - Room Cost Multiplier

@Test func roomCostMultiplierReturns1WhenNotMastered() {
    let mastery = BiomeMastery()
    #expect(mastery.roomCostMultiplier(for: .alpine) == 1.0)
}

@Test func roomCostMultiplierMatchesConfig() {
    var mastery = BiomeMastery()
    for _ in 0..<10 { mastery.recordBirth(in: .burrow) }
    let expected = 1.0 - GameConfig.Prestige.biomeMasteryCostReduction
    #expect(mastery.roomCostMultiplier(for: .burrow) == expected)
}

// MARK: - Signature Mutation Boost

@Test func signatureMutationBoostReturnsZeroWhenNotMastered() {
    let mastery = BiomeMastery()
    #expect(mastery.signatureMutationBoost(for: .crystal) == 0.0)
}

@Test func signatureMutationBoostReturns002WhenMastered() {
    var mastery = BiomeMastery()
    for _ in 0..<10 { mastery.recordBirth(in: .crystal) }
    #expect(mastery.signatureMutationBoost(for: .crystal) == 0.02)
}

@Test func signatureMutationBoostMatchesConfig() {
    var mastery = BiomeMastery()
    for _ in 0..<10 { mastery.recordBirth(in: .garden) }
    #expect(mastery.signatureMutationBoost(for: .garden) == GameConfig.Prestige.biomeMasteryMutationBoost)
}

// MARK: - All Biomes

@Test func masteryRewardsAllBiomes() {
    var mastery = BiomeMastery()
    for biome in BiomeType.allCases {
        for _ in 0..<10 { mastery.recordBirth(in: biome) }
    }
    #expect(mastery.masteredBiomes.count == 8)
    for biome in BiomeType.allCases {
        #expect(mastery.roomCostMultiplier(for: biome) == 0.75)
        #expect(mastery.signatureMutationBoost(for: biome) == 0.02)
    }
}

// MARK: - Codable Round-Trip

@Test func biomeMasteryRewardsPreservedAfterCodableRoundTrip() throws {
    var mastery = BiomeMastery()
    for _ in 0..<10 { mastery.recordBirth(in: .alpine) }
    for _ in 0..<5 { mastery.recordBirth(in: .tropical) }

    let data = try JSONEncoder().encode(mastery)
    let decoded = try JSONDecoder().decode(BiomeMastery.self, from: data)

    #expect(decoded.isMastered(.alpine))
    #expect(!decoded.isMastered(.tropical))
    #expect(decoded.pigsBred(in: .tropical) == 5)
    #expect(decoded.roomCostMultiplier(for: .alpine) == 0.75)
    #expect(decoded.signatureMutationBoost(for: .alpine) == 0.02)
}
