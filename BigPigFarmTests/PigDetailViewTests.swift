/// PigDetailViewTests — Tests for PigDetailView helper logic, genetics gating, and need display.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Rarity.sortOrder

@Suite("Rarity sortOrder")
struct RaritySortOrderTests {

    @Test func sortOrderIsMonotonic() {
        #expect(Rarity.common.sortOrder < Rarity.uncommon.sortOrder)
        #expect(Rarity.uncommon.sortOrder < Rarity.rare.sortOrder)
        #expect(Rarity.rare.sortOrder < Rarity.veryRare.sortOrder)
        #expect(Rarity.veryRare.sortOrder < Rarity.legendary.sortOrder)
    }

    @Test func commonSortOrderIsLowest() {
        for rarity in Rarity.allCases where rarity != .common {
            #expect(Rarity.common.sortOrder < rarity.sortOrder)
        }
    }

    @Test func legendarySortOrderIsHighest() {
        for rarity in Rarity.allCases where rarity != .legendary {
            #expect(Rarity.legendary.sortOrder > rarity.sortOrder)
        }
    }

    @Test func allCasesHaveDistinctSortOrders() {
        let orders = Rarity.allCases.map { $0.sortOrder }
        let uniqueOrders = Set(orders)
        #expect(uniqueOrders.count == Rarity.allCases.count)
    }
}

// MARK: - parentName Helper

@MainActor
@Suite("PigDetailView - parentName")
struct PigDetailParentNameTests {

    @Test func parentNameReturnsLivePigName() {
        let state = makeGameState()
        let parent = GuineaPig.create(name: "Mama", gender: .female)
        state.addGuineaPig(parent)

        let name = resolveParentName(id: parent.id, state: state)
        #expect(name == "Mama")
    }

    @Test func parentNameReturnsUnknownWhenNotInState() {
        let state = makeGameState()
        let missingID = UUID()

        let name = resolveParentName(id: missingID, state: state)
        #expect(name == "Unknown (no longer on farm)")
    }

    @Test func parentNameReturnsAdoptedStringForNilID() {
        let state = makeGameState()

        let name = resolveParentName(id: nil, state: state)
        #expect(name == "Unknown (adopted/starter)")
    }
}

// MARK: - Boredom Inversion

@Suite("PigDetailView - Boredom Display")
struct PigDetailBoredomTests {

    @Test func boredomZeroProducesFunOfOne() {
        var pig = GuineaPig.create(name: "Bouncy", gender: .female)
        pig.needs.boredom = 0.0
        let funValue = (100.0 - pig.needs.boredom) / 100.0
        #expect(funValue == 1.0)
    }

    @Test func boredomHundredProducesFunOfZero() {
        var pig = GuineaPig.create(name: "Bored", gender: .female)
        pig.needs.boredom = 100.0
        let funValue = (100.0 - pig.needs.boredom) / 100.0
        #expect(funValue == 0.0)
    }

    @Test func boredomFiftyProducesFunOfHalf() {
        var pig = GuineaPig.create(name: "Meh", gender: .female)
        pig.needs.boredom = 50.0
        let funValue = (100.0 - pig.needs.boredom) / 100.0
        #expect(funValue == 0.5)
    }

    @Test func allNeedsAreInValidNeedBarRange() {
        let pig = GuineaPig.create(name: "Normal", gender: .female)
        let values = [
            pig.needs.hunger / 100.0,
            pig.needs.thirst / 100.0,
            pig.needs.energy / 100.0,
            pig.needs.happiness / 100.0,
            pig.needs.health / 100.0,
            pig.needs.social / 100.0,
            (100.0 - pig.needs.boredom) / 100.0,
        ]
        for value in values {
            #expect(value >= 0.0)
            #expect(value <= 1.0)
        }
    }
}

// MARK: - Genetics Lab Gating

@MainActor
@Suite("PigDetailView - Genetics Gating")
struct PigDetailGeneticsGatingTests {

    @Test func noLabMeansGeneticsSectionHidden() {
        let state = makeGameState()
        // No genetics lab added
        let hasLab = !state.getFacilitiesByType(.geneticsLab).isEmpty
        #expect(!hasLab)
    }

    @Test func addingLabEnablesGeneticsSection() {
        let state = makeGameState()
        let lab = Facility.create(type: .geneticsLab, x: 5, y: 5)
        _ = state.addFacility(lab)

        let hasLab = !state.getFacilitiesByType(.geneticsLab).isEmpty
        #expect(hasLab)
    }
}

// MARK: - carrierSummary

@Suite("PigDetailView - Carrier Summary")
struct PigDetailCarrierSummaryTests {

    @Test func homozygousDominantGenotypeSummaryIsEmpty() {
        let genotype = Genotype(
            eLocus: AllelePair(first: "E", second: "E"),
            bLocus: AllelePair(first: "B", second: "B"),
            sLocus: AllelePair(first: "S", second: "S"),
            cLocus: AllelePair(first: "C", second: "C"),
            rLocus: AllelePair(first: "r", second: "r"),
            dLocus: AllelePair(first: "D", second: "D")
        )
        let summary = carrierSummary(genotype)
        #expect(summary.isEmpty)
    }

    @Test func heterozygousELocusShowsInSummary() {
        let genotype = Genotype(
            eLocus: AllelePair(first: "E", second: "e"),
            bLocus: AllelePair(first: "B", second: "B"),
            sLocus: AllelePair(first: "S", second: "S"),
            cLocus: AllelePair(first: "C", second: "C"),
            rLocus: AllelePair(first: "r", second: "r"),
            dLocus: AllelePair(first: "D", second: "D")
        )
        let summary = carrierSummary(genotype)
        #expect(!summary.isEmpty)
    }
}

// MARK: - Test Helper (mirrors PigDetailView.parentName)

private func resolveParentName(id: UUID?, state: GameState) -> String {
    guard let id else { return "Unknown (adopted/starter)" }
    if let parent = state.getGuineaPig(id) { return parent.name }
    return "Unknown (no longer on farm)"
}
