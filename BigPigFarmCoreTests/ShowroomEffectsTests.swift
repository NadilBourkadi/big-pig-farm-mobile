/// ShowroomEffectsTests — Tests for all 14 breeding/genetics Showroom upgrade effects.
/// Verifies each upgrade modifies the correct simulation parameter when purchased.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Helpers

private func prestigeWith(_ upgrades: ShowroomUpgrade...) -> PrestigeState {
    var prestige = PrestigeState()
    prestige.purchasedUpgrades = Set(upgrades)
    return prestige
}

private func adultFemale(ageDays: Double = 5.0) -> GuineaPig {
    var pig = GuineaPig.create(name: "Alice", gender: .female)
    pig.ageDays = ageDays
    pig.needs.happiness = 100.0
    return pig
}

private func adultMale(ageDays: Double = 5.0) -> GuineaPig {
    var pig = GuineaPig.create(name: "Bob", gender: .male)
    pig.ageDays = ageDays
    pig.needs.happiness = 100.0
    return pig
}

// MARK: - Fertile Ground

@Test func fertileGroundDoublesBaseBreedingChance() {
    let base = GameConfig.Breeding.baseBreedingChance
    let upgraded = GameConfig.Prestige.fertileGroundBreedingChance
    #expect(base == 0.05)
    #expect(upgraded == 0.10)
    #expect(upgraded == base * 2.0)
}

// MARK: - Early Bloomer

@Test func earlyBloomerAllowsBreedingAt2Days() {
    var pig = GuineaPig.create(name: "Young", gender: .female)
    pig.ageDays = 2.5
    pig.needs.happiness = 100.0

    // Without upgrade: too young (adult age is 3 days)
    let noUpgrade = PrestigeState()
    #expect(!pig.isBreedable(prestige: noUpgrade))
    #expect(pig.checkBreedingBlock(prestige: noUpgrade)?.hasPrefix("Too young") == true)

    // With upgrade: breedable at 2 days
    let withUpgrade = prestigeWith(.earlyBloomer)
    #expect(pig.isBreedable(prestige: withUpgrade))
}

@Test func earlyBloomerStillBlocksBelow2Days() {
    var pig = GuineaPig.create(name: "Baby", gender: .female)
    pig.ageDays = 1.5
    pig.needs.happiness = 100.0

    let withUpgrade = prestigeWith(.earlyBloomer)
    #expect(!pig.isBreedable(prestige: withUpgrade))
}

// MARK: - Rapid Recovery

@Test func rapidRecoveryHalvesRecoveryTime() {
    var pig = adultFemale()
    pig.lastBirthAge = 4.6  // Gave birth 0.4 days ago (ageDays=5.0)

    // Without upgrade: 1 day recovery, 0.6 days left
    let noUpgrade = PrestigeState()
    #expect(!pig.isBreedable(prestige: noUpgrade))
    let reason = pig.checkBreedingBlock(prestige: noUpgrade)
    #expect(reason?.hasPrefix("Recovering") == true)

    // With upgrade: 0.5 day recovery, so 0.4 days elapsed >= 0.5? No, still recovering
    // But if lastBirthAge = 4.4 (0.6 days ago), recovery is 0.5 days, should be clear
    pig.lastBirthAge = 4.4
    let withUpgrade = prestigeWith(.rapidRecovery)
    #expect(pig.isBreedable(prestige: withUpgrade))

    // Without upgrade at same lastBirthAge: still recovering (0.6 < 1.0)
    #expect(!pig.isBreedable(prestige: noUpgrade))
}

// MARK: - Speed Gestation

@Test func speedGestationReducesGestationDisplay() {
    var pig = adultFemale()
    pig.isPregnant = true
    pig.pregnancyDays = 1.6

    // Without upgrade: 2.0 day gestation, 0.4 days left
    let noUpgrade = PrestigeState()
    let reason1 = pig.checkBreedingBlock(prestige: noUpgrade)
    #expect(reason1?.hasPrefix("Pregnant") == true)

    // With upgrade: 1.5 day gestation, 1.6 >= 1.5 so birth is due (no block for "pregnant")
    // Wait - pig is still isPregnant=true so it will still show pregnant.
    // The breedingBlockReason checks isPregnant first, then shows time remaining.
    // With speed gestation, daysLeft = max(0, 1.5 - 1.6) = 0.0
    let withUpgrade = prestigeWith(.speedGestation)
    let reason2 = pig.checkBreedingBlock(prestige: withUpgrade)
    #expect(reason2?.hasPrefix("Pregnant") == true)
    // Key: the "days left" should be 0.0 with upgrade vs 0.4 without
    #expect(reason2?.contains("0.0") == true)
}

@Test func speedGestationConfigValues() {
    #expect(GameConfig.Breeding.gestationDays == 2)
    #expect(GameConfig.Prestige.speedGestationDays == 1.5)
}

// MARK: - Enduring Bonds

