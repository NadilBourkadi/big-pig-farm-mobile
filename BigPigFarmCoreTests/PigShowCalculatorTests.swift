/// PigShowCalculatorTests -- Tests for stat extraction from game state and end-to-end scoring.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Phenotype Helpers

private let commonPhenotype = Phenotype(
    baseColor: .black, pattern: .solid,
    intensity: .full, roan: .none,
    rarity: .common
)

private let legendaryPhenotype = Phenotype(
    baseColor: .smoke, pattern: .dalmatian,
    intensity: .full, roan: .roan,
    rarity: .legendary
)

/// Create a pig with a specific phenotype.
@MainActor
private func makePigWith(phenotype: Phenotype) -> GuineaPig {
    var pig = GuineaPig.create(name: "Test", gender: .female)
    pig.phenotype = phenotype
    return pig
}

// MARK: - Unique Phenotypes

@Test @MainActor
func uniquePhenotypesCountsDistinctOnly() {
    let state = makeGameState()
    let phenoA = commonPhenotype
    let phenoB = Phenotype(
        baseColor: .golden, pattern: .solid,
        intensity: .full, roan: .none,
        rarity: .common
    )

    // Add 3 pigs: 2 with phenoA, 1 with phenoB
    let pig1 = makePigWith(phenotype: phenoA)
    let pig2 = makePigWith(phenotype: phenoA)
    let pig3 = makePigWith(phenotype: phenoB)
    state.guineaPigs[pig1.id] = pig1
    state.guineaPigs[pig2.id] = pig2
    state.guineaPigs[pig3.id] = pig3

    #expect(PigShowCalculator.uniquePhenotypesInHerd(state) == 2)
}

@Test @MainActor
func uniquePhenotypesEmptyHerdReturnsZero() {
    let state = makeGameState()
    #expect(PigShowCalculator.uniquePhenotypesInHerd(state) == 0)
}

@Test @MainActor
func uniquePhenotypesAllDistinct() {
    let state = makeGameState()
    let phenotypes = [
        commonPhenotype,
        Phenotype(baseColor: .golden, pattern: .solid, intensity: .full, roan: .none, rarity: .common),
        Phenotype(baseColor: .cream, pattern: .dutch, intensity: .full, roan: .none, rarity: .rare),
    ]
    for pheno in phenotypes {
        let pig = makePigWith(phenotype: pheno)
        state.guineaPigs[pig.id] = pig
    }
    #expect(PigShowCalculator.uniquePhenotypesInHerd(state) == 3)
}

// MARK: - Legendary Detection

@Test @MainActor
func hasLegendaryReturnsTrueWhenPresent() {
    let state = makeGameState()
    let pig = makePigWith(phenotype: legendaryPhenotype)
    state.guineaPigs[pig.id] = pig
    #expect(PigShowCalculator.hasLegendaryInHerd(state) == true)
}

@Test @MainActor
func hasLegendaryReturnsFalseWhenAbsent() {
    let state = makeGameState()
    let pig = makePigWith(phenotype: commonPhenotype)
    state.guineaPigs[pig.id] = pig
    #expect(PigShowCalculator.hasLegendaryInHerd(state) == false)
}

@Test @MainActor
func hasLegendaryReturnsFalseForEmptyHerd() {
    let state = makeGameState()
    #expect(PigShowCalculator.hasLegendaryInHerd(state) == false)
}

// MARK: - New Pigdex Entries

@Test
func newPigdexEntriesAllNew() {
    var pigdex = Pigdex()
    pigdex.discovered = ["black:solid:full:none": 1, "golden:solid:full:none": 2]
    let previous: Set<String> = []
    #expect(PigShowCalculator.newPigdexEntries(currentPigdex: pigdex, previousEntries: previous) == 2)
}

@Test
func newPigdexEntriesPartialOverlap() {
    var pigdex = Pigdex()
    pigdex.discovered = [
        "black:solid:full:none": 1,
        "golden:solid:full:none": 2,
        "cream:dutch:full:none": 3,
    ]
    let previous: Set<String> = ["black:solid:full:none"]
    #expect(PigShowCalculator.newPigdexEntries(currentPigdex: pigdex, previousEntries: previous) == 2)
}

