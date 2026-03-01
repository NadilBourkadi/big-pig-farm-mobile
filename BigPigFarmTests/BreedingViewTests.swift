/// BreedingViewTests — Tests for BreedingView pair selection logic and prediction.
///
/// Tests exercise the same logic as BreedingView/BreedingPairTab against
/// real GameState objects, without requiring a rendered view.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Pair Eligibility Tests

@Test @MainActor func canSetPairWithEligiblePigs() throws {
    let state = makeGameState()
    let male = GuineaPig.create(name: "Buck", gender: .male, ageDays: 15.0)
    let female = GuineaPig.create(name: "Doe", gender: .female, ageDays: 15.0)
    state.addGuineaPig(male)
    state.addGuineaPig(female)

    let malePig = try #require(state.getGuineaPig(male.id))
    let femalePig = try #require(state.getGuineaPig(female.id))

    let canPair = malePig.canBreed && femalePig.canBreed
        && !malePig.breedingLocked && !femalePig.breedingLocked
        && !femalePig.isPregnant

    #expect(canPair)
}

@Test @MainActor func canSetPairBlockedByPregnancy() throws {
    let state = makeGameState()
    let male = GuineaPig.create(name: "Buck", gender: .male, ageDays: 15.0)
    var female = GuineaPig.create(name: "Doe", gender: .female, ageDays: 15.0)
    female.isPregnant = true
    state.addGuineaPig(male)
    state.addGuineaPig(female)

    let femalePig = try #require(state.getGuineaPig(female.id))
    #expect(femalePig.isPregnant)
    // canSetPair requires !female.isPregnant
    let canPair = !femalePig.isPregnant
    #expect(!canPair)
}

@Test @MainActor func canSetPairBlockedByLocked() throws {
    let state = makeGameState()
    var male = GuineaPig.create(name: "Buck", gender: .male, ageDays: 15.0)
    male.breedingLocked = true
    let female = GuineaPig.create(name: "Doe", gender: .female, ageDays: 15.0)
    state.addGuineaPig(male)
    state.addGuineaPig(female)

    let malePig = try #require(state.getGuineaPig(male.id))
    #expect(malePig.breedingLocked)
    let canPair = !malePig.breedingLocked
    #expect(!canPair)
}

@Test @MainActor func canSetPairBlockedByBaby() throws {
    let state = makeGameState()
    let male = GuineaPig.create(name: "Buck", gender: .male, ageDays: 2.0)
    let female = GuineaPig.create(name: "Doe", gender: .female, ageDays: 15.0)
    state.addGuineaPig(male)
    state.addGuineaPig(female)

    let malePig = try #require(state.getGuineaPig(male.id))
    // A baby is not an adult and canBreed returns false
    #expect(!malePig.isAdult)
    #expect(!malePig.canBreed)
}

@Test @MainActor func canSetPairBlockedByUnhappy() throws {
    let state = makeGameState()
    var male = GuineaPig.create(name: "Buck", gender: .male, ageDays: 15.0)
    male.needs.happiness = 50.0 // Below the 70.0 threshold
    let female = GuineaPig.create(name: "Doe", gender: .female, ageDays: 15.0)
    state.addGuineaPig(male)
    state.addGuineaPig(female)

    let malePig = try #require(state.getGuineaPig(male.id))
    #expect(!malePig.canBreed)
}

// MARK: - SetPair / ClearPair Tests

@Test @MainActor func setPairUpdatesGameState() {
    let state = makeGameState()
    let male = GuineaPig.create(name: "Buck", gender: .male, ageDays: 15.0)
    let female = GuineaPig.create(name: "Doe", gender: .female, ageDays: 15.0)
    state.addGuineaPig(male)
    state.addGuineaPig(female)

    state.setBreedingPair(maleID: male.id, femaleID: female.id)

    #expect(state.breedingPair != nil)
    #expect(state.breedingPair?.maleId == male.id)
    #expect(state.breedingPair?.femaleId == female.id)
}

@Test @MainActor func clearPairClearsGameState() {
    let state = makeGameState()
    let male = GuineaPig.create(name: "Buck", gender: .male, ageDays: 15.0)
    let female = GuineaPig.create(name: "Doe", gender: .female, ageDays: 15.0)
    state.addGuineaPig(male)
    state.addGuineaPig(female)

    state.setBreedingPair(maleID: male.id, femaleID: female.id)
    #expect(state.breedingPair != nil)

    state.clearBreedingPair()
    #expect(state.breedingPair == nil)
}

// MARK: - Pig List Filtering Tests

@Test @MainActor func adultMalesFiltersCorrectly() {
    let state = makeGameState()
    let adultMale = GuineaPig.create(name: "Buck", gender: .male, ageDays: 15.0)
    let babyMale = GuineaPig.create(name: "Pip", gender: .male, ageDays: 2.0)
    let adultFemale = GuineaPig.create(name: "Doe", gender: .female, ageDays: 15.0)
    state.addGuineaPig(adultMale)
    state.addGuineaPig(babyMale)
    state.addGuineaPig(adultFemale)

    let males = state.getPigsList().filter { $0.gender == .male && $0.isAdult }
    #expect(males.count == 1)
    #expect(males.first?.id == adultMale.id)
}

