/// SpriteTextureCache — caches pattern-composited pig textures keyed by pig UUID.
///
/// Two-tier design (per Spec 03 §12):
/// - `solidCache`: Shared entries for solid/full/none pigs (keyed by frame key).
///   These pigs are identical per base color, so one entry per frame suffices.
/// - `patternedCache`: Per-pig entries for pigs with pattern/intensity/roan modifiers.
///   Dalmatian and Roan patterns are pig-specific (seeded by UUID).
///
/// Cache entries are evicted when a pig is sold or dies.
///
/// **Thread Safety:** This type is **not** thread-safe. All calls to `texture(for:)`,
/// `evict(pigID:)`, and `evictAll()` must occur on the same thread — typically the
/// main thread, which is the only thread SpriteKit uses for scene updates. The
/// `@unchecked Sendable` conformance is provided solely to satisfy Swift 6 strict
/// concurrency at the SpriteKit scene boundary; callers must not share an instance
/// across threads.
import SpriteKit

final class SpriteTextureCache: @unchecked Sendable {

    // MARK: - Types

    /// Closure type for loading a base texture by asset name.
    /// Defaults to `SKTexture(imageNamed:)`. Inject a mock in tests.
    typealias TextureLoader = (String) -> SKTexture

    // MARK: - Storage

    private let loadTexture: TextureLoader

    /// Shared cache for solid/full/none pigs. Key: frame key string.
    private var solidCache: [String: SKTexture] = [:]

    /// Per-pig cache for patterned pigs. Outer key: pig UUID. Inner key: frame key.
    private var patternedCache: [UUID: [String: SKTexture]] = [:]

    // MARK: - Diagnostics

    /// Number of unique patterned pigs with cached entries.
    var patternedCacheCount: Int { patternedCache.count }

    /// Number of cached solid-pig frame entries.
    var solidCacheCount: Int { solidCache.count }

    // MARK: - Init

    /// Create a cache with an optional texture loader override.
    ///
    /// - Parameter loader: Closure that returns an `SKTexture` for a given asset name.
    ///   Defaults to `SKTexture(imageNamed:)`, which loads from `Assets.xcassets`.
    init(loader: @escaping TextureLoader = { SKTexture(imageNamed: $0) }) {
        self.loadTexture = loader
    }

    // MARK: - Lookup

    /// Get or create a composited texture for a pig's animation frame.
    ///
    /// - Parameters:
    ///   - pig: The guinea pig whose texture is needed.
    ///   - state: Animation state name (e.g. `"idle"`, `"walking"`, `"sleeping"`).
    ///   - direction: Facing direction (`"left"` or `"right"`).
    ///   - frame: Frame index. Use `0` for single-frame animations (no suffix in name).
    ///            Use `1`, `2`, ... for multi-frame animations.
    /// - Returns: The composited `SKTexture` for this frame.
    func texture(
        for pig: GuineaPig,
        state: String,
        direction: String,
        frame: Int
    ) -> SKTexture {
        let phenotype = pig.phenotype
        let isSolid = phenotype.pattern == .solid
            && phenotype.intensity == .full
            && phenotype.roan == .none

        let age = pig.isBaby ? "baby" : "adult"
        let color = phenotype.baseColor.rawValue
        let cacheKey = "\(age)_\(color)_\(state)_\(direction)_\(frame)"

        // Fast path: solid pigs share a cache entry by frame key
        if isSolid {
            if let cached = solidCache[cacheKey] { return cached }
            let base = loadBaseTexture(age: age, color: color, state: state,
                                       direction: direction, frame: frame)
            solidCache[cacheKey] = base
            return base
        }

        // Patterned pigs: check per-pig cache
        if let pigCache = patternedCache[pig.id],
           let cached = pigCache[cacheKey] {
            return cached
        }

        // Cache miss: load base texture, apply pattern, store
        let base = loadBaseTexture(age: age, color: color, state: state,
                                   direction: direction, frame: frame)
        let config = PatternRenderer.PatternConfig(
            pattern: phenotype.pattern,
            intensity: phenotype.intensity,
            roan: phenotype.roan,
            pigID: pig.id,
            whiteColor: PigPalettes.color(for: .white, baseColor: phenotype.baseColor),
            bellyColor: PigPalettes.color(for: .belly, baseColor: phenotype.baseColor),
            isBaby: pig.isBaby
        )
        let composited = PatternRenderer.applyPattern(baseTexture: base, config: config)

        patternedCache[pig.id, default: [:]][cacheKey] = composited
        return composited
    }

    // MARK: - Eviction

    /// Remove all cached textures for a pig that no longer exists (sold or died).
    func evict(pigID: UUID) {
        patternedCache.removeValue(forKey: pigID)
    }

    /// Remove all cached textures (e.g. on memory warning).
    func evictAll() {
        solidCache.removeAll()
        patternedCache.removeAll()
    }

    // MARK: - Private

    /// Build the asset catalog name for a base-color pig texture.
    ///
    /// Naming convention (Spec 03 §7): `pig_{age}_{color}_{state}_{direction}[_{frame}]`
    /// Single-frame animations (idle, sleeping, etc.) have no frame suffix.
    /// Multi-frame animations (walking) use `_1`, `_2`, etc.
    private func loadBaseTexture(
        age: String,
        color: String,
        state: String,
        direction: String,
        frame: Int
    ) -> SKTexture {
        let frameSuffix = frame > 0 ? "_\(frame)" : ""
        let name = "pig_\(age)_\(color)_\(state)_\(direction)\(frameSuffix)"
        return loadTexture(name)
    }
}
