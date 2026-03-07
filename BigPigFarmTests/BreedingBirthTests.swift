/// BreedingBirthTests — Tests for Breeding and Birth systems.
/// Covers: clearCourtship, startPregnancy, advancePregnancies, checkBirths, ageAllPigs.
/// BreedingProgram tests are in BreedingProgramTests.swift.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Breeding.clearCourtship

@Test @MainActor func clearCourtshipResetsAllFields() {
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

@Test @MainActor func clearCourtshipPreservesNonCourtingBehaviorState() {
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

@Test @MainActor func advancePregnanciesIncreasesPregnancyDays() throws {
    let state = GameState()
    var pig = GuineaPig.create(name: "Mama", gender: .female)
    pig.isPregnant = true
    pig.pregnancyDays = 0.0
    state.addGuineaPig(pig)

    Birth.advancePregnancies(gameState: state, gameHours: 24.0)

    let updated = try #require(state.getGuineaPig(pig.id))
    #expect(updated.pregnancyDays == 1.0)
}

@Test @MainActor func advancePregnanciesSkipsNonPregnantPigs() throws {
    let state = GameState()
    var pig = GuineaPig.create(name: "NotPregnant", gender: .female)
    pig.isPregnant = false
    pig.pregnancyDays = 0.0
    state.addGuineaPig(pig)

    Birth.advancePregnancies(gameState: state, gameHours: 24.0)

    let updated = try #require(state.getGuineaPig(pig.id))
    #expect(updated.pregnancyDays == 0.0)
}

@Test @MainActor func speedBreedingPerkAcceleratesPregnancy() throws {
    let state = GameState()
    state.purchasedUpgrades.insert("speed_breeding")
    var pig = GuineaPig.create(name: "Mama", gender: .female)
    pig.isPregnant = true
    pig.pregnancyDays = 0.0
    state.addGuineaPig(pig)

    Birth.advancePregnancies(gameState: state, gameHours: 24.0)

    let updated = try #require(state.getGuineaPig(pig.id))
    // With speed_breeding: 1 game day * 1.333 = 1.333 days
    #expect(abs(updated.pregnancyDays - 1.333) < 0.001)
}

// MARK: - Birth.checkBirths

@Test @MainActor func checkBirthsAtThresholdProducesBabies() throws {
    let state = makeGameState(withArea: true)
    let fatherGenotype = makeGameStateHomozygousGenotype()
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

@Test @MainActor func checkBirthsBelowThresholdProducesNoBabies() throws {
    let state = makeGameState(withArea: true)
    var mother = GuineaPig.create(name: "Mama", gender: .female)
    mother.isPregnant = true
    mother.pregnancyDays = Double(GameConfig.Breeding.gestationDays) - 1.0
    mother.partnerGenotype = makeGameStateHomozygousGenotype()
    state.addGuineaPig(mother)

    let births = Birth.checkBirths(gameState: state)

    #expect(births == 0)
    // Mother is still pregnant
    let updated = try #require(state.getGuineaPig(mother.id))
    #expect(updated.isPregnant)
}

@Test @MainActor func checkBirthsResetsMotherAfterBirth() throws {
    let state = makeGameState(withArea: true)
    var mother = GuineaPig.create(name: "Mama", gender: .female)
    mother.position = Position(x: 5.0, y: 5.0)
    mother.isPregnant = true
    mother.pregnancyDays = Double(GameConfig.Breeding.gestationDays) + 1.0
    mother.partnerGenotype = makeGameStateHomozygousGenotype()
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

// MARK: - Test Helpers

private func makeGameStateHomozygousGenotype() -> Genotype {
    Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
}
