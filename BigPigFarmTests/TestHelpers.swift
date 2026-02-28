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

// MARK: - Multi-Room Grid Helpers

/// Create a two-room horizontal farm grid for tunnel/area tests.
func makeTwoRoomGrid() -> FarmGrid {
    var grid = FarmGrid(width: 140, height: 40)
    let left = FarmArea(
        id: UUID(), name: "Left", biome: .meadow,
        x1: 0, y1: 0, x2: 61, y2: 36,
        gridCol: 0, gridRow: 0
    )
    let right = FarmArea(
        id: UUID(), name: "Right", biome: .burrow,
        x1: 69, y1: 0, x2: 130, y2: 36,
        gridCol: 1, gridRow: 0
    )
    grid.addArea(left)
    grid.addArea(right)
    return grid
}

/// Create a two-room stacked farm grid for vertical tunnel tests.
func makeStackedRoomGrid() -> FarmGrid {
    var grid = FarmGrid(width: 70, height: 85)
    let top = FarmArea(
        id: UUID(), name: "Top", biome: .meadow,
        x1: 0, y1: 0, x2: 61, y2: 36,
        gridCol: 0, gridRow: 0
    )
    let bottom = FarmArea(
        id: UUID(), name: "Bottom", biome: .garden,
        x1: 0, y1: 44, x2: 61, y2: 80,
        gridCol: 0, gridRow: 1
    )
    grid.addArea(top)
    grid.addArea(bottom)
    return grid
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
