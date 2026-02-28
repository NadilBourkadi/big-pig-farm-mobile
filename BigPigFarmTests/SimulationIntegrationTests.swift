/// SimulationIntegrationTests — Multi-system headless simulation integration tests.
///
/// Each test wires up a complete GameState + BehaviorController + SimulationRunner
/// and runs N ticks to verify emergent cross-system behavior, without any SpriteKit
/// rendering or UI layer.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Stability

/// Verify the full simulation stack runs 100 ticks with 6 pigs without crashing
/// and leaves the farm in a coherent state (at least 1 pig, all positions valid).
@Test @MainActor func simulationFullRunNoCrash() {
    let (state, runner) = makeIntegrationState(
        pigCount: 6,
        addFood: true,
        addWater: true,
        addHideout: true
    )
    runTicks(runner, state: state, count: 100)

    #expect(state.pigCount >= 1)
    let farm = state.farm
    for pig in state.getPigsList() {
        #expect(pig.position.x >= 0)
        #expect(pig.position.x < Double(farm.width))
        #expect(pig.position.y >= 0)
        #expect(pig.position.y < Double(farm.height))
    }
}

// MARK: - Movement

/// Verify that pigs move from their initial positions after 50 ticks.
///
/// The decision timer fires after ~7 ticks (2.0 game-min threshold / 0.3 per tick),
/// at which point BehaviorDecision assigns wandering targets. At least one pig
/// should have a different position after 50 ticks (15 game-minutes).
@Test @MainActor func simulationPigsChangePositionAfterTicks() {
    let (state, runner) = makeIntegrationState(pigCount: 3)
    let initialPositions = state.getPigsList().map { ($0.id, $0.position) }

    runTicks(runner, state: state, count: 50)

    let movedCount = initialPositions.filter { pigId, initial in
        guard let current = state.getGuineaPig(pigId) else { return false }
        return current.position.distanceTo(initial) > 0.1
    }.count
    #expect(movedCount >= 1)
}

// MARK: - Needs Decay

/// Verify that needs decay over time when no food or water facilities exist.
///
/// 100 ticks at 6.0 game-min/tick = 600 game-minutes = 10 game-hours.
/// With hungerDecay=0.6/hr and thirstDecay=0.8/hr, needs drop measurably.
/// No facilities means no recovery can mask the decay.
@Test @MainActor func simulationNeedsDecayAfterManyTicks() {
    let (state, runner) = makeIntegrationState(pigCount: 2, addFood: false, addWater: false)
    let initialNeeds = state.getPigsList().map { ($0.id, $0.needs.hunger, $0.needs.thirst) }

    runTicks(runner, state: state, count: 100, gameMinutesPerTick: 6.0)

    for (pigId, initialHunger, initialThirst) in initialNeeds {
        guard let pig = state.getGuineaPig(pigId) else { continue }
        #expect(pig.needs.hunger < initialHunger)
        #expect(pig.needs.thirst < initialThirst)
        // All needs must stay in the valid clamped range
        #expect(pig.needs.hunger >= 0.0 && pig.needs.hunger <= 100.0)
        #expect(pig.needs.thirst >= 0.0 && pig.needs.thirst <= 100.0)
        #expect(pig.needs.energy >= 0.0 && pig.needs.energy <= 100.0)
    }
}

// MARK: - Game Time

/// Verify that GameTime advances correctly when manually driven in integration tests.
///
/// GameTime.advance(minutes:) stores minute as Int, so sub-minute tick values lose
/// fractions across calls. Using whole-minute tick increments keeps the clock accurate.
/// 60 ticks at 1.0 game-min/tick = 60 game-minutes total.
/// Starting at hour 8, 60 minutes later should be hour 9.
@Test @MainActor func simulationGameTimeAdvancesCorrectly() {
    let (state, runner) = makeIntegrationState(pigCount: 1)

    runTicks(runner, state: state, count: 60, gameMinutesPerTick: 1.0)

    #expect(abs(state.gameTime.totalGameMinutes - 60.0) < 0.01)
    #expect(state.gameTime.hour == 9)
    #expect(state.gameTime.minute == 0)
}

// MARK: - Bounds

/// Verify that the collision + rescue system keeps all pigs within farm bounds
/// after 100 ticks of movement, separation forces, and pathfinding.
@Test @MainActor func simulationPigPositionsStayInBounds() {
    let (state, runner) = makeIntegrationState(pigCount: 5)
    runTicks(runner, state: state, count: 100)

    let farm = state.farm
    for pig in state.getPigsList() {
        #expect(pig.position.x >= 0, "Pig \(pig.name) x < 0")
        #expect(pig.position.x < Double(farm.width), "Pig \(pig.name) x >= width")
        #expect(pig.position.y >= 0, "Pig \(pig.name) y < 0")
        #expect(pig.position.y < Double(farm.height), "Pig \(pig.name) y >= height")
    }
}

// MARK: - Contracts

/// Verify that the contract board is populated during simulation.
///
/// On the first tick, checkContractRefresh finds an empty board and fills it.
/// The starter farm has one meadow area, so ContractGenerator has a valid biome.
@Test @MainActor func simulationContractBoardPopulates() {
    let (state, runner) = makeIntegrationState(pigCount: 2)
    #expect(state.contractBoard.activeContracts.isEmpty)

    runTicks(runner, state: state, count: 3)

    #expect(!state.contractBoard.activeContracts.isEmpty)
    #expect(state.contractBoard.lastRefreshDay == state.gameTime.day)
}
