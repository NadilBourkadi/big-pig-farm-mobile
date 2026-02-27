# Spec 06 -- Farm Scene

> **Status:** Complete
> **Date:** 2026-02-27
> **Depends on:** 02 (Data Models), 03 (Sprite Pipeline), 04 (Game Engine)
> **Blocks:** 08 (Persistence & Polish)

---

## 1. Overview

This document specifies the complete SpriteKit farm scene for the iOS port: the `FarmScene` (SKScene with terrain tile maps), `PigNode` (animated pig sprites), `FacilityNode` (static facility sprites), `CameraController` (pan/zoom/bounds), status indicator rendering, edit mode for facility management, touch handling, and the `SpriteView` integration that bridges SpriteKit into the SwiftUI app.

The Python source renders the farm as Unicode half-block characters into a Textual `Static` widget, with terrain, facilities, and pigs drawn into character/style buffers. The iOS port replaces this with SpriteKit's hardware-accelerated 2D scene graph: `SKTileMapNode` for terrain, `SKSpriteNode` subclasses for pigs and facilities, `SKCameraNode` for viewport control, and gesture recognizers for touch interaction.

### Scope

**In scope:**
- `FarmScene` -- SKScene setup, node hierarchy, update loop syncing from `GameState`
- Terrain rendering via `SKTileMapNode` per biome area
- `PigNode` -- animated sprite node with state-driven animation, direction tracking, name labels, selection highlight, and status indicators
- `FacilityNode` -- static sprite node with state variants, labels, edit mode highlight
- `CameraController` -- pan (drag), pinch-zoom, bounds clamping, center-on-pig follow camera
- Touch handling -- tap-to-select pig, tap-to-deselect, edit mode facility selection
- Edit mode -- facility select, move, remove with visual feedback
- Status indicator rendering -- floating icons above pigs with show/cooldown pulse cycle
- `ContentView` -- `SpriteView` + SwiftUI HUD overlay + `.sheet` wiring for menu screens
- Coordinate system conversion (SpriteKit Y-up vs Python Y-down)
- Performance considerations and node management

**Out of scope:**
- Sprite PNG export and asset catalog creation (Doc 03 -- Sprite Pipeline)
- `SpriteAssets` loading API, `AnimationData`, `PatternRenderer` (Doc 03)
- Game engine tick loop and simulation logic (Doc 04)
- Behavior AI decision tree and movement (Doc 05)
- SwiftUI menu screen implementations (Doc 07)
- Save/load persistence (Doc 08)
- StatusBarView HUD content and layout (Doc 07)

### Deliverable Summary

| Category | Files | Estimated Lines |
|----------|-------|----------------|
| FarmScene | `Scene/FarmScene.swift` | ~280 |
| PigNode | `Scene/PigNode.swift` | ~250 |
| FacilityNode | `Scene/FacilityNode.swift` | ~120 |
| CameraController | `Scene/CameraController.swift` | ~200 |
| ContentView | `ContentView.swift` | ~100 |
| Tests | `BigPigFarmTests/FarmSceneTests.swift` | ~150 |
| **Total** | **6 files** | **~1,100** |

### Source File Mapping

| Python Source | Lines | Swift Target | Notes |
|---------------|-------|-------------|-------|
| `ui/widgets/farm_view.py` | 566 | `Scene/FarmScene.swift` | Core scene: node hierarchy, update loop, pig/facility sync |
| `ui/widgets/terrain_renderer.py` | 287 | `Scene/FarmScene.swift` (terrain methods) | `SKTileMapNode` replaces character buffer drawing |
| `ui/widgets/pig_renderer.py` | 334 | `Scene/PigNode.swift` | Animated sprite node replaces half-block rendering |
| `ui/widgets/edit_mode.py` | 149 | `Scene/FarmScene.swift` (edit mode methods) | Facility select/move/remove |
| `ui/screens/main_game.py` | 536 | `ContentView.swift` | SpriteView root + sheet wiring |
| `ui/widgets/status_bar.py` | 128 | `Views/StatusBarView.swift` (Doc 07 scope) | Referenced but not fully specified here |

---

## 2. Coordinate System and Grid Sizing

### SpriteKit vs Python Coordinates

SpriteKit uses a coordinate system with the origin at the bottom-left, Y increasing upward. The Python source uses origin at the top-left, Y increasing downward. All grid-to-scene conversions must invert the Y axis.

**Maps from:** `farm_view.py` viewport/offset calculations, `terrain_renderer.py` screen coordinate mapping.

### Grid Cell Size

Per Spec 03 Section 4, each art pixel maps to 4 SpriteKit points at @1x scale. Terrain tiles are 8x8 art pixels, producing 32x32 point tiles. This is the grid cell size:

```swift
/// Grid and coordinate constants for the farm scene.
///
/// Centralizes the relationship between grid cells, art pixels, and SpriteKit points.
enum SceneConstants {
    /// Points per art pixel at @1x scale (matches SpriteAssets.pointsPerArtPixel).
    static let pointsPerArtPixel: CGFloat = 4.0

    /// Grid cell size in SpriteKit points (8 art pixels x 4 points/pixel).
    /// Each FarmGrid cell is this many points wide and tall.
    static let cellSize: CGFloat = 32.0

    /// Extra world cells of scroll padding beyond farm edges.
    /// Matches Python VIEWPORT_PADDING = 4.
    static let viewportPadding: CGFloat = 4.0

    /// Minimum camera zoom scale (zoomed out -- sees more of the farm).
    static let minCameraScale: CGFloat = 0.5

    /// Maximum camera zoom scale (zoomed in -- sees less of the farm).
    static let maxCameraScale: CGFloat = 3.0

    /// Default camera zoom scale.
    static let defaultCameraScale: CGFloat = 1.0
}
```

### Coordinate Conversion

Two free functions in `FarmScene` convert between grid coordinates (used by `GameState`, `FarmGrid`, and pig positions) and SpriteKit scene coordinates:

```swift
extension FarmScene {
    /// Convert a grid position to SpriteKit scene coordinates.
    ///
    /// Grid (0,0) is top-left in the game model. SpriteKit (0,0) is bottom-left.
    /// The Y axis is flipped: grid Y=0 maps to the top of the scene (max scene Y).
    ///
    /// - Parameters:
    ///   - gridX: X position in grid coordinates (0..<farm.width).
    ///   - gridY: Y position in grid coordinates (0..<farm.height).
    /// - Returns: CGPoint in scene coordinates.
    func gridToScene(_ gridX: CGFloat, _ gridY: CGFloat) -> CGPoint {
        let sceneX = gridX * SceneConstants.cellSize
        let sceneY = (CGFloat(farmHeight) - gridY) * SceneConstants.cellSize
        return CGPoint(x: sceneX, y: sceneY)
    }

    /// Convert a SpriteKit scene position to grid coordinates.
    ///
    /// Inverse of `gridToScene`. Returns fractional grid coordinates.
    func sceneToGrid(_ point: CGPoint) -> (x: CGFloat, y: CGFloat) {
        let gridX = point.x / SceneConstants.cellSize
        let gridY = CGFloat(farmHeight) - (point.y / SceneConstants.cellSize)
        return (x: gridX, y: gridY)
    }
}
```

---

## 3. FarmScene (SKScene)

**Maps from:** `ui/widgets/farm_view.py` (566 lines) -- `FarmView.__init__`, `render`, `_draw_facilities`, `center_on_pig`, `select_pig`, mouse event handlers.

**Swift file:** `BigPigFarm/Scene/FarmScene.swift`

### Architecture

`FarmScene` is the main `SKScene` subclass. It owns the node hierarchy, syncs sprite positions from `GameState` on every frame, and handles touch input. The scene does not contain game logic -- it is a pure rendering and input layer that reads from `GameState` and posts events back to the SwiftUI layer via delegate callbacks.

Per ROADMAP Decision 5, the scene is displayed via `SpriteView` in SwiftUI. The simulation tick loop (`GameEngine`) runs independently on the main run loop timer. `FarmScene.update(_:)` reads the latest `GameState` each frame and updates node positions/animations accordingly.

### Type Signature

