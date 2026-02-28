/// CullingReplacementTests -- Tests for gender-balance enforcement and active replacement.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - cullSurplusBreeders: gender balance

@Test @MainActor func cullPreservesGenderBalanceBySwap() {
    let state = makeStateWithBreedingProgram(strategy: .target, stockLimit: 4)
    for idx in 1...4 {
        state.addGuineaPig(makeCullingAdult(name: "F\(idx)", gender: .female))
    }
    state.addGuineaPig(makeCullingAdult(name: "MaleSwap", gender: .male))
    state.addGuineaPig(makeCullingAdult(name: "F5", gender: .female))

    Culling.cullSurplusBreeders(gameState: state)

    let markedNames = Set(state.getPigsList().filter { $0.markedForSale }.map { $0.name })
    #expect(!markedNames.contains("MaleSwap"))
    #expect(markedNames.count == 2)
}

// MARK: - activeReplacement: target mode

@Test @MainActor func activeReplacementMarksNonMatchingPigAtLimit() {
    let state = GameState()
    state.breedingProgram.enabled = true
    state.breedingProgram.stockLimit = 4
    state.breedingProgram.strategy = .target
    state.breedingProgram.targetColors = [.golden]

    for idx in 1...3 {
        let gender: Gender = idx == 1 ? .male : .female
        state.addGuineaPig(
            makeCullingAdultWith(genotype: goldenPigGenotype(), name: "Golden\(idx)", gender: gender)
        )
    }
    state.addGuineaPig(makeCullingAdultWith(genotype: blackPigGenotype(), name: "NonMatch", gender: .female))

    Culling.cullSurplusBreeders(gameState: state)

    let marked = state.getPigsList().filter { $0.markedForSale }
    #expect(marked.count == 1)
    #expect(marked[0].name == "NonMatch")
}

@Test @MainActor func activeReplacementNoOpWhenAllMatch() {
    let state = GameState()
    state.breedingProgram.enabled = true
    state.breedingProgram.stockLimit = 4
    state.breedingProgram.strategy = .target
    state.breedingProgram.targetColors = [.golden]

    state.addGuineaPig(makeCullingAdultWith(genotype: goldenPigGenotype(), name: "G1", gender: .male))
    for idx in 2...4 {
        state.addGuineaPig(makeCullingAdultWith(genotype: goldenPigGenotype(), name: "G\(idx)"))
    }

    Culling.cullSurplusBreeders(gameState: state)

    #expect(state.getPigsList().filter { $0.markedForSale }.isEmpty)
}

@Test @MainActor func activeReplacementSkipsPregnantCandidate() {
    let state = GameState()
    state.breedingProgram.enabled = true
    state.breedingProgram.stockLimit = 2
    state.breedingProgram.strategy = .target
    state.breedingProgram.targetColors = [.golden]

    state.addGuineaPig(makeCullingAdultWith(genotype: goldenPigGenotype(), name: "Gold", gender: .male))
    var nonMatch = makeCullingAdultWith(genotype: blackPigGenotype(), name: "NonMatch")
    nonMatch.isPregnant = true
    state.addGuineaPig(nonMatch)

    Culling.cullSurplusBreeders(gameState: state)

    #expect(state.getPigsList().filter { $0.markedForSale }.isEmpty)
}

@Test @MainActor func activeReplacementPreservesGenderBalanceAtLimit() {
    let state = GameState()
    state.breedingProgram.enabled = true
    state.breedingProgram.stockLimit = 2
    state.breedingProgram.strategy = .target
    state.breedingProgram.targetColors = [.golden]

    state.addGuineaPig(makeCullingAdultWith(genotype: goldenPigGenotype(), name: "GoldF"))
    // Non-matching male — selling it would leave zero males; must be preserved.
    state.addGuineaPig(makeCullingAdultWith(genotype: blackPigGenotype(), name: "BlackM", gender: .male))

    Culling.cullSurplusBreeders(gameState: state)

    #expect(state.getPigsList().filter { $0.markedForSale }.isEmpty)
}

// MARK: - activeReplacement: no-op without targets

@Test @MainActor func activeReplacementNoOpWithoutTargets() {
    // Both .money and .target (no targets set) must never fire active replacement.
    for strategy: BreedingStrategy in [.money, .target] {
        let state = makeStateWithBreedingProgram(strategy: strategy, stockLimit: 4)
        for idx in 1...4 {
            state.addGuineaPig(makeCullingAdult(name: "Pig\(idx)", gender: idx % 2 == 0 ? .male : .female))
        }
        Culling.cullSurplusBreeders(gameState: state)
        #expect(state.getPigsList().filter { $0.markedForSale }.isEmpty)
    }
}

// MARK: - Edge cases

@Test @MainActor func cullEmptyHerd() {
    let state = makeStateWithBreedingProgram(stockLimit: 4)
    Culling.cullSurplusBreeders(gameState: state)
    #expect(state.guineaPigs.isEmpty)
}

@Test @MainActor func cullSinglePigBelowLimit() {
    let state = makeStateWithBreedingProgram(stockLimit: 4)
    state.addGuineaPig(makeCullingAdult(name: "Lonely"))

    Culling.cullSurplusBreeders(gameState: state)

    #expect(state.getPigsList().filter { $0.markedForSale }.isEmpty)
}

@Test @MainActor func cullRespectsEffectiveLimitMinimum() {
    // stockLimit = 1 but minBreedingPopulation = 2, so effective limit = 2.
    let state = GameState()
    state.breedingProgram.enabled = true
    state.breedingProgram.stockLimit = 1
    state.breedingProgram.strategy = .target
    state.addGuineaPig(makeCullingAdult(name: "A", gender: .male))
    state.addGuineaPig(makeCullingAdult(name: "B", gender: .female))

    Culling.cullSurplusBreeders(gameState: state)

    // At effective limit (2), active replacement runs but no targets → no-op.
    #expect(state.getPigsList().filter { $0.markedForSale }.isEmpty)
}
