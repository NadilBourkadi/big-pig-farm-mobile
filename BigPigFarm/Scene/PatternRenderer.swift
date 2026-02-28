/// PatternRenderer — applies phenotype patterns to base-color pig sprite textures.
///
/// Maps from: data/pig_portraits.py (pattern application functions)
/// Compositing approach: CGContext pixel manipulation (chosen over SKShader per Spec 03 §12).
/// Patterns are applied once at pig creation and the result is cached -- zero per-frame cost.
import UIKit
import SpriteKit
import GameplayKit
import CryptoKit

/// Applies phenotype patterns to base-color pig sprite textures.
///
/// Pattern application order (matching Python generate_portrait()):
///   1. Pattern (Dutch or Dalmatian) — replaces fur pixels with white
///   2. Intensity (Chinchilla or Himalayan) — modifies fur/body pixels
///   3. Roan — scatters white into remaining inner fur pixels
enum PatternRenderer {

    // MARK: - Configuration

    /// Input bundle for pattern compositing.
    ///
    /// Groups the eight parameters that `applyPattern` needs into one value,
    /// making call sites more readable and the API easier to extend.
    struct PatternConfig {
        let pattern: Pattern
        let intensity: ColorIntensity
        let roan: RoanType
        let pigID: UUID
        let whiteColor: UIColor
        let bellyColor: UIColor
        let isBaby: Bool
    }

    // MARK: - Internal Rendering State

    /// Immutable rendering state shared across compositing steps.
    ///
    /// `CGContext` is a class — drawing through the `context` property
    /// mutates the underlying bitmap without requiring this struct to be inout.
    private struct RenderParams {
        let context: CGContext
        let scale: Int
        let innerFur: Set<GridPosition>
        let allFur: Set<GridPosition>
        let earPixels: Set<GridPosition>
        let white: CGColor
        let belly: CGColor
    }

    // MARK: - Public API

    /// Composite a pattern onto a base-color pig sprite texture.
    ///
    /// Returns `baseTexture` unchanged for the solid/full/none fast path.
    /// Otherwise composites the pattern via CGContext pixel manipulation and
    /// returns a new `SKTexture` with `.filteringMode = .nearest`.
    static func applyPattern(baseTexture: SKTexture, config: PatternConfig) -> SKTexture {
        if config.pattern == .solid && config.intensity == .full && config.roan == .none {
            return baseTexture
        }
        let cgImage = baseTexture.cgImage()
        guard let modifiedImage = composeTexture(cgImage: cgImage, config: config) else {
            return baseTexture
        }
        let result = SKTexture(cgImage: modifiedImage)
        result.filteringMode = .nearest
        return result
    }