@Test
func newPigdexEntriesAllPrevious() {
    var pigdex = Pigdex()
    pigdex.discovered = ["black:solid:full:none": 1, "golden:solid:full:none": 2]
    let previous: Set<String> = ["black:solid:full:none", "golden:solid:full:none"]
    #expect(PigShowCalculator.newPigdexEntries(currentPigdex: pigdex, previousEntries: previous) == 0)
}

@Test
func newPigdexEntriesEmptyPigdex() {
    let pigdex = Pigdex()
    let previous: Set<String> = ["black:solid:full:none"]
    #expect(PigShowCalculator.newPigdexEntries(currentPigdex: pigdex, previousEntries: previous) == 0)
}

// MARK: - Visit Streak Bonus Integration

@Test @MainActor
func evaluateIncludesVisitStreakBonus() {
    let state = makeGameState()
    var prestige = PrestigeState()
    prestige.lifetimeStats.totalSqueaksEarned = 50_000
    // Record 14 visits to get +2 streak bonus
    for _ in 0..<14 {
        prestige.visitStreak.currentStreak += 1
    }

    let breakdown = PigShowCalculator.evaluate(gameState: state, prestigeState: prestige)
    #expect(breakdown.streakBonus == 2)
}

// MARK: - Evaluate with Previous Pigdex Entries

@Test @MainActor
func evaluateDeductsPreviousPigdexEntries() {
    let state = makeGameState()
    var prestige = PrestigeState()
    prestige.lifetimeStats.totalSqueaksEarned = 50_000
    // 10 Pigdex entries, 5 of which were discovered on a prior farm
    for i in 0..<10 { state.pigdex.discovered["pheno_\(i)"] = 1 }
    prestige.previousPigdexEntries = Set((0..<5).map { "pheno_\($0)" })

    let breakdown = PigShowCalculator.evaluate(gameState: state, prestigeState: prestige)
    // 5 net-new entries / 5 = 1 pigdex bonus
    #expect(breakdown.pigdexBonus == 1)
}

// MARK: - End-to-End with Acceptance Criteria

@Test @MainActor
func acceptanceCriteria10Rosettes() {
    let state = makeGameState()
    var prestige = PrestigeState()
    prestige.lifetimeStats.totalSqueaksEarned = 50_000

    // 25 new Pigdex entries
    for i in 0..<25 {
        state.pigdex.discovered["pheno_\(i)"] = 1
    }

    // 15 unique phenotypes in herd
    for i in 0..<15 {
        let color = BaseColor.allCases[i % BaseColor.allCases.count]
        let pattern = Pattern.allCases[i / BaseColor.allCases.count % Pattern.allCases.count]
        let pheno = Phenotype(
            baseColor: color, pattern: pattern,
            intensity: .full, roan: .none,
            rarity: calculateRarity(baseColor: color, pattern: pattern, intensity: .full, roan: .none)
        )
        let pig = makePigWith(phenotype: pheno)
        state.guineaPigs[pig.id] = pig
    }

    // 4 contracts
    state.contractBoard.completedContracts = 4

    let breakdown = PigShowCalculator.evaluate(gameState: state, prestigeState: prestige)
    // base: floor(sqrt(50000/5000)) = 3, pigdex: 25/5 = 5, diversity: 15/10 = 1,
    // contract: 4/3 = 1, rarity: 0, streak: 0
    #expect(breakdown.total == 10)
}

