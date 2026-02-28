/// AutoResourcesTests — Unit tests for AutoResources drip/AoE/veggie systems.
/// Maps from: simulation/auto_resources.py
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - tickAutoResources

@Test @MainActor func tickAutoResourcesNoOpWithoutUpgrades() {
    let state = makeGameState()
    var bowl = Facility.create(type: .foodBowl, x: 5, y: 5)
    bowl.currentAmount = 50.0
    state.facilities[bowl.id] = bowl

    AutoResources.tickAutoResources(state: state, gameHours: 1.0)

    #expect(state.facilities[bowl.id]!.currentAmount == 50.0)
}

@Test @MainActor func tickAutoResourcesDripRefillsGradually() {
    let state = makeGameState()
    state.purchasedUpgrades.insert("drip_system")
    var bowl = Facility.create(type: .foodBowl, x: 5, y: 5)
    bowl.currentAmount = 50.0
    bowl.maxAmount = 200.0
    state.facilities[bowl.id] = bowl

    AutoResources.tickAutoResources(state: state, gameHours: 1.0)

    #expect(state.facilities[bowl.id]!.currentAmount == 52.0)
}

@Test @MainActor func tickAutoResourcesDripClampsToMax() {
    let state = makeGameState()
    state.purchasedUpgrades.insert("drip_system")
    var bowl = Facility.create(type: .foodBowl, x: 5, y: 5)
    bowl.currentAmount = 199.5
    bowl.maxAmount = 200.0
    state.facilities[bowl.id] = bowl

    AutoResources.tickAutoResources(state: state, gameHours: 1.0)

    #expect(state.facilities[bowl.id]!.currentAmount == 200.0)
}

@Test @MainActor func tickAutoResourcesAutoFeederRefillsWhenLow() {
    let state = makeGameState()
    state.purchasedUpgrades.insert("auto_feeders")
    var bowl = Facility.create(type: .foodBowl, x: 5, y: 5)
    // 24% fill (below 25% threshold)
    bowl.maxAmount = 200.0
    bowl.currentAmount = 48.0
    state.facilities[bowl.id] = bowl

    AutoResources.tickAutoResources(state: state, gameHours: 1.0)

    #expect(state.facilities[bowl.id]!.currentAmount == 200.0)
}

@Test @MainActor func tickAutoResourcesAutoFeederSkipsAboveThreshold() {
    let state = makeGameState()
    state.purchasedUpgrades.insert("auto_feeders")
    var bowl = Facility.create(type: .foodBowl, x: 5, y: 5)
    // 26% fill (above 25% threshold)
    bowl.maxAmount = 200.0
    bowl.currentAmount = 52.0
    state.facilities[bowl.id] = bowl

    AutoResources.tickAutoResources(state: state, gameHours: 1.0)

    #expect(state.facilities[bowl.id]!.currentAmount == 52.0)
}

@Test @MainActor func tickAutoResourcesDripThenAutoFeeder() {
    // With both upgrades: drip applies first. If drip pushes above 25%, auto-feeder skips.
    let state = makeGameState()
    state.purchasedUpgrades.insert("drip_system")
    state.purchasedUpgrades.insert("auto_feeders")
    var bowl = Facility.create(type: .foodBowl, x: 5, y: 5)
    // Start at 24% — below threshold. Drip of 2.0 on maxAmount=200 will push to 26% → no auto-fill.
    bowl.maxAmount = 200.0
    bowl.currentAmount = 48.0
    state.facilities[bowl.id] = bowl

    AutoResources.tickAutoResources(state: state, gameHours: 1.0)

    // Drip adds 2.0 → 50.0; 50/200 = 25.0% which is NOT below threshold (< 25.0 is false)
    #expect(state.facilities[bowl.id]!.currentAmount == 50.0)
}

@Test @MainActor func tickAutoResourcesSkipsNonFoodWaterTypes() {
    let state = makeGameState()
    state.purchasedUpgrades.insert("drip_system")
    state.purchasedUpgrades.insert("auto_feeders")
    let hideout = Facility.create(type: .hideout, x: 5, y: 5)
    state.facilities[hideout.id] = hideout
    let initialAmount = state.facilities[hideout.id]!.currentAmount

    AutoResources.tickAutoResources(state: state, gameHours: 1.0)

    #expect(state.facilities[hideout.id]!.currentAmount == initialAmount)
}

