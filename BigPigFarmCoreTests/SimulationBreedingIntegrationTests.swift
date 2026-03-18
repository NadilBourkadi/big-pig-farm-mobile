/// SimulationBreedingIntegrationTests — Integration tests for breeding, birth, and economy.
///
/// Tests wire up the full simulation stack and verify that cross-system breeding
/// flows (courtship → pregnancy → birth) and economy flows (sale → money) work
/// correctly over multiple ticks, without any SpriteKit rendering.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Pregnancy Advancement

/// Verify that Birth.advancePregnancies is called each tick by SimulationRunner,
/// advancing pregnancyDays forward from zero.
@Test @MainActor func simulationPregnancyAdvancesOverTicks() throws {
    let state = GameState()
    state.farm = FarmGrid.createStarter()

    var male = GuineaPig.create(name: "Dad", gender: .male)
    male.ageDays = 5.0
    male.position = Position(x: 8.0, y: 10.0)

    var female = GuineaPig.create(name: "Mum", gender: .female)
    female.ageDays = 5.0
    female.position = Position(x: 10.0, y: 10.0)
    female.isPregnant = true
    female.pregnancyDays = 0.0
    female.partnerGenotype = male.genotype
    female.partnerName = male.name
    female.partnerId = male.id

    state.addGuineaPig(male)
    state.addGuineaPig(female)

    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(state: state, behaviorController: controller, saveManager: makeTempSaveManager())
    let femaleId = female.id

    runTicks(runner, state: state, count: 5, gameMinutesPerTick: 6.0)

    let updatedFemale = try #require(state.getGuineaPig(femaleId))
    // Either still pregnant with advanced days, or birth already fired
    if updatedFemale.isPregnant {
        #expect(updatedFemale.pregnancyDays > 0.0)
    } else {
        // Birth fired — pregnancyDays reset to 0
        #expect(state.totalPigsBorn > 0)
    }
}

// MARK: - Birth

/// Verify that a pig at near-term pregnancy gives birth within a few ticks.
///
/// Female starts at pregnancyDays=1.9 (gestationDays=2.0). Each tick advances by
/// gameHours/24 = (30/60)/24 ≈ 0.021 game-days. After 5 ticks: 1.9+0.104 >= 2.0.
/// Birth.checkBirths fires inside Breeding.checkBreedingOpportunities (processEconomyPhase).
@Test @MainActor func simulationBirthOccursAfterGestation() {
    let state = GameState()
    state.farm = FarmGrid.createStarter()

    var male = GuineaPig.create(name: "Dad", gender: .male)
    male.ageDays = 5.0
    male.position = Position(x: 8.0, y: 10.0)

    var female = GuineaPig.create(name: "Mum", gender: .female)
    female.ageDays = 5.0
    female.position = Position(x: 10.0, y: 10.0)
    female.isPregnant = true
    female.pregnancyDays = 1.9
    female.partnerGenotype = male.genotype
    female.partnerName = male.name
    female.partnerId = male.id

    state.addGuineaPig(male)
    state.addGuineaPig(female)

    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(state: state, behaviorController: controller, saveManager: makeTempSaveManager())

    runTicks(runner, state: state, count: 5, gameMinutesPerTick: 30.0)

    #expect(state.pigCount > 2)
    #expect(state.totalPigsBorn > 0)
}

/// Verify that a birth event is logged with eventType "birth".
@Test @MainActor func simulationBirthEventLogged() {
    let state = GameState()
    state.farm = FarmGrid.createStarter()

    var male = GuineaPig.create(name: "Dad", gender: .male)
    male.ageDays = 5.0
    male.position = Position(x: 8.0, y: 10.0)

    var female = GuineaPig.create(name: "Mum", gender: .female)
    female.ageDays = 5.0
    female.position = Position(x: 10.0, y: 10.0)
    female.isPregnant = true
    female.pregnancyDays = 1.9
    female.partnerGenotype = male.genotype
    female.partnerName = male.name
    female.partnerId = male.id

    state.addGuineaPig(male)
    state.addGuineaPig(female)

    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(state: state, behaviorController: controller, saveManager: makeTempSaveManager())

    runTicks(runner, state: state, count: 5, gameMinutesPerTick: 30.0)

    let birthEvents = state.events.filter { $0.eventType == "birth" }
    #expect(!birthEvents.isEmpty)
}

// MARK: - Courtship

