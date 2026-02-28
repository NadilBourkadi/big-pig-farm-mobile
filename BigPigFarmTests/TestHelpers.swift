/// TestHelpers — Shared factory helpers for test files.
import Foundation
@testable import BigPigFarm

@MainActor
func makeGameState(withArea: Bool = true) -> GameState {
    let state = GameState()
    if withArea {
        state.farm = FarmGrid.createStarter()
    }
    return state
}

@MainActor
func makeController(state: GameState) -> BehaviorController {
    BehaviorController(gameState: state)
}

@MainActor
func makePig(x: Double = 5.0, y: Double = 5.0) -> GuineaPig {
    var pig = GuineaPig.create(name: "Test", gender: .female)
    pig.position = Position(x: x, y: y)
    pig.behaviorState = .wandering
    return pig
}

/// Create a test pig with explicit behavior state and path.
@MainActor
func makePigAt(
    x: Double, y: Double,
    state: BehaviorState = .idle,
    path: [GridPosition] = []
) -> GuineaPig {
    var pig = GuineaPig.create(name: "Test", gender: .female)
    pig.position = Position(x: x, y: y)
    pig.behaviorState = state
    pig.path = path
    return pig
}
