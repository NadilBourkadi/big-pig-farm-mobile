/// AcclimationTests — Unit tests for Acclimation.updateAcclimation.
/// Maps from: simulation/acclimation.py tests
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Test Helpers

/// Create a pig with a known preferredBiome and the specified base color.
@MainActor
func makeAcclimationPig(
    preferredBiome: String? = "meadow",
    baseColor: BaseColor = .black
) -> GuineaPig {
    // Map the desired phenotype (visible color) to the underlying genotype (alleles).
    // Only .blue is explicitly handled because Alpine's signatureColor is .blue —
    // the color-match tests require it. All other cases default to .black.
    let genotype: Genotype
    switch baseColor {
    case .blue:
        // Blue phenotype = E dominant, B dominant, d recessive (dd = dilute)
        genotype = Genotype(
            eLocus: AllelePair(first: "E", second: "E"),
            bLocus: AllelePair(first: "B", second: "B"),
            sLocus: AllelePair(first: "S", second: "S"),
            cLocus: AllelePair(first: "C", second: "C"),
            rLocus: AllelePair(first: "r", second: "r"),
            dLocus: AllelePair(first: "d", second: "d")
        )
    default:
        // Black = E dominant, B dominant, D dominant
        genotype = Genotype(
            eLocus: AllelePair(first: "E", second: "E"),
            bLocus: AllelePair(first: "B", second: "B"),
            sLocus: AllelePair(first: "S", second: "S"),
            cLocus: AllelePair(first: "C", second: "C"),
            rLocus: AllelePair(first: "r", second: "r"),
            dLocus: AllelePair(first: "D", second: "D")
        )
    }
    var pig = GuineaPig.create(name: "TestPig", gender: .female, genotype: genotype)
    pig.preferredBiome = preferredBiome
    return pig
}

private let fullThreshold = GameConfig.Biome.acclimationDays *
    Double(GameConfig.Time.gameHoursPerDay)         // 72.0

private let colorMatchThreshold = fullThreshold *
    GameConfig.Biome.colorMatchAcclimationMultiplier  // 36.0

// MARK: - No-op guards

@Test @MainActor func acclimationNoOpWhenNoPreferredBiome() {
    var pig = makeAcclimationPig(preferredBiome: nil)
    Acclimation.updateAcclimation(pig: &pig, currentBiome: "alpine", hoursPerTick: 2.0)
    #expect(pig.acclimationTimer == 0.0)
    #expect(pig.acclimatingBiome == nil)
}

@Test @MainActor func acclimationNoOpWhenNoCurrentBiome() {
    var pig = makeAcclimationPig(preferredBiome: "meadow")
    Acclimation.updateAcclimation(pig: &pig, currentBiome: nil, hoursPerTick: 2.0)
    #expect(pig.acclimationTimer == 0.0)
    #expect(pig.acclimatingBiome == nil)
}

// MARK: - Home biome

@Test @MainActor func acclimationTimerResetsInHomeBiome() {
    var pig = makeAcclimationPig(preferredBiome: "meadow")
    pig.acclimationTimer = 20.0
    pig.acclimatingBiome = "alpine"
    Acclimation.updateAcclimation(pig: &pig, currentBiome: "meadow", hoursPerTick: 1.0)
    #expect(pig.acclimationTimer == 0.0)
    #expect(pig.acclimatingBiome == nil)
    #expect(pig.preferredBiome == "meadow")
}

@Test @MainActor func acclimationReturnToHomeClearsAcclimatingBiome() {
    var pig = makeAcclimationPig(preferredBiome: "meadow")
    Acclimation.updateAcclimation(pig: &pig, currentBiome: "alpine", hoursPerTick: 10.0)
    #expect(pig.acclimatingBiome == "alpine")
    Acclimation.updateAcclimation(pig: &pig, currentBiome: "meadow", hoursPerTick: 1.0)
    #expect(pig.acclimationTimer == 0.0)
    #expect(pig.acclimatingBiome == nil)
}

// MARK: - Timer progression

@Test @MainActor func acclimationTimerAdvancesInForeignBiome() {
    var pig = makeAcclimationPig(preferredBiome: "meadow")
    Acclimation.updateAcclimation(pig: &pig, currentBiome: "alpine", hoursPerTick: 2.0)
    #expect(pig.acclimationTimer == 2.0)
    #expect(pig.acclimatingBiome == "alpine")
    #expect(pig.preferredBiome == "meadow")
}

@Test @MainActor func acclimationTimerResetsOnBiomeChange() {
    var pig = makeAcclimationPig(preferredBiome: "meadow")
    pig.acclimationTimer = 20.0
    pig.acclimatingBiome = "alpine"
    Acclimation.updateAcclimation(pig: &pig, currentBiome: "tropical", hoursPerTick: 1.0)
    #expect(pig.acclimationTimer == 1.0)
    #expect(pig.acclimatingBiome == "tropical")
}

