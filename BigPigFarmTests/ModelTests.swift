/// ModelTests -- Tests for all model structs ported from Python Pydantic models.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - GridPosition Tests

@Test func gridPositionManhattanDistance() {
    let a = GridPosition(x: 0, y: 0)
    let b = GridPosition(x: 3, y: 4)
    #expect(a.manhattanDistance(to: b) == 7)
}

@Test func gridPositionManhattanDistanceSymmetric() {
    let a = GridPosition(x: 1, y: 2)
    let b = GridPosition(x: 5, y: 8)
    #expect(a.manhattanDistance(to: b) == b.manhattanDistance(to: a))
}

@Test func gridPositionEquality() {
    let a = GridPosition(x: 5, y: 10)
    let b = GridPosition(x: 5, y: 10)
    #expect(a == b)
}

@Test func gridPositionCodable() throws {
    let position = GridPosition(x: 42, y: 17)
    let data = try JSONEncoder().encode(position)
    let decoded = try JSONDecoder().decode(GridPosition.self, from: data)
    #expect(decoded == position)
}

// MARK: - AllelePair Tests

@Test func allelePairContains() {
    let pair = AllelePair(first: "E", second: "e")
    #expect(pair.contains("E"))
    #expect(pair.contains("e"))
    #expect(!pair.contains("B"))
}

@Test func allelePairCount() {
    let heterozygous = AllelePair(first: "E", second: "e")
    #expect(heterozygous.count("E") == 1)
    #expect(heterozygous.count("e") == 1)

    let homozygous = AllelePair(first: "E", second: "E")
    #expect(homozygous.count("E") == 2)
    #expect(homozygous.count("e") == 0)
}

@Test func allelePairIsHomozygous() {
    let homo = AllelePair(first: "S", second: "S")
    #expect(homo.isHomozygous("S"))
    #expect(!homo.isHomozygous("s"))

    let hetero = AllelePair(first: "S", second: "s")
    #expect(!hetero.isHomozygous("S"))
    #expect(!hetero.isHomozygous("s"))
}

@Test func allelePairHasDominant() {
    let pair = AllelePair(first: "R", second: "r")
    #expect(pair.hasDominant("R"))
    #expect(!AllelePair(first: "r", second: "r").hasDominant("R"))
}

@Test func allelePairCodable() throws {
    let pair = AllelePair(first: "C", second: "ch")
    let data = try JSONEncoder().encode(pair)
    let decoded = try JSONDecoder().decode(AllelePair.self, from: data)
    #expect(decoded == pair)
}

// MARK: - Position Tests

@Test func positionDistanceTo() {
    let a = Position(x: 0, y: 0)
    let b = Position(x: 3, y: 4)
    #expect(abs(a.distanceTo(b) - 5.0) < 0.001)
}

@Test func positionDistanceToSelf() {
    let a = Position(x: 5, y: 10)
    #expect(a.distanceTo(a) == 0.0)
}

@Test func positionGridPosition() {
    let pos = Position(x: 3.7, y: 8.2)
    #expect(pos.gridPosition == GridPosition(x: 3, y: 8))
}

@Test func positionDefaultValues() {
    let pos = Position()
    #expect(pos.x == 0.0)
    #expect(pos.y == 0.0)
}

// MARK: - Needs Tests

@Test func needsDefaultValues() {
    let needs = Needs()
    #expect(needs.hunger == 100.0)
    #expect(needs.thirst == 100.0)
    #expect(needs.energy == 100.0)
    #expect(needs.happiness == 75.0)
    #expect(needs.health == 100.0)
    #expect(needs.social == 50.0)
    #expect(needs.boredom == 0.0)
}

@Test func needsClampingUpperBound() {
    var needs = Needs()
    needs.hunger = 150.0
    needs.thirst = 200.0
    needs.clampAll()
    #expect(needs.hunger == 100.0)
    #expect(needs.thirst == 100.0)
}

@Test func needsClampingLowerBound() {
    var needs = Needs()
    needs.hunger = -10.0
    needs.happiness = -5.0
    needs.clampAll()
    #expect(needs.hunger == 0.0)
    #expect(needs.happiness == 0.0)
}

// MARK: - Genotype Tests

