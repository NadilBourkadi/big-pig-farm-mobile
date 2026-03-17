/// OutlineShadowTests — validates gradient shadow texture generation, shadow node
/// construction, wall tile shadow baking, and constant sanity.
import Testing
import SpriteKit
import UIKit
@testable import BigPigFarm

@MainActor
struct OutlineShadowTests {

    // MARK: - Test Helpers

    /// Create a test CGImage with alpha (opaque center, transparent border).
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

    private func makeTestTexture(width: Int, height: Int) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: width, height: height), format: format
        )
        let image = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }

    /// Expected total padding per side: offset + blur spread.
    private func expectedTotalPadding(scale: Int) -> Int {
        let offset = OutlineShadow.artPixelOffset * scale
        let blurPad = Int(ceil(OutlineShadow.blurRadius * 2.5))
        return offset + blurPad
    }

    // MARK: - outlineTexture

    @Test func outlineTextureExpandsDimensionsForAdultPig() throws {
        let source = makeTestCGImage(width: 56, height: 32)
        let outline = try #require(OutlineShadow.outlineTexture(from: source, scale: 4))
        let padding = expectedTotalPadding(scale: 4)
        let cgImage = outline.cgImage()
        #expect(cgImage.width == 56 + 2 * padding)
        #expect(cgImage.height == 32 + 2 * padding)
    }

    @Test func outlineTextureExpandsDimensionsForBabyPig() throws {
        let source = makeTestCGImage(width: 32, height: 24)
        let outline = try #require(OutlineShadow.outlineTexture(from: source, scale: 4))
        let padding = expectedTotalPadding(scale: 4)
        let cgImage = outline.cgImage()
        #expect(cgImage.width == 32 + 2 * padding)
        #expect(cgImage.height == 24 + 2 * padding)
    }

    @Test func babyOutlineIsSmallerThanAdult() throws {
        let adult = makeTestCGImage(width: 56, height: 32)
        let baby = makeTestCGImage(width: 32, height: 24)
        let adultOutline = try #require(OutlineShadow.outlineTexture(from: adult, scale: 4))
        let babyOutline = try #require(OutlineShadow.outlineTexture(from: baby, scale: 4))
        #expect(babyOutline.cgImage().width < adultOutline.cgImage().width)
        #expect(babyOutline.cgImage().height < adultOutline.cgImage().height)
    }

    @Test func outlineTextureUsesLinearFiltering() {
        let source = makeTestCGImage(width: 32, height: 32)
        let outline = OutlineShadow.outlineTexture(from: source, scale: 4)
        #expect(outline?.filteringMode == .linear)
    }

    // MARK: - makeShadowNode

    @Test func shadowNodeHasCorrectZPosition() {
        let tex = makeTestTexture(width: 72, height: 48)
        let node = OutlineShadow.makeShadowNode(
            texture: tex,
            spriteSize: CGSize(width: 56, height: 32)
        )
        #expect(node.zPosition == OutlineShadow.shadowNodeZPosition)
    }

    @Test func shadowNodeSizeIncludesOffsetAndBlurPadding() {
        let tex = makeTestTexture(width: 72, height: 48)
        let spriteSize = CGSize(width: 56, height: 32)
        let node = OutlineShadow.makeShadowNode(texture: tex, spriteSize: spriteSize)
        let offset = CGFloat(OutlineShadow.artPixelOffset) * SpriteAssets.pointsPerArtPixel
        let blurPad = ceil(OutlineShadow.blurRadius * 2.5)
        let expansion = (offset + blurPad) * 2
        #expect(node.size.width == spriteSize.width + expansion)
        #expect(node.size.height == spriteSize.height + expansion)
    }

    // MARK: - wallTileWithShadow

    @Test func wallShadowPreservesTextureDimensions() {
        let source = makeTestTexture(width: 32, height: 32)
        let shadowed = OutlineShadow.wallTileWithShadow(source, scale: 4)
        let cgImage = shadowed.cgImage()
        #expect(cgImage.width == 32)
        #expect(cgImage.height == 32)
    }

    @Test func wallShadowUsesNearestFiltering() {
        let source = makeTestTexture(width: 32, height: 32)
        let shadowed = OutlineShadow.wallTileWithShadow(source, scale: 4)
        #expect(shadowed.filteringMode == .nearest)
    }

    // MARK: - Constants

    @Test func shadowColorAlphaIsSubtle() {
        var white: CGFloat = 0
        var alpha: CGFloat = 0
        OutlineShadow.shadowColor.getWhite(&white, alpha: &alpha)
        #expect(alpha > 0)
        #expect(alpha < 1)
    }

    @Test func wallShadowColorAlphaIsSubtle() {
        var white: CGFloat = 0
        var alpha: CGFloat = 0
        OutlineShadow.wallShadowColor.getWhite(&white, alpha: &alpha)
        #expect(alpha > 0)
        #expect(alpha < 1)
    }

    @Test func artPixelOffsetIsOne() {
        #expect(OutlineShadow.artPixelOffset == 1)
    }

    @Test func blurRadiusIsPositive() {
        #expect(OutlineShadow.blurRadius > 0)
    }

    @Test func shadowNodeZPositionIsBehindSpriteButInFrontOfGlow() {
        #expect(OutlineShadow.shadowNodeZPosition < 0)
        #expect(OutlineShadow.shadowNodeZPosition > -1)
    }

    // MARK: - Alpha Diagnostics

    @Test func pigSpriteLoadedViaUIImageHasAlpha() throws {
        let image = try #require(UIImage(named: "Sprites/Pigs/pig_adult_black_idle_right"))
        let cgImage = try #require(image.cgImage)
        let alphaInfo = cgImage.alphaInfo
        let hasAlpha = alphaInfo == .premultipliedFirst
            || alphaInfo == .premultipliedLast
            || alphaInfo == .first
            || alphaInfo == .last
        #expect(hasAlpha, "cgImage.alphaInfo = \(alphaInfo.rawValue), expected premultiplied alpha")
    }

    @Test func pigSpriteHasTransparentPixels() throws {
        let image = try #require(UIImage(named: "Sprites/Pigs/pig_adult_black_idle_right"))
        let cgImage = try #require(image.cgImage)
        let width = cgImage.width
        let height = cgImage.height

        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            Issue.record("Failed to create CGContext")
            return
        }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = ctx.data else {
            Issue.record("No pixel data")
            return
        }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

        var transparentCount = 0
        var opaqueCount = 0
        for index in 0..<(width * height) {
            let alpha = pixels[index * 4 + 3]
            if alpha == 0 { transparentCount += 1 } else { opaqueCount += 1 }
        }

        #expect(transparentCount > 0, "No transparent pixels found — alpha may be stripped")
        #expect(opaqueCount > 0, "No opaque pixels found")
        #expect(
            transparentCount > width * height / 4,
            "Only \(transparentCount)/\(width * height) transparent — expected >25% background"
        )
    }
}