@Test @MainActor func acclimationTimerAccumulatesAcrossMultipleTicks() {
    var pig = makeAcclimationPig(preferredBiome: "meadow")
    for _ in 0..<10 {
        Acclimation.updateAcclimation(pig: &pig, currentBiome: "alpine", hoursPerTick: 1.0)
    }
    #expect(pig.acclimationTimer == 10.0)
    #expect(pig.acclimatingBiome == "alpine")
}

// MARK: - Adoption

@Test @MainActor func acclimationAdoptsNewBiomeAfterFullThreshold() {
    var pig = makeAcclimationPig(preferredBiome: "meadow")
    pig.acclimationTimer = fullThreshold - 1.0
    pig.acclimatingBiome = "alpine"
    Acclimation.updateAcclimation(pig: &pig, currentBiome: "alpine", hoursPerTick: 2.0)
    #expect(pig.preferredBiome == "alpine")
    #expect(pig.acclimationTimer == 0.0)
    #expect(pig.acclimatingBiome == nil)
}

@Test @MainActor func acclimationAdoptsExactlyAtThreshold() {
    var pig = makeAcclimationPig(preferredBiome: "meadow")
    pig.acclimationTimer = fullThreshold - 1.0
    pig.acclimatingBiome = "alpine"
    Acclimation.updateAcclimation(pig: &pig, currentBiome: "alpine", hoursPerTick: 1.0)
    // Timer is exactly 72.0 → should adopt
    #expect(pig.preferredBiome == "alpine")
}

@Test @MainActor func acclimationSecondAdoptionIsPossible() {
    var pig = makeAcclimationPig(preferredBiome: "meadow")
    pig.acclimationTimer = fullThreshold - 1.0
    pig.acclimatingBiome = "alpine"
    Acclimation.updateAcclimation(pig: &pig, currentBiome: "alpine", hoursPerTick: 2.0)
    #expect(pig.preferredBiome == "alpine")
    // Now start acclimating toward tropical
    Acclimation.updateAcclimation(pig: &pig, currentBiome: "tropical", hoursPerTick: 5.0)
    #expect(pig.acclimationTimer == 5.0)
    #expect(pig.acclimatingBiome == "tropical")
    #expect(pig.preferredBiome == "alpine")
}

@Test @MainActor func acclimationFieldsResetAfterAdoption() {
    var pig = makeAcclimationPig(preferredBiome: "meadow")
    pig.acclimationTimer = fullThreshold - 1.0
    pig.acclimatingBiome = "alpine"
    Acclimation.updateAcclimation(pig: &pig, currentBiome: "alpine", hoursPerTick: 2.0)
    #expect(pig.acclimationTimer == 0.0)
    #expect(pig.acclimatingBiome == nil)
}

// MARK: - Color-match acceleration

@Test @MainActor func acclimationColorMatchReducesThreshold() {
    // alpine's signature color is .blue; a blue pig should adopt at 36.0 hours
    var pig = makeAcclimationPig(preferredBiome: "meadow", baseColor: .blue)
    #expect(pig.phenotype.baseColor == .blue)
    pig.acclimationTimer = colorMatchThreshold - 1.0
    pig.acclimatingBiome = "alpine"
    Acclimation.updateAcclimation(pig: &pig, currentBiome: "alpine", hoursPerTick: 1.0)
    #expect(pig.preferredBiome == "alpine")
}

@Test @MainActor func acclimationColorMatchDoesNotAdoptTooEarly() {
    var pig = makeAcclimationPig(preferredBiome: "meadow", baseColor: .blue)
    pig.acclimationTimer = colorMatchThreshold - 2.0
    pig.acclimatingBiome = "alpine"
    Acclimation.updateAcclimation(pig: &pig, currentBiome: "alpine", hoursPerTick: 1.0)
    // Timer = colorMatchThreshold - 1.0, below threshold → no adoption yet
    #expect(pig.preferredBiome == "meadow")
}

@Test @MainActor func acclimationColorMismatchUsesFullThreshold() {
    // .black is NOT alpine's signature color → full 72-hour threshold applies
    var pig = makeAcclimationPig(preferredBiome: "meadow", baseColor: .black)
    pig.acclimationTimer = colorMatchThreshold  // 36.0
    pig.acclimatingBiome = "alpine"
    Acclimation.updateAcclimation(pig: &pig, currentBiome: "alpine", hoursPerTick: 1.0)
    // Timer = 37.0, still below full 72-hour threshold → no adoption
    #expect(pig.preferredBiome == "meadow")
    #expect(pig.acclimationTimer == colorMatchThreshold + 1.0)
}
