/// BreedingProgramTests — Tests for BreedingProgram, heterozygosityCount, breedingValue,
/// and buildDiversityCounters. Split from BreedingBirthTests.swift to stay under 300 lines.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - BreedingProgram.shouldKeepPig

@Test @MainActor func shouldKeepPigWhenProgramDisabled() {
    var program = BreedingProgram()
    program.enabled = false
    program.targetColors = [.golden]
    let pig = GuineaPig.create(name: "Any", gender: .female)
    // Disabled program always keeps, regardless of phenotype
    #expect(program.shouldKeepPig(pig, hasGeneticsLab: false))
}

@Test @MainActor func shouldKeepPigMatchingColorTarget() {
    var program = BreedingProgram()
    program.enabled = true
    program.targetColors = [.black]
    // Default genotype pig is black (EE BB → black phenotype)
    let pig = GuineaPig.create(name: "Black", gender: .female)
    #expect(program.shouldKeepPig(pig, hasGeneticsLab: false))
}

@Test @MainActor func shouldKeepPigNonMatchingColorTargetReturnsFalse() {
    var program = BreedingProgram()
    program.enabled = true
    program.targetColors = [.golden]
    // Default pig is black, not golden
    let pig = GuineaPig.create(name: "Black", gender: .female)
    #expect(!program.shouldKeepPig(pig, hasGeneticsLab: false))
}

@Test @MainActor func shouldKeepPigCarrierRescueWithLabKeepsPig() {
    var program = BreedingProgram()
    program.enabled = true
    program.targetColors = [.golden]
    program.keepCarriers = true

    // E/e pig is phenotypically black but carries the golden 'e' allele
    let genotype = Genotype(
        eLocus: AllelePair(first: "E", second: "e"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
    let pig = GuineaPig.create(
        name: "Carrier", gender: .female, genotype: genotype,
        position: Position(x: 0, y: 0), ageDays: 0,
        motherId: nil, fatherId: nil, motherName: nil, fatherName: nil
    )
    // Carrier rescue requires genetics lab
    #expect(program.shouldKeepPig(pig, hasGeneticsLab: true))
    #expect(!program.shouldKeepPig(pig, hasGeneticsLab: false))
}

@Test @MainActor func shouldKeepPigMultipleAxesUsesAndLogic() {
    var program = BreedingProgram()
    program.enabled = true
    program.targetColors = [.golden]
    program.targetPatterns = [.dutch]
    // Default black/solid pig: fails color AND pattern → should not keep
    let pig = GuineaPig.create(name: "Black", gender: .female)
    #expect(!program.shouldKeepPig(pig, hasGeneticsLab: false))
}

// MARK: - heterozygosityCount

@Test @MainActor func heterozygosityCountAllHomozygous() {
    let genotype = makeProgramHomozygousDominantGenotype()
    #expect(heterozygosityCount(genotype) == 0)
}

@Test @MainActor func heterozygosityCountAllHeterozygous() {
    let genotype = Genotype(
        eLocus: AllelePair(first: "E", second: "e"),
        bLocus: AllelePair(first: "B", second: "b"),
        sLocus: AllelePair(first: "S", second: "s"),
        cLocus: AllelePair(first: "C", second: "ch"),
        rLocus: AllelePair(first: "R", second: "r"),
        dLocus: AllelePair(first: "D", second: "d")
    )
    #expect(heterozygosityCount(genotype) == 6)
}

@Test @MainActor func heterozygosityCountPartialLoci() {
    let genotype = Genotype(
        eLocus: AllelePair(first: "E", second: "e"), // hetero
        bLocus: AllelePair(first: "B", second: "B"), // homo
        sLocus: AllelePair(first: "S", second: "S"), // homo
        cLocus: AllelePair(first: "C", second: "ch"), // hetero
        rLocus: AllelePair(first: "r", second: "r"), // homo
        dLocus: AllelePair(first: "D", second: "d")  // hetero
    )
    #expect(heterozygosityCount(genotype) == 3)
}

// MARK: - buildDiversityCounters

@Test @MainActor func buildDiversityCountersCorrectlyCounts() {
    let pig1 = GuineaPig.create(name: "A", gender: .female)
    let pig2 = GuineaPig.create(name: "B", gender: .male)
    let pig3 = GuineaPig.create(name: "C", gender: .female)
    let pigs = [pig1, pig2, pig3]

    let (phenoCounts, colorCounts) = buildDiversityCounters(pigs: pigs)

    // All pigs have default black phenotype, so black count = 3
    #expect(colorCounts[.black] == 3)
    // All identical → one phenotype key with count 3
    let totalPhenoCount = phenoCounts.values.reduce(0, +)
    #expect(totalPhenoCount == 3)
}

// MARK: - breedingValue

@Test @MainActor func breedingValueWithNoTargetsReturnsAgeBonus() {
    let program = BreedingProgram() // no targets
    let pig = GuineaPig.create(name: "Young", gender: .female) // ageDays = 0
    let value = breedingValue(pig: pig, program: program, hasLab: false)
    // No target contributions; pure age tiebreaker = 5.0 for fresh pig
    #expect(abs(value - 5.0) < 0.01)
}

@Test @MainActor func breedingValueIncreasesWithTargetAllelesPresent() {
    // E/e pig (1 recessive 'e') vs EE pig (0 recessive 'e'), both with .golden target
    let carrierGenotype = Genotype(
        eLocus: AllelePair(first: "E", second: "e"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
    // Use explicit EE genotype so the comparison is deterministic (not randomCommon())
    let baseGenotype = makeProgramHomozygousDominantGenotype()
    let carrierPig = GuineaPig.create(
        name: "Carrier", gender: .female, genotype: carrierGenotype,
        position: Position(x: 0, y: 0), ageDays: 0,
        motherId: nil, fatherId: nil, motherName: nil, fatherName: nil
    )
    let basePig = GuineaPig.create(
        name: "Base", gender: .female, genotype: baseGenotype,
        position: Position(x: 0, y: 0), ageDays: 0,
        motherId: nil, fatherId: nil, motherName: nil, fatherName: nil
    )

    var program = BreedingProgram()
    program.targetColors = [.golden]

    let carrierScore = breedingValue(pig: carrierPig, program: program, hasLab: false)
    let baseScore = breedingValue(pig: basePig, program: program, hasLab: false)

    // Carrier (1 'e' allele) should score higher than base (0 'e' alleles)
    #expect(carrierScore > baseScore)
    #expect(abs(carrierScore - 6.0) < 0.01) // 1.0 (allele) + 5.0 (age tiebreaker)
    #expect(abs(baseScore - 5.0) < 0.01)    // 0.0 (no allele) + 5.0 (age tiebreaker)
}

// MARK: - Test Helpers

private func makeProgramHomozygousDominantGenotype() -> Genotype {
    Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
}
