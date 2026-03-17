/// OutlineShadow — generates soft gradient shadow textures for sprites.
///
/// Combines two techniques for a visible-yet-soft shadow:
/// 1. 8-directional silhouette offset creates a solid pig-shaped outline core.
/// 2. CIGaussianBlur softens the result into a smooth gradient.
///
/// IMPORTANT: Entity shadows must be generated from CGImages loaded via
/// `UIImage(named:)`, NOT from `SKTexture.cgImage()`. SpriteKit's internal
/// GPU texture format strips alpha transparency, producing rectangular
/// shadows instead of silhouette-shaped ones.
import UIKit
import SpriteKit
import CoreImage

@MainActor
enum OutlineShadow {

    // MARK: - Constants

    /// Shadow color for entity sprites (pigs, facilities).
    static let shadowColor = UIColor(white: 0.0, alpha: 0.08)

    /// Shadow color for wall tiles (subtler to avoid heavy grid lines).
    static let wallShadowColor = UIColor(white: 0.0, alpha: 0.08)

    /// Outline offset in art pixels for the silhouette core.
    static let artPixelOffset = 1

    /// Gaussian blur radius applied after the offset step to soften the outline.
    static let blurRadius: CGFloat = 6.0

    /// Wall shadow border width in art pixels.
    static let wallBorderArtPixels = 1

    /// Z-position for shadow child nodes (behind sprite at 0, in front of glow at -1).
    static let shadowNodeZPosition: CGFloat = -0.5

    /// Shared Core Image context for blur rendering.
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Outline Texture Generation

    /// Generate a soft gradient shadow texture from a CGImage with proper alpha.
    ///
    /// Algorithm:
    /// 1. Create a fully opaque silhouette from the source's alpha channel.
    /// 2. Draw the silhouette at 8 offsets on an expanded canvas (solid outline).
    /// 3. Tint with the shadow color via `.sourceIn`.
    /// 4. Apply CIGaussianBlur to soften the hard outline into a gradient.
    ///
    /// The canvas is expanded enough to fit both the offset AND the blur spread.
    /// The interior is shadow-colored but hidden behind the real sprite at zPosition 0.
    ///
    /// - Parameter cgImage: Source image loaded via `UIImage(named:)?.cgImage`
    ///   to preserve alpha. Do NOT use `SKTexture.cgImage()` — it strips transparency.
    static func outlineTexture(
        from cgImage: CGImage,
        scale: Int = Int(SpriteAssets.pointsPerArtPixel),
        color: UIColor = shadowColor
    ) -> SKTexture? {
        let srcW = cgImage.width
        let srcH = cgImage.height
        guard srcW > 0, srcH > 0 else { return nil }

        let offset = artPixelOffset * scale
        let blurPadding = Int(ceil(blurRadius * 2.5))
        let totalPadding = offset + blurPadding
        let outW = srcW + 2 * totalPadding
        let outH = srcH + 2 * totalPadding

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let silhouette = createSilhouette(
            from: cgImage, colorSpace: colorSpace, bitmapInfo: bitmapInfo
        ) else { return nil }

        // Draw opaque silhouette at 8 offsets (cardinal + diagonal).
        guard let outCtx = CGContext(
            data: nil, width: outW, height: outH,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: bitmapInfo
        ) else { return nil }

        let center = totalPadding
        let offsets: [(Int, Int)] = [
            (center - offset, center),           // left
            (center + offset, center),           // right
            (center, center - offset),           // down
            (center, center + offset),           // up
            (center - offset, center - offset),  // down-left
            (center + offset, center - offset),  // down-right
            (center - offset, center + offset),  // up-left
            (center + offset, center + offset),  // up-right
        ]

        for (dx, dy) in offsets {
            outCtx.draw(silhouette, in: CGRect(x: dx, y: dy, width: srcW, height: srcH))
        }

        // Step 3: Tint with shadow color. sourceIn: result = fill × dest_alpha.
        outCtx.setBlendMode(.sourceIn)
        outCtx.setFillColor(color.cgColor)
        outCtx.fill(CGRect(x: 0, y: 0, width: outW, height: outH))

        guard let tintedImage = outCtx.makeImage() else { return nil }

        // Step 4: Gaussian blur to soften the hard outline into a gradient.
        let ciImage = CIImage(cgImage: tintedImage)
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return nil }
        blurFilter.setValue(ciImage, forKey: kCIInputImageKey)
        blurFilter.setValue(blurRadius, forKey: kCIInputRadiusKey)
        guard let blurred = blurFilter.outputImage else { return nil }

