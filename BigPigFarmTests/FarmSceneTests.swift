/// FarmSceneTests — Unit tests for FarmScene coordinate conversion, constants,
/// indicator priority, and tile mapping logic.
import Testing
import SpriteKit
@testable import BigPigFarm

// MARK: - SceneConstants Tests

@Suite("SceneConstants")
struct SceneConstantsTests {

    @Test("Cell size equals 8 art pixels times pointsPerArtPixel")
    func cellSizeMatchesArtPixels() {
        // Art pixel grid cell: 8px wide × 4 points/px = 32 points
        let expected: CGFloat = 8 * SceneConstants.pointsPerArtPixel
        #expect(SceneConstants.cellSize == expected)
    }

    @Test("Camera scale range is valid: min < default < max")
    func cameraScaleRange() {
        #expect(SceneConstants.minCameraScale < SceneConstants.defaultCameraScale)
        #expect(SceneConstants.defaultCameraScale < SceneConstants.maxCameraScale)
        #expect(SceneConstants.minCameraScale > 0)
    }

    @Test("Viewport padding is 4 (matches Python VIEWPORT_PADDING)")
    func viewportPaddingValue() {
        #expect(SceneConstants.viewportPadding == 4.0)
    }

    @Test("pointsPerArtPixel is consistent with SpriteAssets")
    func pointsPerArtPixelConsistency() {
        #expect(SceneConstants.pointsPerArtPixel == SpriteAssets.pointsPerArtPixel)
    }
}

// MARK: - Coordinate Conversion Formula Tests

/// Tests the coordinate conversion math directly without needing a running SKScene.
/// Formula: sceneX = gridX * cellSize, sceneY = (farmHeight - gridY) * cellSize
@Suite("Coordinate Conversion Formulas")
struct CoordinateConversionTests {

    private let cellSize = SceneConstants.cellSize
    private let farmWidth = 20
    private let farmHeight = 14

    private func gridToScene(_ gridX: CGFloat, _ gridY: CGFloat) -> CGPoint {
        CGPoint(
            x: gridX * cellSize,
            y: (CGFloat(farmHeight) - gridY) * cellSize
        )
    }

    private func sceneToGrid(_ point: CGPoint) -> (x: CGFloat, y: CGFloat) {
        (
            x: point.x / cellSize,
            y: CGFloat(farmHeight) - (point.y / cellSize)
        )
    }

    @Test("Grid origin (0,0) maps to top-left of scene")
    func originMapsToTopOfScene() {
        let point = gridToScene(0, 0)
        #expect(point.x == 0)
        #expect(point.y == CGFloat(farmHeight) * cellSize)
    }

    @Test("Grid bottom-left (0, farmHeight) maps to scene origin")
    func bottomGridMapsToSceneZero() {
        let point = gridToScene(0, CGFloat(farmHeight))
        #expect(point.x == 0)
        #expect(point.y == 0)
    }

    @Test("Round-trip grid → scene → grid preserves float position")
    func roundTripPreservesPosition() {
        let inputX: CGFloat = 7.5
        let inputY: CGFloat = 3.25
        let scenePoint = gridToScene(inputX, inputY)
        let (roundX, roundY) = sceneToGrid(scenePoint)
        #expect(abs(roundX - inputX) < 0.001)
        #expect(abs(roundY - inputY) < 0.001)
    }

    @Test("Higher grid-y gives lower scene-y (Y-axis flip)")
    func higherGridYGivesLowerSceneY() {
        let topPoint = gridToScene(0, 1)
        let bottomPoint = gridToScene(0, 5)
        #expect(topPoint.y > bottomPoint.y)
    }

    @Test("Pig at integer cell position gets positive scene-y")
    func pigAtCellHasPositiveSceneY() {
        let point = gridToScene(2, 3)
        #expect(point.y > 0)
    }

    @Test("X coordinate is independent of farmHeight")
    func xCoordinateIndependentOfHeight() {
        let point = gridToScene(5, 3)
        #expect(point.x == 5 * cellSize)
    }
}

// MARK: - Indicator Priority Tests

@Suite("Indicator Priority")
@MainActor
struct IndicatorPriorityTests {

    private func makeScene() -> FarmScene {
        FarmScene(gameState: GameState())
    }

    private func pig(
        health: Double = 100,
        hunger: Double = 100,
        thirst: Double = 100,
        energy: Double = 100,
        state: BehaviorState = .idle,
        pregnant: Bool = false
    ) -> GuineaPig {
        var pig = GuineaPig.create(name: "Test", gender: .female)
        pig.needs.health = health
        pig.needs.hunger = hunger
        pig.needs.thirst = thirst
        pig.needs.energy = energy
        pig.behaviorState = state
        pig.isPregnant = pregnant
        return pig
    }