    /// Generate Dalmatian spot positions for a specific pig.
    ///
    /// Deterministic: same `pigID` always produces the same spots.
    /// Mirrors `_apply_dalmatian_spots()` from `data/pig_portraits.py`.
    ///
    /// - Parameters:
    ///   - pigID: UUID seed for deterministic placement.
    ///   - width: Sprite width in art pixels (kept for spec signature parity).
    ///   - height: Sprite height in art pixels (kept for spec signature parity).
    ///   - innerFurPixels: Set of eligible art-pixel coordinates.
    /// - Returns: Set of art-pixel positions that should be white.
    static func generateDalmatianSpots(
        pigID: UUID,
        width: Int,
        height: Int,
        innerFurPixels: Set<GridPosition>
    ) -> Set<GridPosition> {
        guard !innerFurPixels.isEmpty else { return [] }

        let rng = seededRNG(pigID: pigID, suffix: "_dalmatian")
        var shuffled = innerFurPixels.sorted { ($0.y, $0.x) < ($1.y, $1.x) }
        let centerCount = max(1, shuffled.count / 4)

        for index in 0..<centerCount {
            let swapIndex = index + rng.nextInt(upperBound: shuffled.count - index)
            shuffled.swapAt(index, swapIndex)
        }
        let spotCenters = Array(shuffled[0..<centerCount])

        var spotted = Set<GridPosition>()
        for center in spotCenters {
            spotted.insert(center)
            for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                let neighbor = GridPosition(x: center.x + dx, y: center.y + dy)
                if innerFurPixels.contains(neighbor) && rng.nextBool() {
                    spotted.insert(neighbor)
                }
            }
        }
        return spotted
    }

    /// Generate Roan scatter positions for a specific pig.
    ///
    /// Deterministic: same `pigID` always produces the same scatter.
    /// Mirrors `_apply_roan()` from `data/pig_portraits.py` (~30% coverage).
    ///
    /// - Parameters:
    ///   - pigID: UUID seed for deterministic scatter.
    ///   - innerFurPixels: Eligible art-pixel positions (already-modified pixels excluded).
    /// - Returns: Set of art-pixel positions that should become white.
    static func generateRoanScatter(
        pigID: UUID,
        innerFurPixels: Set<GridPosition>
    ) -> Set<GridPosition> {
        guard !innerFurPixels.isEmpty else { return [] }

        let rng = seededRNG(pigID: pigID, suffix: "_roan")
        let sortedFur = innerFurPixels.sorted { ($0.y, $0.x) < ($1.y, $1.x) }

        var scattered = Set<GridPosition>()
        for pos in sortedFur where rng.nextUniform() < 0.3 {
            scattered.insert(pos)
        }
        return scattered
    }

    // MARK: - Private Compositing Pipeline

    private static func composeTexture(cgImage: CGImage, config: PatternConfig) -> CGImage? {
        let textureWidth = cgImage.width
        let textureHeight = cgImage.height
        let artWidth = config.isBaby ? 8 : 14

        guard let ctx = CGContext(
            data: nil,
            width: textureWidth, height: textureHeight,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: textureWidth, height: textureHeight))
        ctx.setBlendMode(.copy)

        let params = RenderParams(
            context: ctx,
            scale: textureWidth / artWidth,
            innerFur: config.isBaby ? SpriteFurMaps.babyInnerFur : SpriteFurMaps.adultInnerFur,
            allFur: config.isBaby ? SpriteFurMaps.babyAllFur : SpriteFurMaps.adultAllFur,
            earPixels: config.isBaby ? SpriteFurMaps.babyEarPixels : SpriteFurMaps.adultEarPixels,
            white: config.whiteColor.cgColor,
            belly: config.bellyColor.cgColor
        )

        var modified = applyPatternStep(params: params, config: config)
        modified.formUnion(applyIntensityStep(params: params, config: config))

        if config.roan == .roan {
            let eligible = params.innerFur.subtracting(modified)
            let scattered = generateRoanScatter(pigID: config.pigID, innerFurPixels: eligible)
            paint(params: params, positions: scattered, color: params.white)
        }

        return params.context.makeImage()
    }

    private static func applyPatternStep(
        params: RenderParams,
        config: PatternConfig
    ) -> Set<GridPosition> {
        switch config.pattern {
        case .dutch:
            let region = dutchRegion(allFur: params.allFur, isBaby: config.isBaby)
            paint(params: params, positions: region, color: params.white)
            return region
        case .dalmatian:
            let artWidth = config.isBaby ? 8 : 14
            let artHeight = config.isBaby ? 6 : 8
            let spots = generateDalmatianSpots(
                pigID: config.pigID, width: artWidth,
                height: artHeight, innerFurPixels: params.innerFur
            )
            paint(params: params, positions: spots, color: params.white)
            return spots
        case .solid:
            return []
        }
    }

    private static func applyIntensityStep(
        params: RenderParams,
        config: PatternConfig
    ) -> Set<GridPosition> {
        switch config.intensity {
        case .chinchilla:
            let ticked = Set(params.innerFur.filter { ($0.y + $0.x) % 3 == 0 })
            paint(params: params, positions: ticked, color: params.white)
            return ticked
        case .himalayan:
            let region = params.allFur.subtracting(params.earPixels)
            paint(params: params, positions: region, color: params.belly)
            return region
        case .full:
            return []
        }
    }

    // MARK: - Drawing

    /// Paint a set of art-pixel positions with a solid color.
    ///
    /// Uses `CGContext.fill` with `.copy` blend mode for exact pixel replacement.
    /// Setting the fill color once before the loop avoids repeated state changes.
    private static func paint(
        params: RenderParams,
        positions: Set<GridPosition>,
        color: CGColor
    ) {
        params.context.setFillColor(color)
        for pos in positions {
            params.context.fill(CGRect(
                x: pos.x * params.scale, y: pos.y * params.scale,
                width: params.scale, height: params.scale
            ))
        }
    }

    // MARK: - Private Helpers

    private static func seededRNG(pigID: UUID, suffix: String) -> GKRandomSource {
        let input = pigID.uuidString.lowercased() + suffix
        let digest = Insecure.MD5.hash(data: Data(input.utf8))
        return GKARC4RandomSource(seed: Data(digest))
    }

    private static func dutchRegion(
        allFur: Set<GridPosition>,
        isBaby: Bool
    ) -> Set<GridPosition> {
        allFur.filter { pos in
            if isBaby {
                return (pos.y <= 1 && pos.x >= 4 && pos.x <= 6) || pos.y >= 3
            } else {
                return (pos.y <= 3 && pos.x >= 3 && pos.x <= 10) || pos.y >= 5
            }
        }
    }
}
