/// ModelEntityTests -- Tests for entity models (GuineaPig, Facility, FarmArea, Biome, Bloodline).
/// Pigdex, Cell, GameTime, Currency, BreedingProgram, ContractBoard, and Sendable tests
/// are in ModelEntityExtrasTests.swift.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - GuineaPig Tests

@Test func guineaPigAgeGroupBaby() {
    let pig = GuineaPig(
        id: UUID(), name: "Test", genotype: Genotype.randomCommon(),
        phenotype: Phenotype(baseColor: .black, pattern: .solid, intensity: .full, roan: .none, rarity: .common),
        gender: .male, birthTime: Date(), ageDays: 1.0
    )
    #expect(pig.ageGroup == .baby)
    #expect(pig.isBaby)
    #expect(!pig.isAdult)
}

@Test func guineaPigAgeGroupAdult() {
    let pig = GuineaPig(
        id: UUID(), name: "Test", genotype: Genotype.randomCommon(),
        phenotype: Phenotype(baseColor: .black, pattern: .solid, intensity: .full, roan: .none, rarity: .common),
        gender: .male, birthTime: Date(), ageDays: 10.0
    )
    #expect(pig.ageGroup == .adult)
    #expect(pig.isAdult)
}

@Test func guineaPigAgeGroupSenior() {
    let pig = GuineaPig(
        id: UUID(), name: "Test", genotype: Genotype.randomCommon(),
        phenotype: Phenotype(baseColor: .black, pattern: .solid, intensity: .full, roan: .none, rarity: .common),
        gender: .male, birthTime: Date(), ageDays: 35.0
    )
    #expect(pig.ageGroup == .senior)
    #expect(pig.isSenior)
}

@Test func guineaPigCreateFactory() {
    let pig = GuineaPig.create(name: "Squeaky", gender: .female)
    #expect(pig.name == "Squeaky")
    #expect(pig.gender == .female)
    #expect(!pig.personality.isEmpty)
    #expect(pig.personality.count <= 2)
}

@Test func guineaPigHasTrait() {
    var pig = GuineaPig(
        id: UUID(), name: "Test", genotype: Genotype.randomCommon(),
        phenotype: Phenotype(baseColor: .black, pattern: .solid, intensity: .full, roan: .none, rarity: .common),
        gender: .male, birthTime: Date(), personality: [.greedy, .brave]
    )
    #expect(pig.hasTrait(.greedy))
    #expect(pig.hasTrait(.brave))
    #expect(!pig.hasTrait(.shy))
    _ = pig // suppress mutation warning
}

@Test func guineaPigBreedingBlockedBaby() {
    let pig = GuineaPig(
        id: UUID(), name: "Test", genotype: Genotype.randomCommon(),
        phenotype: Phenotype(baseColor: .black, pattern: .solid, intensity: .full, roan: .none, rarity: .common),
        gender: .male, birthTime: Date(), ageDays: 1.0
    )
    #expect(!pig.canBreed)
    #expect(pig.breedingBlockReason != nil)
}

// MARK: - Facility Tests

@Test func facilityCellsComputed() {
    let facility = Facility.create(type: .hideout, x: 5, y: 10)
    let cells = facility.cells
    // Hideout is 3x2 = 6 cells
    #expect(cells.count == 6)
    #expect(cells.contains(GridPosition(x: 5, y: 10)))
    #expect(cells.contains(GridPosition(x: 7, y: 11)))
}

@Test func facilityInteractionPoint() {
    let facility = Facility.create(type: .foodBowl, x: 10, y: 5)
    // Food bowl is 2x1, interaction point at front-center
    let point = facility.interactionPoint
    #expect(point.x == 11)  // 10 + 2/2
    #expect(point.y == 6)   // 5 + 1
}

@Test func facilityConsume() {
    var facility = Facility.create(type: .foodBowl, x: 0, y: 0)
    let consumed = facility.consume(50.0)
    #expect(consumed == 50.0)
    #expect(facility.currentAmount == 150.0)
}

@Test func facilityConsumeMoreThanAvailable() {
    var facility = Facility.create(type: .foodBowl, x: 0, y: 0)
    facility.currentAmount = 30.0
    let consumed = facility.consume(50.0)
    #expect(consumed == 30.0)
    #expect(facility.currentAmount == 0.0)
}

