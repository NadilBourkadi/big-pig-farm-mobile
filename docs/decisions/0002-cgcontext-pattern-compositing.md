# ADR-0002: CGContext Compositing for Pattern Overlays

## Status

Accepted

## Context

Pig sprites have 144 phenotype combinations (8 base colors x 3 patterns x 3 intensities x 2 roan).
Patterns (Dutch, Dalmatian, Chinchilla, Himalayan, Roan) must be applied to base-color sprites at
runtime. Two rendering approaches were considered: per-frame GPU shaders via `SKShader`, or one-time
CPU compositing via `CGContext` with texture caching.

The pig sprites are tiny (14x8 art pixels at 4x scale = 56x32 actual) and patterns are static per
pig (phenotype is fixed at birth). The farm scene can display 50-100+ pigs simultaneously.

## Options Considered

### Option A: SKShader (per-frame GPU)

Attach a GLSL fragment shader to each `PigNode` that applies pattern logic every frame. Uniforms
would pass pattern type, pig UUID seed, and palette colors per node.

Trade-offs:
- No extra texture memory (patterns computed on the fly)
- Per-frame GPU cost for every visible pig, every frame, for data that never changes
- Each unique uniform combination creates a separate draw batch, breaking SpriteKit's automatic
  draw call batching and increasing draw call count
- GLSL shader authoring is harder to debug than pixel manipulation
- Shader compilation overhead on first use

### Option B: CGContext alpha compositing (one-time CPU)

At pig creation, extract the base-color `CGImage`, create a `CGContext`, composite pattern pixels
using `CGContext.fill()` with `.copy` blend mode, then cache the result as a standard `SKTexture`.

Trade-offs:
- One-time CPU cost at pig creation (sub-millisecond for 56x32 textures)
- Zero per-frame rendering cost (cached texture batches identically to pre-rendered assets)
- Additional texture memory per patterned pig (~7 KB per texture, ~66% of pigs are solid and
  skip compositing entirely)
- Straightforward pixel manipulation, easy to debug and verify

## Decision

Option B (CGContext compositing). Patterns are static per pig, so per-frame GPU computation is
wasteful. The one-time CGContext compositing produces a standard `SKTexture` that SpriteKit batches
identically to pre-rendered assets, preserving optimal draw call counts. The sprite dimensions are
so small (56x32) that compositing cost is negligible.

The two-tier `SpriteTextureCache` design amplifies the advantage: solid pigs (~66%) share a single
cached texture per base color, while patterned pigs composite once per animation frame key and cache
the result. Total per-frame overhead from pattern rendering: zero.

Performance validation with 50-100 pig scenes (SpriteViewPerformanceTests) confirmed frame times
well within budget with compositing active.

## Consequences

- `PatternRenderer` uses `CGContext` pixel manipulation exclusively. No shader infrastructure needed.
- `SpriteTextureCache` maintains a two-tier cache: solid textures shared by base color, patterned
  textures keyed by pig UUID + animation frame.
- Future pattern types should follow the same approach: implement as pixel manipulation in
  `PatternRenderer`, not as shaders.
- If the game ever needs per-frame dynamic pattern effects (e.g., animated shimmer), `SKShader`
  could be revisited for that specific case, but static phenotype patterns should remain composited.
