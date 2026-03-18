/// GlowEffect — colored silhouette glow textures for selection highlights.
///
/// Reuses the OutlineShadow pipeline (8-directional offset + Gaussian blur) with
/// brighter colors and wider spread for a visible selection glow effect.
import UIKit
import SpriteKit

@MainActor
enum GlowEffect {

    // MARK: - Glow Colors

    /// Pig follow/selection glow — warm yellow.
    static let pigSelectionColor = UIColor(red: 1.0, green: 0.9, blue: 0.2, alpha: 0.55)

    /// Facility selected (edit mode) — cool blue.
    static let facilitySelectedColor = UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 0.45)

    /// Facility being dragged — warm yellow matching pig selection.
    static let facilityMovingColor = UIColor(red: 1.0, green: 0.9, blue: 0.2, alpha: 0.45)

    // MARK: - Glow Parameters

    /// Larger offset than shadow for a thicker silhouette core.
    static let glowPixelOffset = 2

    /// Wider blur than shadow for a softer, more visible glow.
    static let glowBlurRadius: CGFloat = 10.0

    /// Z-position for glow nodes (behind shadow at -0.5, behind sprite at 0).
    static let glowNodeZPosition: CGFloat = -1.0

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
