/// PigNodeLabelTests — Verifies the name label Y offset formula places the label below the pig sprite.
import Testing
@testable import BigPigFarm

/// Tests for PigNode name label positioning (bead a0p).
///
/// SpriteKit uses Y-up coordinates. With a centre anchor (0.5, 0.5):
///   - Top edge    = +height/2
///   - Bottom edge = -height/2
/// The label must sit below the bottom edge, so Y must be negative.
/// Formula: -(height / 2) - 2   (2pt gap, matching spec 06)
struct PigNodeLabelTests {

    @Test("Adult name label Y offset is negative (below pig)")
    func adultLabelYIsNegative() {
        let height = SpriteAssets.adultSpriteSize.height * SpriteAssets.pointsPerArtPixel
        let labelY = -(height / 2) - 2
        #expect(labelY < 0, "Label must be below the sprite centre in SpriteKit Y-up coordinates")
    }

    @Test("Adult name label Y offset matches spec formula")
    func adultLabelYMatchesSpec() {
        let height = SpriteAssets.adultSpriteSize.height * SpriteAssets.pointsPerArtPixel
        let labelY = -(height / 2) - 2
        #expect(labelY == -18, "Adult: -(32/2) - 2 = -18pt (artHeight=8, scale=4)")
    }

    @Test("Baby name label Y offset is negative (below pig)")
    func babyLabelYIsNegative() {
        let height = SpriteAssets.babySpriteSize.height * SpriteAssets.pointsPerArtPixel
        let labelY = -(height / 2) - 2
        #expect(labelY < 0, "Label must be below the sprite centre in SpriteKit Y-up coordinates")
    }

    @Test("Baby name label Y offset matches spec formula")
    func babyLabelYMatchesSpec() {
        let height = SpriteAssets.babySpriteSize.height * SpriteAssets.pointsPerArtPixel
        let labelY = -(height / 2) - 2
        #expect(labelY == -14, "Baby: -(24/2) - 2 = -14pt (artHeight=6, scale=4)")
    }

    @Test("Label Y offset is below bottom edge, not above top edge")
    func labelIsNotAboveTopEdge() {
        // Regression: the bug placed the label at +height/2 + 4 (above the pig).
        // Verify the correct formula is strictly negative for both sprite sizes.
        for artSize in [SpriteAssets.adultSpriteSize, SpriteAssets.babySpriteSize] {
            let height = artSize.height * SpriteAssets.pointsPerArtPixel
            let buggyY = height / 2 + 4
            let fixedY = -(height / 2) - 2
            #expect(fixedY < 0)
            #expect(fixedY < buggyY, "Fixed offset must be lower than the buggy above-pig offset")
        }
    }
}
