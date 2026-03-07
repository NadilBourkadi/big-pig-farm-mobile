/// FarmScene — Main SpriteKit scene for terrain, pigs, camera, and touch input.
/// Maps from: new SpriteKit rendering layer
import SpriteKit

// MARK: - SceneConstants

/// Grid and viewport constants for the farm scene.
enum SceneConstants {
    static let pointsPerArtPixel: CGFloat = 4.0
    static let cellSize: CGFloat = 32.0
    static let viewportPadding: CGFloat = 4.0
    static let minCameraScale: CGFloat = 0.5
    static let maxCameraScale: CGFloat = 3.0
    static let defaultCameraScale: CGFloat = 1.0
    /// Golden hay base tone — matched to the programmatic hay tile texture's background pixel.
    static let outOfBoundsColor = SKColor(red: 0.68, green: 0.57, blue: 0.30, alpha: 1.0)
    /// Side length in tiles of the out-of-bounds hay tile map.
    /// 200 × 32 pt = 6400 pt — covers the 96×56 max farm plus worst-case viewport margin at minCameraScale (0.5).
    static let outOfBoundsTileMapDimension = 200
}

// MARK: - FarmSceneDelegate

/// Receives scene-level events (selection, edit mode) for SwiftUI handling.
@MainActor
protocol FarmSceneDelegate: AnyObject {
    func farmScene(_ scene: FarmScene, didSelectPig pigID: UUID)
    func farmSceneDidDeselectPig(_ scene: FarmScene)
    func farmScene(_ scene: FarmScene, didSelectFacility facilityID: UUID)
    func farmSceneDidDeselectFacility(_ scene: FarmScene)
    func farmScene(_ scene: FarmScene, didRemoveFacility facilityID: UUID)
}

// MARK: - IndicatorTimer

/// Tracks indicator pulse state per pig.
struct IndicatorTimer: Sendable {
    var indicatorType: String
    var triggerFrame: Int
}

// MARK: - FarmScene

/// The primary SpriteKit scene rendering the farm world.
@MainActor
class FarmScene: SKScene {

    // MARK: - Dependencies

    let gameState: GameState
    weak var sceneDelegate: FarmSceneDelegate?

    // MARK: - Node Layers

    private let terrainLayer = SKNode()
    private let facilityLayer = SKNode()
    private let pigLayer = SKNode()

    // MARK: - Node Tracking

    private(set) var pigNodes: [UUID: PigNode] = [:]
    private var facilityNodes: [UUID: FacilityNode] = [:]

    // MARK: - Camera

    private(set) var cameraController: CameraController!
    /// Deferred zoom flag — cleared after the first update() with a valid view frame.
    private var needsInitialZoom = true

    // MARK: - Selection

    var selectedPigID: UUID? { didSet { updateSelectionHighlight() } }

    // MARK: - Edit Mode

    var isEditMode: Bool = false
    var selectedFacilityID: UUID?
    var isMovingFacility: Bool = false

    /// Called by confirmFacilityPlacement() when a move gesture ends.
    /// ContentView uses this to reset its editModeIsMovingFacility @State.
    var onFacilityMoveEnded: (() -> Void)?

    // MARK: - Terrain State

    private var lastGridGeneration: Int = -1
    private var farmWidth: Int = 0
    private var farmHeight: Int = 0
    var outOfBoundsTileMap: SKTileMapNode?

    // MARK: - Indicators

    var indicatorTimers: [UUID: IndicatorTimer] = [:]
    private var frameCount: Int = 0

    // MARK: - Init

    init(gameState: GameState) {
        self.gameState = gameState
        super.init(size: .zero)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }
}

// MARK: - Lifecycle

extension FarmScene {

    override func didMove(to view: SKView) {
        backgroundColor = SceneConstants.outOfBoundsColor
        anchorPoint = CGPoint(x: 0, y: 0)
        scaleMode = .aspectFill

        let farm = gameState.farm
        farmWidth = farm.width
        farmHeight = farm.height
        size = CGSize(
            width: CGFloat(farmWidth) * SceneConstants.cellSize,
            height: CGFloat(farmHeight) * SceneConstants.cellSize
        )

        setupOutOfBoundsBackground()

        terrainLayer.zPosition = 0
        facilityLayer.zPosition = 5
        pigLayer.zPosition = 10
        addChild(terrainLayer)
        addChild(facilityLayer)
        addChild(pigLayer)

        let cameraNode = SKCameraNode()
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(cameraNode)
        camera = cameraNode

        cameraController = CameraController(
            camera: cameraNode,
            scene: self,
            farmWidth: farmWidth,
            farmHeight: farmHeight
        )
        cameraController.setupGestureRecognizers(in: view)

        // Set a safe default; the fit-to-screen zoom is deferred to the first
        // update() frame where the view has its final layout dimensions.
        cameraNode.setScale(SceneConstants.defaultCameraScale)

        rebuildTerrain()
        syncFacilities()
        syncPigs()
    }