    @Test("No indicator when all needs are healthy")
    func noIndicatorWhenHealthy() {
        let scene = makeScene()
        #expect(scene.indicatorType(for: pig()) == nil)
    }

    @Test("Health indicator overrides hunger when both are critical")
    func healthOverridesHunger() {
        let scene = makeScene()
        let testPig = pig(health: 10, hunger: 10)
        #expect(scene.indicatorType(for: testPig) == IndicatorType.health.rawValue)
    }

    @Test("Hunger indicator appears when hunger is below threshold")
    func hungerIndicatorWhenLow() {
        let scene = makeScene()
        let low = Double(GameConfig.Needs.lowThreshold) - 1
        let testPig = pig(hunger: low)
        #expect(scene.indicatorType(for: testPig) == IndicatorType.hunger.rawValue)
    }

    @Test("Hunger takes priority over thirst at same critical level")
    func hungerBeforeThirst() {
        let scene = makeScene()
        let low = Double(GameConfig.Needs.lowThreshold) - 1
        let testPig = pig(hunger: low, thirst: low)
        #expect(scene.indicatorType(for: testPig) == IndicatorType.hunger.rawValue)
    }

    @Test("Courting indicator shows when all needs healthy")
    func courtingWhenHealthy() {
        let scene = makeScene()
        let testPig = pig(state: .courting)
        #expect(scene.indicatorType(for: testPig) == IndicatorType.courting.rawValue)
    }

    @Test("Courting has priority over pregnant")
    func courtingBeforePregnant() {
        let scene = makeScene()
        let testPig = pig(state: .courting, pregnant: true)
        #expect(scene.indicatorType(for: testPig) == IndicatorType.courting.rawValue)
    }

    @Test("Energy indicator appears when energy is below threshold")
    func energyIndicatorWhenLow() {
        let scene = makeScene()
        let low = Double(GameConfig.Needs.lowThreshold) - 1
        let testPig = pig(energy: low)
        #expect(scene.indicatorType(for: testPig) == IndicatorType.energy.rawValue)
    }

    @Test("Pregnant indicator shown when no higher-priority needs trigger")
    func pregnantIndicatorAlone() {
        let scene = makeScene()
        let testPig = pig(pregnant: true)
        #expect(scene.indicatorType(for: testPig) == IndicatorType.pregnant.rawValue)
    }
}

// MARK: - Tile Mapping Y-Flip Tests

/// Tests the Y-flip formula used in fillTiles(into:with:farm:) without needing a tile map.
@Suite("Tile Mapping Y-Flip")
struct TileMappingTests {

    @Test("Grid row 0 maps to tile row (height-1)")
    func gridRow0MapsToTopTileRow() {
        let farmHeight = 10
        let tileRow = farmHeight - 1 - 0
        #expect(tileRow == farmHeight - 1)
    }

    @Test("Grid row (height-1) maps to tile row 0")
    func gridLastRowMapsToTileRow0() {
        let farmHeight = 10
        let tileRow = farmHeight - 1 - (farmHeight - 1)
        #expect(tileRow == 0)
    }

    @Test("Y-flip is its own inverse")
    func yFlipIsInverse() {
        let farmHeight = 15
        for gridY in 0..<farmHeight {
            let tileRow = farmHeight - 1 - gridY
            let backToGridY = farmHeight - 1 - tileRow
            #expect(backToGridY == gridY)
        }
    }

    @Test("Wall corner cell uses post group type")
    func wallCornerUsesPost() {
        var cell = Cell()
        cell.cellType = .wall
        cell.isCorner = true
        let groupType: String = cell.cellType == .wall
            ? (cell.isCorner ? "post" : "wall")
            : "floor"
        #expect(groupType == "post")
    }

    @Test("Wall non-corner cell uses wall group type")
    func wallNonCornerUsesWall() {
        var cell = Cell()
        cell.cellType = .wall
        cell.isCorner = false
        let groupType: String = cell.cellType == .wall
            ? (cell.isCorner ? "post" : "wall")
            : "floor"
        #expect(groupType == "wall")
    }

    @Test("Floor/bedding/grass cells use floor group type")
    func floorCellsUseFloor() {
        for cellType in [CellType.floor, .bedding, .grass] {
            var cell = Cell()
            cell.cellType = cellType
            let groupType: String = cell.cellType == .wall
                ? (cell.isCorner ? "post" : "wall")
                : "floor"
            #expect(groupType == "floor", "Expected floor for \(cellType)")
        }
    }
}