@Test @MainActor func tickAutoResourcesNoOpWithEmptyFacilities() {
    let state = makeGameState()
    state.purchasedUpgrades.insert("drip_system")

    // Should not crash with no facilities
    AutoResources.tickAutoResources(state: state, gameHours: 1.0)
}

// MARK: - applyBulkFeeders

@Test @MainActor func applyBulkFeedersDoublesCapacityAndCurrent() {
    let state = makeGameState()
    var bowl = Facility.create(type: .foodBowl, x: 5, y: 5)
    bowl.maxAmount = 200.0
    bowl.currentAmount = 100.0
    state.facilities[bowl.id] = bowl

    AutoResources.applyBulkFeeders(state: state)

    #expect(state.facilities[bowl.id]!.maxAmount == 400.0)
    #expect(state.facilities[bowl.id]!.currentAmount == 200.0)
}

@Test @MainActor func applyBulkFeedersSkipsNonFoodWaterTypes() {
    let state = makeGameState()
    let hideout = Facility.create(type: .hideout, x: 5, y: 5)
    state.facilities[hideout.id] = hideout
    let initialMax = state.facilities[hideout.id]!.maxAmount
    let initialCurrent = state.facilities[hideout.id]!.currentAmount

    AutoResources.applyBulkFeeders(state: state)

    #expect(state.facilities[hideout.id]!.maxAmount == initialMax)
    #expect(state.facilities[hideout.id]!.currentAmount == initialCurrent)
}

@Test @MainActor func applyBulkFeedersNoOpWhenNoFacilities() {
    let state = makeGameState()
    // Should not crash with empty facilities
    AutoResources.applyBulkFeeders(state: state)
}

// MARK: - tickVeggieGardens

@Test @MainActor func tickVeggieGardensDistributesFoodEvenly() {
    let state = makeGameState()
    let garden = Facility.create(type: .veggieGarden, x: 0, y: 0)
    state.facilities[garden.id] = garden

    var bowl1 = Facility.create(type: .foodBowl, x: 5, y: 5)
    bowl1.currentAmount = 0.0
    bowl1.maxAmount = 200.0
    state.facilities[bowl1.id] = bowl1

    var bowl2 = Facility.create(type: .foodBowl, x: 10, y: 5)
    bowl2.currentAmount = 0.0
    bowl2.maxAmount = 200.0
    state.facilities[bowl2.id] = bowl2

    AutoResources.tickVeggieGardens(state: state, gameHours: 1.0)

    // foodProduction = 10, gameHours = 1.0, 2 targets → 5.0 each
    #expect(state.facilities[bowl1.id]!.currentAmount == 5.0)
    #expect(state.facilities[bowl2.id]!.currentAmount == 5.0)
}

@Test @MainActor func tickVeggieGardensSkipsFullFacilities() {
    let state = makeGameState()
    let garden = Facility.create(type: .veggieGarden, x: 0, y: 0)
    state.facilities[garden.id] = garden

    // bowl1 is full — should be excluded
    let bowl1 = Facility.create(type: .foodBowl, x: 5, y: 5)
    state.facilities[bowl1.id] = bowl1

    var bowl2 = Facility.create(type: .foodBowl, x: 10, y: 5)
    bowl2.currentAmount = 0.0
    bowl2.maxAmount = 200.0
    state.facilities[bowl2.id] = bowl2

    AutoResources.tickVeggieGardens(state: state, gameHours: 1.0)

    // bowl1 stays full; bowl2 gets all 10.0 units
    #expect(state.facilities[bowl1.id]!.currentAmount == state.facilities[bowl1.id]!.maxAmount)
    #expect(state.facilities[bowl2.id]!.currentAmount == 10.0)
}