    override func update(_ currentTime: TimeInterval) {
        frameCount += 1

        if needsInitialZoom, let view = self.view, view.frame.width > 0, view.frame.height > 0 {
            cameraController.applyFitToScreenZoom(for: view, contentRect: contentBounds())
            needsInitialZoom = false
        }

        let farm = gameState.farm
        if farm.gridGeneration != lastGridGeneration {
            farmWidth = farm.width
            farmHeight = farm.height
            cameraController.updateFarmDimensions(width: farmWidth, height: farmHeight)
            size = CGSize(
                width: CGFloat(farmWidth) * SceneConstants.cellSize,
                height: CGFloat(farmHeight) * SceneConstants.cellSize
            )
            outOfBoundsTileMap?.position = CGPoint(x: size.width / 2, y: size.height / 2)
            rebuildTerrain()
        }

        syncFacilities()
        syncPigs()

        // Only track a selected pig when the viewport is small enough that the
        // pig could be off-screen. At fit-zoom the whole farm is visible, so
        // tracking would lock the camera to the pig's position and fight panning.
        if let selectedID = selectedPigID, let pigNode = pigNodes[selectedID],
           cameraController.isZoomedInForPigTracking {
            cameraController.follow(pigNode.position)
        }
    }
}

// MARK: - Content Bounds

extension FarmScene {

