/// PatternRendererTests — Tests for PatternRenderer (compositing logic).
import Testing
import UIKit
import SpriteKit
@testable import BigPigFarm

@Suite("PatternRenderer")
struct PatternRendererTests {

    // MARK: - Helpers

    private func makeTexture(width: Int = 56, height: Int = 32) -> SKTexture {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: image)
    }

    private func makeConfig(
        pattern: Pattern = .solid,
        intensity: ColorIntensity = .full,
        roan: RoanType = .none,
        pigID: UUID = UUID(),
        isBaby: Bool = false
    ) -> PatternRenderer.PatternConfig {
        PatternRenderer.PatternConfig(
            pattern: pattern, intensity: intensity, roan: roan,
            pigID: pigID, whiteColor: .white, bellyColor: .lightGray,
            isBaby: isBaby
        )
    }

    // MARK: - Fast Path

    @Test func solidFullNoneReturnsSameObject() {
        let base = makeTexture()
        let result = PatternRenderer.applyPattern(
            baseTexture: base, config: makeConfig()
        )
        #expect(result === base, "solid/full/none must return the exact same texture object")
    }

    @Test func solidFullNoneBabyReturnsSameObject() {
        let base = makeTexture(width: 32, height: 24)
        let result = PatternRenderer.applyPattern(
            baseTexture: base, config: makeConfig(isBaby: true)
        )
        #expect(result === base)
    }

    // MARK: - Pattern Produces New Texture

    @Test func dutchPatternReturnsNewTexture() {
        let base = makeTexture()
        let result = PatternRenderer.applyPattern(
            baseTexture: base, config: makeConfig(pattern: .dutch)
        )
        #expect(result !== base, "Dutch pattern should produce a new texture")
    }

    @Test func dalmatianPatternReturnsNewTexture() {
        let base = makeTexture()
        let result = PatternRenderer.applyPattern(
            baseTexture: base, config: makeConfig(pattern: .dalmatian)
        )
        #expect(result !== base, "Dalmatian pattern should produce a new texture")
    }

    @Test func chinchillaIntensityReturnsNewTexture() {
        let base = makeTexture()
        let result = PatternRenderer.applyPattern(
            baseTexture: base, config: makeConfig(intensity: .chinchilla)
        )
        #expect(result !== base, "Chinchilla intensity should produce a new texture")
    }

    @Test func himalayanIntensityReturnsNewTexture() {
        let base = makeTexture()
        let result = PatternRenderer.applyPattern(
            baseTexture: base, config: makeConfig(intensity: .himalayan)
        )
        #expect(result !== base, "Himalayan intensity should produce a new texture")
    }

    @Test func roanAloneReturnsNewTexture() {
        let base = makeTexture()
        let result = PatternRenderer.applyPattern(
            baseTexture: base, config: makeConfig(roan: .roan)
        )
        #expect(result !== base, "Roan modifier should produce a new texture")
    }

    // MARK: - Dalmatian Determinism

    @Test func dalmatianSameIDProducesSameSpots() {
        let pigID = UUID()
        let innerFur = SpriteFurMaps.adultInnerFur
        let spots1 = PatternRenderer.generateDalmatianSpots(
            pigID: pigID, width: 14, height: 8, innerFurPixels: innerFur
        )
        let spots2 = PatternRenderer.generateDalmatianSpots(
            pigID: pigID, width: 14, height: 8, innerFurPixels: innerFur
        )
        #expect(spots1 == spots2, "Dalmatian spots must be deterministic for the same pigID")
    }

    @Test func dalmatianDifferentIDProducesDifferentSpots() {
        let innerFur = SpriteFurMaps.adultInnerFur
        let spots1 = PatternRenderer.generateDalmatianSpots(
            pigID: UUID(), width: 14, height: 8, innerFurPixels: innerFur
        )
        let spots2 = PatternRenderer.generateDalmatianSpots(
            pigID: UUID(), width: 14, height: 8, innerFurPixels: innerFur
        )
        #expect(spots1 != spots2, "Different pigIDs should produce different spot patterns")
    }

    @Test func dalmatianSpotsAreSubsetOfInnerFur() {
        let innerFur = SpriteFurMaps.adultInnerFur
        let spots = PatternRenderer.generateDalmatianSpots(
            pigID: UUID(), width: 14, height: 8, innerFurPixels: innerFur
        )
        #expect(spots.isSubset(of: innerFur), "All spots must be within inner fur pixels")
    }

    @Test func dalmatianSpotCoverageInRange() {
        let innerFur = SpriteFurMaps.adultInnerFur
        let spots = PatternRenderer.generateDalmatianSpots(
            pigID: UUID(), width: 14, height: 8, innerFurPixels: innerFur
        )
        let coverage = Double(spots.count) / Double(innerFur.count)
        #expect(coverage >= 0.10 && coverage <= 0.60,
                "Dalmatian coverage \(coverage) outside expected 10-60% range")
    }

    @Test func dalmatianEmptyInnerFurProducesEmptySpots() {
        let spots = PatternRenderer.generateDalmatianSpots(
            pigID: UUID(), width: 14, height: 8, innerFurPixels: []
        )
        #expect(spots.isEmpty)
    }

    @Test func dalmatianBabyDeterministic() {
        let pigID = UUID()
        let innerFur = SpriteFurMaps.babyInnerFur
        let spots1 = PatternRenderer.generateDalmatianSpots(
            pigID: pigID, width: 8, height: 6, innerFurPixels: innerFur
        )
        let spots2 = PatternRenderer.generateDalmatianSpots(
            pigID: pigID, width: 8, height: 6, innerFurPixels: innerFur
        )
        #expect(spots1 == spots2)
    }

    @Test func dalmatianBabySpotsSubsetOfBabyInnerFur() {
        let innerFur = SpriteFurMaps.babyInnerFur
        let spots = PatternRenderer.generateDalmatianSpots(
            pigID: UUID(), width: 8, height: 6, innerFurPixels: innerFur
        )
        #expect(spots.isSubset(of: innerFur))
    }

    // MARK: - Roan Determinism

    @Test func roanSameIDProducesSameScatter() {
        let pigID = UUID()
        let innerFur = SpriteFurMaps.adultInnerFur
        let scatter1 = PatternRenderer.generateRoanScatter(pigID: pigID, innerFurPixels: innerFur)
        let scatter2 = PatternRenderer.generateRoanScatter(pigID: pigID, innerFurPixels: innerFur)
        #expect(scatter1 == scatter2, "Roan scatter must be deterministic for the same pigID")
    }

    @Test func roanDifferentIDProducesDifferentScatter() {
        let innerFur = SpriteFurMaps.adultInnerFur
        let s1 = PatternRenderer.generateRoanScatter(pigID: UUID(), innerFurPixels: innerFur)
        let s2 = PatternRenderer.generateRoanScatter(pigID: UUID(), innerFurPixels: innerFur)
        #expect(s1 != s2, "Different pigIDs should produce different roan scatter")
    }

    @Test func roanScatterIsSubsetOfInnerFur() {
        let innerFur = SpriteFurMaps.adultInnerFur
        let scatter = PatternRenderer.generateRoanScatter(pigID: UUID(), innerFurPixels: innerFur)
        #expect(scatter.isSubset(of: innerFur), "All roan scatter must be within inner fur pixels")
    }

    @Test func roanScatterCoverageNear30Percent() {
        let innerFur = SpriteFurMaps.adultInnerFur
        var totalCoverage = 0.0
        for _ in 0..<20 {
            let scatter = PatternRenderer.generateRoanScatter(pigID: UUID(), innerFurPixels: innerFur)
            totalCoverage += Double(scatter.count) / Double(innerFur.count)
        }
        let meanCoverage = totalCoverage / 20.0
        #expect(meanCoverage >= 0.18 && meanCoverage <= 0.42,
                "Mean roan coverage \(meanCoverage) far from expected 30%")
    }

    @Test func roanEmptyInnerFurProducesEmptyScatter() {
        let scatter = PatternRenderer.generateRoanScatter(pigID: UUID(), innerFurPixels: [])
        #expect(scatter.isEmpty)
    }
}
