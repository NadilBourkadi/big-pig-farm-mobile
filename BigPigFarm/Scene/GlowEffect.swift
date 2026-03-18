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