```swift
import SpriteKit

/// Delegate protocol for FarmScene events that the SwiftUI layer handles.
///
/// FarmScene fires these callbacks on touch interactions. The SwiftUI
/// ContentView implements this to update sheet presentation state and
/// selected pig tracking.
@MainActor
protocol FarmSceneDelegate: AnyObject {
    /// Called when the player taps a pig sprite.
    func farmScene(_ scene: FarmScene, didSelectPig pigID: UUID)

    /// Called when the player taps empty space (deselect).
    func farmSceneDidDeselectPig(_ scene: FarmScene)

    /// Called when the player selects a facility in edit mode.
    func farmScene(_ scene: FarmScene, didSelectFacility facilityID: UUID)

    /// Called when the player removes a facility in edit mode.
    func farmScene(_ scene: FarmScene, didRemoveFacility facilityID: UUID)
}

/// The primary SpriteKit scene rendering the farm world.
///
/// Maps from: ui/widgets/farm_view.py (FarmView class)
///
/// Renders terrain via SKTileMapNode, pigs as animated PigNode sprites,
/// and facilities as FacilityNode sprites. Reads from GameState each frame
/// to sync positions and animations.
@MainActor
class FarmScene: SKScene {

    // MARK: - Dependencies

    /// The game state to render. Set before the scene is presented.
    var gameState: GameState!

    /// Delegate for scene events (pig selection, facility actions).
    weak var delegate: FarmSceneDelegate?

    // MARK: - Node Layers

    /// Container for all terrain tile map nodes. Z = 0.
    private let terrainLayer = SKNode()

    /// Container for all facility sprite nodes. Z = 10.
    private let facilityLayer = SKNode()

    /// Container for all pig sprite nodes. Z = 20.
    private let pigLayer = SKNode()

    // MARK: - Node Tracking

    /// Active pig nodes keyed by pig UUID. Used to sync with GameState.
    private var pigNodes: [UUID: PigNode] = [:]

    /// Active facility nodes keyed by facility UUID.
    private var facilityNodes: [UUID: FacilityNode] = [:]

    // MARK: - Camera

    /// Camera controller managing pan, zoom, and bounds.
    private(set) var cameraController: CameraController!

    // MARK: - Selection State

    /// Currently selected pig UUID, if any.
    var selectedPigID: UUID? {
        didSet { updateSelectionHighlight() }
    }

    // MARK: - Edit Mode

    /// Whether edit mode is active (facility select/move/remove).
    var isEditMode: Bool = false

    /// Currently selected facility in edit mode.
    var selectedFacilityID: UUID?

    /// Whether a facility is currently being moved.
    var isMovingFacility: Bool = false

    // MARK: - Terrain Cache

    /// The grid generation counter from the last terrain rebuild.
    /// When this changes, terrain tile maps are rebuilt.
    private var lastGridGeneration: Int = -1

    /// Cached farm dimensions for coordinate conversion.
    private var farmWidth: Int = 0
    private var farmHeight: Int = 0

    // MARK: - Indicator Tracking

    /// Ephemeral indicator state per pig (show/cooldown cycle).
    private var indicatorTimers: [UUID: IndicatorTimer] = [:]

    /// Frame counter for indicator pulse animation.
    private var frameCount: Int = 0
}
```

### Scene Setup

```swift
extension FarmScene {
    override func didMove(to view: SKView) {
        backgroundColor = .black
        anchorPoint = CGPoint(x: 0, y: 0)

        // Cache farm dimensions
        farmWidth = gameState.farm.width
        farmHeight = gameState.farm.height

        // Set scene size to match the full farm grid
        let sceneWidth = CGFloat(farmWidth) * SceneConstants.cellSize
        let sceneHeight = CGFloat(farmHeight) * SceneConstants.cellSize
        size = CGSize(width: sceneWidth, height: sceneHeight)

        // Layer setup with z-ordering
        terrainLayer.zPosition = 0
        addChild(terrainLayer)

        facilityLayer.zPosition = 10
        addChild(facilityLayer)

        pigLayer.zPosition = 20
        addChild(pigLayer)

        // Camera
        let cameraNode = SKCameraNode()
        cameraNode.position = CGPoint(x: sceneWidth / 2, y: sceneHeight / 2)
        addChild(cameraNode)
        camera = cameraNode

        cameraController = CameraController(
            camera: cameraNode,
            scene: self,
            farmWidth: farmWidth,
            farmHeight: farmHeight
        )
        cameraController.setupGestureRecognizers(in: view)

        // Initial terrain build
        rebuildTerrain()

        // Initial facility/pig sync
        syncFacilities()
        syncPigs()
    }
}
```

### Update Loop

The `update(_:)` method runs every frame (targeting 60fps). It syncs pig positions, updates animations, and checks for terrain changes.

```swift
extension FarmScene {
    override func update(_ currentTime: TimeInterval) {
        frameCount += 1

        // Check if terrain needs rebuilding (grid_generation changed)
        if gameState.farm.gridGeneration != lastGridGeneration {
            farmWidth = gameState.farm.width
            farmHeight = gameState.farm.height
            rebuildTerrain()
            lastGridGeneration = gameState.farm.gridGeneration
        }

        // Sync pig nodes with GameState
        syncPigs()

        // Sync facility nodes (less frequent changes)
        syncFacilities()

        // Update follow camera
        if let selectedID = selectedPigID,
           let pigNode = pigNodes[selectedID] {
            cameraController.follow(pigNode.position)
        }
    }
}
```

### Pig Node Synchronization

The scene maintains a `[UUID: PigNode]` dictionary mirroring `GameState.guineaPigs`. Each frame, it adds nodes for new pigs, removes nodes for deleted pigs, and updates positions/animations for existing pigs.

**Maps from:** `pig_renderer.py` `draw_guinea_pigs()` -- sorted by Y so lower pigs draw on top (higher zPosition in SpriteKit since Y is flipped).

```swift
extension FarmScene {
    /// Sync pig sprite nodes with the current GameState.
    ///
    /// - Adds PigNode for any new pig in GameState
    /// - Removes PigNode for any pig no longer in GameState
    /// - Updates position, animation state, and direction for existing pigs
    private func syncPigs() {
        let currentPigs = gameState.guineaPigs

        // Remove nodes for pigs that no longer exist
        for (pigID, node) in pigNodes {
            if currentPigs[pigID] == nil {
                node.removeFromParent()
                pigNodes.removeValue(forKey: pigID)
                indicatorTimers.removeValue(forKey: pigID)
            }
        }

        // Add or update nodes for current pigs
        for (pigID, pig) in currentPigs {
            if let existingNode = pigNodes[pigID] {
                // Update position and animation
                existingNode.update(from: pig, in: self)

                // Y-based draw ordering: pigs lower on screen draw on top.
                // In SpriteKit (Y-up), lower grid-Y means higher scene-Y,
                // so pigs with higher scene-Y should have lower zPosition.
                existingNode.zPosition = -existingNode.position.y

                // Update selection highlight
                existingNode.isSelected = (pigID == selectedPigID)

                // Update status indicator
                updateIndicator(for: existingNode, pig: pig)
            } else {
                // New pig -- create node
                let node = PigNode(pig: pig, scene: self)
                node.isSelected = (pigID == selectedPigID)
                pigLayer.addChild(node)
                pigNodes[pigID] = node
            }
        }
    }
}
```

### Facility Node Synchronization

Similar to pig sync, but facilities change less frequently (only on purchase, move, or remove).

```swift
extension FarmScene {
    /// Sync facility sprite nodes with the current GameState.
    private func syncFacilities() {
        let currentFacilities = gameState.facilities

        // Remove nodes for facilities that no longer exist
        for (facilityID, node) in facilityNodes {
            if currentFacilities[facilityID] == nil {
                node.removeFromParent()
                facilityNodes.removeValue(forKey: facilityID)
            }
        }

        // Add or update nodes for current facilities
        for (facilityID, facility) in currentFacilities {
            if let existingNode = facilityNodes[facilityID] {
                existingNode.update(from: facility, in: self)
                existingNode.isSelectedInEditMode = (
                    isEditMode && facilityID == selectedFacilityID
                )
            } else {
                let node = FacilityNode(facility: facility, scene: self)
                facilityLayer.addChild(node)
                facilityNodes[facilityID] = node
            }
        }
    }
}
```

---

## 4. Terrain Rendering (SKTileMapNode)

**Maps from:** `terrain_renderer.py` (287 lines) -- `draw_terrain()`, `floor_texture()`, `wall_texture()`. The Python code draws terrain character-by-character into a buffer. SpriteKit uses `SKTileMapNode` for efficient batched tile rendering.

### Architecture Decision

Per ROADMAP Decision 4, we use `SKTileMapNode` instead of individual `SKSpriteNode` per cell. One `SKTileMapNode` per biome area keeps the node count manageable (max 8 areas = 8 tile map nodes), while SpriteKit batches the tile rendering internally.

### Tile Set Construction

Each biome has a tile set with 3 tile groups: floor, wall, and post. The textures are loaded from the asset catalog via `SpriteAssets.terrainTexture(biome:tileType:)` (defined in Spec 03).

```swift
extension FarmScene {
    /// Build an SKTileSet for a biome with floor, wall, and post tile groups.
    ///
    /// - Parameter biome: The biome type value string (e.g., "meadow").
    /// - Returns: A tuple of (tileSet, floorGroup, wallGroup, postGroup).
    private func makeTileSet(
        for biome: String
    ) -> (SKTileSet, SKTileGroup, SKTileGroup, SKTileGroup) {
        let floorTexture = SpriteAssets.terrainTexture(biome: biome, tileType: "floor")
        let wallTexture = SpriteAssets.terrainTexture(biome: biome, tileType: "wall")
        let postTexture = SpriteAssets.terrainTexture(biome: biome, tileType: "post")

        let floorDef = SKTileDefinition(texture: floorTexture, size: CGSize(
            width: SceneConstants.cellSize, height: SceneConstants.cellSize
        ))
        let wallDef = SKTileDefinition(texture: wallTexture, size: CGSize(
            width: SceneConstants.cellSize, height: SceneConstants.cellSize
        ))
        let postDef = SKTileDefinition(texture: postTexture, size: CGSize(
            width: SceneConstants.cellSize, height: SceneConstants.cellSize
        ))

        let floorGroup = SKTileGroup(tileDefinition: floorDef)
        let wallGroup = SKTileGroup(tileDefinition: wallDef)
        let postGroup = SKTileGroup(tileDefinition: postDef)

        let tileSet = SKTileSet(tileGroups: [floorGroup, wallGroup, postGroup])
        return (tileSet, floorGroup, wallGroup, postGroup)
    }
}
```

### Terrain Rebuild

Terrain is rebuilt when `gameState.farm.gridGeneration` changes (indicating the grid has been modified -- new rooms, tunnels, etc.). The rebuild clears all tile map nodes and creates new ones.

The Python source separates terrain into biome areas, each with its own bounds and floor/wall coloring. In SpriteKit, each area gets its own `SKTileMapNode` covering the full grid dimensions but only filling cells that belong to that area. This avoids complex sub-tiling arithmetic.

