/// BreedingBirthTests — Tests for Breeding, Birth, and BreedingProgram systems.
/// Covers: clearCourtship, startPregnancy, advancePregnancies, checkBirths,
/// ageAllPigs, shouldKeepPig, breedingValue, heterozygosityCount.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Breeding.clearCourtship

@Test func clearCourtshipResetsAllFields() {
    var pig = GuineaPig.create(name: "Pig", gender: .female)
    pig.behaviorState = .courting
    pig.courtingPartnerId = UUID()
    pig.courtingInitiator = true
    pig.courtingTimer = 5.0
    pig.targetDescription = "courting Bob"

    Breeding.clearCourtship(pig: &pig)

    #expect(pig.courtingPartnerId == nil)
    #expect(!pig.courtingInitiator)
    #expect(pig.courtingTimer == 0.0)
    #expect(pig.behaviorState == .idle)
    #expect(pig.targetDescription == nil)
}

@Test func clearCourtshipPreservesNonCourtingBehaviorState() {
    var pig = GuineaPig.create(name: "Pig", gender: .female)
    pig.behaviorState = .wandering
    pig.courtingPartnerId = UUID()

    Breeding.clearCourtship(pig: &pig)

    // Non-courting state should be preserved
    #expect(pig.behaviorState == .wandering)
}

// MARK: - Breeding.startPregnancyFromCourtship

@Test @MainActor func startPregnancySetsFemalePregantAndStoresGenotype() {
    let state = GameState()
    var male = GuineaPig.create(name: "Bob", gender: .male)
    var female = GuineaPig.create(name: "Alice", gender: .female)

    Breeding.startPregnancyFromCourtship(male: &male, female: &female, gameState: state)

    #expect(female.isPregnant)
    #expect(female.pregnancyDays == 0.0)
    #expect(female.partnerId == male.id)
    #expect(female.partnerGenotype != nil)
    #expect(female.partnerName == male.name)
}

@Test @MainActor func startPregnancyClearsCourtshipOnBothPigs() {
    let state = GameState()
    var male = GuineaPig.create(name: "Bob", gender: .male)
    var female = GuineaPig.create(name: "Alice", gender: .female)
    male.behaviorState = .courting
    male.courtingPartnerId = female.id
    female.behaviorState = .courting
    female.courtingPartnerId = male.id

    Breeding.startPregnancyFromCourtship(male: &male, female: &female, gameState: state)

    #expect(male.behaviorState == .idle)
    #expect(female.behaviorState == .idle)
    #expect(male.courtingPartnerId == nil)
    #expect(female.courtingPartnerId == nil)
}

// MARK: - Birth.advancePregnancies

@Test @MainActor func advancePregnanciesIncreasesPregnancyDays() {
    let state = GameState()
    var pig = GuineaPig.create(name: "Mama", gender: .female)
    pig.isPregnant = true
    pig.pregnancyDays = 0.0
    state.addGuineaPig(pig)

    Birth.advancePregnancies(gameState: state, gameHours: 24.0)

    let updated = state.getGuineaPig(pig.id)!
    #expect(updated.pregnancyDays == 1.0)
}

@Test @MainActor func advancePregnanciesSkipsNonPregnantPigs() {
    let state = GameState()
    var pig = GuineaPig.create(name: "NotPregnant", gender: .female)
    pig.isPregnant = false
    pig.pregnancyDays = 0.0
    state.addGuineaPig(pig)

    Birth.advancePregnancies(gameState: state, gameHours: 24.0)

    let updated = state.getGuineaPig(pig.id)!
    #expect(updated.pregnancyDays == 0.0)
}

@Test @MainActor func speedBreedingPerkAcceleratesPregnancy() {
    let state = GameState()
    state.purchasedUpgrades.insert("speed_breeding")
    var pig = GuineaPig.create(name: "Mama", gender: .female)
    pig.isPregnant = true
    pig.pregnancyDays = 0.0
    state.addGuineaPig(pig)

    Birth.advancePregnancies(gameState: state, gameHours: 24.0)

    let updated = state.getGuineaPig(pig.id)!
    // With speed_breeding: 1 game day * 1.333 = 1.333 days
    #expect(abs(updated.pregnancyDays - 1.333) < 0.001)
}