@Test @MainActor func adultFemalesFiltersCorrectly() {
    let state = makeGameState()
    let adultFemale = GuineaPig.create(name: "Doe", gender: .female, ageDays: 15.0)
    let babyFemale = GuineaPig.create(name: "Tiny", gender: .female, ageDays: 2.0)
    let adultMale = GuineaPig.create(name: "Buck", gender: .male, ageDays: 15.0)
    state.addGuineaPig(adultFemale)
    state.addGuineaPig(babyFemale)
    state.addGuineaPig(adultMale)

    let females = state.getPigsList().filter { $0.gender == .female && $0.isAdult }
    #expect(females.count == 1)
    #expect(females.first?.id == adultFemale.id)
}

@Test @MainActor func noPigsShowsEmptyLists() {
    let state = makeGameState()
    let males = state.getPigsList().filter { $0.gender == .male && $0.isAdult }
    let females = state.getPigsList().filter { $0.gender == .female && $0.isAdult }
    #expect(males.isEmpty)
    #expect(females.isEmpty)
}

// MARK: - Pair Status Tests

@Test @MainActor func isPairedDetectsCurrentPair() {
    let state = makeGameState()
    let male = GuineaPig.create(name: "Buck", gender: .male, ageDays: 15.0)
    let female = GuineaPig.create(name: "Doe", gender: .female, ageDays: 15.0)
    state.addGuineaPig(male)
    state.addGuineaPig(female)

    state.setBreedingPair(maleID: male.id, femaleID: female.id)

    guard let pair = state.breedingPair else {
        Issue.record("breedingPair should not be nil")
        return
    }
    #expect(male.id == pair.maleId || male.id == pair.femaleId)
    #expect(female.id == pair.maleId || female.id == pair.femaleId)
}

@Test @MainActor func isAutoPairedDetectsAutoProgram() {
    let state = makeGameState()
    let male = GuineaPig.create(name: "Buck", gender: .male, ageDays: 15.0)
    let female = GuineaPig.create(name: "Doe", gender: .female, ageDays: 15.0)
    state.addGuineaPig(male)
    state.addGuineaPig(female)

    state.setBreedingPair(maleID: male.id, femaleID: female.id)
    state.breedingProgram.enabled = true
    state.breedingProgram.autoPair = true

    #expect(state.breedingProgram.shouldAutoPair())
    #expect(state.breedingPair != nil)
}

// MARK: - Offspring Prediction Tests

@Test @MainActor func predictionReturnsResults() throws {
    let state = makeGameState()
    let male = GuineaPig.create(name: "Buck", gender: .male, ageDays: 15.0)
    let female = GuineaPig.create(name: "Doe", gender: .female, ageDays: 15.0)
    state.addGuineaPig(male)
    state.addGuineaPig(female)

    let malePig = try #require(state.getGuineaPig(male.id))
    let femalePig = try #require(state.getGuineaPig(female.id))

    let predictions = predictOffspringPhenotypes(malePig.genotype, femalePig.genotype)
    #expect(!predictions.isEmpty)
    // Probabilities should sum to ~1.0
    let total = predictions.reduce(0.0) { $0 + $1.1 }
    #expect(total > 0.9 && total <= 1.01)
}

@Test @MainActor func predictionProbabilitiesAreSortedDescending() {
    let male = GuineaPig.create(name: "Buck", gender: .male, ageDays: 15.0)
    let female = GuineaPig.create(name: "Doe", gender: .female, ageDays: 15.0)

    let predictions = predictOffspringPhenotypes(male.genotype, female.genotype)
    for index in 1..<predictions.count {
        #expect(predictions[index].1 <= predictions[index - 1].1)
    }
}

@Test @MainActor func targetProbabilityWithMatchingTargets() {
    // Homozygous dominant at E, B, D loci → 100% black offspring
    let blackGenotype = Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
    let male = GuineaPig.create(name: "Buck", gender: .male, genotype: blackGenotype, ageDays: 15.0)
    let female = GuineaPig.create(name: "Doe", gender: .female, genotype: blackGenotype, ageDays: 15.0)
    let prob = calculateTargetProbability(
        male.genotype, female.genotype,
        targetColors: [.black],
        targetPatterns: [],
        targetIntensities: [],
        targetRoan: []
    )
    #expect(prob > 0.99)
}

@Test @MainActor func breedingProgramHasTargetWhenSet() {
    let state = makeGameState()
    #expect(!state.breedingProgram.hasTarget)

    state.breedingProgram.targetColors.insert(.chocolate)
    #expect(state.breedingProgram.hasTarget)

    state.breedingProgram.targetColors.remove(.chocolate)
    #expect(!state.breedingProgram.hasTarget)
}