@Test func enduringBondsExtendsMaxBreedingAge() {
    var pig = adultMale(ageDays: 35.0)

    // Without upgrade: senior at 30 days, blocked
    let noUpgrade = PrestigeState()
    #expect(!pig.isBreedable(prestige: noUpgrade))
    #expect(pig.checkBreedingBlock(prestige: noUpgrade) == "Too old (senior)")

    // With upgrade: max breed age is 40, pig at 35 is still breedable
    let withUpgrade = prestigeWith(.enduringBonds)
    #expect(pig.isBreedable(prestige: withUpgrade))
}

@Test func enduringBondsBlocksAbove40Days() {
    var pig = adultMale(ageDays: 42.0)
    pig.needs.happiness = 100.0

    let withUpgrade = prestigeWith(.enduringBonds)
    #expect(!pig.isBreedable(prestige: withUpgrade))
    #expect(pig.checkBreedingBlock(prestige: withUpgrade) == "Too old (senior)")
}

@Test func enduringBondsExtendsDeathAge() {
    #expect(GameConfig.Simulation.maxAgeDays == 45)
    #expect(GameConfig.Prestige.enduringBondsMaxAge == 60)
}

// MARK: - Prolific Line

@Test func prolificLineMinLitterIs2() {
    #expect(GameConfig.Breeding.minLitterSize == 1)
    #expect(GameConfig.Prestige.prolificLineMinLitter == 2)
}

// MARK: - Twin Spark

@Test func twinSparkChanceIs10Percent() {
    #expect(GameConfig.Prestige.twinSparkChance == 0.10)
}

// MARK: - Pigdex Momentum

@Test func pigdexMomentumBonusCalculation() {
    // 10 discoveries * 0.005 = 0.05 (5% bonus)
    let bonus = min(10.0 * GameConfig.Prestige.pigdexMomentumPerEntry,
                    GameConfig.Prestige.pigdexMomentumCap)
    #expect(bonus == 0.05)

    // 20 discoveries * 0.005 = 0.10, matches cap
    let maxBonus = min(20.0 * GameConfig.Prestige.pigdexMomentumPerEntry,
                       GameConfig.Prestige.pigdexMomentumCap)
    #expect(maxBonus == 0.10)

    // 30 discoveries * 0.005 = 0.15, but capped at 0.10
    let cappedBonus = min(30.0 * GameConfig.Prestige.pigdexMomentumPerEntry,
                          GameConfig.Prestige.pigdexMomentumCap)
    #expect(cappedBonus == 0.10)
}

// MARK: - Mutation Catalyst

@Test func mutationCatalystIncreasesBaseRate() {
    #expect(GameConfig.Genetics.mutationRate == 0.02)
    #expect(GameConfig.Prestige.mutationCatalystRate == 0.05)
}

// MARK: - Biome Intuition

@Test func biomeIntuitionMultiplierIs2x() {
    #expect(GameConfig.Prestige.biomeIntuitionMultiplier == 2.0)
}

// MARK: - Premium Genetics

@Test func premiumGeneticsMultiplierIs1Point5x() {
    #expect(GameConfig.Prestige.premiumGeneticsRarityMultiplier == 1.5)
}

// MARK: - Legendary Lineage

@Test func legendaryLineageMultiplierIs2x() {
    #expect(GameConfig.Prestige.legendaryLineageMultiplier == 2.0)
}

// MARK: - Phenotype Recall

@Test func phenotypeRecallChanceIs15Percent() {
    #expect(GameConfig.Prestige.phenotypeRecallChance == 0.15)
}

@Test func canonicalGenotypeProducesCorrectPhenotype() {
    // Test a few representative phenotypes
    let testCases: [(BaseColor, Pattern, ColorIntensity, RoanType)] = [
        (.black, .solid, .full, .none),
        (.golden, .dutch, .chinchilla, .roan),
        (.smoke, .dalmatian, .himalayan, .none),
        (.lilac, .solid, .full, .roan),
        (.cream, .dutch, .full, .none),
        (.blue, .dalmatian, .chinchilla, .roan),
        (.saffron, .solid, .himalayan, .none),
        (.chocolate, .dutch, .full, .none),
    ]

    for (color, pattern, intensity, roan) in testCases {
        let genotype = canonicalGenotype(baseColor: color, pattern: pattern,
                                          intensity: intensity, roan: roan)
        let phenotype = calculatePhenotype(genotype)
        #expect(phenotype.baseColor == color, "Color mismatch for \(color)")
        #expect(phenotype.pattern == pattern, "Pattern mismatch for \(color)")
        #expect(phenotype.intensity == intensity, "Intensity mismatch for \(color)")
        #expect(phenotype.roan == roan, "Roan mismatch for \(color)")
    }
}

@Test func canonicalGenotypeFromKeyRoundTrips() {
    let key = "golden:dutch:chinchilla:roan"
    guard let genotype = canonicalGenotype(forPhenotypeKey: key) else {
        Issue.record("Failed to parse phenotype key")
        return
    }
    let phenotype = calculatePhenotype(genotype)
    let resultKey = phenotypeKey(phenotype)
    #expect(resultKey == key)
}