// MARK: - Birth.checkBirths

@Test @MainActor func checkBirthsAtThresholdProducesBabies() throws {
    let state = makeGameState(withArea: true)
    let fatherGenotype = makeHomozygousDominantGenotype()
    var mother = GuineaPig.create(name: "Mama", gender: .female)
    mother.position = Position(x: 5.0, y: 5.0)
    mother.isPregnant = true
    mother.pregnancyDays = Double(GameConfig.Breeding.gestationDays) + 1.0
    mother.partnerGenotype = fatherGenotype
    mother.partnerName = "Papa"
    state.addGuineaPig(mother)

    let births = Birth.checkBirths(gameState: state)

    #expect(births == 1)
    #expect(state.pigCount > 1)
}

@Test @MainActor func checkBirthsBelowThresholdProducesNoBabies() {
    let state = makeGameState(withArea: true)
    var mother = GuineaPig.create(name: "Mama", gender: .female)
    mother.isPregnant = true
    mother.pregnancyDays = Double(GameConfig.Breeding.gestationDays) - 1.0
    mother.partnerGenotype = makeHomozygousDominantGenotype()
    state.addGuineaPig(mother)

    let births = Birth.checkBirths(gameState: state)

    #expect(births == 0)
    // Mother is still pregnant
    let updated = state.getGuineaPig(mother.id)!
    #expect(updated.isPregnant)
}

@Test @MainActor func checkBirthsResetsMotherAfterBirth() throws {
    let state = makeGameState(withArea: true)
    var mother = GuineaPig.create(name: "Mama", gender: .female)
    mother.position = Position(x: 5.0, y: 5.0)
    mother.isPregnant = true
    mother.pregnancyDays = Double(GameConfig.Breeding.gestationDays) + 1.0
    mother.partnerGenotype = makeHomozygousDominantGenotype()
    mother.partnerName = "Papa"
    let fatherId = UUID()
    mother.partnerId = fatherId
    state.addGuineaPig(mother)

    _ = Birth.checkBirths(gameState: state)

    let updated = try #require(state.getGuineaPig(mother.id))
    #expect(!updated.isPregnant)
    #expect(updated.pregnancyDays == 0.0)
    #expect(updated.partnerId == nil)
    #expect(updated.partnerGenotype == nil)
}

@Test @MainActor func checkBirthsBabyHasCorrectParentIds() throws {
    let state = makeGameState(withArea: true)
    var male = GuineaPig.create(name: "Papa", gender: .male)
    let fatherId = male.id
    state.addGuineaPig(male)

    var mother = GuineaPig.create(name: "Mama", gender: .female)
    mother.position = Position(x: 5.0, y: 5.0)
    mother.isPregnant = true
    mother.pregnancyDays = Double(GameConfig.Breeding.gestationDays) + 1.0
    mother.partnerId = fatherId
    mother.partnerGenotype = male.genotype
    mother.partnerName = male.name
    state.addGuineaPig(mother)

    _ = Birth.checkBirths(gameState: state)

    let babies = state.getPigsList().filter { $0.id != mother.id && $0.id != fatherId }
    #expect(!babies.isEmpty)
    for baby in babies {
        #expect(baby.motherId == mother.id)
        #expect(baby.fatherId == fatherId)
    }
}

@Test @MainActor func checkBirthsWorksWhenFatherHasBeenSold() throws {
    // Father's genotype is snapshotted at conception; birth works even if father is removed
    let state = makeGameState(withArea: true)
    var male = GuineaPig.create(name: "Papa", gender: .male)
    state.addGuineaPig(male)

    var mother = GuineaPig.create(name: "Mama", gender: .female)
    mother.position = Position(x: 5.0, y: 5.0)
    mother.isPregnant = true
    mother.pregnancyDays = Double(GameConfig.Breeding.gestationDays) + 1.0
    mother.partnerId = male.id
    mother.partnerGenotype = male.genotype // snapshot stored at conception
    mother.partnerName = male.name
    state.addGuineaPig(mother)

    // Sell/remove the father before birth
    _ = state.removeGuineaPig(male.id)
    #expect(state.getGuineaPig(male.id) == nil)

    let births = Birth.checkBirths(gameState: state)

    // Birth should still succeed via stored partnerGenotype
    #expect(births == 1)
}

