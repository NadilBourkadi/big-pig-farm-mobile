/// TickCounterTests — Validate simulationTick increments correctly per tick.
@testable import BigPigFarmCore
import Foundation
import Testing

@MainActor
struct TickCounterTests {

    @Test func tickCounterStartsAtZero() {
        let state = GameState()
        #expect(state.simulationTick == 0)
    }

    @Test func tickCounterIncrementsOncePerTick() {
        let (state, runner) = makeLargeIntegrationState(pigCount: 3)
        let before = state.simulationTick
        runTicks(runner, state: state, count: 5)
        #expect(state.simulationTick == before + 5)
    }

    @Test func advanceSimulationTickIncrementsDirectly() {
        let state = GameState()
        state.advanceSimulationTick()
        state.advanceSimulationTick()
        state.advanceSimulationTick()
        #expect(state.simulationTick == 3)
    }
}
