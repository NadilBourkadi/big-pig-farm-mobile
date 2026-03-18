/// CullingTests -- Tests for Culling.sellMarkedAdults and basic cullSurplusBreeders guards.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Test Helpers (shared with CullingReplacementTests)

@MainActor
func makeCullingAdult(
    name: String = "Pig",
    gender: Gender = .female,
    ageDays: Double = 10.0,
    markedForSale: Bool = false,
    isPregnant: Bool = false
) -> GuineaPig {
    var pig = GuineaPig.create(name: name, gender: gender)
    pig.ageDays = ageDays
    pig.markedForSale = markedForSale
    pig.isPregnant = isPregnant
    return pig
}

@MainActor
func makeCullingAdultWith(genotype: Genotype, name: String, gender: Gender = .female) -> GuineaPig {
    var pig = GuineaPig.create(name: name, gender: gender, genotype: genotype)
    pig.ageDays = 10.0
    return pig
}

@MainActor
func makeCullingBaby(name: String = "Baby", gender: Gender = .female) -> GuineaPig {
    var pig = GuineaPig.create(name: name, gender: gender)
    pig.ageDays = 0.0
    return pig
}

@MainActor
func makeStateWithBreedingProgram(
    strategy: BreedingStrategy = .target,
    stockLimit: Int = 4,
    targetColors: Set<BaseColor> = [],
    enabled: Bool = true
) -> GameState {
    let state = GameState()
    state.breedingProgram.enabled = enabled
    state.breedingProgram.strategy = strategy
    state.breedingProgram.stockLimit = stockLimit
    state.breedingProgram.targetColors = targetColors
    return state
}