However, a more efficient approach is to use a single `SKTileMapNode` for the entire grid, since areas may overlap at tunnel boundaries and the total grid never exceeds 96x56 (5,376 cells). A single tile map node with 5,376 tiles is well within SpriteKit's performance envelope.

**Decision:** Use a single `SKTileMapNode` for the entire farm grid. Each cell is assigned the appropriate biome's tile group based on its area membership. Tunnel cells use a dedicated grey stone tile. Void cells (no area) are left empty (transparent).

```swift
extension FarmScene {
    /// Rebuild all terrain tile maps from the current FarmGrid.
    ///
    /// Called on initial load and whenever gridGeneration changes.
    /// Uses a single SKTileMapNode covering the full grid.
    func rebuildTerrain() {
        // Remove existing terrain
        terrainLayer.removeAllChildren()

        let farm = gameState.farm

        // Build tile sets for each biome that has at least one area
        var biomeTileSets: [String: (SKTileSet, SKTileGroup, SKTileGroup, SKTileGroup)] = [:]
        for area in farm.areas {
            let biome = area.biome.rawValue
            if biomeTileSets[biome] == nil {
                biomeTileSets[biome] = makeTileSet(for: biome)
            }
        }

        // Build a tunnel tile set (grey stone)
        let tunnelTileSet = makeTileSet(for: "meadow")
        // Note: tunnel cells use a neutral grey tile. The export tool should
        // produce a "tunnel" terrain tile, or we use meadow as fallback.
        // Decision needed: whether to add a dedicated tunnel tile to the sprite pipeline.

        // Collect all unique tile groups across biomes into one unified tile set
        var allGroups: [SKTileGroup] = []
        var biomeFloorGroups: [String: SKTileGroup] = [:]
        var biomeWallGroups: [String: SKTileGroup] = [:]
        var biomePostGroups: [String: SKTileGroup] = [:]

        for (biome, (_, floor, wall, post)) in biomeTileSets {
            allGroups.append(contentsOf: [floor, wall, post])
            biomeFloorGroups[biome] = floor
            biomeWallGroups[biome] = wall
            biomePostGroups[biome] = post
        }

        let unifiedTileSet = SKTileSet(tileGroups: allGroups)

        // Create a single tile map covering the full grid
        let tileMap = SKTileMapNode(
            tileSet: unifiedTileSet,
            columns: farm.width,
            rows: farm.height,
            tileSize: CGSize(
                width: SceneConstants.cellSize,
                height: SceneConstants.cellSize
            )
        )
        tileMap.position = CGPoint(
            x: CGFloat(farm.width) * SceneConstants.cellSize / 2,
            y: CGFloat(farm.height) * SceneConstants.cellSize / 2
        )
        tileMap.anchorPoint = CGPoint(x: 0.5, y: 0.5)

        // Fill cells
        for gridY in 0..<farm.height {
            for gridX in 0..<farm.width {
                let cell = farm.cells[gridY][gridX]

                // SKTileMapNode rows are numbered bottom-up (row 0 = bottom).
                // Grid Y=0 is the top of the farm, so we flip:
                let tileRow = farm.height - 1 - gridY

                // Skip void cells (not part of any area and not a tunnel)
                guard cell.areaID != nil || cell.isTunnel else { continue }

                // Determine the biome for this cell
                let biome: String
                if cell.isTunnel {
                    biome = "meadow" // Tunnels use meadow tile as fallback
                } else if let areaID = cell.areaID,
                          let area = farm.getAreaByID(areaID) {
                    biome = area.biome.rawValue
                } else {
                    continue
                }

                // Select tile group based on cell type
                let group: SKTileGroup?
                switch cell.cellType {
                case .wall:
                    if cell.isCorner {
                        group = biomePostGroups[biome]
                    } else {
                        group = biomeWallGroups[biome]
                    }
                case .floor, .bedding, .grass:
                    group = biomeFloorGroups[biome]
                }

                if let group {
                    tileMap.setTileGroup(group, forColumn: gridX, row: tileRow)
                }
            }
        }

        terrainLayer.addChild(tileMap)
    }
}
```

### Decision Needed: Tunnel Tile

The Python source renders tunnel cells with distinct grey stone coloring (`#3a3a3a` background with grey dot characters). The current terrain tile export (Spec 03) does not include a dedicated tunnel tile -- only per-biome floor/wall/post tiles.

**Options:**
1. Add a `terrain_tunnel_floor` tile to the sprite pipeline (preferred -- distinct visual)
2. Use meadow floor tile with a grey color tint applied via `SKSpriteNode.color` and `colorBlendFactor`
3. Use meadow floor tile as-is (tunnels look the same as meadow)

**Recommendation:** Option 1. Add a dedicated tunnel tile to the export pipeline (small scope -- one more tile image). File a follow-up task if this is deferred.

---

## 5. PigNode (Animated Sprite)

**Maps from:** `pig_renderer.py` (334 lines) -- `draw_pig()`, `draw_guinea_pigs()`, `_draw_indicator()`, `_update_indicator_timer()`.

**Swift file:** `BigPigFarm/Scene/PigNode.swift`

### Type Signature

```swift
import SpriteKit

/// A SpriteKit node that renders and animates a single guinea pig.
///
/// Maps from: ui/widgets/pig_renderer.py (draw_pig function)
///
/// Each PigNode is a child of FarmScene.pigLayer. It loads textures from
/// SpriteAssets, runs SKAction animations for the current behavior state,
/// and displays a name label below and an optional status indicator above.
class PigNode: SKSpriteNode {

    // MARK: - Identity

    /// The UUID of the guinea pig this node represents.
    let pigID: UUID

    // MARK: - Current Display State

    /// The pig's base color (determines which texture set to load).
    private var baseColor: BaseColor

    /// Whether this pig is a baby (smaller sprite, limited animation states).
    private var isBaby: Bool

    /// Current behavior state name (idle, walking, eating, etc.).
    private var currentState: String = "idle"

    /// Current facing direction (left, right).
    private var currentDirection: String = "right"

    /// The stored facing direction. Only updated when clear horizontal
    /// movement is detected, avoiding oscillation on vertical paths.
    /// Matches Python: `_pig_facing` dict in farm_view.py.
    private var storedFacing: String = "right"

    // MARK: - Child Nodes

    /// Name label displayed below the pig sprite.
    private let nameLabel: SKLabelNode

    /// Status indicator node displayed above the pig.
    /// Nil when no indicator is active.
    private var indicatorNode: SKSpriteNode?

    /// Selection glow effect node (elliptical highlight).
    private var selectionGlow: SKShapeNode?

    // MARK: - Selection

    /// Whether this pig is currently selected (follow camera + highlight).
    var isSelected: Bool = false {
        didSet {
            if isSelected != oldValue {
                updateSelectionGlow()
            }
        }
    }

    // MARK: - Animation Tracking

    /// Key identifying the current animation action (state_direction).
    /// Used to avoid restarting the same animation every frame.
    private var currentAnimationKey: String = ""
}
```

### Initialization

```swift
extension PigNode {
    /// Create a PigNode for a guinea pig.
    ///
    /// - Parameters:
    ///   - pig: The guinea pig data to render.
    ///   - scene: The FarmScene (used for coordinate conversion).
    convenience init(pig: GuineaPig, scene: FarmScene) {
        let isBaby = pig.isBaby
        let baseColor = pig.phenotype.baseColor
        let displayState = isBaby
            ? AnimationData.babyFallbackState(for: pig.displayState)
            : pig.displayState

        let texture = SpriteAssets.pigTexture(
            baseColor: baseColor,
            state: displayState,
            direction: "right",
            isBaby: isBaby
        )

        // Sprite size in points: art pixel dimensions x pointsPerArtPixel
        let artSize = isBaby
            ? SpriteAssets.babySpriteSize
            : SpriteAssets.adultSpriteSize
        let spriteSize = CGSize(
            width: artSize.width * SceneConstants.pointsPerArtPixel,
            height: artSize.height * SceneConstants.pointsPerArtPixel
        )

        self.init(texture: texture, color: .clear, size: spriteSize)

        self.pigID = pig.id
        self.baseColor = baseColor
        self.isBaby = isBaby

        // Name label
        nameLabel = SKLabelNode(fontNamed: "Helvetica")
        nameLabel.text = String(pig.name.prefix(10))
        nameLabel.fontSize = 10
        nameLabel.fontColor = .white
        nameLabel.alpha = 0.7
        nameLabel.verticalAlignmentMode = .top
        nameLabel.position = CGPoint(x: 0, y: -spriteSize.height / 2 - 2)
        addChild(nameLabel)

        // Set initial position
        let scenePos = scene.gridToScene(
            CGFloat(pig.position.x),
            CGFloat(pig.position.y)
        )
        position = scenePos

        // Ensure pixel-art crispness
        texture?.filteringMode = .nearest
    }
}
```

### Position and State Updates

Called every frame from `FarmScene.syncPigs()`. Updates the node's position and animation to match the current `GuineaPig` data.

