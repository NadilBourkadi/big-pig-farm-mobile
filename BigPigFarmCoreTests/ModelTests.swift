/// ModelTests -- Tests for value-type models (GridPosition, AllelePair, Genotype, Position, Needs).
/// Phenotype calculation, rarity, and display name tests are in ModelPhenotypeTests.swift.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - GridPosition Tests

@Test func gridPositionManhattanDistance() {
    let origin = GridPosition(x: 0, y: 0)
    let target = GridPosition(x: 3, y: 4)
    #expect(origin.manhattanDistance(to: target) == 7)
}

@Test func gridPositionManhattanDistanceSymmetric() {
    let pos1 = GridPosition(x: 1, y: 2)
    let pos2 = GridPosition(x: 5, y: 8)
    #expect(pos1.manhattanDistance(to: pos2) == pos2.manhattanDistance(to: pos1))
}

@Test func gridPositionEquality() {
    let pos1 = GridPosition(x: 5, y: 10)
    let pos2 = GridPosition(x: 5, y: 10)
    #expect(pos1 == pos2)
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
    let origin = Position(x: 0, y: 0)
    let target = Position(x: 3, y: 4)
    #expect(abs(origin.distanceTo(target) - 5.0) < 0.001)
}

@Test func positionDistanceToSelf() {
    let pos = Position(x: 5, y: 10)
    #expect(pos.distanceTo(pos) == 0.0)
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
    let json = try #require(String(data: data, encoding: .utf8))
    #expect(json.contains("e_locus"))
    #expect(json.contains("b_locus"))
    #expect(json.contains("d_locus"))
}
