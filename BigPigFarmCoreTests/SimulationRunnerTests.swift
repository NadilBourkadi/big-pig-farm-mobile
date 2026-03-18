/// SimulationRunnerTests — Unit tests for SimulationRunner tick orchestration.
import Testing
import Foundation
@testable import BigPigFarmCore

// MARK: - Initialization

@Test @MainActor func simulationRunnerInitializes() {
    let state = GameState()
    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(state: state, behaviorController: controller, saveManager: makeTempSaveManager())
    #expect(runner.currentTPS == 0.0)
}

// MARK: - TPS Measurement

@Test @MainActor func tpsMeasurementAfterMultipleTicks() {
    let state = GameState()
    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(state: state, behaviorController: controller, saveManager: makeTempSaveManager())
    for _ in 0..<10 {
        runner.tick(gameMinutes: 0.3)
    }
    #expect(runner.currentTPS > 0.0)
}

@Test @MainActor func tpsWindowCappedAtMaxTimestamps() {
    let state = GameState()
    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(state: state, behaviorController: controller, saveManager: makeTempSaveManager())
    // Run well past the 50-timestamp window — should not crash or allocate unboundedly
    for _ in 0..<100 {
        runner.tick(gameMinutes: 0.3)
    }
    #expect(runner.currentTPS > 0.0)
}

// MARK: - Empty Farm

@Test @MainActor func tickWithNoPigsDoesNotCrash() {
    let state = GameState()
    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(state: state, behaviorController: controller, saveManager: makeTempSaveManager())
    for _ in 0..<100 {
        runner.tick(gameMinutes: 0.3)
    }
    #expect(runner.currentTPS > 0.0)
}

// MARK: - Breeding Throttle

@Test @MainActor func breedingThrottleResetsAfterInterval() {
    let state = GameState()
    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(state: state, behaviorController: controller, saveManager: makeTempSaveManager())
    // 20 ticks = 2 full breeding-check cycles (interval = 10); must not crash
    for _ in 0..<20 {
        runner.tick(gameMinutes: 0.3)
    }
    // TPS should be measurable after 20 ticks
    #expect(runner.currentTPS > 0.0)
}

// MARK: - Auto-Save Counter

@Test @MainActor func autoSaveCounterOver300Ticks() {
    let state = GameState()
    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(state: state, behaviorController: controller, saveManager: makeTempSaveManager())
    for _ in 0..<300 {
        runner.tick(gameMinutes: 0.3)
    }
    // Should not crash; save counter resets at 300
    #expect(runner.currentTPS > 0.0)
}

@Test @MainActor func autoSaveTriggersAfter300Ticks() {
    let state = makeGameState()
    let controller = makeController(state: state)
    let runner = SimulationRunner(state: state, behaviorController: controller, saveManager: makeTempSaveManager())
    #expect(state.lastSave == nil)
    for _ in 0..<300 {
        runner.tick(gameMinutes: 0.3)
    }
    #expect(state.lastSave != nil)
}

@Test @MainActor func autoSaveDoesNotTriggerBefore300Ticks() {
    let state = makeGameState()
    let controller = makeController(state: state)
    let runner = SimulationRunner(state: state, behaviorController: controller, saveManager: makeTempSaveManager())
    for _ in 0..<299 {
        runner.tick(gameMinutes: 0.3)
    }
    #expect(state.lastSave == nil)
}

@Test @MainActor func autoSaveCounterResetsAfterTrigger() throws {
    let state = makeGameState()
    let controller = makeController(state: state)
    let runner = SimulationRunner(state: state, behaviorController: controller, saveManager: makeTempSaveManager())
    for _ in 0..<300 {
        runner.tick(gameMinutes: 0.3)
    }
    let firstSave = try #require(state.lastSave)
    for _ in 0..<300 {
        runner.tick(gameMinutes: 0.3)
    }
    let secondSave = try #require(state.lastSave)
    #expect(secondSave >= firstSave)
}

// MARK: - Farm Bell

@Test @MainActor func farmBellLogsWhenCriticalHunger() {
    let state = GameState()
    state.purchasedUpgrades.insert("farm_bell")
    var pig = GuineaPig.create(name: "TestPig", gender: .male)
    pig.needs.hunger = 5.0  // Below criticalThreshold (20)
    state.addGuineaPig(pig)
    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(state: state, behaviorController: controller, saveManager: makeTempSaveManager())
    runner.tick(gameMinutes: 0.3)
    let farmBellEvents = state.events.filter { $0.eventType == "farm_bell" }
    #expect(!farmBellEvents.isEmpty)
}

@Test @MainActor func farmBellSkippedWithoutPerk() {
    let state = GameState()
    var pig = GuineaPig.create(name: "TestPig", gender: .male)
    pig.needs.hunger = 5.0
    state.addGuineaPig(pig)
    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(state: state, behaviorController: controller, saveManager: makeTempSaveManager())
    runner.tick(gameMinutes: 0.3)
    let farmBellEvents = state.events.filter { $0.eventType == "farm_bell" }
    #expect(farmBellEvents.isEmpty)
}