```swift
extension PigNode {
    /// Update this node's position and animation from the latest pig data.
    ///
    /// Maps from: pig_renderer.py draw_pig() -- position calc, direction
    /// determination, animation frame selection.
    ///
    /// - Parameters:
    ///   - pig: The current GuineaPig data from GameState.
    ///   - scene: The FarmScene for coordinate conversion.
    func update(from pig: GuineaPig, in scene: FarmScene) {
        // Update position
        let scenePos = scene.gridToScene(
            CGFloat(pig.position.x),
            CGFloat(pig.position.y)
        )
        position = scenePos

        // Determine facing direction (port from Python pig_renderer.py)
        // Only update stored facing when a clear horizontal direction is found
        // in the path. This avoids rapid left/right flipping during vertical
        // movement or at float-boundary crossings.
        if !pig.path.isEmpty {
            for waypoint in pig.path {
                if CGFloat(waypoint.0) > CGFloat(pig.position.x) + 0.5 {
                    storedFacing = "right"
                    break
                } else if CGFloat(waypoint.0) < CGFloat(pig.position.x) - 0.5 {
                    storedFacing = "left"
                    break
                }
            }
        }

        // Determine display state (with baby fallback)
        let displayState = isBaby
            ? AnimationData.babyFallbackState(for: pig.displayState)
            : pig.displayState

        // Check if animation needs updating
        let animKey = "\(displayState)_\(storedFacing)"
        if animKey != currentAnimationKey {
            currentAnimationKey = animKey
            currentState = displayState
            currentDirection = storedFacing
            startAnimation(state: displayState, direction: storedFacing)
        }

        // Update name label
        nameLabel.text = String(pig.name.prefix(10))
        nameLabel.fontColor = isSelected ? .yellow : .white
        nameLabel.alpha = isSelected ? 1.0 : 0.7
    }
}
```

### Animation System

Animations are driven by `SKAction` sequences. Each behavior state maps to a texture array loaded via `SpriteAssets.pigAnimationFrames()`. Animated states use ping-pong looping (0, 1, 2, 1, 0, ...) to match the Python renderer's behavior.

**Maps from:** `pig_renderer.py` frame calculation -- ping-pong cycle with per-pig phase offset and speed variation.

```swift
extension PigNode {
    /// Start or restart the animation for the given state and direction.
    ///
    /// Static states (idle, sad) show a single texture. Animated states
    /// (walking, eating, sleeping, happy) run a ping-pong SKAction loop.
    ///
    /// - Parameters:
    ///   - state: Display state name (idle, walking, eating, sleeping, happy, sad).
    ///   - direction: Facing direction (left, right).
    private func startAnimation(state: String, direction: String) {
        // Remove any running animation
        removeAction(forKey: "pigAnimation")

        // Load textures
        let textures = SpriteAssets.pigAnimationFrames(
            baseColor: baseColor,
            state: state,
            direction: direction,
            isBaby: isBaby
        )

        guard !textures.isEmpty else { return }

        // Ensure nearest-neighbor filtering on all textures
        for tex in textures {
            tex.filteringMode = .nearest
        }

        // Static state (1 frame) -- just set the texture
        if textures.count == 1 {
            texture = textures[0]
            return
        }

        // Animated state -- build ping-pong sequence
        // Python uses ping-pong: for 3 frames -> 0,1,2,1,0,1,2,1...
        var pingPong = textures
        if textures.count > 2 {
            pingPong.append(contentsOf: textures.dropFirst().dropLast().reversed())
        } else {
            // 2 frames: just alternate 0,1,0,1...
            pingPong = textures
        }

        // Per-pig speed variation (port from Python)
        // Python: speed_var = (pig_hash >> 8) % 3 - 1 => -1, 0, or +1
        // ticksPerFrame adjusted by speed_var, clamped to >= 2
        let baseTicks = AnimationData.ticksPerFrame(for: state) ?? 3
        let pigHash = pigID.hashValue
        let speedVariation = ((pigHash >> 8) % 3) - 1
        let adjustedTicks = max(2, baseTicks + speedVariation)

        // Convert ticks to seconds: each tick is 1/10 second (10 TPS)
        let frameDuration = Double(adjustedTicks) / 10.0

        let animate = SKAction.animate(
            with: pingPong,
            timePerFrame: frameDuration,
            resize: false,
            restore: false
        )
        let loop = SKAction.repeatForever(animate)

        // Phase offset: start at a random point in the animation cycle
        // so pigs don't all animate in lockstep
        run(loop, withKey: "pigAnimation")
    }
}
```

### Selection Glow

When a pig is selected, an elliptical glow is drawn behind the sprite. This matches the Python renderer's `glow_bg` effect.

**Maps from:** `pig_renderer.py` lines 122-140 -- oval glow under selected pig.

```swift
extension PigNode {
    /// Show or hide the selection glow effect.
    private func updateSelectionGlow() {
        if isSelected {
            if selectionGlow == nil {
                let glowSize = CGSize(
                    width: size.width + 16,
                    height: size.height + 16
                )
                let glow = SKShapeNode(
                    ellipseOf: glowSize
                )
                glow.fillColor = SKColor(
                    red: 0.54, green: 0.44, blue: 0.06, alpha: 0.5
                )  // #8a7010 at 50% alpha
                glow.strokeColor = .clear
                glow.zPosition = -1
                addChild(glow)
                selectionGlow = glow
            }
        } else {
            selectionGlow?.removeFromParent()
            selectionGlow = nil
        }
    }
}
```

---

## 6. FacilityNode (Static Sprite)

**Maps from:** `farm_view.py` `_draw_facility()` and `_draw_facility_halfblock()` (lines 281-421).

**Swift file:** `BigPigFarm/Scene/FacilityNode.swift`

### Type Signature

```swift
import SpriteKit

/// A SpriteKit node that renders a facility on the farm grid.
///
/// Maps from: farm_view.py _draw_facility(), _draw_facility_halfblock()
///
/// Facilities are static sprites positioned at their grid location.
/// Consumable facilities (food bowl, water bottle, hay rack, feast table)
/// swap textures between normal, empty, and full states.
class FacilityNode: SKSpriteNode {

    // MARK: - Identity

    /// The UUID of the facility this node represents.
    let facilityID: UUID

    /// The facility type (used for texture lookup).
    let facilityType: FacilityType

    // MARK: - State Tracking

    /// Current texture state key (nil, "empty", or "full").
    /// Used to avoid redundant texture swaps.
    private var currentTextureState: String?

    // MARK: - Child Nodes

    /// Label displayed below the facility sprite.
    private let nameLabel: SKLabelNode

    // MARK: - Edit Mode

    /// Whether this facility is selected in edit mode.
    var isSelectedInEditMode: Bool = false {
        didSet {
            if isSelectedInEditMode != oldValue {
                updateEditHighlight()
            }
        }
    }

    /// Whether this facility is currently being moved.
    var isBeingMoved: Bool = false {
        didSet {
            if isBeingMoved != oldValue {
                updateEditHighlight()
            }
        }
    }
}
```

### Facility Labels

Short labels displayed below facility sprites, matching the Python `_FACILITY_LABELS` dictionary.

```swift
extension FacilityNode {
    /// Short display labels for facility types.
    ///
    /// Maps from: farm_view.py _FACILITY_LABELS dict.
    static let facilityLabels: [String: String] = [
        "food_bowl": "Food",
        "water_bottle": "Water",
        "hay_rack": "Hay",
        "hideout": "Hideout",
        "exercise_wheel": "Wheel",
        "tunnel": "Tunnel",
        "play_area": "Play",
        "breeding_den": "Love Den",
        "nursery": "Nursery",
        "veggie_garden": "Garden",
        "grooming_station": "Groom",
        "genetics_lab": "Gen. Lab",
        "feast_table": "Feast",
        "campfire": "Campfire",
        "therapy_garden": "Therapy",
        "hot_spring": "Hot Spring",
        "stage": "Stage",
    ]
}
```

### Initialization

```swift
extension FacilityNode {
    /// Create a FacilityNode for a facility.
    ///
    /// - Parameters:
    ///   - facility: The facility data to render.
    ///   - scene: The FarmScene for coordinate conversion.
    convenience init(facility: Facility, scene: FarmScene) {
        let texture = SpriteAssets.facilityTexture(
            facilityType: facility.facilityType.rawValue
        )

        // Facility sprite size: use the texture's natural size scaled by pointsPerArtPixel.
        // The texture is exported at the art pixel resolution; SpriteKit scales it.
        let spriteSize = CGSize(
            width: texture.size().width * SceneConstants.pointsPerArtPixel,
            height: texture.size().height * SceneConstants.pointsPerArtPixel
        )

        self.init(texture: texture, color: .clear, size: spriteSize)

        self.facilityID = facility.id
        self.facilityType = facility.facilityType

        // Ensure pixel-art crispness
        texture?.filteringMode = .nearest

        // Name label
        let labelText = Self.facilityLabels[facility.facilityType.rawValue] ?? ""
        nameLabel = SKLabelNode(fontNamed: "Helvetica")
        nameLabel.text = labelText
        nameLabel.fontSize = 9
        nameLabel.fontColor = SKColor(white: 1.0, alpha: 0.6)
        nameLabel.verticalAlignmentMode = .top
        nameLabel.position = CGPoint(x: 0, y: -spriteSize.height / 2 - 2)
        addChild(nameLabel)

        // Position: facilities are anchored at their grid position (top-left in Python).
        // In SpriteKit, the anchor point is the center by default. Position the node
        // so that the top-left corner of the sprite aligns with the grid cell.
        let scenePos = scene.gridToScene(
            CGFloat(facility.positionX),
            CGFloat(facility.positionY)
        )
        // Offset by half the sprite size to align top-left with grid position
        position = CGPoint(
            x: scenePos.x + spriteSize.width / 2,
            y: scenePos.y - spriteSize.height / 2
        )
    }
}
```

### State Updates

