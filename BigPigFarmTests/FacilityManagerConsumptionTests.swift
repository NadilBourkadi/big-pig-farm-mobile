/// FacilityManagerConsumptionTests — Arrival, consumption, scoring, and biome affinity tests.
import Foundation
import Testing
@testable import BigPigFarm

@MainActor
struct FacilityManagerConsumptionTests {

    // MARK: - Helpers

    // swiftlint:disable:next large_tuple
    func makeManager() -> (FacilityManager, GameState, BehaviorController) {
        let state = makeGameState()
        let controller = makeController(state: state)
        return (controller.facilityManager, state, controller)
    }

    func placeFacility(type: FacilityType, x: Int, y: Int, state: GameState) -> Facility {
        let facility = Facility.create(type: type, x: x, y: y)
        let placed = state.addFacility(facility)
        precondition(placed, "Failed to place \(type) at (\(x), \(y))")
        return state.getFacility(facility.id)!
    }

    func pigAt(x: Double, y: Double, state: BehaviorState = .idle) -> GuineaPig {
        var pig = GuineaPig.create(name: "Test", gender: .female)
        pig.position = Position(x: x, y: y)
        pig.behaviorState = state
        return pig
    }

    // MARK: - Arrival Tests

    @Test("checkArrivedAtFacility at food bowl sets eating state")
    func testArrivalAtFoodBowlSetsEating() {
        let (manager, state, unusedController) = makeManager()
        placeFacility(type: .foodBowl, x: 4, y: 9, state: state)

        var pig = pigAt(x: 5.0, y: 9.0, state: .wandering)
        pig.needs.hunger = 30.0
        pig.targetFacilityId = state.getFacilitiesByType(.foodBowl).first?.id
        state.addGuineaPig(pig)

        manager.checkArrivedAtFacility(pig: &pig)
        #expect(pig.behaviorState == .eating)
    }

    @Test("checkArrivedAtFacility at empty food bowl marks facility as failed and goes idle")
    func testArrivalAtEmptyBowlMarksAsFailed() {
        let (manager, state, unusedController) = makeManager()
        var facility = placeFacility(type: .foodBowl, x: 4, y: 9, state: state)
        facility.currentAmount = 0
        state.facilities[facility.id] = facility

        var pig = pigAt(x: 5.0, y: 9.0, state: .wandering)
        pig.needs.hunger = 30.0
        pig.targetFacilityId = facility.id
        state.addGuineaPig(pig)

        manager.checkArrivedAtFacility(pig: &pig)
        #expect(manager.getFailedFacilities(pig.id).contains(facility.id))
        #expect(pig.behaviorState == .idle)
    }

    @Test("checkArrivedAtFacility at water bottle sets drinking state")
    func testArrivalAtWaterBottleSetsdrinking() {
        let (manager, state, unusedController) = makeManager()
        placeFacility(type: .waterBottle, x: 5, y: 9, state: state)

        var pig = pigAt(x: 5.0, y: 9.0, state: .wandering)
        pig.needs.thirst = 30.0
        pig.targetFacilityId = state.getFacilitiesByType(.waterBottle).first?.id
        state.addGuineaPig(pig)

        manager.checkArrivedAtFacility(pig: &pig)
        #expect(pig.behaviorState == .drinking)
    }

    @Test("checkArrivedAtFacility at hideout with low energy sets sleeping state")
    func testArrivalAtHideoutWithLowEnergySleeps() {
        let (manager, state, unusedController) = makeManager()
        placeFacility(type: .hideout, x: 4, y: 9, state: state)

        // Pig at left-side interaction point (3,9) of hideout at (4,9) size 3x2
        var pig = pigAt(x: 3.0, y: 9.0, state: .wandering)
        pig.needs.energy = 20.0
        pig.targetFacilityId = state.getFacilitiesByType(.hideout).first?.id
        state.addGuineaPig(pig)

        manager.checkArrivedAtFacility(pig: &pig)
        #expect(pig.behaviorState == .sleeping)
    }

    @Test("checkArrivedAtFacility at therapy garden goes idle when pig is happy")
    func testArrivalAtTherapyGardenSkipsIfHappy() {
        let (manager, state, unusedController) = makeManager()
        placeFacility(type: .therapyGarden, x: 4, y: 9, state: state)

        // Pig at left-side interaction point (3,9) of therapy garden at (4,9) size 5x5
        var pig = pigAt(x: 3.0, y: 9.0, state: .wandering)
        pig.needs.happiness = 80.0
        pig.targetFacilityId = state.getFacilitiesByType(.therapyGarden).first?.id
        state.addGuineaPig(pig)

        let savedTargetId = pig.targetFacilityId
        manager.checkArrivedAtFacility(pig: &pig)
        #expect(pig.behaviorState == .idle)
        #expect(manager.getFailedFacilities(pig.id).contains(savedTargetId!))
    }

    @Test("checkArrivedAtFacility goes idle if no nearby facility found")
    func testArrivalWithNoFacilityGoesIdle() {
        let (manager, state, unusedController) = makeManager()
        var pig = pigAt(x: 5.0, y: 5.0, state: .wandering)
        state.addGuineaPig(pig)

        manager.checkArrivedAtFacility(pig: &pig)
        #expect(pig.behaviorState == .idle)
    }

    // MARK: - Consumption Tests

