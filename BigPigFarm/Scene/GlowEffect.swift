/// GlowEffect — colored silhouette glow textures for selection highlights.
///
/// Reuses the OutlineShadow pipeline (8-directional offset + Gaussian blur) with
/// brighter colors and wider spread for a visible selection glow effect.
import UIKit
import SpriteKit

@MainActor
enum GlowEffect {

    // MARK: - Glow Colors

    /// Pig follow/selection glow — soft white.
    static let pigSelectionColor = UIColor(white: 1.0, alpha: 0.25)

    /// Facility selected (edit mode) — soft white.
    static let facilitySelectedColor = UIColor(white: 1.0, alpha: 0.2)

    /// Facility being dragged — soft white.
    static let facilityMovingColor = UIColor(white: 1.0, alpha: 0.2)

    // MARK: - Glow Parameters

    /// Larger offset than shadow for a thicker silhouette core.
    static let glowPixelOffset = 2

    /// Wide blur for a soft, diffuse glow.
    static let glowBlurRadius: CGFloat = 14.0

    /// Z-position for glow nodes (behind shadow at -0.5, behind sprite at 0).
    static let glowNodeZPosition: CGFloat = -1.0

    // MARK: - Cache

    /// Cached glow textures keyed by "assetName|colorHex". Bounded at ~98 entries
    /// (64 pig variants: 16 colours x 2 directions x 2 ages; 34 facility variants:
    /// 17 types x 2 glow colours). Permanent for app lifetime.
    private static var glowCache: [String: SKTexture] = [:]

    // MARK: - Cached Texture Access

    /// Get or create a cached glow texture for the given asset and color.
    static func cachedGlowTexture(assetName: String, color: UIColor) -> SKTexture? {
        let key = "\(assetName)|\(colorKey(color))"
        if let cached = glowCache[key] { return cached }
        guard let cgImage = OutlineShadow.loadCGImage(named: assetName),
              let texture = glowTexture(from: cgImage, color: color) else { return nil }
        glowCache[key] = texture
        return texture
    }

    /// Remove all cached glow textures. Used by tests to reset state.
    static func evictGlowCache() {
        glowCache.removeAll()
    }

    /// Stable string key for a UIColor (RGBA hex).
    private static func colorKey(_ color: UIColor) -> String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return color.description
        }
        return String(format: "%02X%02X%02X%02X",
                      Int(red * 255), Int(green * 255), Int(blue * 255), Int(alpha * 255))
    }

    // MARK: - Texture Generation

    /// Generate a colored silhouette glow texture from a CGImage.
    static func glowTexture(from cgImage: CGImage, color: UIColor) -> SKTexture? {
        OutlineShadow.outlineTexture(
            from: cgImage,
            color: color,
            pixelOffset: glowPixelOffset,
            blur: glowBlurRadius
        )
    }

    /// Create a glow sprite node positioned behind the main sprite.
    static func makeGlowNode(texture: SKTexture, spriteSize: CGSize) -> SKSpriteNode {
        OutlineShadow.makeShadowNode(
            texture: texture,
            spriteSize: spriteSize,
            pixelOffset: glowPixelOffset,
            blur: glowBlurRadius,
            zPosition: glowNodeZPosition
        )
    }
}