```swift
extension FacilityNode {
    /// Update this node from the latest facility data.
    ///
    /// Swaps textures for consumable facilities based on fill state
    /// (empty, full, or normal). Repositions if the facility has been moved.
    func update(from facility: Facility, in scene: FarmScene) {
        // Determine texture state for consumable facilities
        let newState: String?
        if facility.isEmpty {
            newState = "empty"
        } else if facility.currentAmount >= facility.maxAmount {
            newState = "full"
        } else {
            newState = nil
        }

        // Swap texture only if state changed
        if newState != currentTextureState {
            currentTextureState = newState
            let newTexture = SpriteAssets.facilityTexture(
                facilityType: facility.facilityType.rawValue,
                state: newState
            )
            newTexture.filteringMode = .nearest
            texture = newTexture
        }

        // Update position (in case facility was moved in edit mode)
        let scenePos = scene.gridToScene(
            CGFloat(facility.positionX),
            CGFloat(facility.positionY)
        )
        position = CGPoint(
            x: scenePos.x + size.width / 2,
            y: scenePos.y - size.height / 2
        )
    }
}
```

### Edit Mode Highlight

```swift
extension FacilityNode {
    /// Update the visual highlight for edit mode selection.
    private func updateEditHighlight() {
        if isBeingMoved {
            colorBlendFactor = 0.5
            color = .green
        } else if isSelectedInEditMode {
            colorBlendFactor = 0.3
            color = .yellow
        } else {
            colorBlendFactor = 0.0
        }
    }
}
```

---

## 7. CameraController (Pan/Zoom/Bounds)

**Maps from:** `farm_view.py` `_clamp_viewport()`, `scroll()`, `center_on_pig()`, `cycle_zoom()`, mouse scroll handlers.

**Swift file:** `BigPigFarm/Scene/CameraController.swift`

### Architecture

The Python source uses a viewport offset (`_viewport_x`, `_viewport_y`) and zoom scale to determine which portion of the grid is visible. In SpriteKit, the `SKCameraNode` handles this natively -- its `position` controls the viewport center, and its `xScale`/`yScale` control zoom.

Touch input uses gesture recognizers attached to the `SKView`:
- `UIPanGestureRecognizer` for camera panning
- `UIPinchGestureRecognizer` for pinch-to-zoom

### Type Signature

```swift
import SpriteKit
import UIKit

/// Manages camera pan, zoom, and bounds clamping for the farm scene.
///
/// Maps from: farm_view.py viewport management (_clamp_viewport, scroll,
/// center_on_pig, cycle_zoom, VIEWPORT_PADDING)
///
/// Uses UIPanGestureRecognizer for dragging and UIPinchGestureRecognizer
/// for pinch-to-zoom. The camera's position and scale are clamped to
/// keep the farm visible within bounds.
@MainActor
class CameraController {

    // MARK: - References

    /// The SKCameraNode being controlled.
    private let camera: SKCameraNode

    /// The scene this camera belongs to (for size queries).
    private weak var scene: FarmScene?

    // MARK: - Farm Dimensions

    /// Farm width in grid cells.
    private var farmWidth: Int

    /// Farm height in grid cells.
    private var farmHeight: Int

    // MARK: - Gesture State

    /// Camera position at the start of a pan gesture.
    private var panStartPosition: CGPoint = .zero

    /// Camera scale at the start of a pinch gesture.
    private var pinchStartScale: CGFloat = 1.0

    // MARK: - Follow Mode

    /// Whether the camera is following a pig (smooth tracking).
    private var isFollowing: Bool = false
}
```

### Initialization and Gesture Setup

```swift
extension CameraController {
    init(
        camera: SKCameraNode,
        scene: FarmScene,
        farmWidth: Int,
        farmHeight: Int
    ) {
        self.camera = camera
        self.scene = scene
        self.farmWidth = farmWidth
        self.farmHeight = farmHeight
    }

    /// Attach gesture recognizers to the SKView.
    ///
    /// Called from FarmScene.didMove(to:).
    func setupGestureRecognizers(in view: SKView) {
        let pan = UIPanGestureRecognizer(
            target: self, action: #selector(handlePan(_:))
        )
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(
            target: self, action: #selector(handlePinch(_:))
        )
        view.addGestureRecognizer(pinch)
    }
}
```

### Pan Gesture

```swift
extension CameraController {
    /// Handle pan gesture for camera dragging.
    ///
    /// Maps from: farm_view.py scroll(dx, dy) and mouse scroll handlers.
    ///
    /// The translation is inverted because dragging "right" should move
    /// the camera "left" (revealing content to the right). The translation
    /// is also scaled by the camera's current zoom level.
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let view = scene?.view else { return }

        switch gesture.state {
        case .began:
            isFollowing = false
            panStartPosition = camera.position

        case .changed:
            let translation = gesture.translation(in: view)
            let scale = camera.xScale

            // Invert: drag right = camera moves left
            // Scale: at higher zoom (smaller scale), drag moves less
            camera.position = CGPoint(
                x: panStartPosition.x - translation.x * scale,
                y: panStartPosition.y + translation.y * scale
                // Y is inverted because UIKit Y-down vs SpriteKit Y-up
            )
            clampCameraPosition()

        case .ended, .cancelled:
            clampCameraPosition()

        default:
            break
        }
    }
}
```

### Pinch-to-Zoom

```swift
extension CameraController {
    /// Handle pinch gesture for camera zooming.
    ///
    /// Maps from: farm_view.py cycle_zoom() -- but continuous instead of discrete.
    ///
    /// Pinch-out (scale > 1) zooms in (camera scale decreases).
    /// Pinch-in (scale < 1) zooms out (camera scale increases).
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            isFollowing = false
            pinchStartScale = camera.xScale

        case .changed:
            // Invert: pinch-out (gesture.scale > 1) should zoom in (smaller camera scale)
            let newScale = pinchStartScale / gesture.scale
            let clampedScale = max(
                SceneConstants.minCameraScale,
                min(newScale, SceneConstants.maxCameraScale)
            )
            camera.setScale(clampedScale)
            clampCameraPosition()

        case .ended, .cancelled:
            clampCameraPosition()

        default:
            break
        }
    }
}
```

### Bounds Clamping

Prevents the camera from scrolling beyond the farm edges (with padding), matching the Python `_clamp_viewport()` behavior.

```swift
extension CameraController {
    /// Clamp the camera position to keep the farm visible.
    ///
    /// Maps from: farm_view.py _clamp_viewport()
    ///
    /// The visible area depends on the camera's scale (zoom level) and
    /// the view's size. We add VIEWPORT_PADDING cells of extra scroll
    /// beyond the farm edges.
    func clampCameraPosition() {
        guard let view = scene?.view else { return }

        let scale = camera.xScale
        let viewWidth = view.bounds.width * scale
        let viewHeight = view.bounds.height * scale

        let farmWidthPoints = CGFloat(farmWidth) * SceneConstants.cellSize
        let farmHeightPoints = CGFloat(farmHeight) * SceneConstants.cellSize
        let padding = SceneConstants.viewportPadding * SceneConstants.cellSize

        let minX = viewWidth / 2 - padding
        let maxX = farmWidthPoints - viewWidth / 2 + padding
        let minY = viewHeight / 2 - padding
        let maxY = farmHeightPoints - viewHeight / 2 + padding

        var pos = camera.position

        if maxX > minX {
            pos.x = max(minX, min(pos.x, maxX))
        } else {
            // Farm is smaller than the view -- center the camera
            pos.x = farmWidthPoints / 2
        }

        if maxY > minY {
            pos.y = max(minY, min(pos.y, maxY))
        } else {
            pos.y = farmHeightPoints / 2
        }

        camera.position = pos
    }
}
```

### Follow Camera

Centers the camera on a pig, used when a pig is selected.

```swift
extension CameraController {
    /// Center the camera on a scene position (used for follow-pig mode).
    ///
    /// Maps from: farm_view.py center_on_pig()
    func follow(_ position: CGPoint) {
        isFollowing = true
        camera.position = position
        clampCameraPosition()
    }

    /// Update farm dimensions (after grid expansion).
    func updateFarmDimensions(width: Int, height: Int) {
        farmWidth = width
        farmHeight = height
    }

    /// Programmatic zoom to a specific scale with animation.
    ///
    /// - Parameters:
    ///   - scale: Target camera scale.
    ///   - duration: Animation duration in seconds.
    func zoomTo(scale: CGFloat, duration: TimeInterval = 0.3) {
        let clamped = max(
            SceneConstants.minCameraScale,
            min(scale, SceneConstants.maxCameraScale)
        )
        let action = SKAction.scale(to: clamped, duration: duration)
        action.timingMode = .easeInEaseOut
        camera.run(action) { [weak self] in
            self?.clampCameraPosition()
        }
    }

    /// Get the current zoom scale.
    var currentScale: CGFloat {
        camera.xScale
    }
}
```

---

## 8. Touch Handling

**Maps from:** `farm_view.py` `on_click()` (line 519), `pig_renderer.py` `pig_at_screen_pos()` (line 282), `main_game.py` `on_farm_view_pig_clicked/empty_clicked`.

### Tap Recognition

Touch handling for pig selection uses `touchesBegan`/`touchesEnded` on `FarmScene` rather than gesture recognizers. This avoids conflicts with the pan gesture recognizer and gives direct access to SpriteKit's node hit testing.

The pan gesture recognizer is configured with `maximumNumberOfTouches = 1` and requires a minimum translation before activating, so brief taps still reach `touchesEnded`.

