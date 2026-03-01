/// TestHelpers — Shared factory helpers for test files.
import Darwin
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

// MARK: - Integration Test Helpers

/// Create a fully-wired integration test rig: a GameState with a starter farm,
/// optional facilities, N adult pigs, and a running SimulationRunner.
///
/// Pig positions are placed at interior walkable cells far from facilities.
/// Alternates gender (male, female, male, ...) so breeding tests work.
@MainActor
func makeIntegrationState(
    pigCount: Int = 2,
    addFood: Bool = true,
    addWater: Bool = true,
    addHideout: Bool = false,
    money: Int = 200
) -> (GameState, SimulationRunner) {
    let state = GameState()
    state.farm = FarmGrid.createStarter()
    state.money = money

    if addFood {
        let food = Facility.create(type: .foodBowl, x: 5, y: 5)
        _ = state.addFacility(food)
    }
    if addWater {
        let water = Facility.create(type: .waterBottle, x: 10, y: 5)
        _ = state.addFacility(water)
    }
    if addHideout {
        let hideout = Facility.create(type: .hideout, x: 15, y: 5)
        _ = state.addFacility(hideout)
    }

    for i in 0..<pigCount {
        let gender: Gender = i.isMultiple(of: 2) ? .male : .female
        var pig = GuineaPig.create(name: "IntegPig\(i)", gender: gender)
        pig.ageDays = 5.0          // Adult (adultAgeDays = 3)
        pig.needs.happiness = 80.0 // Above minHappinessToBreed (70)
        pig.position = Position(x: Double(25 + (i % 3) * 5), y: Double(15 + (i / 3) * 5))
        state.addGuineaPig(pig)
    }

    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(state: state, behaviorController: controller)
    return (state, runner)
}

// MARK: - Performance Test Helpers

/// Create a large integration state with N adult pigs spread across a two-room grid.
///
/// Uses `makeTwoRoomGrid()` (140×40 with two large rooms). Each room has ~58×35
/// walkable interior cells — enough for 200+ pigs without collision saturation.
/// Alternates gender so breeding logic has valid pairs.
@MainActor
func makeLargeIntegrationState(
    pigCount: Int,
    money: Int = 1000
) -> (GameState, SimulationRunner) {
    let state = GameState()
    state.farm = makeTwoRoomGrid()
    state.money = money

    // Two food/water facilities per room so needs system can find them.
    _ = state.addFacility(Facility.create(type: .foodBowl, x: 5, y: 5))
    _ = state.addFacility(Facility.create(type: .waterBottle, x: 10, y: 5))
    _ = state.addFacility(Facility.create(type: .foodBowl, x: 80, y: 5))
    _ = state.addFacility(Facility.create(type: .waterBottle, x: 90, y: 5))

    // Spread pigs in a 10-column grid inside the left room (x: 3–48, y: 3–32).
    // 50 pigs fit in rows 0–4, 100 in rows 0–9 — all within the 37-row room.
    // addGuineaPig does not enforce capacity, so any count is accepted.
    for i in 0..<pigCount {
        let gender: Gender = i.isMultiple(of: 2) ? .male : .female
        var pig = GuineaPig.create(name: "Pig\(i)", gender: gender)
        pig.ageDays = 5.0
        pig.needs.happiness = 80.0
        pig.position = Position(
            x: 3.0 + Double(i % 10) * 5.0,
            y: 3.0 + Double(i / 10) * 3.0
        )
        state.addGuineaPig(pig)
    }

    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(state: state, behaviorController: controller)
    return (state, runner)
}

/// Resident memory usage of the current process in MB, or -1 on failure.
func memoryUsageMB() -> Double {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(
        MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
    )
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    guard result == KERN_SUCCESS else { return -1 }
    return Double(info.resident_size) / (1024.0 * 1024.0)
}

/// Duration in milliseconds (double precision).
extension Duration {
    var milliseconds: Double {
        let (seconds, attoseconds) = components
        return Double(seconds) * 1_000.0 + Double(attoseconds) / 1_000_000_000_000_000.0
    }
}

/// Run N simulation ticks, manually advancing GameTime before each tick.
///
/// GameEngine normally advances time, but in headless tests we drive it manually.
/// Default of 0.3 game-minutes/tick matches GameSpeed.normal at 10 TPS.
@MainActor
func runTicks(
    _ runner: SimulationRunner,
    state: GameState,
    count: Int,
    gameMinutesPerTick: Double = 0.3
) {
    for _ in 0..<count {
        state.gameTime.advance(minutes: gameMinutesPerTick)
        runner.tick(gameMinutes: gameMinutesPerTick)
    }
}