@Test @MainActor func checkBirthsCancelsPregnancyWhenNoFatherGenotype() throws {
    let state = makeGameState(withArea: true)
    var mother = GuineaPig.create(name: "Mama", gender: .female)
    mother.isPregnant = true
    mother.pregnancyDays = Double(GameConfig.Breeding.gestationDays) + 1.0
    // No partnerId, no partnerGenotype
    state.addGuineaPig(mother)

    let births = Birth.checkBirths(gameState: state)

    #expect(births == 0)
    let updated = try #require(state.getGuineaPig(mother.id))
    #expect(!updated.isPregnant)
}

// MARK: - Birth.ageAllPigs

@Test @MainActor func ageAllPigsIncreasesAge() throws {
    let state = GameState()
    var pig = GuineaPig.create(name: "Test", gender: .female)
    pig.ageDays = 10.0
    state.addGuineaPig(pig)

    _ = Birth.ageAllPigs(gameState: state, gameHours: 24.0)

    let updated = try #require(state.getGuineaPig(pig.id))
    #expect(updated.ageDays == 11.0)
}

@Test @MainActor func ageAllPigsDoesNotKillYoungPigs() {
    let state = GameState()
    var pig = GuineaPig.create(name: "Young", gender: .female)
    pig.ageDays = 1.0 // well below max age
    state.addGuineaPig(pig)

    let deaths = Birth.ageAllPigs(gameState: state, gameHours: 24.0)

    // Young pigs cannot die of old age
    #expect(deaths.isEmpty)
}

// MARK: - BreedingProgram.shouldKeepPig

@Test func shouldKeepPigWhenProgramDisabled() {
    var program = BreedingProgram()
    program.enabled = false
    program.targetColors = [.golden]
    let pig = GuineaPig.create(name: "Any", gender: .female)
    // Disabled program always keeps, regardless of phenotype
    #expect(program.shouldKeepPig(pig, hasGeneticsLab: false))
}

@Test func shouldKeepPigMatchingColorTarget() {
    var program = BreedingProgram()
    program.enabled = true
    program.targetColors = [.black]
    // Default genotype pig is black (EE BB → black phenotype)
    let pig = GuineaPig.create(name: "Black", gender: .female)
    #expect(program.shouldKeepPig(pig, hasGeneticsLab: false))
}

@Test func shouldKeepPigNonMatchingColorTargetReturnsFalse() {
    var program = BreedingProgram()
    program.enabled = true
    program.targetColors = [.golden]
    // Default pig is black, not golden
    let pig = GuineaPig.create(name: "Black", gender: .female)
    #expect(!program.shouldKeepPig(pig, hasGeneticsLab: false))
}

@Test func shouldKeepPigCarrierRescueWithLabKeepsPig() {
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

@Test func shouldKeepPigMultipleAxesUsesAndLogic() {
    var program = BreedingProgram()
    program.enabled = true
    program.targetColors = [.golden]
    program.targetPatterns = [.dutch]
    // Default black/solid pig: fails color AND pattern → should not keep
    let pig = GuineaPig.create(name: "Black", gender: .female)
    #expect(!program.shouldKeepPig(pig, hasGeneticsLab: false))
}

// MARK: - heterozygosityCount

@Test func heterozygosityCountAllHomozygous() {
    let genotype = makeHomozygousDominantGenotype()
    #expect(heterozygosityCount(genotype) == 0)
}

@Test func heterozygosityCountAllHeterozygous() {
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

@Test func heterozygosityCountPartialLoci() {
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

@Test func buildDiversityCountersCorrectlyCounts() {
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

@Test func breedingValueWithNoTargetsReturnsAgeBonus() {
    let program = BreedingProgram() // no targets
    let pig = GuineaPig.create(name: "Young", gender: .female) // ageDays = 0
    let value = breedingValue(pig: pig, program: program, hasLab: false)
    // No target contributions; pure age tiebreaker = 5.0 for fresh pig
    #expect(abs(value - 5.0) < 0.01)
}

@Test func breedingValueIncreasesWithTargetAllelesPresent() {
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
    let baseGenotype = makeHomozygousDominantGenotype()
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

private func makeHomozygousDominantGenotype() -> Genotype {
    Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
}