func blackPigGenotype() -> Genotype {
    Genotype(
        eLocus: AllelePair(first: "E", second: "E"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
}

func goldenPigGenotype() -> Genotype {
    Genotype(
        eLocus: AllelePair(first: "e", second: "e"),
        bLocus: AllelePair(first: "B", second: "B"),
        sLocus: AllelePair(first: "S", second: "S"),
        cLocus: AllelePair(first: "C", second: "C"),
        rLocus: AllelePair(first: "r", second: "r"),
        dLocus: AllelePair(first: "D", second: "D")
    )
}

// MARK: - sellMarkedAdults: basic sale

@Test @MainActor func sellMarkedAdultsReturnsEmptyWhenNoPigsMarked() {
    let state = GameState()
    state.addGuineaPig(makeCullingAdult(name: "Alice"))

    let sold = Culling.sellMarkedAdults(gameState: state)

    #expect(sold.isEmpty)
    #expect(state.guineaPigs.count == 1)
}

@Test @MainActor func sellMarkedAdultsSellsMarkedAdult() {
    let state = GameState()
    state.addGuineaPig(makeCullingAdult(name: "Alice", markedForSale: true))
    let startingMoney = state.money

    let sold = Culling.sellMarkedAdults(gameState: state)

    #expect(sold.count == 1)
    #expect(state.guineaPigs.isEmpty)
    #expect(state.money > startingMoney)
}

@Test @MainActor func sellMarkedAdultsSkipsBabyEvenIfMarked() {
    let state = GameState()
    var baby = makeCullingBaby(name: "Tiny")
    baby.markedForSale = true
    state.addGuineaPig(baby)

    let sold = Culling.sellMarkedAdults(gameState: state)

    #expect(sold.isEmpty)
    #expect(state.guineaPigs.count == 1)
}

@Test @MainActor func sellMarkedAdultsIncrementsTotalPigsSold() {
    let state = GameState()
    state.addGuineaPig(makeCullingAdult(name: "Bob", markedForSale: true))

    Culling.sellMarkedAdults(gameState: state)

    #expect(state.totalPigsSold == 1)
}

@Test @MainActor func sellMarkedAdultsReturnsSoldPigRecord() throws {
    let state = GameState()
    let pig = makeCullingAdult(name: "Charlie", markedForSale: true)
    let pigID = pig.id
    state.addGuineaPig(pig)

    let sold = Culling.sellMarkedAdults(gameState: state)

    try #require(sold.count == 1)
    #expect(sold[0].pigName == "Charlie")
    #expect(sold[0].pigID == pigID)
    #expect(sold[0].totalValue > 0)
    #expect(sold[0].contractBonus == 0)
}

@Test @MainActor func sellMarkedAdultsSellsMultiplePigsInOneCall() {
    let state = GameState()
    for idx in 1...3 {
        state.addGuineaPig(makeCullingAdult(name: "Pig\(idx)", markedForSale: true))
    }
    state.addGuineaPig(makeCullingAdult(name: "Keeper"))

    let sold = Culling.sellMarkedAdults(gameState: state)

    #expect(sold.count == 3)
    #expect(state.guineaPigs.count == 1)
}

// MARK: - sellMarkedAdults: contract bonus

@Test @MainActor func sellMarkedAdultsAppliesContractBonus() throws {
    let state = GameState()
    let contract = BreedingContract(requiredColor: .black, reward: 100)
    state.contractBoard.activeContracts.append(contract)
    var pig = makeCullingAdultWith(genotype: blackPigGenotype(), name: "Blackie")
    pig.markedForSale = true
    state.addGuineaPig(pig)
    let startingMoney = state.money

    let sold = Culling.sellMarkedAdults(gameState: state)

    try #require(sold.count == 1)
    #expect(sold[0].contractBonus == 100)
    #expect(sold[0].totalValue > 0)
    #expect(state.money > startingMoney + pig.getValue())
    #expect(state.contractBoard.activeContracts.allSatisfy { $0.fulfilled })
}

@Test @MainActor func sellMarkedAdultsFulfillsMatchedContract() {
    let state = GameState()
    let contract = BreedingContract(requiredColor: .black, reward: 50)
    state.contractBoard.activeContracts.append(contract)
    var pig = makeCullingAdultWith(genotype: blackPigGenotype(), name: "Jet", gender: .male)
    pig.markedForSale = true
    state.addGuineaPig(pig)

    Culling.sellMarkedAdults(gameState: state)

    #expect(state.contractBoard.activeContracts.isEmpty)
    #expect(state.contractBoard.completedContracts == 1)
}

// MARK: - cullSurplusBreeders: guards and logging

@Test @MainActor func cullDoesNothingWhenProgramDisabled() {
    let state = makeStateWithBreedingProgram(enabled: false)
    for idx in 1...6 {
        state.addGuineaPig(makeCullingAdult(name: "Pig\(idx)"))
    }

    Culling.cullSurplusBreeders(gameState: state)

    #expect(state.getPigsList().filter { $0.markedForSale }.isEmpty)
}

@Test @MainActor func cullDoesNothingBelowStockLimit() {
    let state = makeStateWithBreedingProgram(stockLimit: 6)
    state.addGuineaPig(makeCullingAdult(name: "A", gender: .male))
    state.addGuineaPig(makeCullingAdult(name: "B", gender: .female))

    Culling.cullSurplusBreeders(gameState: state)

    #expect(state.getPigsList().filter { $0.markedForSale }.isEmpty)
}

@Test @MainActor func cullMarksSurplusAboveLimit() {
    let state = makeStateWithBreedingProgram(stockLimit: 4)
    state.addGuineaPig(makeCullingAdult(name: "M1", gender: .male))
    state.addGuineaPig(makeCullingAdult(name: "M2", gender: .male))
    for idx in 1...4 {
        state.addGuineaPig(makeCullingAdult(name: "F\(idx)", gender: .female))
    }

    Culling.cullSurplusBreeders(gameState: state)

    #expect(state.getPigsList().filter { $0.markedForSale }.count == 2)
}

@Test @MainActor func cullSkipsPregnantPigsInSurplus() {
    let state = makeStateWithBreedingProgram(stockLimit: 4)
    state.addGuineaPig(makeCullingAdult(name: "M1", gender: .male))
    state.addGuineaPig(makeCullingAdult(name: "M2", gender: .male))
    state.addGuineaPig(makeCullingAdult(name: "F1", gender: .female))
    state.addGuineaPig(makeCullingAdult(name: "F2", gender: .female))
    state.addGuineaPig(makeCullingAdult(name: "F3", gender: .female, isPregnant: true))
    state.addGuineaPig(makeCullingAdult(name: "F4", gender: .female))

    Culling.cullSurplusBreeders(gameState: state)

    // Invariant: no pregnant pig is ever marked for sale.
    #expect(state.getPigsList().allSatisfy { !($0.isPregnant && $0.markedForSale) })
}

@Test @MainActor func cullExcludesBabiesFromAdultCount() {
    let state = makeStateWithBreedingProgram(stockLimit: 4)
    state.addGuineaPig(makeCullingAdult(name: "M1", gender: .male))
    state.addGuineaPig(makeCullingAdult(name: "M2", gender: .male))
    state.addGuineaPig(makeCullingAdult(name: "F1", gender: .female))
    state.addGuineaPig(makeCullingAdult(name: "F2", gender: .female))
    state.addGuineaPig(makeCullingBaby(name: "B1"))
    state.addGuineaPig(makeCullingBaby(name: "B2"))

    Culling.cullSurplusBreeders(gameState: state)

    // Babies excluded from adult count; at limit with no targets → no-op
    #expect(state.getPigsList().filter { $0.markedForSale }.isEmpty)
}

@Test @MainActor func cullLogsEventWhenMarkingSurplus() {
    let state = makeStateWithBreedingProgram(stockLimit: 4)
    for idx in 1...6 {
        state.addGuineaPig(makeCullingAdult(name: "Pig\(idx)", gender: idx % 2 == 0 ? .male : .female))
    }

    Culling.cullSurplusBreeders(gameState: state)

    #expect(state.events.contains { $0.message.contains("surplus pig") })
}

@Test @MainActor func sellMarkedAdultsEmptyHerd() {
    let state = GameState()
    let sold = Culling.sellMarkedAdults(gameState: state)
    #expect(sold.isEmpty)
}
