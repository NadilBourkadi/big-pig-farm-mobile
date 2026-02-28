/// SpriteAssetTests — Tests for SpriteAssets loading API.
/// Verifies constants, filtering mode, frame count delegation, and API contract.
import Testing
import SpriteKit
@testable import BigPigFarm

// MARK: - Constants

@Test func pointsPerArtPixel() {
    #expect(SpriteAssets.pointsPerArtPixel == 4.0)
}

@Test func adultSpriteSize() {
    #expect(SpriteAssets.adultSpriteSize == CGSize(width: 14, height: 8))
}

@Test func babySpriteSize() {
    #expect(SpriteAssets.babySpriteSize == CGSize(width: 8, height: 6))
}

// MARK: - Filtering Mode

@Test func pigTextureFilteringIsNearest() {
    let texture = SpriteAssets.pigTexture(
        baseColor: .black, state: "idle", direction: "right", isBaby: false
    )
    #expect(texture.filteringMode == .nearest)
}

@Test func facilityTextureFilteringIsNearest() {
    let texture = SpriteAssets.facilityTexture(facilityType: "food_bowl")
    #expect(texture.filteringMode == .nearest)
}

@Test func indicatorTextureFilteringIsNearest() {
    let texture = SpriteAssets.indicatorTexture(indicatorType: "health", bright: true)
    #expect(texture.filteringMode == .nearest)
}

@Test func portraitTextureFilteringIsNearest() {
    let texture = SpriteAssets.portraitTexture(
        baseColor: .black, pattern: .solid, intensity: .full, roan: .none
    )
    #expect(texture.filteringMode == .nearest)
}

@Test func terrainTextureFilteringIsNearest() {
    let texture = SpriteAssets.terrainTexture(biome: "meadow", tileType: "floor")
    #expect(texture.filteringMode == .nearest)
}

// MARK: - Pig Texture Variants

@Test func pigTextureAllBaseColors() {
    for color in BaseColor.allCases {
        let texture = SpriteAssets.pigTexture(
            baseColor: color, state: "idle", direction: "right", isBaby: false
        )
        #expect(texture.filteringMode == .nearest)
    }
}

@Test func babyPigTextureLoads() {
    let texture = SpriteAssets.pigTexture(
        baseColor: .cream, state: "idle", direction: "left", isBaby: true
    )
    #expect(texture.filteringMode == .nearest)
}

// MARK: - Animation Frame Counts

@Test func animationFramesIdleHasOneFrame() {
    let frames = SpriteAssets.pigAnimationFrames(
        baseColor: .black, state: "idle", direction: "right", isBaby: false
    )
    #expect(frames.count == 1)
}

@Test func animationFramesSadHasOneFrame() {
    let frames = SpriteAssets.pigAnimationFrames(
        baseColor: .golden, state: "sad", direction: "left", isBaby: false
    )
    #expect(frames.count == 1)
}

@Test func animationFramesWalkingHasThreeFrames() {
    let frames = SpriteAssets.pigAnimationFrames(
        baseColor: .black, state: "walking", direction: "right", isBaby: false
    )
    #expect(frames.count == 3)
}

@Test func animationFramesEatingHasTwoFrames() {
    let frames = SpriteAssets.pigAnimationFrames(
        baseColor: .cream, state: "eating", direction: "left", isBaby: false
    )
    #expect(frames.count == 2)
}

@Test func animationFramesSleepingHasTwoFrames() {
    let frames = SpriteAssets.pigAnimationFrames(
        baseColor: .blue, state: "sleeping", direction: "right", isBaby: false
    )
    #expect(frames.count == 2)
}

@Test func animationFramesHappyHasTwoFrames() {
    let frames = SpriteAssets.pigAnimationFrames(
        baseColor: .lilac, state: "happy", direction: "right", isBaby: false
    )
    #expect(frames.count == 2)
}

@Test func allAnimationFramesHaveNearestFiltering() {
    let frames = SpriteAssets.pigAnimationFrames(
        baseColor: .black, state: "walking", direction: "right", isBaby: false
    )
    for frame in frames {
        #expect(frame.filteringMode == .nearest)
    }
}

@Test func babyAnimationFramesWalking() {
    let frames = SpriteAssets.pigAnimationFrames(
        baseColor: .chocolate, state: "walking", direction: "right", isBaby: true
    )
    #expect(frames.count == 3)
}

// MARK: - Facility Variants

@Test func facilityTextureWithState() {
    let texture = SpriteAssets.facilityTexture(facilityType: "food_bowl", state: "empty")
    #expect(texture.filteringMode == .nearest)
}

@Test func facilityTextureWithoutState() {
    let texture = SpriteAssets.facilityTexture(facilityType: "hideout")
    #expect(texture.filteringMode == .nearest)
}

// MARK: - Indicator Variants

@Test func indicatorTextureBright() {
    let texture = SpriteAssets.indicatorTexture(indicatorType: "hunger", bright: true)
    #expect(texture.filteringMode == .nearest)
}

@Test func indicatorTextureDim() {
    let texture = SpriteAssets.indicatorTexture(indicatorType: "hunger", bright: false)
    #expect(texture.filteringMode == .nearest)
}

// MARK: - Portrait Variants

@Test func portraitTextureAllPatterns() {
    for pattern in Pattern.allCases {
        let texture = SpriteAssets.portraitTexture(
            baseColor: .black, pattern: pattern, intensity: .full, roan: .none
        )
        #expect(texture.filteringMode == .nearest)
    }
}

@Test func portraitTextureAllIntensities() {
    for intensity in ColorIntensity.allCases {
        let texture = SpriteAssets.portraitTexture(
            baseColor: .golden, pattern: .solid, intensity: intensity, roan: .none
        )
        #expect(texture.filteringMode == .nearest)
    }
}

@Test func portraitTextureRoan() {
    let texture = SpriteAssets.portraitTexture(
        baseColor: .black, pattern: .solid, intensity: .full, roan: .roan
    )
    #expect(texture.filteringMode == .nearest)
}