@Test @MainActor
func acceptanceCriteria13Rosettes() {
    let state = makeGameState()
    var prestige = PrestigeState()
    prestige.lifetimeStats.totalSqueaksEarned = 150_000

    for i in 0..<20 { state.pigdex.discovered["pheno_\(i)"] = 1 }

    // 25 unique non-legendary phenotypes (force .common to avoid accidental legendary)
    for i in 0..<25 {
        let color = BaseColor.allCases[i % BaseColor.allCases.count]
        let pattern = Pattern.allCases[(i / BaseColor.allCases.count) % Pattern.allCases.count]
        let intensity = ColorIntensity.allCases[(i / (BaseColor.allCases.count * Pattern.allCases.count)) % ColorIntensity.allCases.count]
        let pheno = Phenotype(
            baseColor: color, pattern: pattern,
            intensity: intensity, roan: .none,
            rarity: .common
        )
        let pig = makePigWith(phenotype: pheno)
        state.guineaPigs[pig.id] = pig
    }

    state.contractBoard.completedContracts = 8

    let breakdown = PigShowCalculator.evaluate(gameState: state, prestigeState: prestige)
    // base: floor(sqrt(30)) = 5, pigdex: 20/5 = 4, diversity: 25/10 = 2,
    // contract: 8/3 = 2, rarity: 0, streak: 0
    #expect(breakdown.total == 13)
}

@Test @MainActor
func acceptanceCriteria23Rosettes() {
    let state = makeGameState()
    var prestige = PrestigeState()
    prestige.lifetimeStats.totalSqueaksEarned = 500_000

    for i in 0..<15 { state.pigdex.discovered["pheno_\(i)"] = 1 }

    // 39 non-legendary pigs with distinct phenotypes + 1 explicit legendary = 40 unique
    for i in 0..<39 {
        let color = BaseColor.allCases[i % BaseColor.allCases.count]
        let pattern = Pattern.allCases[(i / BaseColor.allCases.count) % Pattern.allCases.count]
        let intensity = ColorIntensity.allCases[(i / (BaseColor.allCases.count * Pattern.allCases.count)) % ColorIntensity.allCases.count]
        let pheno = Phenotype(
            baseColor: color, pattern: pattern,
            intensity: intensity, roan: .none,
            rarity: calculateRarity(baseColor: color, pattern: pattern, intensity: intensity, roan: .none)
        )
        let pig = makePigWith(phenotype: pheno)
        state.guineaPigs[pig.id] = pig
    }
    let legendaryPig = makePigWith(phenotype: legendaryPhenotype)
    state.guineaPigs[legendaryPig.id] = legendaryPig

    state.contractBoard.completedContracts = 15

    let breakdown = PigShowCalculator.evaluate(gameState: state, prestigeState: prestige)
    // base: floor(sqrt(100)) = 10, pigdex: 15/5 = 3, diversity: 40/10 = 4,
    // contract: 15/3 = 5, rarity: 1 (legendary), streak: 0
    #expect(breakdown.total == 23)
}

@Test @MainActor
func acceptanceCriteria35Rosettes() {
    let state = makeGameState()
    var prestige = PrestigeState()
    prestige.lifetimeStats.totalSqueaksEarned = 2_000_000

    for i in 0..<5 { state.pigdex.discovered["pheno_\(i)"] = 1 }

    // 49 non-legendary pigs with distinct phenotypes + 1 explicit legendary = 50 unique
    for i in 0..<49 {
        let color = BaseColor.allCases[i % BaseColor.allCases.count]
        let pattern = Pattern.allCases[(i / BaseColor.allCases.count) % Pattern.allCases.count]
        let intensity = ColorIntensity.allCases[(i / (BaseColor.allCases.count * Pattern.allCases.count)) % ColorIntensity.allCases.count]
        let pheno = Phenotype(
            baseColor: color, pattern: pattern,
            intensity: intensity, roan: .none,
            rarity: calculateRarity(baseColor: color, pattern: pattern, intensity: intensity, roan: .none)
        )
        let pig = makePigWith(phenotype: pheno)
        state.guineaPigs[pig.id] = pig
    }
    let legendaryPig = makePigWith(phenotype: legendaryPhenotype)
    state.guineaPigs[legendaryPig.id] = legendaryPig

    state.contractBoard.completedContracts = 25

    let breakdown = PigShowCalculator.evaluate(gameState: state, prestigeState: prestige)
    // base: floor(sqrt(400)) = 20, pigdex: 5/5 = 1, diversity: 50/10 = 5,
    // contract: 25/3 = 8, rarity: 1 (legendary), streak: 0
    #expect(breakdown.total == 35)
}