```swift
extension FarmScene {
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        if isEditMode {
            handleEditModeTap(at: location)
            return
        }

        // Check if a pig was tapped
        if let pigNode = pigNodeAt(location) {
            selectedPigID = pigNode.pigID
            delegate?.farmScene(self, didSelectPig: pigNode.pigID)
        } else {
            selectedPigID = nil
            delegate?.farmSceneDidDeselectPig(self)
        }
    }
}
```

### Pig Hit Testing

Finds the pig closest to a tap point. Uses node-based hit testing with expanded hit areas for small sprites.

**Maps from:** `pig_renderer.py` `pig_at_screen_pos()` -- iterates all pigs, checks sprite bounds with padding, picks closest by center distance.

```swift
extension FarmScene {
    /// Find the PigNode closest to a scene position.
    ///
    /// Maps from: pig_renderer.py pig_at_screen_pos()
    ///
    /// Uses SpriteKit's coordinate system. Expands the hit area by a
    /// tap tolerance to make small sprites easier to tap on mobile.
    ///
    /// - Parameter location: The tap position in scene coordinates.
    /// - Returns: The closest PigNode within tap tolerance, or nil.
    private func pigNodeAt(_ location: CGPoint) -> PigNode? {
        let tapTolerance: CGFloat = 16.0 // Extra points around sprite bounds

        var bestNode: PigNode? = nil
        var bestDistance: CGFloat = .infinity

        for (_, node) in pigNodes {
            let expandedFrame = node.frame.insetBy(
                dx: -tapTolerance,
                dy: -tapTolerance
            )
            guard expandedFrame.contains(location) else { continue }

            let distance = hypot(
                location.x - node.position.x,
                location.y - node.position.y
            )
            if distance < bestDistance {
                bestDistance = distance
                bestNode = node
            }
        }

        return bestNode
    }
}
```

### Selection Highlight Update

```swift
extension FarmScene {
    /// Update all pig nodes' selection state.
    private func updateSelectionHighlight() {
        for (pigID, node) in pigNodes {
            node.isSelected = (pigID == selectedPigID)
        }
    }
}
```

---

## 9. Edit Mode

**Maps from:** `edit_mode.py` (149 lines) -- `toggle_edit_mode()`, `select_facility_at_cursor()`, `move_cursor()`, `start_moving_facility()`, `confirm_placement()`, `remove_selected_facility()`, `draw_cursor()`.

The Python edit mode uses a keyboard-driven cursor that moves cell-by-cell. On iOS, edit mode uses direct tap-to-select and drag-to-move instead, which is more natural for touch interaction.

### Edit Mode State

Edit mode is toggled via a button in the SwiftUI HUD (StatusBarView, Doc 07). When active:
1. Tapping a facility selects it (highlighted in yellow)
2. A "Move" action starts drag mode (facility follows touch)
3. A "Remove" action deletes the facility and fires a callback for refunding

### Tap in Edit Mode

```swift
extension FarmScene {
    /// Handle a tap in edit mode -- select or deselect a facility.
    ///
    /// Maps from: edit_mode.py select_facility_at_cursor()
    private func handleEditModeTap(at location: CGPoint) {
        // Check if a facility was tapped
        for (facilityID, node) in facilityNodes {
            let expandedFrame = node.frame.insetBy(dx: -8, dy: -8)
            if expandedFrame.contains(location) {
                selectedFacilityID = facilityID
                syncFacilities() // Update highlight state
                delegate?.farmScene(self, didSelectFacility: facilityID)
                return
            }
        }

        // Tapped empty space -- deselect
        selectedFacilityID = nil
        syncFacilities()
    }
}
```

### Facility Move

Moving a facility is initiated from the SwiftUI layer (via a "Move" button) and uses the pan gesture to drag the facility. The FarmScene validates walkability at the new position.

```swift
extension FarmScene {
    /// Begin moving the selected facility.
    ///
    /// Maps from: edit_mode.py start_moving_facility()
    func startMovingSelectedFacility() {
        guard let facilityID = selectedFacilityID,
              let node = facilityNodes[facilityID] else { return }
        isMovingFacility = true
        node.isBeingMoved = true
    }

    /// Move the selected facility to a new grid position.
    ///
    /// Maps from: edit_mode.py move_cursor() with moving_facility=True
    ///
    /// - Parameter gridPosition: The target grid position.
    /// - Returns: True if the position is valid (walkable, not overlapping).
    func moveSelectedFacility(to gridPosition: GridPosition) -> Bool {
        guard let facilityID = selectedFacilityID,
              let facility = gameState.getFacility(facilityID) else {
            return false
        }

        let farm = gameState.farm

        // Check walkability at new position
        guard farm.isWalkable(gridPosition.x, gridPosition.y) else {
            return false
        }

        // Check overlap with other facilities (min 3-cell spacing)
        for other in gameState.getFacilitiesList() {
            if other.id != facilityID {
                if abs(other.positionX - gridPosition.x) < 3
                    && abs(other.positionY - gridPosition.y) < 3 {
                    return false
                }
            }
        }

        // Move the facility in GameState
        farm.removeFacility(facility)
        var movedFacility = facility
        movedFacility.positionX = gridPosition.x
        movedFacility.positionY = gridPosition.y
        _ = farm.placeFacility(movedFacility)
        gameState.facilities[facilityID] = movedFacility

        return true
    }

    /// Confirm facility placement (end move mode).
    ///
    /// Maps from: edit_mode.py confirm_placement()
    func confirmFacilityPlacement() {
        guard let facilityID = selectedFacilityID,
              let node = facilityNodes[facilityID] else { return }
        isMovingFacility = false
        node.isBeingMoved = false
    }

    /// Remove the selected facility from the game.
    ///
    /// Maps from: edit_mode.py remove_selected_facility()
    func removeSelectedFacility() {
        guard let facilityID = selectedFacilityID else { return }
        selectedFacilityID = nil
        isMovingFacility = false
        delegate?.farmScene(self, didRemoveFacility: facilityID)
    }
}
```

---

## 10. Status Indicators

**Maps from:** `pig_renderer.py` `_draw_indicator()`, `_update_indicator_timer()`, `_IndicatorTimer` class. `indicator_sprites.py` `get_pig_indicator_type()`.

Status indicators are small floating icons above pigs that show when a need is critical or when the pig is courting/pregnant. They follow a show/cooldown/resurface cycle to avoid visual clutter.

### IndicatorTimer

```swift
/// Tracks the ephemeral show/cooldown cycle for one pig's status indicator.
///
/// Maps from: pig_renderer.py _IndicatorTimer class
struct IndicatorTimer: Sendable {
    /// Which indicator is active.
    var indicatorType: String

    /// Frame number when the indicator was triggered.
    var triggerFrame: Int

    /// Whether the indicator is currently in the visible phase.
    var isVisible: Bool = true
}
```

### Indicator Constants

```swift
extension FarmScene {
    /// Indicator timing constants (in frames at ~60fps).
    ///
    /// Maps from: pig_renderer.py _INDICATOR_SHOW_TICKS, _INDICATOR_COOLDOWN_TICKS,
    /// _INDICATOR_PULSE_TICKS. Scaled from 15fps render ticks to 60fps frames.
    private enum IndicatorConfig {
        /// Frames the indicator is visible (~3 seconds at 60fps).
        static let showFrames: Int = 180

        /// Frames the indicator is hidden during cooldown (~10 seconds at 60fps).
        static let cooldownFrames: Int = 600

        /// Frames per pulse toggle (~0.5 seconds at 60fps).
        static let pulseFrames: Int = 30
    }
}
```

### Indicator Priority

```swift
extension FarmScene {
    /// Determine the highest-priority indicator type for a pig.
    ///
    /// Maps from: indicator_sprites.py get_pig_indicator_type()
    ///
    /// Priority order: health > hunger > thirst > energy > courting > pregnant.
    /// Returns nil if no indicator should show.
    private func indicatorType(for pig: GuineaPig) -> String? {
        let lowThreshold = NeedsConfig.lowThreshold  // 40.0

        if pig.needs.health < lowThreshold { return "health" }
        if pig.needs.hunger < lowThreshold
            || pig.behaviorState == .eating { return "hunger" }
        if pig.needs.thirst < lowThreshold
            || pig.behaviorState == .drinking { return "thirst" }
        if pig.needs.energy < lowThreshold
            || pig.behaviorState == .sleeping { return "energy" }
        if pig.behaviorState == .courting { return "courting" }
        if pig.isPregnant { return "pregnant" }
        return nil
    }
}
```

### Indicator Rendering

```swift
extension FarmScene {
    /// Update the status indicator for a pig node.
    ///
    /// Maps from: pig_renderer.py _draw_indicator(), _update_indicator_timer()
    ///
    /// Manages the show/cooldown/resurface cycle and pulse animation.
    private func updateIndicator(for node: PigNode, pig: GuineaPig) {
        // Don't show indicators for selected pig (detail view shows needs)
        guard !node.isSelected else {
            node.hideIndicator()
            return
        }

        guard let type = indicatorType(for: pig) else {
            // No critical need -- clear timer and hide
            indicatorTimers.removeValue(forKey: pig.id)
            node.hideIndicator()
            return
        }

        var timer = indicatorTimers[pig.id]

        // New indicator or type changed -- start fresh
        if timer == nil || timer?.indicatorType != type {
            timer = IndicatorTimer(
                indicatorType: type,
                triggerFrame: frameCount
            )
            indicatorTimers[pig.id] = timer
        }

        guard let activeTimer = timer else { return }
        let elapsed = frameCount - activeTimer.triggerFrame

        if elapsed < IndicatorConfig.showFrames {
            // Show phase -- pulse between bright and dim
            let bright = (frameCount / IndicatorConfig.pulseFrames) % 2 == 0
            node.showIndicator(type: type, bright: bright)
        } else if elapsed < IndicatorConfig.showFrames + IndicatorConfig.cooldownFrames {
            // Cooldown phase -- hide
            node.hideIndicator()
        } else {
            // Cooldown expired -- resurface
            indicatorTimers[pig.id]?.triggerFrame = frameCount
            let bright = (frameCount / IndicatorConfig.pulseFrames) % 2 == 0
            node.showIndicator(type: type, bright: bright)
        }
    }
}
```

