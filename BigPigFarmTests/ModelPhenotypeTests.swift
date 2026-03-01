/// ModelPhenotypeTests -- Phenotype calculation, rarity, and display name tests.
/// Continuation of ModelTests.swift (split for file length limit).
import Testing
import Foundation
@testable import BigPigFarm

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
