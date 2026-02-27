/// ModelTests -- Tests for value-type models (GridPosition, AllelePair, Genotype, Phenotype).
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