    /// Bounding rect of all farm areas in scene points.
    /// Falls back to the full grid if no areas exist.
    func contentBounds() -> CGRect {
        let farm = gameState.farm
        guard !farm.areas.isEmpty else {
            return CGRect(x: 0, y: 0, width: size.width, height: size.height)
        }
        var minGX = Int.max, minGY = Int.max, maxGX = 0, maxGY = 0
        for area in farm.areas {
            minGX = min(minGX, area.x1)
            minGY = min(minGY, area.y1)
            maxGX = max(maxGX, area.x2 + 1) // +1: x2 is inclusive
            maxGY = max(maxGY, area.y2 + 1)
        }
        // Convert grid bounds to scene coordinates (Y is flipped).
        let topLeft = gridToScene(CGFloat(minGX), CGFloat(minGY))
        let bottomRight = gridToScene(CGFloat(maxGX), CGFloat(maxGY))
        let x = min(topLeft.x, bottomRight.x)
        let y = min(topLeft.y, bottomRight.y)
        let width = abs(bottomRight.x - topLeft.x)
        let height = abs(bottomRight.y - topLeft.y)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

// MARK: - Coordinate Conversion

extension FarmScene {

    /// Convert a game-grid point to a SpriteKit scene point.
    /// Grid (0,0) is the top-left corner; scene (0,0) is the bottom-left corner.
    func gridToScene(_ gridX: CGFloat, _ gridY: CGFloat) -> CGPoint {
        CGPoint(
            x: gridX * SceneConstants.cellSize,
            y: (CGFloat(farmHeight) - gridY) * SceneConstants.cellSize
        )
    }

    /// Convert a SpriteKit scene point back to a game-grid point.
    func sceneToGrid(_ point: CGPoint) -> (x: CGFloat, y: CGFloat) {
        (
            x: point.x / SceneConstants.cellSize,
            y: CGFloat(farmHeight) - (point.y / SceneConstants.cellSize)
        )
    }
}

// MARK: - Terrain

/// Per-biome tile group triplet used when filling the tile map.
private struct BiomeTileGroups {
    let floor: SKTileGroup
    let wall: SKTileGroup
    let post: SKTileGroup
}

extension FarmScene {

    func rebuildTerrain() {
        terrainLayer.removeAllChildren()
        let farm = gameState.farm
        let tileSize = CGSize(width: SceneConstants.cellSize, height: SceneConstants.cellSize)

        // Collect biomes that appear in the grid.
        var usedBiomes: Set<String> = []
        for area in farm.areas {
            usedBiomes.insert(area.biome.rawValue)
        }
        if !farm.tunnels.isEmpty { usedBiomes.insert(BiomeType.meadow.rawValue) }
        if usedBiomes.isEmpty { usedBiomes.insert(BiomeType.meadow.rawValue) }

        // Build one tile group triplet per biome.
        var allTileGroups: [SKTileGroup] = []
        var biomeGroups: [String: BiomeTileGroups] = [:]

        for biome in usedBiomes {
            let floorGroup = makeTileGroup(biome: biome, tileType: "floor", size: tileSize)
            let wallGroup = makeTileGroup(biome: biome, tileType: "wall", size: tileSize)
            let postGroup = makeTileGroup(biome: biome, tileType: "post", size: tileSize)
            biomeGroups[biome] = BiomeTileGroups(floor: floorGroup, wall: wallGroup, post: postGroup)
            allTileGroups.append(contentsOf: [floorGroup, wallGroup, postGroup])
        }

        let tileSet = SKTileSet(tileGroups: allTileGroups)
        let tileMap = SKTileMapNode(
            tileSet: tileSet,
            columns: farm.width,
            rows: farm.height,
            tileSize: tileSize
        )
        tileMap.anchorPoint = CGPoint(x: 0, y: 0)
        tileMap.position = .zero
        tileMap.zPosition = 0

        fillTiles(into: tileMap, with: biomeGroups, farm: farm)
        terrainLayer.addChild(tileMap)
        lastGridGeneration = farm.gridGeneration
    }

    private func fillTiles(
        into tileMap: SKTileMapNode,
        with biomeGroups: [String: BiomeTileGroups],
        farm: FarmGrid
    ) {
        for gridY in 0..<farm.height {
            for gridX in 0..<farm.width {
                let cell = farm.cells[gridY][gridX]
                let tileRow = farm.height - 1 - gridY  // Flip: tile row 0 is at scene bottom.

                let biomeName: String
                if cell.isTunnel {
                    biomeName = BiomeType.meadow.rawValue
                } else if let areaId = cell.areaId, let area = farm.areaLookup[areaId] {
                    biomeName = area.biome.rawValue
                } else {
                    continue  // void cell — leave empty
                }

                guard let groups = biomeGroups[biomeName] else { continue }
                let group: SKTileGroup = cell.cellType == .wall
                    ? (cell.isCorner ? groups.post : groups.wall)
                    : groups.floor
                tileMap.setTileGroup(group, forColumn: gridX, row: tileRow)
            }
        }
    }

    private func makeTileGroup(biome: String, tileType: String, size: CGSize) -> SKTileGroup {
        let texture = SpriteAssets.terrainTexture(biome: biome, tileType: tileType)
        let definition = SKTileDefinition(texture: texture, size: size)
        return SKTileGroup(tileDefinition: definition)
    }
}

// MARK: - Node Sync

extension FarmScene {

    func syncPigs() {
        let currentIDs = Set(gameState.guineaPigs.keys)
        let existingIDs = Set(pigNodes.keys)

        for removedID in existingIDs.subtracting(currentIDs) {
            pigNodes[removedID]?.removeFromParent()
            pigNodes.removeValue(forKey: removedID)
            indicatorTimers.removeValue(forKey: removedID)
        }

        for (id, pig) in gameState.guineaPigs {
            if let node = pigNodes[id] {
                node.update(from: pig, in: self)
            } else {
                let node = PigNode(pig: pig, scene: self)
                node.zPosition = 10
                pigLayer.addChild(node)
                pigNodes[id] = node
            }
            if let node = pigNodes[id] {
                node.isSelected = (id == selectedPigID)
                updateIndicator(for: node, pig: pig)
            }
        }
    }

    func syncFacilities() {
        let currentIDs = Set(gameState.facilities.keys)
        let existingIDs = Set(facilityNodes.keys)

        for removedID in existingIDs.subtracting(currentIDs) {
            facilityNodes[removedID]?.removeFromParent()
            facilityNodes.removeValue(forKey: removedID)
        }

        for (id, facility) in gameState.facilities {
            if let node = facilityNodes[id] {
                node.update(from: facility, in: self)
            } else {
                let node = FacilityNode(facility: facility, scene: self)
                node.zPosition = 5
                facilityLayer.addChild(node)
                facilityNodes[id] = node
            }
            if let node = facilityNodes[id] {
                node.isSelectedInEditMode = (id == selectedFacilityID && isEditMode)
                node.isBeingMoved = (id == selectedFacilityID && isMovingFacility)
            }
        }
    }
}

// MARK: - Indicators

extension FarmScene {

    /// Returns the highest-priority status indicator type for a pig, or nil if none.
    /// Marked internal so tests can call it directly.
    internal func indicatorType(for pig: GuineaPig) -> String? {
        let low = Double(GameConfig.Needs.lowThreshold)
        if pig.needs.health < low { return IndicatorType.health.rawValue }
        if pig.needs.hunger < low { return IndicatorType.hunger.rawValue }
        if pig.needs.thirst < low { return IndicatorType.thirst.rawValue }
        if pig.needs.energy < low { return IndicatorType.energy.rawValue }
        if pig.behaviorState == .courting { return IndicatorType.courting.rawValue }
        if pig.isPregnant { return IndicatorType.pregnant.rawValue }
        return nil
    }

    private func updateIndicator(for node: PigNode, pig: GuineaPig) {
        guard let indicatorName = indicatorType(for: pig) else {
            node.hideIndicator()
            return
        }
        // Pulse: bright for 2 s, dim for 1 s, at 10 TPS.
        let cycleFrames = GameConfig.Simulation.ticksPerSecond * 3
        let brightFrames = GameConfig.Simulation.ticksPerSecond * 2
        let isBright = (frameCount % cycleFrames) < brightFrames
        node.showIndicator(type: indicatorName, bright: isBright)
    }
}