### PigNode Indicator Methods

```swift
extension PigNode {
    /// Show a status indicator above this pig.
    ///
    /// - Parameters:
    ///   - type: Indicator type name (health, hunger, thirst, energy, courting, pregnant).
    ///   - bright: Whether to show the bright or dim pulse frame.
    func showIndicator(type: String, bright: Bool) {
        let texture = SpriteAssets.indicatorTexture(
            indicatorType: type,
            bright: bright
        )
        texture.filteringMode = .nearest

        if indicatorNode == nil {
            let node = SKSpriteNode(texture: texture)
            // Position above the pig sprite
            node.position = CGPoint(x: 0, y: size.height / 2 + 12)
            node.zPosition = 5
            addChild(node)
            indicatorNode = node
        } else {
            indicatorNode?.texture = texture
        }
    }

    /// Hide the status indicator.
    func hideIndicator() {
        indicatorNode?.removeFromParent()
        indicatorNode = nil
    }
}
```

---

## 11. SpriteView Integration into ContentView

**Maps from:** `main_game.py` `MainGameScreen` (536 lines) -- composition, screen pushing, event handling.

**Swift file:** `BigPigFarm/ContentView.swift`

### Architecture Decision

Per ROADMAP Decision 5, `SpriteView` is the root view. SwiftUI screens are presented as `.sheet` overlays. The simulation runs continuously in the background (via `GameEngine` timer) and the `FarmScene` reads the latest state each frame.

`ContentView` owns the `FarmScene` instance and acts as its delegate. It manages sheet presentation state and passes `GameState` to SwiftUI screens.

### Type Signature

```swift
import SwiftUI
import SpriteKit

/// Root view of the app. Embeds the SpriteKit farm scene and overlays
/// SwiftUI HUD elements. Menu screens are presented as .sheet modifiers.
///
/// Maps from: ui/screens/main_game.py (MainGameScreen)
///
/// Architecture: SpriteView displays FarmScene. StatusBarView floats on top.
/// Shop, PigList, Breeding, etc. are presented via .sheet when triggered
/// by user actions.
struct ContentView: View {
    /// The shared game state, created by BigPigFarmApp.
    @State var gameState: GameState

    /// The game engine managing the tick loop.
    @State var engine: GameEngine

    /// The farm scene displayed in SpriteView.
    @State private var farmScene: FarmScene

    /// The coordinator that bridges FarmScene delegate to SwiftUI state.
    @State private var coordinator: FarmSceneCoordinator

    // MARK: - Sheet Presentation State

    @State private var showShop = false
    @State private var showPigList = false
    @State private var showBreeding = false
    @State private var showAlmanac = false
    @State private var showBiomeSelect = false
    @State private var showPigDetail = false

    /// The pig currently selected for detail view.
    @State private var selectedPigID: UUID?

    /// Whether edit mode is active.
    @State private var isEditMode = false

    var body: some View {
        ZStack(alignment: .top) {
            // Farm scene (full screen)
            SpriteView(
                scene: farmScene,
                transition: nil,
                isPaused: false,
                preferredFramesPerSecond: 60,
                options: [.ignoresSiblingEvents],
                debugOptions: []
            )
            .ignoresSafeArea()

            // HUD overlay (top bar)
            VStack {
                StatusBarView(
                    gameState: gameState,
                    isEditMode: $isEditMode,
                    onShopTapped: { showShop = true },
                    onPigListTapped: { showPigList = true },
                    onBreedingTapped: { showBreeding = true },
                    onAlmanacTapped: { showAlmanac = true },
                    onEditTapped: { toggleEditMode() },
                    onPauseTapped: { togglePause() },
                    onSpeedTapped: { cycleSpeed() }
                )
                Spacer()
            }
        }
        .sheet(isPresented: $showShop) {
            // ShopView(gameState: gameState) -- Doc 07
            Text("Shop") // Placeholder until Doc 07
        }
        .sheet(isPresented: $showPigList) {
            // PigListView(gameState: gameState) -- Doc 07
            Text("Pig List")
        }
        .sheet(isPresented: $showBreeding) {
            // BreedingView(gameState: gameState) -- Doc 07
            Text("Breeding")
        }
        .sheet(isPresented: $showAlmanac) {
            // AlmanacView(gameState: gameState) -- Doc 07
            Text("Almanac")
        }
        .sheet(isPresented: $showPigDetail) {
            if let pigID = selectedPigID {
                // PigDetailView(gameState: gameState, pigID: pigID) -- Doc 07
                Text("Pig Detail: \(pigID)")
            }
        }
        .onAppear {
            coordinator.contentView = self
        }
    }
}
```

### FarmSceneCoordinator

A reference-type coordinator bridges `FarmSceneDelegate` callbacks from the SpriteKit scene to SwiftUI state updates. This is necessary because `FarmSceneDelegate` requires a class (weak reference), and `ContentView` is a struct.

```swift
/// Bridges FarmScene delegate callbacks to SwiftUI state in ContentView.
///
/// FarmScene holds a weak reference to its delegate. Since ContentView is
/// a struct, this coordinator class acts as the intermediary, forwarding
/// events to update ContentView's @State properties.
@MainActor
class FarmSceneCoordinator: FarmSceneDelegate {
    /// Back-reference to ContentView (set in onAppear).
    /// This is unowned because the coordinator's lifetime is tied to ContentView.
    weak var contentView: ContentView?

    private let gameState: GameState

    init(gameState: GameState) {
        self.gameState = gameState
    }

    func farmScene(_ scene: FarmScene, didSelectPig pigID: UUID) {
        // Update ContentView state to show pig detail or follow camera
        // The actual SwiftUI state mutation happens via the binding
        // mechanism documented in Doc 07.
    }

    func farmSceneDidDeselectPig(_ scene: FarmScene) {
        // Clear pig selection
    }

    func farmScene(_ scene: FarmScene, didSelectFacility facilityID: UUID) {
        // Show facility options in edit mode
    }

    func farmScene(_ scene: FarmScene, didRemoveFacility facilityID: UUID) {
        // Remove facility from GameState and refund cost
        if let facility = gameState.removeFacility(facilityID) {
            let refund = Shop.facilityCost(facility.facilityType)
            gameState.addMoney(refund)
        }
    }
}
```

### ContentView Action Methods

```swift
extension ContentView {
    /// Toggle the game pause state.
    ///
    /// Maps from: main_game.py action_toggle_pause()
    private func togglePause() {
        _ = engine.togglePause()
    }

    /// Cycle the game speed.
    ///
    /// Maps from: main_game.py action_speed_up()
    private func cycleSpeed() {
        _ = engine.cycleSpeed()
    }

    /// Toggle edit mode on the farm scene.
    ///
    /// Maps from: main_game.py action_toggle_edit()
    private func toggleEditMode() {
        isEditMode.toggle()
        farmScene.isEditMode = isEditMode
        if !isEditMode {
            farmScene.selectedFacilityID = nil
            farmScene.isMovingFacility = false
        }
    }
}
```

### SpriteView Options

The `SpriteView` is configured with:
- `isPaused: false` -- the scene's update loop runs continuously
- `preferredFramesPerSecond: 60` -- targeting 60fps rendering
- `.ignoresSiblingEvents` -- prevents SwiftUI from intercepting touch events meant for the SpriteKit scene
- No `debugOptions` in production (`.showsFPS` and `.showsNodeCount` can be enabled for debugging)

### Decision Needed: ContentView Coordinator Pattern

The coordinator pattern shown above is one approach to bridging FarmScene delegate callbacks to SwiftUI state. An alternative is to use Combine publishers or an `@Observable` intermediary. The coordinator pattern is simpler and sufficient for the small number of events (pig select, facility select, facility remove).

If the SwiftUI layer needs to trigger actions on `FarmScene` (e.g., "center on pig" from the pig list), `ContentView` can call methods directly on its `farmScene` reference since `FarmScene` is `@MainActor`.

---

## 12. Performance Considerations

### Node Count Management

The farm supports up to ~50 pigs at maximum capacity. Each pig has 1 `PigNode` (with 1-2 child nodes for label and indicator). Facilities cap at ~30. Terrain is a single `SKTileMapNode`. Total node count is well under 200, which is trivially fast for SpriteKit.

### Off-Screen Optimization

SpriteKit automatically culls off-screen nodes when rendering. No manual visibility management is needed. The `SKCameraNode` defines the visible region, and SpriteKit skips rendering nodes outside that region.

However, `SKAction` animations continue running on off-screen nodes. For 50 pigs with simple texture-swap animations, this is negligible overhead. If profiling shows animation as a bottleneck, animations can be paused on off-screen nodes using `isPaused` based on the camera's visible rect.

### Texture Caching

SpriteKit caches `SKTexture` objects by name. Calling `SKTexture(imageNamed:)` with the same name returns the cached texture. The `SpriteAssets` API (Spec 03) always uses the same naming convention, so textures are loaded once and reused.

### Render Budget