@Test @MainActor func tickVeggieGardensNoOpWithoutGardens() {
    let state = makeGameState()
    var bowl = Facility.create(type: .foodBowl, x: 5, y: 5)
    bowl.currentAmount = 50.0
    bowl.maxAmount = 200.0
    state.facilities[bowl.id] = bowl

    AutoResources.tickVeggieGardens(state: state, gameHours: 1.0)

    #expect(state.facilities[bowl.id]!.currentAmount == 50.0)
}

@Test @MainActor func tickVeggieGardensNoOpWithoutFoodFacilities() {
    let state = makeGameState()
    let garden = Facility.create(type: .veggieGarden, x: 0, y: 0)
    state.facilities[garden.id] = garden

    // No food facilities — should not crash
    AutoResources.tickVeggieGardens(state: state, gameHours: 1.0)
}

@Test @MainActor func tickVeggieGardensMultipleGardensAccumulate() {
    let state = makeGameState()
    let garden1 = Facility.create(type: .veggieGarden, x: 0, y: 0)
    state.facilities[garden1.id] = garden1
    let garden2 = Facility.create(type: .veggieGarden, x: 4, y: 0)
    state.facilities[garden2.id] = garden2

    var bowl = Facility.create(type: .foodBowl, x: 5, y: 5)
    bowl.currentAmount = 0.0
    bowl.maxAmount = 200.0
    state.facilities[bowl.id] = bowl

    AutoResources.tickVeggieGardens(state: state, gameHours: 1.0)

    // garden1 produces 10.0 → bowl gets 10.0; garden2 produces 10.0 → bowl gets 10.0 more
    #expect(state.facilities[bowl.id]!.currentAmount == 20.0)
}

@Test @MainActor func tickVeggieGardensDoesNotOverfill() {
    let state = makeGameState()
    let garden = Facility.create(type: .veggieGarden, x: 0, y: 0)
    state.facilities[garden.id] = garden

    var bowl = Facility.create(type: .foodBowl, x: 5, y: 5)
    bowl.currentAmount = 198.0
    bowl.maxAmount = 200.0
    state.facilities[bowl.id] = bowl

    AutoResources.tickVeggieGardens(state: state, gameHours: 1.0)

    // Refill clamps to maxAmount
    #expect(state.facilities[bowl.id]!.currentAmount == 200.0)
}

// MARK: - tickAoEFacilities

@Test @MainActor func tickAoEFacilitiesNoPigsNoOp() {
    let state = makeGameState()
    let stage = Facility.create(type: .stage, x: 5, y: 5)
    state.facilities[stage.id] = stage

    // Should not crash with no pigs
    AutoResources.tickAoEFacilities(state: state, gameHours: 1.0)
}

@Test @MainActor func tickAoEFacilitiesNoStagesNoOp() {
    let state = makeGameState()
    var pig = makePig(x: 5.0, y: 5.0)
    pig.behaviorState = .idle
    state.addGuineaPig(pig)

    // Should not crash with no stages
    AutoResources.tickAoEFacilities(state: state, gameHours: 1.0)
}

@Test @MainActor func tickAoEFacilitiesNoPerformerNoEffect() {
    let state = makeGameState()
    let stage = Facility.create(type: .stage, x: 5, y: 5)
    state.facilities[stage.id] = stage

    // Pig is near stage but NOT performing
    var pig = makePig(x: 8.0, y: 8.0)
    pig.behaviorState = .idle
    pig.needs.happiness = 50.0
    state.addGuineaPig(pig)

    AutoResources.tickAoEFacilities(state: state, gameHours: 1.0)

    #expect(state.getGuineaPig(pig.id)!.needs.happiness == 50.0)
}