@Test func genotypeRandomCommonProducesCommon() {
    // Run multiple times to verify randomCommon produces common phenotypes
    for _ in 0..<20 {
        let genotype = Genotype.randomCommon()
        let phenotype = calculatePhenotype(genotype)
        // Common genotypes should be solid, full, no roan
        #expect(phenotype.pattern == .solid)
        #expect(phenotype.intensity == .full)
        #expect(phenotype.roan == .none)
    }
}

@Test func genotypeCodingKeysSnakeCase() throws {
    let genotype = Genotype(
        eLocus: AllelePair(first: "E", second: "e"),
        bLocus: AllelePair(first: "B", second: "b"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
    let data = try JSONEncoder().encode(genotype)
    let json = String(data: data, encoding: .utf8)!
    #expect(json.contains("e_locus"))
    #expect(json.contains("b_locus"))
    #expect(json.contains("d_locus"))
}

// MARK: - Phenotype Calculation Tests

@Test func phenotypeBlackFromEEBBDD() {
    let genotype = Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
    let phenotype = calculatePhenotype(genotype)
    #expect(phenotype.baseColor == .black)
    #expect(phenotype.pattern == .solid)
    #expect(phenotype.intensity == .full)
    #expect(phenotype.roan == .none)
    #expect(phenotype.rarity == .common)
}

@Test func phenotypeChocolateFromEbbDD() {
    let genotype = Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "b", second: "b"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
    let phenotype = calculatePhenotype(genotype)
    #expect(phenotype.baseColor == .chocolate)
}

@Test func phenotypeGoldenFromeeBBDD() {
    let genotype = Genotype(
        eLocus: AllelePair(first: "e", second: "e"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
    let phenotype = calculatePhenotype(genotype)
    #expect(phenotype.baseColor == .golden)
}

@Test func phenotypeCreamFromeebbDD() {
    let genotype = Genotype(
        eLocus: AllelePair(first: "e", second: "e"),
        bLocus: AllelePair(first: "b", second: "b"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
    let phenotype = calculatePhenotype(genotype)
    #expect(phenotype.baseColor == .cream)
}

@Test func phenotypeBlueFromEEBBdd() {
    let genotype = Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "d", second: "d")
    )
    let phenotype = calculatePhenotype(genotype)
    #expect(phenotype.baseColor == .blue)
}

@Test func phenotypeSmokeFromeebbdd() {
    let genotype = Genotype(
        eLocus: AllelePair(first: "e", second: "e"),
        bLocus: AllelePair(first: "b", second: "b"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "d", second: "d")
    )
    let phenotype = calculatePhenotype(genotype)
    #expect(phenotype.baseColor == .smoke)
}

@Test func patternSolidFromSS() {
    let genotype = Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
    #expect(calculatePhenotype(genotype).pattern == .solid)
}

@Test func patternDutchFromSs() {
    let genotype = Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "s"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
    #expect(calculatePhenotype(genotype).pattern == .dutch)
}

@Test func patternDalmatianFromss() {
    let genotype = Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "s", second: "s"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
    #expect(calculatePhenotype(genotype).pattern == .dalmatian)
}

@Test func intensityFullFromCC() {
    let genotype = Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
    #expect(calculatePhenotype(genotype).intensity == .full)
}

@Test func intensityChinchillaFromCch() {
    let genotype = Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "ch"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
    #expect(calculatePhenotype(genotype).intensity == .chinchilla)
}

@Test func intensityHimalayanFromchch() {
    let genotype = Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "ch", second: "ch"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
    #expect(calculatePhenotype(genotype).intensity == .himalayan)
}

@Test func roanFromRr() {
    let genotype = Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "R", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
    #expect(calculatePhenotype(genotype).roan == .roan)
}

@Test func noRoanFromrr() {
    let genotype = Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
    #expect(calculatePhenotype(genotype).roan == .none)
}

// MARK: - Rarity Tests

@Test func rarityCommonSolidBlack() {
    let rarity = calculateRarity(
        baseColor: .black, pattern: .solid,
        intensity: .full, roan: .none
    )
    #expect(rarity == .common)
}

@Test func rarityUncommonChocolate() {
    let rarity = calculateRarity(
        baseColor: .chocolate, pattern: .solid,
        intensity: .full, roan: .none
    )
    #expect(rarity == .uncommon)
}

@Test func rarityRareDalmatian() {
    let rarity = calculateRarity(
        baseColor: .black, pattern: .dalmatian,
        intensity: .full, roan: .none
    )
    #expect(rarity == .rare)
}

@Test func rarityLegendaryFull() {
    // Roan (2) + Himalayan (3) + Dutch (1) = 6 -> legendary
    let rarity = calculateRarity(
        baseColor: .black, pattern: .dutch,
        intensity: .himalayan, roan: .roan
    )
    #expect(rarity == .legendary)
}

// MARK: - Phenotype Display Name Tests

@Test func phenotypeDisplayNameSolidBlack() {
    let phenotype = Phenotype(
        baseColor: .black, pattern: .solid,
        intensity: .full, roan: .none, rarity: .common
    )
    #expect(phenotype.displayName == "Black")
}

@Test func phenotypeDisplayNameRoanChinchillaDutchChocolate() {
    let phenotype = Phenotype(
        baseColor: .chocolate, pattern: .dutch,
        intensity: .chinchilla, roan: .roan, rarity: .legendary
    )
    #expect(phenotype.displayName == "Roan Chinchilla Dutch Chocolate")
}

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

@Test func bloodlineApplyToGenotype() {
    let base = Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
    let spotted = bloodlines[.spotted]!
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

// MARK: - Pigdex Tests

@Test func pigdexRegisterNew() {
    var pigdex = Pigdex()
    let isNew = pigdex.registerPhenotype(key: "black:solid:full:none", gameDay: 1)
    #expect(isNew)
    #expect(pigdex.discoveredCount == 1)
}

@Test func pigdexRegisterDuplicate() {
    var pigdex = Pigdex()
    _ = pigdex.registerPhenotype(key: "black:solid:full:none", gameDay: 1)
    let isNew = pigdex.registerPhenotype(key: "black:solid:full:none", gameDay: 2)
    #expect(!isNew)
    #expect(pigdex.discoveredCount == 1)
}

@Test func pigdexMilestones() {
    var pigdex = Pigdex()
    // Register 36 phenotypes (25% of 144)
    for i in 0..<36 {
        _ = pigdex.registerPhenotype(key: "key_\(i)", gameDay: 1)
    }
    let milestones = pigdex.checkMilestones()
    #expect(milestones.contains(25))
}

@Test func pigdexCompletionPercent() {
    var pigdex = Pigdex()
    _ = pigdex.registerPhenotype(key: "test", gameDay: 1)
    let expected = (1.0 / 144.0) * 100
    #expect(abs(pigdex.completionPercent - expected) < 0.01)
}

@Test func phenotypeKeyRoundTrip() {
    let phenotype = Phenotype(
        baseColor: .chocolate, pattern: .dutch,
        intensity: .chinchilla, roan: .roan, rarity: .legendary
    )
    let key = phenotypeKey(phenotype)
    #expect(key == "chocolate:dutch:chinchilla:roan")
}

@Test func getAllPhenotypeKeysCount() {
    let keys = getAllPhenotypeKeys()
    #expect(keys.count == 144)
}

// MARK: - Cell Tests

@Test func cellDefaultValues() {
    let cell = Cell()
    #expect(cell.cellType == .floor)
    #expect(cell.facilityId == nil)
    #expect(cell.isWalkable)
    #expect(!cell.isTunnel)
    #expect(!cell.isCorner)
}

@Test func cellCodable() throws {
    let cell = Cell(cellType: .wall, isWalkable: false, isCorner: true)
    let data = try JSONEncoder().encode(cell)
    let decoded = try JSONDecoder().decode(Cell.self, from: data)
    #expect(decoded.cellType == .wall)
    #expect(!decoded.isWalkable)
    #expect(decoded.isCorner)
}

// MARK: - GameTime Tests

@Test func gameTimeAdvance() {
    var time = GameTime()
    time.advance(minutes: 90)
    #expect(time.hour == 9)    // 8 + 1
    #expect(time.minute == 30) // 0 + 30
}

@Test func gameTimeAdvanceNewDay() {
    var time = GameTime(day: 1, hour: 23, minute: 30)
    time.advance(minutes: 60)
    #expect(time.day == 2)
    #expect(time.hour == 0)
    #expect(time.minute == 30)
}

@Test func gameTimeIsDaytime() {
    let morning = GameTime(hour: 8)
    #expect(morning.isDaytime)

    let night = GameTime(hour: 22)
    #expect(!night.isDaytime)
}

@Test func gameTimeDisplayTime() {
    let time = GameTime(day: 3, hour: 14, minute: 5)
    #expect(time.displayTime == "Day 3 14:05")
}

// MARK: - Currency Tests

@Test func currencyFormatMoney() {
    #expect(Currency.formatMoney(500) == "500")
    #expect(Currency.formatMoney(1500) == "1.5K")
    #expect(Currency.formatMoney(2500000) == "2.5M")
}

@Test func currencyFormatCurrency() {
    #expect(Currency.formatCurrency(1500) == "Sq1.5K")
}

// MARK: - BreedingProgram Tests

@Test func breedingProgramHasTarget() {
    var program = BreedingProgram()
    #expect(!program.hasTarget)
    program.targetColors.insert(.black)
    #expect(program.hasTarget)
}

@Test func breedingProgramShouldAutoPair() {
    var program = BreedingProgram()
    #expect(!program.shouldAutoPair())
    program.enabled = true
    program.autoPair = true
    #expect(program.shouldAutoPair())
}

@Test func breedingProgramCodable() throws {
    var program = BreedingProgram()
    program.targetColors = [.black, .chocolate]
    program.strategy = .diversity
    program.enabled = true
    let data = try JSONEncoder().encode(program)
    let decoded = try JSONDecoder().decode(BreedingProgram.self, from: data)
    #expect(decoded.targetColors == [.black, .chocolate])
    #expect(decoded.strategy == .diversity)
    #expect(decoded.enabled)
}

// MARK: - ContractBoard Tests

@Test func contractBoardRemoveFulfilled() {
    var board = ContractBoard()
    board.activeContracts = [
        BreedingContract(requiredColor: .black, fulfilled: true),
        BreedingContract(requiredColor: .golden, fulfilled: false),
    ]
    board.removeFulfilled()
    #expect(board.activeContracts.count == 1)
    #expect(board.activeContracts[0].requiredColor == .golden)
}

@Test func contractBoardCheckExpiry() {
    var board = ContractBoard()
    board.activeContracts = [
        BreedingContract(requiredColor: .black, deadlineDay: 5),
        BreedingContract(requiredColor: .golden, deadlineDay: 20),
    ]
    let expired = board.checkExpiry(gameDay: 10)
    #expect(expired.count == 1)
    #expect(board.activeContracts.count == 1)
}

@Test func contractBoardNeedsRefresh() {
    let board = ContractBoard(lastRefreshDay: 1)
    #expect(board.needsRefresh(gameDay: 15))
    #expect(!board.needsRefresh(gameDay: 5))
}

// MARK: - TunnelConnection Tests

@Test func tunnelConnectionCodable() throws {
    let tunnel = TunnelConnection(
        id: UUID(),
        areaAId: UUID(),
        areaBId: UUID(),
        cells: [GridPosition(x: 5, y: 10), GridPosition(x: 6, y: 10)]
    )
    let data = try JSONEncoder().encode(tunnel)
    let decoded = try JSONDecoder().decode(TunnelConnection.self, from: data)
    #expect(decoded.id == tunnel.id)
    #expect(decoded.cells.count == 2)
}

// MARK: - Sendable Conformance

@Test func allStructsAreSendable() {
    // Compile-time verification of Sendable conformance
    let _: any Sendable = AllelePair(first: "E", second: "e")
    let _: any Sendable = GridPosition(x: 0, y: 0)
    let _: any Sendable = Position()
    let _: any Sendable = Needs()
    let _: any Sendable = Genotype.randomCommon()
    let _: any Sendable = Phenotype(baseColor: .black, pattern: .solid, intensity: .full, roan: .none, rarity: .common)
    let _: any Sendable = FacilitySize(width: 1, height: 1)
    let _: any Sendable = Facility.create(type: .foodBowl, x: 0, y: 0)
    let _: any Sendable = FarmArea(id: UUID(), name: "Test", biome: .meadow, x1: 0, y1: 0, x2: 10, y2: 10)
    let _: any Sendable = TunnelConnection(id: UUID(), areaAId: UUID(), areaBId: UUID())
    let _: any Sendable = Pigdex()
    let _: any Sendable = GameTime()
    let _: any Sendable = EventLog(timestamp: Date(), gameDay: 1, message: "Test", eventType: "info")
    let _: any Sendable = BreedingPair(maleId: UUID(), femaleId: UUID())
    let _: any Sendable = Cell()
    let _: any Sendable = BreedingContract()
    let _: any Sendable = ContractBoard()
    let _: any Sendable = BreedingProgram()
    let _: any Sendable = SaleResult(baseValue: 100, contractBonus: 0, matchedContract: nil)
}
