/// FarmScene+Background — Out-of-bounds hay tile background setup.
import SpriteKit
import UIKit

extension FarmScene {

    /// Tiles a pixel-art hay texture behind the farm grid so the out-of-bounds area
    /// looks like scattered hay rather than a void.
    func setupOutOfBoundsBackground() {
        let tileSize = CGSize(width: SceneConstants.cellSize, height: SceneConstants.cellSize)
        let dim = SceneConstants.outOfBoundsTileMapDimension
        let hayTexture = makeHayTileTexture()
        let tileDef = SKTileDefinition(texture: hayTexture, size: tileSize)
        let tileGroup = SKTileGroup(tileDefinition: tileDef)
        let tileSet = SKTileSet(tileGroups: [tileGroup])
        let tileMap = SKTileMapNode(
            tileSet: tileSet,
            columns: dim,
            rows: dim,
            tileSize: tileSize
        )
        tileMap.fill(with: tileGroup)
        tileMap.position = CGPoint(x: size.width / 2, y: size.height / 2)
        tileMap.zPosition = -1
        addChild(tileMap)
        outOfBoundsTileMap = tileMap
    }

    /// Generates an 8×8 pixel-art hay tile at the scene's native art resolution.
    /// Uses nearest-neighbour filtering so pixels stay crisp at the 4× display scale.
    private func makeHayTileTexture() -> SKTexture {
        let artSize = 8
        let rect = CGRect(x: 0, y: 0, width: artSize, height: artSize)
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            // Base golden-tan — derived from SceneConstants.outOfBoundsColor (single source of truth)
            UIColor(cgColor: SceneConstants.outOfBoundsColor.cgColor).setFill()
            cg.fill(rect)
            // Dark and light straw strokes — horizontal runs scattered across the tile
            let dark = UIColor(red: 0.45, green: 0.35, blue: 0.15, alpha: 1.0)
            let light = UIColor(red: 0.80, green: 0.70, blue: 0.44, alpha: 1.0)
            let darkPixels: [(Int, Int)] = [
                (0, 0), (1, 0), (2, 0),
                (3, 1), (4, 1),
                (5, 2), (6, 2), (7, 2),
                (0, 4), (1, 4),
                (2, 5), (3, 5),
                (7, 6),
                (0, 7), (6, 7), (7, 7)
            ]
            let lightPixels: [(Int, Int)] = [
                (5, 0), (6, 0),
                (0, 2),
                (1, 3), (2, 3),
                (5, 4), (6, 4),
                (7, 5),
                (4, 6), (5, 6),
                (3, 7)
            ]
            dark.setFill()
            for (x, y) in darkPixels { cg.fill(CGRect(x: x, y: y, width: 1, height: 1)) }
            light.setFill()
            for (x, y) in lightPixels { cg.fill(CGRect(x: x, y: y, width: 1, height: 1)) }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }
}
