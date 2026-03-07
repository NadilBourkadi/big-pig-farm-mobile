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
        let hideout = Facility.create(type: .hideout, x: 12, y: 5)
        _ = state.addFacility(hideout)
    }

    for i in 0..<pigCount {
        let gender: Gender = i.isMultiple(of: 2) ? .male : .female
        var pig = GuineaPig.create(name: "IntegPig\(i)", gender: gender)
        pig.ageDays = 5.0          // Adult (adultAgeDays = 3)
        pig.needs.happiness = 80.0 // Above minHappinessToBreed (70)
        pig.position = Position(x: Double(5 + (i % 3) * 3), y: Double(10 + (i / 3) * 3))
        state.addGuineaPig(pig)
    }

    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(state: state, behaviorController: controller, saveManager: makeTempSaveManager())
    return (state, runner)
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

// MARK: - Large Integration State (Performance Tests)

/// Create a GameState with a Grand Master-sized farm (96×56) and up to 200 pigs,
/// suitable for performance/benchmarking tests.
///
/// Pigs are spread in a 3-cell stride grid across the interior so none are placed
/// off-map even at pigCount=200. Food and water are included to keep needs valid.
@MainActor
func makeLargeIntegrationState(pigCount: Int) -> (GameState, SimulationRunner) {
    let state = GameState()
    var grid = FarmGrid(width: 96, height: 56)
    grid.createLegacyStarterArea()
    state.farm = grid

    let food = Facility.create(type: .foodBowl, x: 5, y: 5)
    _ = state.addFacility(food)
    let water = Facility.create(type: .waterBottle, x: 10, y: 5)
    _ = state.addFacility(water)

    // Spread pigs in a 3-cell stride grid. 28 columns fit within 96-wide interior.
    let interiorCols = (96 - 10) / 3
    for i in 0..<pigCount {
        let gender: Gender = i.isMultiple(of: 2) ? .male : .female
        var pig = GuineaPig.create(name: "PerfPig\(i)", gender: gender)
        pig.ageDays = 5.0
        pig.needs.happiness = 80.0
        pig.position = Position(
            x: Double(5 + (i % interiorCols) * 3),
            y: Double(10 + (i / interiorCols) * 3)
        )
        state.addGuineaPig(pig)
    }

    let controller = BehaviorController(gameState: state)
    let runner = SimulationRunner(
        state: state,
        behaviorController: controller,
        saveManager: makeTempSaveManager()
    )
    return (state, runner)
}

// MARK: - Memory Measurement

/// Current process resident-set size in megabytes, via mach_task_basic_info.
/// Returns 0.0 if the kernel call fails (allows callers to skip gracefully).
func memoryUsageMB() -> Double {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(
        MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size
    )
    let kern: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    guard kern == KERN_SUCCESS else { return 0.0 }
    return Double(info.resident_size) / (1_024 * 1_024)
}

// MARK: - Duration Extension

extension Duration {
    /// Wall-clock milliseconds as a Double.
    ///
    /// `Duration.components` returns `(seconds: Int64, attoseconds: Int64)`.
    /// 1 millisecond = 10^15 attoseconds, so: `seconds*1000 + attoseconds/10^15`.
    var milliseconds: Double {
        let parts = components
        return Double(parts.seconds) * 1_000.0 + Double(parts.attoseconds) / 1_000_000_000_000_000.0
    }
}
