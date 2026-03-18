/// SceneTestHelpers — Factory helpers for scene tests that remain in the Xcode test target.
///
/// These are copies of helpers from BigPigFarmCoreTests/TestHelpers.swift, scoped to
/// the BigPigFarm module (not BigPigFarmCore) since scene tests need SpriteKit types.
import Foundation
@testable import BigPigFarm

// MARK: - Save Manager Helper

@MainActor
func makeTempSaveManager() -> SaveManager {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    return SaveManager(baseDirectoryURL: tempDir)
}

// MARK: - Large Integration State (Performance Tests)

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