@Test func facilityUpgrade() {
    var facility = Facility.create(type: .foodBowl, x: 0, y: 0)
    let success = facility.upgrade()
    #expect(success)
    #expect(facility.level == 2)
    #expect(facility.maxAmount == 300.0) // 200 * 1.5
}

@Test func facilityUpgradeMaxLevel() {
    var facility = Facility.create(type: .foodBowl, x: 0, y: 0)
    _ = facility.upgrade() // level 2
    _ = facility.upgrade() // level 3 (max)
    let success = facility.upgrade() // should fail
    #expect(!success)
    #expect(facility.level == 3)
}

@Test func facilityInfoComplete() {
    // All 17 facility types should have entries
    for type in FacilityType.allCases {
        #expect(facilityInfo[type] != nil, "Missing facilityInfo for \(type)")
    }
}

@Test func facilityCreateSetsCapacity() {
    let facility = Facility.create(type: .waterBottle, x: 0, y: 0)
    #expect(facility.currentAmount == 200.0)
    #expect(facility.maxAmount == 200.0)
}

// MARK: - FarmArea Tests

@Test func farmAreaInteriorBounds() {
    let area = FarmArea(
        id: UUID(), name: "Test", biome: .meadow,
        x1: 0, y1: 0, x2: 10, y2: 8
    )
    #expect(area.interiorX1 == 1)
    #expect(area.interiorY1 == 1)
    #expect(area.interiorX2 == 9)
    #expect(area.interiorY2 == 7)
    #expect(area.interiorWidth == 9)
    #expect(area.interiorHeight == 7)
}

@Test func farmAreaContains() {
    let area = FarmArea(
        id: UUID(), name: "Test", biome: .meadow,
        x1: 5, y1: 5, x2: 15, y2: 15
    )
    #expect(area.contains(x: 5, y: 5))   // On wall
    #expect(area.contains(x: 10, y: 10)) // Interior
    #expect(!area.contains(x: 4, y: 5))  // Outside
}

@Test func farmAreaContainsInterior() {
    let area = FarmArea(
        id: UUID(), name: "Test", biome: .meadow,
        x1: 5, y1: 5, x2: 15, y2: 15
    )
    #expect(!area.containsInterior(x: 5, y: 5))  // On wall, not interior
    #expect(area.containsInterior(x: 6, y: 6))    // Interior
    #expect(area.containsInterior(x: 14, y: 14))  // Interior edge
    #expect(!area.containsInterior(x: 15, y: 15)) // On wall
}

@Test func farmAreaCenter() {
    let area = FarmArea(
        id: UUID(), name: "Test", biome: .meadow,
        x1: 0, y1: 0, x2: 10, y2: 8
    )
    #expect(area.centerX == 5)
    #expect(area.centerY == 4)
}

// MARK: - Biome Tests

@Test func biomeInfoComplete() {
    for type in BiomeType.allCases {
        #expect(biomes[type] != nil, "Missing biome info for \(type)")
    }
}

@Test func biomeSignatureColorsMeadow() {
    #expect(biomeSignatureColors["meadow"] == .black)
}

@Test func biomeSignatureColorsSanctuary() {
    #expect(biomeSignatureColors["sanctuary"] == .smoke)
}

@Test func colorToBiomeReverseLookup() {
    #expect(colorToBiome[.black] == "meadow")
    #expect(colorToBiome[.chocolate] == "burrow")
    #expect(colorToBiome[.smoke] == "sanctuary")
}

// MARK: - Bloodline Tests

@Test func bloodlineComplete() {
    for type in BloodlineType.allCases {
        #expect(bloodlines[type] != nil, "Missing bloodline for \(type)")
    }
}

@Test func bloodlineApplyToGenotype() throws {
    let base = Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
    let spotted = try #require(bloodlines[.spotted])
    let result = spotted.applyToGenotype(base)
    #expect(result.sLocus == AllelePair(first: "S", second: "s"))
    // Other loci unchanged
    #expect(result.eLocus == base.eLocus)
    #expect(result.bLocus == base.bLocus)
}

@Test func getAvailableBloodlinesTier1() {
    let available = getAvailableBloodlines(farmTier: 1)
    #expect(available.count == 2)  // spotted and chocolate
}

@Test func getAvailableBloodlinesTier5() {
    let available = getAvailableBloodlines(farmTier: 5)
    #expect(available.count == 7)  // all bloodlines
}