/// Verify that manually-initiated courtship completes when pigs are adjacent.
///
/// The courtship timer advances by gameMinutes when the initiator pig has an
/// empty path and is within minPigDistance+2.0 (=5.0) cells of partner.
/// courtshipTogetherSeconds = 4.0 game-minutes.
/// Pre-loading courtingTimer to 3.9 means one tick at 1.0 game-min completes it.
/// The decision timer won't fire on tick 1 (initial random(0,1) + 1.0 < 2.0).
@Test @MainActor func simulationCourtshipCompletesWhenAdjacent() throws {
    let state = GameState()
    state.farm = FarmGrid.createStarter()

    var male = GuineaPig.create(name: "Romeo", gender: .male)
    male.ageDays = 5.0
    male.needs.happiness = 80.0
    male.position = Position(x: 8.0, y: 10.0)
    male.path = []

    var female = GuineaPig.create(name: "Juliet", gender: .female)
    female.ageDays = 5.0
    female.needs.happiness = 80.0
    female.position = Position(x: 10.0, y: 10.0)
    female.path = []

    // Pre-wire courtship state — timer just below threshold (4.0)
    male.behaviorState = .courting
    male.courtingPartnerId = female.id
    male.courtingInitiator = true
    male.courtingTimer = 3.9

    female.behaviorState = .courting
    female.courtingPartnerId = male.id
    female.courtingInitiator = false
    female.courtingTimer = 3.9

    state.addGuineaPig(male)
    state.addGuineaPig(female)

    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(state: state, behaviorController: controller, saveManager: makeTempSaveManager())
    let femaleId = female.id

    // One tick at 1.0 game-min: timer goes 3.9 + 1.0 = 4.9 >= 4.0, courtship completes
    runTicks(runner, state: state, count: 1, gameMinutesPerTick: 1.0)

    let updatedFemale = try #require(state.getGuineaPig(femaleId))
    // Female is now pregnant (courtship completed → startPregnancyFromCourtship)
    // or at minimum the courtship has been processed
    let breedingEvents = state.events.filter { $0.eventType == "breeding" }
    #expect(updatedFemale.isPregnant || !breedingEvents.isEmpty)
}

// MARK: - Economy

/// Verify that selling a pig marked for sale increments money and removes the pig.
///
/// Culling.sellMarkedAdults processes marked adults each tick via processEconomyPhase.
/// Pig must be adult (ageDays >= 3) — babies are skipped until adulthood.
@Test @MainActor func simulationSellingMarkedAdultIncrementsMoney() {
    let state = GameState()
    state.farm = FarmGrid.createStarter()
    state.money = 0

    var pig = GuineaPig.create(name: "ForSale", gender: .female)
    pig.ageDays = 5.0
    pig.markedForSale = true
    state.addGuineaPig(pig)

    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(state: state, behaviorController: controller, saveManager: makeTempSaveManager())

    runTicks(runner, state: state, count: 1)

    #expect(state.money > 0)
    #expect(state.pigCount == 0)
    #expect(state.totalPigsSold == 1)
}

/// Verify that selling multiple marked adults in one tick works correctly.
@Test @MainActor func simulationEconomyFlowSellMultiplePigs() {
    let (state, runner) = makeIntegrationState(pigCount: 4, money: 0)

    for var pig in state.getPigsList() {
        pig.markedForSale = true
        state.updateGuineaPig(pig)
    }

    runTicks(runner, state: state, count: 1)

    #expect(state.money > 0)
    #expect(state.totalPigsSold == 4)
    #expect(state.pigCount == 0)
}

// MARK: - State Coherence

/// Verify that after 200 ticks all pig needs are in [0, 100] and all positions
/// are in grid bounds — a general regression guard against state corruption.
@Test @MainActor func simulationStateCoherenceAfterManyTicks() {
    let (state, runner) = makeIntegrationState(
        pigCount: 5,
        addFood: true,
        addWater: true,
        addHideout: true
    )

    runTicks(runner, state: state, count: 200)

    let farm = state.farm
    for pig in state.getPigsList() {
        #expect(pig.needs.hunger >= 0.0 && pig.needs.hunger <= 100.0)
        #expect(pig.needs.thirst >= 0.0 && pig.needs.thirst <= 100.0)
        #expect(pig.needs.energy >= 0.0 && pig.needs.energy <= 100.0)
        #expect(pig.needs.happiness >= 0.0 && pig.needs.happiness <= 100.0)
        #expect(pig.position.x >= 0 && pig.position.x < Double(farm.width))
        #expect(pig.position.y >= 0 && pig.position.y < Double(farm.height))
        // Orphaned courtship references must not exist
        if let partnerId = pig.courtingPartnerId {
            let partnerExists = state.getGuineaPig(partnerId) != nil
            let pigStillCourting = pig.behaviorState == .courting
            #expect(!pigStillCourting || partnerExists,
                "\(pig.name) is courting a non-existent pig \(partnerId)")
        }
    }
}