        // Crop to original canvas bounds (blur extends the CIImage extent).
        let cropRect = CGRect(x: 0, y: 0, width: outW, height: outH)
        let cropped = blurred.cropped(to: cropRect)

        guard let blurredCG = ciContext.createCGImage(cropped, from: cropRect) else {
            return nil
        }

        let texture = SKTexture(cgImage: blurredCG)
        texture.filteringMode = .linear
        return texture
    }

    /// Create a fully opaque black silhouette from the source alpha channel.
    private static func createSilhouette(
        from cgImage: CGImage,
        colorSpace: CGColorSpace,
        bitmapInfo: UInt32
    ) -> CGImage? {
        let srcW = cgImage.width
        let srcH = cgImage.height
        guard let ctx = CGContext(
            data: nil, width: srcW, height: srcH,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: bitmapInfo
        ) else { return nil }

        let rect = CGRect(x: 0, y: 0, width: srcW, height: srcH)
        ctx.draw(cgImage, in: rect)
        ctx.setBlendMode(.sourceIn)
        ctx.setFillColor(UIColor.black.cgColor)
        ctx.fill(rect)
        return ctx.makeImage()
    }

    // MARK: - Asset Loading

    /// Load a CGImage from the asset catalog via UIImage (preserves alpha).
    ///
    /// SKTexture.cgImage() strips transparency from sprite textures. This method
    /// loads through UIImage which correctly preserves the PNG's alpha channel.
    static func loadCGImage(named assetName: String) -> CGImage? {
        UIImage(named: assetName)?.cgImage
    }

    // MARK: - Wall Tile Shadow

    /// Add a subtle inner shadow to a wall tile texture.
    ///
    /// Draws a semi-transparent dark border on all 4 edges, 1 art pixel wide.
    /// This gives wall blocks depth definition without adding scene nodes.
    /// Wall tiles are fully opaque rectangles, so alpha preservation is not needed.
    static func wallTileWithShadow(
        _ wallTexture: SKTexture,
        scale: Int = Int(SpriteAssets.pointsPerArtPixel),
        color: UIColor = wallShadowColor
    ) -> SKTexture {
        let cgImage = wallTexture.cgImage()
        let tileWidth = cgImage.width
        let tileHeight = cgImage.height
        let border = wallBorderArtPixels * scale
        guard tileWidth > 2 * border, tileHeight > 2 * border else { return wallTexture }

        guard let ctx = CGContext(
            data: nil, width: tileWidth, height: tileHeight,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return wallTexture }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: tileWidth, height: tileHeight))
        ctx.setFillColor(color.cgColor)
        ctx.setBlendMode(.sourceAtop)

        // Four non-overlapping border strips.
        let innerHeight = tileHeight - 2 * border
        ctx.fill(CGRect(x: 0, y: tileHeight - border, width: tileWidth, height: border))
        ctx.fill(CGRect(x: 0, y: 0, width: tileWidth, height: border))
        ctx.fill(CGRect(x: 0, y: border, width: border, height: innerHeight))
        ctx.fill(CGRect(x: tileWidth - border, y: border, width: border, height: innerHeight))

        guard let result = ctx.makeImage() else { return wallTexture }
        let texture = SKTexture(cgImage: result)
        texture.filteringMode = .nearest
        return texture
    }

    // MARK: - Shadow Node Factory

    /// Create a shadow sprite node positioned behind the main sprite.
    static func makeShadowNode(
        texture: SKTexture,
        spriteSize: CGSize
    ) -> SKSpriteNode {
        let offset = CGFloat(artPixelOffset) * SpriteAssets.pointsPerArtPixel
        let blurPad = ceil(blurRadius * 2.5)
        let expansion = (offset + blurPad) * 2
        let shadowSize = CGSize(
            width: spriteSize.width + expansion,
            height: spriteSize.height + expansion
        )
        let node = SKSpriteNode(texture: texture, size: shadowSize)
        node.zPosition = shadowNodeZPosition
        return node
    }
}