    @Test("consumeFromNearbyFacility eating reduces food bowl currentAmount")
    func testConsumeFromFoodBowlReducesAmount() {
        let (manager, state, unusedController) = makeManager()
        let facility = placeFacility(type: .foodBowl, x: 4, y: 9, state: state)
        let initialAmount = facility.currentAmount

        var pig = pigAt(x: 5.0, y: 9.0, state: .eating)
        pig.targetFacilityId = facility.id
        state.addGuineaPig(pig)

        manager.consumeFromNearbyFacility(pig: &pig, gameMinutes: 1.0)
        let updatedFacility = state.getFacility(facility.id)!
        #expect(updatedFacility.currentAmount < initialAmount)
    }

    @Test("consumeFromNearbyFacility sets idle when food bowl is empty")
    func testConsumeFromEmptyBowlGoesIdle() {
        let (manager, state, unusedController) = makeManager()
        var facility = placeFacility(type: .foodBowl, x: 4, y: 9, state: state)
        facility.currentAmount = 0
        state.facilities[facility.id] = facility

        var pig = pigAt(x: 5.0, y: 9.0, state: .eating)
        pig.targetFacilityId = facility.id
        state.addGuineaPig(pig)

        manager.consumeFromNearbyFacility(pig: &pig, gameMinutes: 1.0)
        #expect(pig.behaviorState == .idle)
    }

    @Test("consumeFromNearbyFacility hay rack applies health bonus")
    func testHayRackHealthBonus() {
        let (manager, state, unusedController) = makeManager()
        let facility = placeFacility(type: .hayRack, x: 4, y: 9, state: state)

        var pig = pigAt(x: 5.0, y: 9.0, state: .eating)
        pig.needs.health = 50.0
        pig.targetFacilityId = facility.id
        state.addGuineaPig(pig)

        manager.consumeFromNearbyFacility(pig: &pig, gameMinutes: 1.0)
        #expect(pig.needs.health > 50.0)
    }

    @Test("consumeFromNearbyFacility hot spring claws back energy (multi-need trade-off)")
    func testHotSpringReducesEnergyRecovery() {
        let (manager, state, unusedController) = makeManager()
        let facility = placeFacility(type: .hotSpring, x: 4, y: 9, state: state)

        // Pig at interactionPoint (7,15) of hot spring at (4,9) size 6x6
        // interactionPoint = (positionX + width/2, positionY + height) = (4+3, 9+6) = (7,15)
        var pig = pigAt(x: 7.0, y: 15.0, state: .sleeping)
        pig.needs.energy = 50.0
        pig.targetFacilityId = facility.id
        state.addGuineaPig(pig)

        manager.consumeFromNearbyFacility(pig: &pig, gameMinutes: 1.0)
        #expect(pig.needs.energy < 50.0)
    }

    // MARK: - Scoring Tests

    @Test("rankFacilitiesBySpread mostly prefers the closer facility")
    func testRankFacilitiesBySpreadPrefersCloser() {
        let (manager, state, unusedController) = makeManager()
        manager.updateAreaPopulations()
        let closeFacility = placeFacility(type: .foodBowl, x: 4, y: 9, state: state)
        let farFacility = placeFacility(type: .foodBowl, x: 18, y: 9, state: state)
        let pig = pigAt(x: 5.0, y: 5.0)

        var closeFirst = 0
        for _ in 0..<20 {
            let ranked = manager.rankFacilitiesBySpread(pig: pig, facilities: [closeFacility, farFacility])
            if ranked.first?.id == closeFacility.id { closeFirst += 1 }
        }
        #expect(closeFirst >= 14)  // Close facility wins ≥70% of the time
    }

    // MARK: - countPigsUsingFacility Tests

    @Test("countPigsUsingFacility returns 0 when no pigs are near facility")
    func testCountPigsUsingFacilityZeroWhenNone() {
        let (manager, state, unusedController) = makeManager()
        let facility = placeFacility(type: .hideout, x: 4, y: 9, state: state)
        let controller = makeController(state: state)
        controller.collision.rebuildSpatialGrid()
        let count = manager.countPigsUsingFacility(facility, excludePig: nil)
        #expect(count == 0)
    }

    // MARK: - pigColorMatchesBiome Tests

    @Test("pigColorMatchesBiome returns true when pig color matches biome signature color")
    func testPigColorMatchesBiomeMatch() {
        var pig = GuineaPig.create(name: "Test", gender: .female)
        pig.phenotype = Phenotype(
            baseColor: .black,
            pattern: pig.phenotype.pattern,
            intensity: pig.phenotype.intensity,
            roan: pig.phenotype.roan,
            rarity: pig.phenotype.rarity
        )
        #expect(pigColorMatchesBiome(pig, biomeString: "meadow"))
    }

    @Test("pigColorMatchesBiome returns false when pig color does not match biome signature")
    func testPigColorMatchesBiomeMismatch() {
        var pig = GuineaPig.create(name: "Test", gender: .female)
        pig.phenotype = Phenotype(
            baseColor: .golden,
            pattern: pig.phenotype.pattern,
            intensity: pig.phenotype.intensity,
            roan: pig.phenotype.roan,
            rarity: pig.phenotype.rarity
        )
        #expect(!pigColorMatchesBiome(pig, biomeString: "meadow"))
    }

    @Test("pigColorMatchesBiome returns false for an unknown biome string")
    func testPigColorMatchesBiomeUnknownBiome() {
        let pig = GuineaPig.create(name: "Test", gender: .female)
        #expect(!pigColorMatchesBiome(pig, biomeString: "unknown_biome"))
    }
}