@Test @MainActor func tickAoEFacilitiesAudienceGetsBonus() {
    let state = makeGameState()
    let stage = Facility.create(type: .stage, x: 5, y: 5)
    state.facilities[stage.id] = stage

    // Performer at stage
    var performer = makePig(x: 8.0, y: 8.0)
    performer.behaviorState = .playing
    performer.targetFacilityId = stage.id
    performer.needs.happiness = 50.0
    state.addGuineaPig(performer)

    // Audience pig — within 6 cells of stage center (8.0, 8.0)
    // Stage center for a 6x6 stage at (5,5): X=5+3=8.0, Y=5+3=8.0
    // Pig at (10.0, 8.0): distance = 2.0 → within radius
    var audience = makePig(x: 10.0, y: 8.0)
    audience.behaviorState = .idle
    audience.needs.happiness = 60.0
    audience.needs.social = 40.0
    state.addGuineaPig(audience)

    AutoResources.tickAoEFacilities(state: state, gameHours: 1.0)

    let updatedAudience = state.getGuineaPig(audience.id)!
    #expect(updatedAudience.needs.happiness == 62.0)
    #expect(updatedAudience.needs.social == 41.5)
}

@Test @MainActor func tickAoEFacilitiesPerformerExcluded() {
    let state = makeGameState()
    let stage = Facility.create(type: .stage, x: 5, y: 5)
    state.facilities[stage.id] = stage

    // Performer at stage center
    var performer = makePig(x: 8.0, y: 8.0)
    performer.behaviorState = .playing
    performer.targetFacilityId = stage.id
    performer.needs.happiness = 60.0
    performer.needs.social = 40.0
    state.addGuineaPig(performer)

    AutoResources.tickAoEFacilities(state: state, gameHours: 1.0)

    // Performer should NOT get the audience bonus
    let updatedPerformer = state.getGuineaPig(performer.id)!
    #expect(updatedPerformer.needs.happiness == 60.0)
    #expect(updatedPerformer.needs.social == 40.0)
}

@Test @MainActor func tickAoEFacilitiesPigOutsideRadiusUnaffected() {
    let state = makeGameState()
    let stage = Facility.create(type: .stage, x: 0, y: 0)
    state.facilities[stage.id] = stage

    // Performer at stage
    var performer = makePig(x: 3.0, y: 3.0)
    performer.behaviorState = .playing
    performer.targetFacilityId = stage.id
    state.addGuineaPig(performer)

    // Stage center: (0+3, 0+3) = (3.0, 3.0). Pig at (20.0, 20.0): far outside radius.
    var farPig = makePig(x: 20.0, y: 20.0)
    farPig.behaviorState = .idle
    farPig.needs.happiness = 50.0
    state.addGuineaPig(farPig)

    AutoResources.tickAoEFacilities(state: state, gameHours: 1.0)

    #expect(state.getGuineaPig(farPig.id)!.needs.happiness == 50.0)
}

@Test @MainActor func tickAoEFacilitiesBonusClampedTo100() {
    let state = makeGameState()
    let stage = Facility.create(type: .stage, x: 5, y: 5)
    state.facilities[stage.id] = stage

    var performer = makePig(x: 8.0, y: 8.0)
    performer.behaviorState = .playing
    performer.targetFacilityId = stage.id
    state.addGuineaPig(performer)

    // Audience pig near stage with near-max happiness
    var audience = makePig(x: 10.0, y: 8.0)
    audience.behaviorState = .idle
    audience.needs.happiness = 99.5
    state.addGuineaPig(audience)

    AutoResources.tickAoEFacilities(state: state, gameHours: 1.0)

    #expect(state.getGuineaPig(audience.id)!.needs.happiness == 100.0)
}

@Test @MainActor func tickAoEFacilitiesBonusScalesWithGameHours() {
    let state = makeGameState()
    let stage = Facility.create(type: .stage, x: 5, y: 5)
    state.facilities[stage.id] = stage

    var performer = makePig(x: 8.0, y: 8.0)
    performer.behaviorState = .playing
    performer.targetFacilityId = stage.id
    state.addGuineaPig(performer)

    var audience = makePig(x: 10.0, y: 8.0)
    audience.behaviorState = .idle
    audience.needs.happiness = 50.0
    audience.needs.social = 30.0
    state.addGuineaPig(audience)

    // 3 game hours → happiness +6.0, social +4.5
    AutoResources.tickAoEFacilities(state: state, gameHours: 3.0)

    let updated = state.getGuineaPig(audience.id)!
    #expect(updated.needs.happiness == 56.0)
    #expect(updated.needs.social == 34.5)
}
