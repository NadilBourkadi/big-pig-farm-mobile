/// SpriteAssets — Centralized texture loading API for all pig and farm sprites.
/// Maps from: Spec 03 §13
import SpriteKit

enum SpriteAssets {

    // MARK: - Constants

    /// Points per art pixel at @1x scale (sprites are drawn at 1x, scaled in-scene).
    static let pointsPerArtPixel: CGFloat = 4.0

    /// Adult pig sprite dimensions in art pixels.
    static let adultSpriteSize = CGSize(width: 14, height: 8)

    /// Baby pig sprite dimensions in art pixels.
    static let babySpriteSize = CGSize(width: 8, height: 6)

    // MARK: - Pig Sprites

    /// Load a pig sprite texture by phenotype, display state, and direction.
    /// Asset name: `Sprites/Pigs/pig_{age}_{color}_{state}_{direction}[_{frame}]`
    static func pigTexture(
        baseColor: BaseColor,
        state: String,
        direction: String,
        isBaby: Bool,
        frame: Int? = nil
    ) -> SKTexture {
        let age = isBaby ? "baby" : "adult"
        var name = "Sprites/Pigs/pig_\(age)_\(baseColor.rawValue)_\(state)_\(direction)"
        if let frame {
            name += "_\(frame)"
        }
        return loadTexture(named: name)
    }

    /// Load all animation frames for a pig state as an ordered array.
    /// Delegates frame count to AnimationData; static states return a single-element array.
    static func pigAnimationFrames(
        baseColor: BaseColor,
        state: String,
        direction: String,
        isBaby: Bool
    ) -> [SKTexture] {
        let count = AnimationData.frameCount(for: state)
        if count <= 1 {
            return [pigTexture(baseColor: baseColor, state: state, direction: direction, isBaby: isBaby)]
        }
        return (1...count).map { frame in
            pigTexture(baseColor: baseColor, state: state, direction: direction, isBaby: isBaby, frame: frame)
        }
    }

    // MARK: - Facility Sprites

    /// Load a facility sprite texture.
    /// Asset name: `Sprites/Facilities/facility_{facilityType}[_{state}]`
    static func facilityTexture(
        facilityType: String,
        state: String? = nil
    ) -> SKTexture {
        var name = "Sprites/Facilities/facility_\(facilityType)"
        if let state {
            name += "_\(state)"
        }
        return loadTexture(named: name)
    }

    // MARK: - Indicator Sprites

    /// Load a status indicator sprite texture.
    /// Asset name: `Sprites/Indicators/indicator_{indicatorType}_{bright|dim}`
    static func indicatorTexture(
        indicatorType: String,
        bright: Bool
    ) -> SKTexture {
        let brightness = bright ? "bright" : "dim"
        return loadTexture(named: "Sprites/Indicators/indicator_\(indicatorType)_\(brightness)")
    }

    // MARK: - Portrait Sprites

    /// Load a pre-rendered Pigdex portrait texture.
    /// Asset name: `Sprites/Portraits/portrait_{color}_{pattern}_{intensity}_{roan}`
    static func portraitTexture(
        baseColor: BaseColor,
        pattern: Pattern,
        intensity: ColorIntensity,
        roan: RoanType
    ) -> SKTexture {
        let parts = [baseColor.rawValue, pattern.rawValue, intensity.rawValue, roan.rawValue]
        let name = "Sprites/Portraits/portrait_" + parts.joined(separator: "_")
        return loadTexture(named: name)
    }

    // MARK: - Terrain Tiles

    /// Load a terrain tile texture for use in SKTileMapNode.
    /// Asset name: `Sprites/Terrain/terrain_{biome}_{tileType}`
    static func terrainTexture(
        biome: String,
        tileType: String
    ) -> SKTexture {
        loadTexture(named: "Sprites/Terrain/terrain_\(biome)_\(tileType)")
    }

    // MARK: - Private

    /// Load a texture by asset catalog name and apply nearest-neighbor filtering.
    /// SKTexture(imageNamed:) never returns nil — missing assets degrade to a
    /// placeholder texture rather than crashing.
    private static func loadTexture(named name: String) -> SKTexture {
        let texture = SKTexture(imageNamed: name)
        texture.filteringMode = .nearest
        return texture
    }
}
