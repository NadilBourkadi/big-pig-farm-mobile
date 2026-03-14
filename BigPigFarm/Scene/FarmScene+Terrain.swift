/// FarmScene+Terrain — Tile map construction and biome rendering.
import SpriteKit

/// Per-biome tile group triplet used when filling the tile map.
struct BiomeTileGroups {
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

    func fillTiles(
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

    func makeTileGroup(biome: String, tileType: String, size: CGSize) -> SKTileGroup {
        let texture = SpriteAssets.terrainTexture(biome: biome, tileType: tileType)
        let definition = SKTileDefinition(texture: texture, size: size)
        return SKTileGroup(tileDefinition: definition)
    }
}
