/// GlowEffectTests — validates glow texture generation and glow node construction.
import Testing
import SpriteKit
import UIKit
@testable import BigPigFarm

@MainActor
struct GlowEffectTests {

    // MARK: - Test Helpers

    private func makeTestCGImage(width: Int, height: Int) -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: width, height: height), format: format
        )
        let image = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 1, y: 1, width: width - 2, height: height - 2))
        }
        return image.cgImage!  // swiftlint:disable:this force_unwrapping
    }

    private func expectedGlowPadding(scale: Int) -> Int {
        let offset = GlowEffect.glowPixelOffset * scale
        let blurPad = Int(ceil(GlowEffect.glowBlurRadius * 2.5))
        return offset + blurPad
    }

    // MARK: - glowTexture

    @Test func glowTextureExpandsDimensions() throws {
        let source = makeTestCGImage(width: 56, height: 32)
        let glow = try #require(GlowEffect.glowTexture(from: source, color: GlowEffect.pigSelectionColor))
        let padding = expectedGlowPadding(scale: Int(SpriteAssets.pointsPerArtPixel))
        let cgImage = glow.cgImage()
        #expect(cgImage.width == 56 + 2 * padding)
        #expect(cgImage.height == 32 + 2 * padding)
    }

    @Test func glowTextureIsLargerThanShadowTexture() throws {
        let source = makeTestCGImage(width: 56, height: 32)
        let glow = try #require(GlowEffect.glowTexture(from: source, color: GlowEffect.pigSelectionColor))
        let shadow = try #require(OutlineShadow.outlineTexture(from: source))
        #expect(glow.cgImage().width > shadow.cgImage().width)
        #expect(glow.cgImage().height > shadow.cgImage().height)
    }

    @Test func glowTextureUsesLinearFiltering() {
        let source = makeTestCGImage(width: 32, height: 32)
        let glow = GlowEffect.glowTexture(from: source, color: GlowEffect.facilitySelectedColor)
        #expect(glow?.filteringMode == .linear)
    }

    // MARK: - makeGlowNode

    @Test func glowNodeHasCorrectZPosition() {
        let source = makeTestCGImage(width: 32, height: 32)
        let tex = SKTexture(cgImage: source)
        let node = GlowEffect.makeGlowNode(texture: tex, spriteSize: CGSize(width: 56, height: 32))
        #expect(node.zPosition == GlowEffect.glowNodeZPosition)
    }

    @Test func glowNodeZPositionIsBehindShadow() {
        #expect(GlowEffect.glowNodeZPosition < OutlineShadow.shadowNodeZPosition)
    }

    @Test func glowNodeSizeIncludesOffsetAndBlurPadding() {
        let source = makeTestCGImage(width: 32, height: 32)
        let tex = SKTexture(cgImage: source)
        let spriteSize = CGSize(width: 56, height: 32)
        let node = GlowEffect.makeGlowNode(texture: tex, spriteSize: spriteSize)
        let offset = CGFloat(GlowEffect.glowPixelOffset) * SpriteAssets.pointsPerArtPixel
        let blurPad = ceil(GlowEffect.glowBlurRadius * 2.5)
        let expansion = (offset + blurPad) * 2
        #expect(node.size.width == spriteSize.width + expansion)
        #expect(node.size.height == spriteSize.height + expansion)
    }

    // MARK: - Constants

    @Test func glowPixelOffsetIsLargerThanShadow() {
        #expect(GlowEffect.glowPixelOffset > OutlineShadow.artPixelOffset)
    }

    @Test func glowBlurRadiusIsLargerThanShadow() {
        #expect(GlowEffect.glowBlurRadius > OutlineShadow.blurRadius)
    }
}
