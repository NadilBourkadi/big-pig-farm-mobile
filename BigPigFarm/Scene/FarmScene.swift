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
    static let outOfBoundsColor = SKColor(red: 0.42, green: 0.34, blue: 0.16, alpha: 1.0)
    /// Side length in tiles of the out-of-bounds hay tile map.
    /// 200 × 32 pt = 6400 pt — covers the 96×56 max farm plus worst-case viewport margin at minCameraScale (0.5).
    static let outOfBoundsTileMapDimension = 200
    /// Intrinsic height of the StatusInfoRow HUD bar, excluding safe area inset.
    static let hudTopHeight: CGFloat = 22.0
    /// Intrinsic height of the StatusToolbar HUD bar, excluding safe area inset.
    static let hudBottomHeight: CGFloat = 37.0
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

    let terrainLayer = SKNode()
    let facilityLayer = SKNode()
    let pigLayer = SKNode()

    // MARK: - Node Tracking

    var pigNodes: [UUID: PigNode] = [:]
    var facilityNodes: [UUID: FacilityNode] = [:]

    // MARK: - Camera

    private(set) var cameraController: CameraController!
    /// Deferred zoom flag — cleared after the first update() with a valid view frame.
    private var needsInitialZoom = true

    // MARK: - Selection

    var selectedPigID: UUID? { didSet { updateSelectionHighlight() } }

    // MARK: - Edit Mode

    var isEditMode: Bool = false
    var selectedFacilityID: UUID?
    var draggedFacilityID: UUID?

    /// Called when a drag gesture begins on a facility in edit mode.
    var onFacilityDragBegan: ((UUID) -> Void)?

    /// Called when a drag gesture ends (facility placed or cancelled).
    var onFacilityMoveEnded: (() -> Void)?

    // MARK: - Terrain State

    var lastGridGeneration: Int = -1
    var farmWidth: Int = 0
    var farmHeight: Int = 0
    var outOfBoundsTileMap: SKTileMapNode?

    // MARK: - Indicators

    var indicatorTimers: [UUID: IndicatorTimer] = [:]
    var frameCount: Int = 0

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
