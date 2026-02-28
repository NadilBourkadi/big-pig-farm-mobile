/// SpriteTextureCacheTests — Tests for SpriteTextureCache hit/miss and eviction.
import Testing
import UIKit
import SpriteKit
@testable import BigPigFarm

@Suite("SpriteTextureCache")
struct SpriteTextureCacheTests {

    // MARK: - Helpers

    private func makeCache() -> SpriteTextureCache {
        SpriteTextureCache { name in
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 56, height: 32))
            let image = renderer.image { ctx in
                let hue = CGFloat(abs(name.hashValue % 360)) / 360.0
                UIColor(hue: hue, saturation: 1.0, brightness: 0.8, alpha: 1.0).setFill()
                ctx.fill(CGRect(origin: .zero, size: CGSize(width: 56, height: 32)))
            }
            return SKTexture(image: image)
        }
    }

    /// Solid/full/none pig using the default randomCommon() genotype.
    private func makeSolidPig() -> GuineaPig {
        GuineaPig.create(name: "SolidPig", gender: .female)
    }

    /// Dalmatian pig (ss/SS → ss = dalmatian pattern).
    private func makeDalmatianPig() -> GuineaPig {
        GuineaPig.create(
            name: "DalmatianPig",
            gender: .female,
            genotype: Genotype(
                eLocus: AllelePair(first: "E", second: "E"),
                bLocus: AllelePair(first: "B", second: "B"),
                sLocus: AllelePair(first: "s", second: "s"),
                cLocus: AllelePair(first: "C", second: "C"),
                rLocus: AllelePair(first: "r", second: "r"),
                dLocus: AllelePair(first: "D", second: "D")
            )
        )
    }

    // MARK: - Cache Hit

    @Test func cacheHitReturnsSameObject() {
        let cache = makeCache()
        let pig = makeSolidPig()
        let first = cache.texture(for: pig, state: "idle", direction: "right", frame: 0)
        let second = cache.texture(for: pig, state: "idle", direction: "right", frame: 0)
        #expect(first === second, "Second call must return the cached texture (identity check)")
    }

    @Test func differentFramesGetDifferentTextures() {
        let cache = makeCache()
        let pig = makeSolidPig()
        let frame1 = cache.texture(for: pig, state: "walking", direction: "right", frame: 1)
        let frame2 = cache.texture(for: pig, state: "walking", direction: "right", frame: 2)
        #expect(frame1 !== frame2, "Frame 1 and frame 2 should be different textures")
    }

    // MARK: - Solid Cache Sharing

    @Test func solidPigsShareCacheEntry() {
        let cache = makeCache()
        let pig1 = makeSolidPig()
        let pig2 = makeSolidPig()
        #expect(pig1.id != pig2.id)
        #expect(pig1.phenotype.pattern == .solid)
        #expect(pig1.phenotype.baseColor == pig2.phenotype.baseColor)

        let texture1 = cache.texture(for: pig1, state: "idle", direction: "right", frame: 0)
        let texture2 = cache.texture(for: pig2, state: "idle", direction: "right", frame: 0)
        #expect(texture1 === texture2,
                "Two solid pigs with same base color should share a solidCache entry")
    }

    // MARK: - Patterned Cache Isolation

    @Test func patternedPigsGetSeparateCacheEntries() {
        let cache = makeCache()
        let pig1 = makeDalmatianPig()
        let pig2 = makeDalmatianPig()
        #expect(pig1.id != pig2.id)

        let texture1 = cache.texture(for: pig1, state: "idle", direction: "right", frame: 0)
        let texture2 = cache.texture(for: pig2, state: "idle", direction: "right", frame: 0)
        #expect(texture1 !== texture2,
                "Two dalmatian pigs should have separate patterned cache entries")
    }

    @Test func patternedPigCacheHit() {
        let cache = makeCache()
        let pig = makeDalmatianPig()
        let first = cache.texture(for: pig, state: "idle", direction: "right", frame: 0)
        let second = cache.texture(for: pig, state: "idle", direction: "right", frame: 0)
        #expect(first === second, "Same patterned pig must get a cache hit on second call")
    }

    // MARK: - Eviction

    @Test func evictRemovesPigEntry() {
        let cache = makeCache()
        let pig = makeDalmatianPig()
        let before = cache.texture(for: pig, state: "idle", direction: "right", frame: 0)
        cache.evict(pigID: pig.id)
        let after = cache.texture(for: pig, state: "idle", direction: "right", frame: 0)
        #expect(before !== after, "Evicted entry should produce a new texture on next access")
    }

    @Test func evictAllClearsBothCaches() {
        let cache = makeCache()
        _ = cache.texture(for: makeSolidPig(), state: "idle", direction: "right", frame: 0)
        _ = cache.texture(for: makeDalmatianPig(), state: "idle", direction: "right", frame: 0)

        #expect(cache.solidCacheCount > 0)
        #expect(cache.patternedCacheCount > 0)

        cache.evictAll()

        #expect(cache.solidCacheCount == 0, "evictAll() should clear solidCache")
        #expect(cache.patternedCacheCount == 0, "evictAll() should clear patternedCache")
    }

    // MARK: - Counters

    @Test func solidCacheCountReflectsFrameEntries() {
        let cache = makeCache()
        let pig = makeSolidPig()
        _ = cache.texture(for: pig, state: "idle", direction: "right", frame: 0)
        _ = cache.texture(for: pig, state: "walking", direction: "right", frame: 1)
        #expect(cache.solidCacheCount >= 2)
    }

    @Test func patternedCacheCountReflectsPigCount() {
        let cache = makeCache()
        let pig1 = makeDalmatianPig()
        let pig2 = makeDalmatianPig()
        _ = cache.texture(for: pig1, state: "idle", direction: "right", frame: 0)
        _ = cache.texture(for: pig2, state: "idle", direction: "right", frame: 0)
        #expect(cache.patternedCacheCount == 2)
    }
}
