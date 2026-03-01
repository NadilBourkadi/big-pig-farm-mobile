/// BiomeSelectViewTests — Unit tests for BiomeSelectView biome status logic.
/// Tests focus on model/business-rule correctness, not SwiftUI rendering.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - biomeStatus: Already Built

@Test @MainActor func builtBiomeIsUnavailable() {
    let view = BiomeSelectView(farmTier: 5, existingBiomes: [.meadow], onBiomeSelected: { _ in })
    let (available, reason) = view.biomeStatus(.meadow)
    #expect(!available)
    #expect(reason == "Built")
}

@Test @MainActor func unbuiltBiomeIsNotMarkedBuilt() {
    let view = BiomeSelectView(farmTier: 5, existingBiomes: [.meadow], onBiomeSelected: { _ in })
    let (_, reason) = view.biomeStatus(.burrow)
    #expect(reason != "Built")
}

// MARK: - biomeStatus: Tier Locking

@Test @MainActor func meadowAvailableAtTierOne() {
    let view = BiomeSelectView(farmTier: 1, existingBiomes: [], onBiomeSelected: { _ in })
    let (available, lockReason) = view.biomeStatus(.meadow)
    #expect(available)
    #expect(lockReason == nil)
}

@Test @MainActor func tierLockedBiomeIsUnavailable() {
    // alpine requires tier 3; farmTier is 2
    let view = BiomeSelectView(farmTier: 2, existingBiomes: [], onBiomeSelected: { _ in })
    let (available, reason) = view.biomeStatus(.alpine)
    #expect(!available)
    #expect(reason == "Requires Tier 3")
}

@Test @MainActor func biomeUnlocksAtExactRequiredTier() {
    // burrow requires tier 1; farmTier 1 with no prerequisites needed
    let view = BiomeSelectView(farmTier: 1, existingBiomes: [], onBiomeSelected: { _ in })
    let (available, _) = view.biomeStatus(.burrow)
    #expect(available)
}

// MARK: - biomeStatus: Prerequisite Tiers

@Test @MainActor func prerequisiteTierMissingBlocksBiome() {
    // garden requires tier 2; no tier-1 biome built yet
    let view = BiomeSelectView(farmTier: 2, existingBiomes: [], onBiomeSelected: { _ in })
    let (available, reason) = view.biomeStatus(.garden)
    #expect(!available)
    #expect(reason == "Build a Tier 1 biome first")
}

@Test @MainActor func prerequisiteTierSatisfiedAllowsBiome() {
    // garden requires tier 2; meadow (tier 1) is already built
    let view = BiomeSelectView(farmTier: 2, existingBiomes: [.meadow], onBiomeSelected: { _ in })
    let (available, lockReason) = view.biomeStatus(.garden)
    #expect(available)
    #expect(lockReason == nil)
}

@Test @MainActor func sanctuaryRequiresAllLowerTiers() {
    // sanctuary requires tier 5; only tier 1 covered — missing tier 2
    let view = BiomeSelectView(farmTier: 5, existingBiomes: [.meadow], onBiomeSelected: { _ in })
    let (available, reason) = view.biomeStatus(.sanctuary)
    #expect(!available)
    #expect(reason == "Build a Tier 2 biome first")
}

@Test @MainActor func sanctuaryAvailableWhenAllTiersCovered() {
    // meadow=tier1, garden=tier2, alpine=tier3, wildflower=tier4
    let existing: Set<BiomeType> = [.meadow, .garden, .alpine, .wildflower]
    let view = BiomeSelectView(farmTier: 5, existingBiomes: existing, onBiomeSelected: { _ in })
    let (available, lockReason) = view.biomeStatus(.sanctuary)
    #expect(available)
    #expect(lockReason == nil)
}

// MARK: - biomeStatus: Edge Cases

@Test @MainActor func emptyExistingBiomesShowsNoneBuilt() {
    let view = BiomeSelectView(farmTier: 5, existingBiomes: [], onBiomeSelected: { _ in })
    for biome in BiomeType.allCases {
        let (_, reason) = view.biomeStatus(biome)
        #expect(reason != "Built")
    }
}

@Test @MainActor func allBiomesBuiltShowsAllAsBuilt() {
    let all = Set(BiomeType.allCases)
    let view = BiomeSelectView(farmTier: 5, existingBiomes: all, onBiomeSelected: { _ in })
    for biome in BiomeType.allCases {
        let (available, reason) = view.biomeStatus(biome)
        #expect(!available)
        #expect(reason == "Built")
    }
}

// MARK: - BiomeInfo Data Integrity

@Test func allBiomeTypesHaveInfoEntries() {
    for biome in BiomeType.allCases {
        #expect(biomes[biome] != nil, "Missing BiomeInfo for \(biome)")
    }
}

@Test func biomeDisplayNamesAreNonEmpty() {
    for biome in BiomeType.allCases {
        let name = biomes[biome]?.displayName ?? ""
        #expect(!name.isEmpty, "Empty displayName for \(biome)")
    }
}

@Test func biomeCostsAreNonNegative() {
    for biome in BiomeType.allCases {
        let cost = biomes[biome]?.cost ?? -1
        #expect(cost >= 0, "Negative cost for \(biome)")
    }
}

@Test func meadowIsFree() {
    #expect(biomes[.meadow]?.cost == 0)
}

@Test func biomeHappinessBonusIsPositive() {
    for biome in BiomeType.allCases {
        let bonus = biomes[biome]?.happinessBonus ?? -1
        #expect(bonus > 0, "Non-positive happinessBonus for \(biome)")
    }
}

@Test func biomeRequiredTiersAreInRange() {
    for biome in BiomeType.allCases {
        let tier = biomes[biome]?.requiredTier ?? 0
        #expect(tier >= 1 && tier <= 5, "requiredTier out of range for \(biome): \(tier)")
    }
}