@Test @MainActor func farmBellThrottledToOncePerGameHour() {
    let state = GameState()
    state.purchasedUpgrades.insert("farm_bell")
    var pig = GuineaPig.create(name: "TestPig", gender: .male)
    pig.needs.hunger = 5.0
    state.addGuineaPig(pig)
    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(state: state, behaviorController: controller, saveManager: makeTempSaveManager())
    // Two ticks in the same game-hour — only one notification
    runner.tick(gameMinutes: 0.3)
    runner.tick(gameMinutes: 0.3)
    let farmBellEvents = state.events.filter { $0.eventType == "farm_bell" }
    #expect(farmBellEvents.count == 1)
}

@Test @MainActor func farmBellNotFiredWhenNeedsOk() {
    let state = GameState()
    state.purchasedUpgrades.insert("farm_bell")
    // Pig with healthy needs — farm bell should not fire
    let pig = GuineaPig.create(name: "HealthyPig", gender: .male)
    state.addGuineaPig(pig)
    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(state: state, behaviorController: controller, saveManager: makeTempSaveManager())
    runner.tick(gameMinutes: 0.3)
    let farmBellEvents = state.events.filter { $0.eventType == "farm_bell" }
    #expect(farmBellEvents.isEmpty)
}

// MARK: - Contract Refresh

@Test @MainActor func contractBoardLastRefreshDayUpdatedOnFirstTick() {
    let state = GameState()
    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(state: state, behaviorController: controller, saveManager: makeTempSaveManager())
    #expect(state.contractBoard.lastRefreshDay == 0)
    runner.tick(gameMinutes: 0.3)
    // Board starts empty with lastRefreshDay == 0, so refresh triggers immediately
    #expect(state.contractBoard.lastRefreshDay == state.gameTime.day)
}

@Test @MainActor func contractRefreshFillsEmptyBoard() {
    let state = GameState()
    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(state: state, behaviorController: controller, saveManager: makeTempSaveManager())
    // Advance game time significantly so expiry check runs on a non-trivial day
    state.gameTime.advance(minutes: Double(60 * 24 * 15))  // 15 game-days
    runner.tick(gameMinutes: 0.3)
    // ContractGenerator now fills the board when empty
    #expect(!state.contractBoard.activeContracts.isEmpty)
    #expect(state.contractBoard.lastRefreshDay == state.gameTime.day)
}

// MARK: - Event Callbacks

@Test @MainActor func onPigSoldCallbackNotFiredWhenNoPigsForSale() {
    let state = GameState()
    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(state: state, behaviorController: controller, saveManager: makeTempSaveManager())
    var sold = false
    runner.onPigSold = { _, _, _, _ in sold = true }
    runner.tick(gameMinutes: 0.3)
    #expect(!sold)
}

@Test @MainActor func onPregnancyCallbackNotFiredWithNoPigs() {
    let state = GameState()
    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(state: state, behaviorController: controller, saveManager: makeTempSaveManager())
    var pregnancyFired = false
    runner.onPregnancy = { _, _ in pregnancyFired = true }
    runner.tick(gameMinutes: 0.3)
    #expect(!pregnancyFired)
}

@Test @MainActor func onBirthCallbackNotFiredWithNoPigs() {
    let state = GameState()
    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(state: state, behaviorController: controller, saveManager: makeTempSaveManager())
    var birthFired = false
    runner.onBirth = { _ in birthFired = true }
    runner.tick(gameMinutes: 0.3)
    #expect(!birthFired)
}

// MARK: - Acclimation Phase

@Test @MainActor func acclimationPhaseSkipsPigsWithNoPreferredBiomeAndNoTimer() throws {
    let state = GameState()
    var pig = GuineaPig.create(name: "TestPig", gender: .male)
    pig.preferredBiome = nil
    pig.acclimationTimer = 0.0
    pig.acclimatingBiome = nil
    state.addGuineaPig(pig)
    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(state: state, behaviorController: controller, saveManager: makeTempSaveManager())
    runner.tick(gameMinutes: 0.3)
    let updatedPig = try #require(state.getGuineaPig(pig.id))
    #expect(updatedPig.acclimationTimer == 0.0)
    #expect(updatedPig.acclimatingBiome == nil)
}

// MARK: - Pig Mutation Writeback

@Test @MainActor func tickWritesBackMutatedPigs() throws {
    let state = GameState()
    var pig = GuineaPig.create(name: "TestPig", gender: .male)
    pig.needs.hunger = 100.0
    state.addGuineaPig(pig)
    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(state: state, behaviorController: controller, saveManager: makeTempSaveManager())
    // After one tick at normal speed, hunger should have decayed slightly
    runner.tick(gameMinutes: 1.0)
    let updatedPig = try #require(state.getGuineaPig(pig.id))
    // Hunger should decay from 100.0 (decay rate is 0.6/hour, 1 minute = 0.01 hour)
    #expect(updatedPig.needs.hunger < 100.0)
}
