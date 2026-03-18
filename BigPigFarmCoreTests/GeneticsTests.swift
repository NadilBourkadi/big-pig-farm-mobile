/// GeneticsTests -- Tests for phenotype calculation, rarity scoring, and allele helpers.
/// Covers: calculatePhenotype, calculateRarity, displayName, AllelePair methods.
import Testing

@testable import BigPigFarmCore

// MARK: - Phenotype From Genotype

@Test func testPhenotypeBlackFromEEBB() {
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
}

@Test func testPhenotypeChocolateFromEEbb() {
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

@Test func testPhenotypeGoldenFromeeBB() {
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

@Test func testPhenotypeCreamFromeebb() {
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

@Test func testPhenotypeDilutedColors() {
    // Blue = E_ B_ dd
    let blue = Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "d", second: "d")
    )
    #expect(calculatePhenotype(blue).baseColor == .blue)

    // Lilac = E_ bb dd
    let lilac = Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "b", second: "b"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "d", second: "d")
    )
    #expect(calculatePhenotype(lilac).baseColor == .lilac)

    // Saffron = ee B_ dd
    let saffron = Genotype(
        eLocus: AllelePair(first: "e", second: "e"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "d", second: "d")
    )
    #expect(calculatePhenotype(saffron).baseColor == .saffron)

    // Smoke = ee bb dd
    let smoke = Genotype(
        eLocus: AllelePair(first: "e", second: "e"),
        bLocus: AllelePair(first: "b", second: "b"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "d", second: "d")
    )
    #expect(calculatePhenotype(smoke).baseColor == .smoke)
}

// MARK: - Pattern From S Locus

@Test func testPatternFromSLocus() {
    var genotype = makeBaseGenotype()

    // SS = solid
    genotype.sLocus = AllelePair(first: "S", second: "S")
    #expect(calculatePhenotype(genotype).pattern == .solid)

    // Ss = dutch
    genotype.sLocus = AllelePair(first: "S", second: "s")
    #expect(calculatePhenotype(genotype).pattern == .dutch)

    // ss = dalmatian
    genotype.sLocus = AllelePair(first: "s", second: "s")
    #expect(calculatePhenotype(genotype).pattern == .dalmatian)
}

// MARK: - Intensity From C Locus

@Test func testIntensityFromCLocus() {
    var genotype = makeBaseGenotype()

    // CC = full
    genotype.cLocus = AllelePair(first: "C", second: "C")
    #expect(calculatePhenotype(genotype).intensity == .full)

    // C/ch = chinchilla
    genotype.cLocus = AllelePair(first: "C", second: "ch")
    #expect(calculatePhenotype(genotype).intensity == .chinchilla)

    // ch/ch = himalayan
    genotype.cLocus = AllelePair(first: "ch", second: "ch")
    #expect(calculatePhenotype(genotype).intensity == .himalayan)
}

// MARK: - Roan From R Locus

@Test func testRoanFromRLocus() {
    var genotype = makeBaseGenotype()

    // rr = none
    genotype.rLocus = AllelePair(first: "r", second: "r")
    #expect(calculatePhenotype(genotype).roan == .none)

    // Rr = roan
    genotype.rLocus = AllelePair(first: "R", second: "r")
    #expect(calculatePhenotype(genotype).roan == .roan)
}

// MARK: - Rarity Calculation

@Test func testRarityCalculation() {
    // Solid black = 0 points = common
    #expect(calculateRarity(baseColor: .black, pattern: .solid, intensity: .full, roan: .none) == .common)

    // Chocolate = 1 point = uncommon
    #expect(calculateRarity(baseColor: .chocolate, pattern: .solid, intensity: .full, roan: .none) == .uncommon)

    // Dutch = 1 point = uncommon
    #expect(calculateRarity(baseColor: .black, pattern: .dutch, intensity: .full, roan: .none) == .uncommon)

    // Blue = 2 points = rare
    #expect(calculateRarity(baseColor: .blue, pattern: .solid, intensity: .full, roan: .none) == .rare)

    // Dalmatian = 2 points = rare
    #expect(calculateRarity(baseColor: .black, pattern: .dalmatian, intensity: .full, roan: .none) == .rare)

    // Chinchilla (2) + roan (2) = 4 points = very rare
    #expect(calculateRarity(baseColor: .black, pattern: .solid, intensity: .chinchilla, roan: .roan) == .veryRare)

    // Smoke (4) + dalmatian (2) = 6 points = legendary
    #expect(calculateRarity(baseColor: .smoke, pattern: .dalmatian, intensity: .full, roan: .none) == .legendary)

    // Himalayan (3) + lilac (3) = 6 points = legendary
    #expect(calculateRarity(baseColor: .lilac, pattern: .solid, intensity: .himalayan, roan: .none) == .legendary)
}

// MARK: - Display Name

@Test func testPhenotypeDisplayName() {
    let solidBlack = Phenotype(
        baseColor: .black, pattern: .solid, intensity: .full, roan: .none, rarity: .common
    )
    #expect(solidBlack.displayName == "Black")

    let roanDutchChocolate = Phenotype(
        baseColor: .chocolate, pattern: .dutch, intensity: .full, roan: .roan, rarity: .rare
    )
    #expect(roanDutchChocolate.displayName == "Roan Dutch Chocolate")

    let chinchillaDalmatianBlue = Phenotype(
        baseColor: .blue, pattern: .dalmatian, intensity: .chinchilla, roan: .none, rarity: .legendary
    )
    #expect(chinchillaDalmatianBlue.displayName == "Chinchilla Dalmatian Blue")

    let roanHimalayanSmoke = Phenotype(
        baseColor: .smoke, pattern: .solid, intensity: .himalayan, roan: .roan, rarity: .legendary
    )
    #expect(roanHimalayanSmoke.displayName == "Roan Himalayan Smoke")
}

// MARK: - AllelePair Helpers

@Test func testAllelePairContains() {
    let pair = AllelePair(first: "E", second: "e")
    #expect(pair.contains("E"))
    #expect(pair.contains("e"))
    #expect(!pair.contains("B"))
}

@Test func testAllelePairCount() {
    let homozygous = AllelePair(first: "E", second: "E")
    #expect(homozygous.count("E") == 2)
    #expect(homozygous.count("e") == 0)

    let heterozygous = AllelePair(first: "E", second: "e")
    #expect(heterozygous.count("E") == 1)
    #expect(heterozygous.count("e") == 1)
}

@Test func testAllelePairIsHomozygous() {
    let homozygous = AllelePair(first: "E", second: "E")
    #expect(homozygous.isHomozygous("E"))
    #expect(!homozygous.isHomozygous("e"))

    let heterozygous = AllelePair(first: "E", second: "e")
    #expect(!heterozygous.isHomozygous("E"))
    #expect(!heterozygous.isHomozygous("e"))
}

@Test func testAllelePairHasDominant() {
    let pair = AllelePair(first: "E", second: "e")
    #expect(pair.hasDominant("E"))
    #expect(!AllelePair(first: "e", second: "e").hasDominant("E"))
}

// MARK: - Test Helpers

/// Create a simple homozygous dominant genotype for testing.
private func makeBaseGenotype() -> Genotype {
    Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
}