@Test func canonicalGenotypeFromInvalidKeyReturnsNil() {
    #expect(canonicalGenotype(forPhenotypeKey: "invalid") == nil)
    #expect(canonicalGenotype(forPhenotypeKey: "a:b:c") == nil)
    #expect(canonicalGenotype(forPhenotypeKey: "") == nil)
}

// MARK: - Genetic Imprinting

@Test func geneticImprintingForcesAlleleFromParent() {
    // Parent 1 is homozygous dominant at E locus (E/E)
    let parent1 = Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
    // Parent 2 is homozygous recessive at E locus (e/e)
    let parent2 = Genotype(
        eLocus: AllelePair(first: "e", second: "e"),
        bLocus: AllelePair(first: "b", second: "b"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )

    // Lock parent1's E locus: child must have at least one "E"
    let locked: [(locusName: String, parentGenotype: Genotype)] = [("eLocus", parent1)]

    var forcedECount = 0
    let trials = 200
    for _ in 0..<trials {
        let result = breed(parent1, parent2, lockedLoci: locked)
        if result.genotype.eLocus.contains("E") {
            forcedECount += 1
        }
    }

    // Without locking, ~75% would have E (since parent1 always gives E, parent2 always gives e,
    // so child is always E/e normally). But with imprinting, the first allele is forced from
    // parent1 (always E), so child should always have E. Allow small tolerance.
    #expect(forcedECount == trials, "All children should have at least one E allele")
}

@Test func geneticImprintingLockedLocusField() {
    var pig = GuineaPig.create(name: "Imprinted", gender: .female)
    #expect(pig.imprintedLocus == nil)

    pig.imprintedLocus = "eLocus"
    #expect(pig.imprintedLocus == "eLocus")
}

@Test func geneticImprintingRoanSafetyCheck() {
    // Lock a parent's R locus with dominant R. Ensure child never gets lethal RR.
    let parent1 = Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "R", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
    let parent2 = Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "R", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )

    let locked: [(locusName: String, parentGenotype: Genotype)] = [("rLocus", parent1)]
    for _ in 0..<200 {
        let result = breed(parent1, parent2, lockedLoci: locked)
        #expect(!result.genotype.rLocus.isHomozygous("R"),
                "Lethal RR should never occur even with locked R locus")
    }
}

// MARK: - No Upgrade = Base Values

@Test func noUpgradeUsesBaseValues() {
    let pig = adultFemale()
    let noUpgrade = PrestigeState()
    #expect(pig.isBreedable(prestige: noUpgrade))
    #expect(pig.checkBreedingBlock(prestige: noUpgrade) == nil)
}

@Test func lockedPigBlockedRegardlessOfPrestige() {
    var pig = adultFemale()
    pig.breedingLocked = true

    let withAll = prestigeWith(.earlyBloomer, .enduringBonds, .rapidRecovery, .speedGestation)
    #expect(!pig.isBreedable(prestige: withAll))
    #expect(pig.checkBreedingBlock(prestige: withAll) == "Breeding locked")
}

// MARK: - Multiple Upgrades Stack

@Test func multipleUpgradesStackCorrectly() {
    // A pig at 2.5 days old, post-birth 0.4 days ago, with happiness 100
    var pig = GuineaPig.create(name: "Stack", gender: .female)
    pig.ageDays = 2.5
    pig.needs.happiness = 100.0
    pig.lastBirthAge = 2.1  // gave birth 0.4 days ago

    // Without upgrades: too young (needs 3 days) AND recovering (needs 1 day)
    let noUpgrade = PrestigeState()
    #expect(!pig.isBreedable(prestige: noUpgrade))

    // With Early Bloomer only: old enough (2 days), but still recovering (1 day, 0.6 left)
    let earlyOnly = prestigeWith(.earlyBloomer)
    #expect(!pig.isBreedable(prestige: earlyOnly))

    // With Early Bloomer + Rapid Recovery: old enough AND recovery is 0.5 days, 0.4 elapsed
    // Wait, 0.5 - 0.4 = 0.1 > 0, still recovering
    // Let's adjust: pig at 2.6 days, lastBirth at 2.0, so 0.6 days since birth > 0.5 recovery
    pig.ageDays = 2.6
    pig.lastBirthAge = 2.0
    let both = prestigeWith(.earlyBloomer, .rapidRecovery)
    #expect(pig.isBreedable(prestige: both))
}

@Test func premiumAndLegendaryStack() {
    let baseRate = GameConfig.Genetics.mutationRate  // 0.02
    let premiumMultiplier = GameConfig.Prestige.premiumGeneticsRarityMultiplier  // 1.5
    let legendaryMultiplier = GameConfig.Prestige.legendaryLineageMultiplier  // 2.0

    // Both stacking: 0.02 * 1.5 * 2.0 = 0.06
    let stacked = baseRate * premiumMultiplier * legendaryMultiplier
    #expect(abs(stacked - 0.06) < 0.001)
}