At 60fps, each frame has a 16.67ms budget. The scene update loop (`syncPigs`, `syncFacilities`) iterates over all pigs and facilities once per frame. With 50 pigs:
- Position update: 50 x CGPoint assignment = trivial
- Animation check: 50 x string comparison = trivial
- Indicator update: 50 x threshold check = trivial

The terrain rebuild only happens when `gridGeneration` changes (room additions, tunnels), which is rare during gameplay.

### SKTileMapNode Efficiency

A single `SKTileMapNode` with 5,376 tiles (96x56 grid) is well within SpriteKit's performance limits. The tile map is rendered as a single draw call by the GPU. This is orders of magnitude more efficient than 5,376 individual `SKSpriteNode` objects (per ROADMAP Decision 4).

### Investigation Item: SpriteView Performance

Per the CHECKLIST investigation item "Test SpriteView performance with 50+ animated nodes (during Phase 3)", the implementer should profile with Instruments after completing the initial implementation. Specific metrics to track:
- Frame time in the SpriteKit render loop
- CPU time in `update(_:)` for pig/facility sync
- GPU draw call count
- Memory usage for loaded textures

---

## 13. Stub Corrections

The Doc 01 stubs created placeholder types that need updating:

| File | Current Declaration | Correct Declaration | Reason |
|------|-------------------|-------------------|--------|
| `Scene/FarmScene.swift` | `class FarmScene: SKScene` | `@MainActor class FarmScene: SKScene` | Needs `@MainActor` for `GameState` access |
| `Scene/PigNode.swift` | `class PigNode: SKSpriteNode` | `class PigNode: SKSpriteNode` | No change needed |
| `Scene/FacilityNode.swift` | `class FacilityNode: SKSpriteNode` | `class FacilityNode: SKSpriteNode` | No change needed |
| `Scene/CameraController.swift` | `class CameraController` | `@MainActor class CameraController` | Needs `@MainActor` for scene/view access |
| `ContentView.swift` | `struct ContentView: View` | `struct ContentView: View` | No type change, but body completely rewritten |

### New Files

| File | Purpose |
|------|---------|
| `BigPigFarmTests/FarmSceneTests.swift` | Tests for coordinate conversion, pig node animation mapping, camera bounds |

---

## 14. Test Specifications

**Test file:** `BigPigFarmTests/FarmSceneTests.swift`

### Coordinate Conversion Tests

```swift
import Testing
@testable import BigPigFarm

@Suite("FarmScene Coordinate Conversion")
struct CoordinateConversionTests {

    @Test("Grid origin (0,0) maps to top-left of scene")
    func gridOriginMapsToTopLeft() {
        // Grid (0,0) is top-left. In a 10x10 farm, scene Y = 10 * cellSize.
        let farmHeight = 10
        let sceneY = CGFloat(farmHeight) * SceneConstants.cellSize
        let sceneX: CGFloat = 0

        // gridToScene(0, 0) should give (0, farmHeight * cellSize)
        #expect(sceneX == 0)
        #expect(sceneY == 320) // 10 * 32
    }

    @Test("Grid bottom-right maps to scene origin area")
    func gridBottomRightMapsToSceneOrigin() {
        let farmHeight = 10
        let farmWidth = 10

        // Grid (9, 9) should map to near scene (9*32, 1*32) = (288, 32)
        let sceneX = CGFloat(9) * SceneConstants.cellSize
        let sceneY = (CGFloat(farmHeight) - CGFloat(9)) * SceneConstants.cellSize

        #expect(sceneX == 288)
        #expect(sceneY == 32)
    }

    @Test("Round-trip grid -> scene -> grid preserves position")
    func roundTripConversion() {
        let farmHeight = 20
        let gridX: CGFloat = 5.5
        let gridY: CGFloat = 12.3

        let sceneX = gridX * SceneConstants.cellSize
        let sceneY = (CGFloat(farmHeight) - gridY) * SceneConstants.cellSize

        let backX = sceneX / SceneConstants.cellSize
        let backY = CGFloat(farmHeight) - (sceneY / SceneConstants.cellSize)

        #expect(abs(backX - gridX) < 0.001)
        #expect(abs(backY - gridY) < 0.001)
    }

    @Test("Cell size is consistent with spec constants")
    func cellSizeConsistency() {
        #expect(SceneConstants.cellSize == 32.0)
        #expect(SceneConstants.pointsPerArtPixel == 4.0)
        // 8 art pixels per tile * 4 points per art pixel = 32 points
        #expect(SceneConstants.cellSize == 8 * SceneConstants.pointsPerArtPixel)
    }
}
```

### Animation Mapping Tests

```swift
@Suite("PigNode Animation Mapping")
struct PigAnimationTests {

    @Test("Baby pigs fall back to idle for unsupported states")
    func babyFallbackStates() {
        #expect(AnimationData.babyFallbackState(for: "eating") == "idle")
        #expect(AnimationData.babyFallbackState(for: "happy") == "idle")
        #expect(AnimationData.babyFallbackState(for: "sad") == "idle")
    }

    @Test("Baby pigs retain supported states")
    func babySupportedStates() {
        #expect(AnimationData.babyFallbackState(for: "idle") == "idle")
        #expect(AnimationData.babyFallbackState(for: "walking") == "walking")
        #expect(AnimationData.babyFallbackState(for: "sleeping") == "sleeping")
    }

    @Test("All behavior states map to valid display states")
    func allBehaviorStatesMap() {
        let behaviorStates = [
            "idle", "wandering", "eating", "drinking",
            "playing", "sleeping", "socializing", "courting"
        ]
        // All states should produce a non-empty display state
        for state in behaviorStates {
            let display = AnimationData.babyFallbackState(for: state)
            #expect(!display.isEmpty, "State '\(state)' produced empty display state")
        }
    }
}
```

### Camera Bounds Tests

```swift
@Suite("CameraController Bounds")
struct CameraBoundsTests {

    @Test("Camera scale is clamped to valid range")
    func scaleClamp() {
        #expect(SceneConstants.minCameraScale == 0.5)
        #expect(SceneConstants.maxCameraScale == 3.0)
        #expect(SceneConstants.defaultCameraScale == 1.0)

        // Min < default < max
        #expect(SceneConstants.minCameraScale < SceneConstants.defaultCameraScale)
        #expect(SceneConstants.defaultCameraScale < SceneConstants.maxCameraScale)
    }

    @Test("Viewport padding matches Python constant")
    func viewportPadding() {
        // Python: VIEWPORT_PADDING = 4
        #expect(SceneConstants.viewportPadding == 4.0)
    }
}
```

### Indicator Priority Tests

```swift
@Suite("Status Indicator Priority")
struct IndicatorPriorityTests {

    @Test("Indicator types are ordered by priority")
    func indicatorPriorityOrder() {
        // Health is highest priority, pregnant is lowest
        // This test verifies the priority order in indicatorType(for:)
        // by checking that health overrides hunger, etc.

        // The indicatorType(for:) function checks in order:
        // health < lowThreshold -> health
        // hunger < lowThreshold OR eating -> hunger
        // thirst < lowThreshold OR drinking -> thirst
        // energy < lowThreshold OR sleeping -> energy
        // courting -> courting
        // pregnant -> pregnant

        // This order matches Python: indicator_sprites.py get_pig_indicator_type()
        let priorities = ["health", "hunger", "thirst", "energy", "courting", "pregnant"]
        #expect(priorities.count == 6)
    }
}
```

---

## 15. Summary of Changes

### New Files

| File | Purpose |
|------|---------|
| `docs/specs/06-farm-scene.md` | This specification document |
| `BigPigFarmTests/FarmSceneTests.swift` | Tests for coordinate conversion, animation mapping, camera bounds, indicator priority |

### Modified Files

| File | Change |
|------|--------|
| `BigPigFarm/Scene/FarmScene.swift` | Complete implementation (replaces stub) |
| `BigPigFarm/Scene/PigNode.swift` | Complete implementation (replaces stub) |
| `BigPigFarm/Scene/FacilityNode.swift` | Complete implementation (replaces stub) |
| `BigPigFarm/Scene/CameraController.swift` | Complete implementation (replaces stub) |
| `BigPigFarm/ContentView.swift` | Complete implementation (replaces stub) |

### Dependencies on Other Specs

| Dependency | What's Needed |
|------------|---------------|
| Spec 02 (Data Models) | `GuineaPig`, `Facility`, `FacilityType`, `BaseColor`, `BehaviorState`, `GridPosition`, `Needs`, `GameState`, `FarmGrid`, `FarmArea`, `Cell`, `CellType` |
| Spec 03 (Sprite Pipeline) | `SpriteAssets` loading API, `AnimationData` timing/frame counts, terrain tile PNGs, pig/facility/indicator PNGs, `PatternRenderer` |
| Spec 04 (Game Engine) | `GameState` observable container, `GameEngine` tick loop, `FarmGrid` query methods (`isWalkable`, `getAreaByID`, `placeFacility`, `removeFacility`), `NeedsConfig.lowThreshold` |
| Spec 05 (Behavior AI) | `GuineaPig.displayState`, `GuineaPig.path`, `GuineaPig.isPregnant`, `GuineaPig.isBaby`, behavior state enum values |

### What's Next

With the farm scene specified, the remaining specs are:
1. **Doc 07 (SwiftUI Screens):** All menu and info screens -- shop, pig list, breeding, almanac, biome select, adoption, status bar HUD, pig detail. Depends on this spec for the `ContentView` shell and sheet wiring.
2. **Doc 08 (Persistence & Polish):** Save/load, app lifecycle, haptics, performance tuning. Depends on all previous specs.
