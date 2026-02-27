# Spec 03 — Sprite Pipeline

> **Status:** Complete
> **Date:** 2026-02-27
> **Depends on:** 01 (Project Setup)
> **Blocks:** 06 (Farm Scene)

---

## 1. Overview

This document specifies the complete sprite pipeline for the iOS port: a Python export tool that converts the game's half-block pixel art into PNG textures, the Xcode asset catalog organization, the Swift API for loading and looking up sprites at runtime, and the runtime pattern compositing system.

The Python source codebase renders sprites as Unicode half-block characters (`▀▄█`) in a terminal. SpriteKit renders sprites as `SKTexture` objects loaded from PNG images. The pipeline bridges this gap: read the existing pixel grid data, apply color palettes, and output PNGs that SpriteKit can load directly.

### Scope

**In scope:**
- Complete inventory of all sprite assets from the Python source
- Python export tool (`tools/export_sprites.py`) that produces PNG files from pixel grid data
- Pig sprite export: 8 base colors x all animation states x 2 directions x 2 ages
- Facility sprite export: 17 types with state variants
- Indicator sprite export: 6 types x 2 brightness levels
- Portrait sprite export: procedural 32x22 face generation for all 144 phenotype combos
- Terrain tile generation for `SKTileMapNode` (8 biome floor + wall tiles)
- Asset catalog organization and naming conventions
- Swift `SpriteAssets` loading API with type signatures
- Runtime pattern overlay system (Dutch, Dalmatian, Chinchilla, Himalayan, Roan)
- Animation frame data ported from Python constants
- Validation tests

**Out of scope:**
- SpriteKit node hierarchy and scene graph (Doc 06)
- `SKAction` animation sequences and timing (Doc 06)
- Camera and zoom behavior (Doc 06)
- Touch interaction with sprites (Doc 06)
- SwiftUI portrait views (Doc 07)

### Deliverable Summary

| Category | Assets | Files |
|----------|--------|-------|
| Python export tool | 1 CLI script | `tools/export_sprites.py` |
| Pig sprite PNGs | 544 (8 colors x 34 frames x 2 ages) | `Assets.xcassets/Sprites/Pigs/` |
| Facility sprite PNGs | 25 | `Assets.xcassets/Sprites/Facilities/` |
| Indicator sprite PNGs | 12 | `Assets.xcassets/Sprites/Indicators/` |
| Portrait sprite PNGs | 1,152 (8 colors x 144 combos) | `Assets.xcassets/Sprites/Portraits/` |
| Terrain tile PNGs | 24 (8 biomes x 3 tile types) | `Assets.xcassets/Sprites/Terrain/` |
| Pattern mask PNGs | ~10 | `Assets.xcassets/Sprites/Patterns/` |
| Swift loading API | 1 file | `BigPigFarm/Scene/SpriteAssets.swift` |
| Swift pattern system | 1 file | `BigPigFarm/Scene/PatternRenderer.swift` |
| Swift animation data | 1 file | `BigPigFarm/Scene/AnimationData.swift` |
| Test file | 1 file | `BigPigFarmTests/SpriteAssetTests.swift` |

---

## 2. Architecture Overview

### Python Half-Block System (Source)

The Python codebase stores sprites as 2D arrays of palette key strings. Each pixel is a key like `"fur"`, `"dark"`, `"eye"`, or `nil` (transparent). A separate palette dictionary maps keys to hex color strings. The `convert_pixels()` function in `sprite_engine.py` pairs rows into half-block characters for terminal rendering.

**Key source files:**

| File | Purpose | Lines |
|------|---------|-------|
| `data/sprite_engine.py` | Core types, palettes (8 colors x 13 keys), `convert_pixels()` | 347 |
| `data/pig_sprites.py` | Normal-zoom pig pixel grids (14x8 adult, 8x6 baby) | 469 |
| `data/pig_sprites_close.py` | Close-zoom pig pixel grids (28x16 adult, 16x12 baby) | 366 |
| `data/pig_sprite_lookup.py` | State/direction/zoom resolution logic | 82 |
| `data/pig_portraits.py` | 32x22 procedural face template + pattern application | 247 |
| `data/facility_pixels.py` | Normal + far facility pixel grids, palettes | 670 |
| `data/facility_pixels_close.py` | Close-zoom facility pixel grids | 732 |
| `data/indicator_pixels.py` | Status indicator pixel grids + palettes | 192 |
| `data/indicator_sprites.py` | Indicator lookup + threshold logic | 111 |
| `data/sprites.py` | Master lookup, zoom dispatch, `get_pig_halfblock_sprite()` | 306 |
| `tools/sprite_export.py` | Existing JSON export tool (not PNG -- we extend this) | 166 |

### SpriteKit Target System

On iOS, sprites are `SKTexture` objects loaded from the Xcode asset catalog (`Assets.xcassets`). Each PNG file becomes a texture. Related textures can be grouped into texture atlases for efficient GPU batching.

The pipeline:

```
Python pixel grids + palettes
        |
        v
  export_sprites.py (Pillow)
        |
        v
  PNG files (1 pixel = 1 PNG pixel, scaled at export)
        |
        v
  Assets.xcassets (organized by category)
        |
        v
  SKTexture / SKTextureAtlas (loaded at runtime)
        |
        v
  SKSpriteNode (displayed in scene)
```

### Decision: Normal Zoom Only (ROADMAP Decision 6)

The Python source has three zoom levels (far 7x6, normal 14x8, close 28x16) with separate hand-crafted sprites per level. SpriteKit handles zoom natively via `SKCameraNode` -- zooming the camera scales all nodes uniformly without needing separate sprite sets.

**We export only normal-zoom sprites.** The camera zooms into the normal-resolution textures. With `SKTexture.filteringMode = .nearest` (pixel-art filtering), zooming in preserves sharp pixel edges. Zooming out naturally downscales.

This eliminates:
- 22 close-zoom adult sprites (28x16)
- 12 close-zoom baby sprites (16x12)
- 10 far-zoom adult sprites (7x6)
- 6 far-zoom baby sprites (5x4)
- All close/far facility variants
- All close indicator variants

**Exception: Portraits.** The 32x22 portrait template is its own asset type used in the `PigDetailView` (SwiftUI), not as a sprite in the farm scene. Portraits are always displayed at a fixed size, not affected by camera zoom. They are exported at their native 32x22 resolution and scaled up via `imageInterpolation: .none` in SwiftUI.

---

## 3. Sprite Inventory

### 3.1 Pig Sprites — Normal Zoom

**Adult (14w x 8h pixels per frame):**

| State | Directions | Frames | Keys in `PIG_PIXELS_ADULT` |
|-------|-----------|--------|---------------------------|
| idle | right, left | 1 | `idle_right`, `idle_left` |
| walking | right, left | 3 | `walking_{dir}_{1,2,3}` |
| eating | right, left | 2 | `eating_{dir}_{1,2}` |
| sleeping | right, left | 2 | `sleeping_{dir}_{1,2}` |
| happy | right, left | 2 | `happy_{dir}_{1,2}` |
| sad | right, left | 1 | `sad_right`, `sad_left` |

**Total adult frames:** 22 (11 right + 11 left)

**Baby (8w x 6h pixels per frame):**

| State | Directions | Frames | Keys in `PIG_PIXELS_BABY` |
|-------|-----------|--------|--------------------------|
| idle | right, left | 1 | `idle_right`, `idle_left` |
| walking | right, left | 3 | `walking_{dir}_{1,2,3}` |
| sleeping | right, left | 2 | `sleeping_{dir}_{1,2}` |

**Total baby frames:** 12 (6 right + 6 left)

**Per-color output:** 8 base colors x 34 frames = **272 pig PNGs per age group**, **544 total**.

Palette keys used in pig grids: `fur`, `shade`, `dark`, `belly`, `pupil`, `eye`, `nose`, `ear`, `paw`, `tooth`, `white`, `blush`, `tear`, `T` (transparent).

### 3.2 Pig Portraits

**Template:** 32w x 22h pixels, front-facing guinea pig face.

Source: `data/pig_portraits.py` -- `_FACE_TEMPLATE` (32x22 grid) with `generate_portrait()` applying pattern/intensity/roan modifications.

Portraits are generated per-phenotype combination:
- 8 base colors
- 3 patterns (solid, dutch, dalmatian)
- 3 intensities (full, chinchilla, himalayan)
- 2 roan states (none, roan)

**Total combinations:** 8 x 3 x 3 x 2 = **144 phenotype variants**.

However, dalmatian and roan patterns are seeded by pig UUID, meaning each pig gets a unique pattern. Pre-rendering all 144 combos with a fixed seed gives representative portraits for UI use (Pigdex, adoption center). Runtime portraits for specific pigs will use the pig's UUID seed.

**Decision:** Pre-render 144 representative portraits (one per phenotype) for the Pigdex and collection UI. For individual pig detail views, generate portraits at runtime using the Swift `PatternRenderer` (Section 12) with the pig's UUID seed. This balances asset size against visual variety.

**Export approach for pre-rendered portraits:** Use a fixed seed string (e.g., `"pigdex_preview"`) for dalmatian spot placement and roan scatter. This produces deterministic, visually representative portraits for UI grids.

### 3.3 Facility Sprites — Normal Zoom

**Source:** `data/facility_pixels.py` -- `FACILITY_PIXELS` dict + `FACILITY_PALETTES` dict.

| Facility Type | Dimensions | State Variants | Palette Keys |
|--------------|-----------|----------------|-------------|
| food_bowl | 8x6 | default, empty, full | frame, bowl, food, empty, base |
| water_bottle | 5x10 | default, empty, full | frame, glass, water, empty, cap, nozzle, drop |
| hay_rack | 8x8 | default, empty, full | frame, hay, straw, empty, slat |
| hideout | 11x8 | default | frame, roof, wall, door, plank |
| exercise_wheel | 9x8 | default | frame, wheel, spoke, axle, stand |
| tunnel | 9x6 | default | frame, tube, open, ridge |
| play_area | 10x8 | default | frame, floor, ball, block, star, mat |
| breeding_den | 9x8 | default | frame, floor, cushion, heart, glow |
| nursery | 11x8 | default | frame, floor, blanket, star, mobile |
| veggie_garden | 9x8 | default | frame, soil, plant, carrot, leaf |
| grooming_station | 9x8 | default | frame, floor, mirror, brush, sparkle |
| genetics_lab | 11x8 | default | frame, floor, flask, dna, glow, bench |
| feast_table | 14x14 | default, empty, full | frame, table, plate, food, cloth, candle |
| campfire | 14x14 | default | frame, ground, log, flame, ember, smoke |
| therapy_garden | 14x14 | default | frame, ground, flower, leaf, path, pot |
| hot_spring | 18x18 | default | frame, water, steam, rock, edge, glow |
| stage | 18x18 | default | frame, floor, curtain, light, star, note |

**Total facility PNGs:** 25 (17 defaults + 3x consumable state variants for food_bowl, water_bottle, hay_rack, feast_table, minus the defaults that overlap = 17 + 8 state variants = 25)

### 3.4 Indicator Sprites — Normal Zoom

**Source:** `data/indicator_pixels.py` -- `INDICATOR_PIXELS_NORMAL` (7x6 grids) + `INDICATOR_PALETTES`.

| Indicator | Dimensions | Variants | Palette Keys |
|-----------|-----------|----------|-------------|
| health | 7x6 | bright, dim | a (red), b (white) |
| hunger | 7x6 | bright, dim | a (red), b (green) |
| thirst | 7x6 | bright, dim | a (blue), b (light blue) |
| energy | 7x6 | bright, dim | a (purple), b (light purple) |
| courting | 7x6 | bright, dim | a (pink), b (light pink) |
| pregnant | 7x6 | bright, dim | a (rose), b (light rose) |

**Total indicator PNGs:** 12 (6 types x 2 brightness levels)

### 3.5 Terrain Tiles

**Source:** `entities/biomes.py` -- `BiomeInfo.floor_colors`, `floor_bg`, `floor_chars` per biome. `data/sprites.py` -- `WALL_PLANK`, `WALL_GRAIN`, `WALL_POST`, `FLOOR_CHARS`, `FLOOR_COLORS`.

Terrain tiles are not pixel grids in the Python source -- they are terminal characters with colors. For SpriteKit's `SKTileMapNode`, we need small tile PNGs.

**Tile types per biome:**
1. **Floor tile** (1x1 cell) -- solid color from `floor_bg`, optionally with subtle variation
2. **Wall tile** (1x1 cell) -- wooden plank color from `wall_tint_plank` (or default `WALL_PLANK`)
3. **Wall post tile** (1x1 cell) -- darker accent from `WALL_POST` or biome override

**8 biomes:** Meadow, Burrow, Garden, Tropical, Alpine, Crystal, Wildflower, Sanctuary.

**Total terrain tile PNGs:** 24 (8 biomes x 3 tile types)

Each terrain tile is a small square (e.g., 8x8 pixels) with subtle color variation to avoid a flat look. The export tool generates these procedurally from the biome color arrays.

---

## 4. Export Resolution and Scaling Strategy

### Pixel-to-Point Mapping

SpriteKit works in points. On Retina displays, 1 point = 2-3 physical pixels. The pixel art must remain sharp at its intended display size.

**Strategy: Export at 1 logical pixel = 1 PNG pixel. Scale up at export time for device resolution.**

The normal-zoom adult pig is 14x8 logical pixels. In the terminal, each pixel is one character cell (~8x16 physical screen pixels). On iOS, we want each logical art pixel to be clearly visible.

**Target display size:** Each art pixel maps to a 4x4 point block at @1x (making an adult pig 56x32 points on screen -- roughly the size of a fingertip). The export tool produces:

| Scale | Art Pixel Size | Adult Pig PNG | Baby Pig PNG | Purpose |
|-------|---------------|---------------|-------------|---------|
| @1x | 4x4 px | 56x32 | 32x24 | Base (non-retina, never actually used) |
| @2x | 8x8 px | 112x64 | 64x48 | Standard Retina |
| @3x | 12x12 px | 168x96 | 96x72 | iPhone Pro Max displays |

The asset catalog image set uses all three scales. Xcode selects the correct variant at runtime.

**Scale factor constant:** `PIXELS_PER_ART_PIXEL = 4` (at @1x). This value is tunable -- if pigs look too small or too large in the scene, adjust this single constant and re-export.

**Nearest-neighbor scaling:** The export tool uses `Image.resize(..., resample=Image.NEAREST)` (Pillow) to preserve sharp pixel edges. No anti-aliasing, no blurring.

### Facility and Indicator Scaling

Same `PIXELS_PER_ART_PIXEL = 4` applies to all sprite types. A food bowl (8x6 art pixels) becomes 32x24 points at @1x. Indicators (7x6) become 28x24 points -- small icons that float above pigs.

### Portrait Scaling

Portraits (32x22 art pixels) are displayed in SwiftUI views at a larger size. They use a separate scale factor:

`PORTRAIT_PIXELS_PER_ART_PIXEL = 8` (at @1x), producing 256x176 points. SwiftUI's `Image` with `.interpolation(.none)` ensures pixel-perfect rendering.

### Terrain Tile Scaling

Terrain tiles need to be exactly 1 grid cell in SpriteKit. The grid cell size in points equals `PIXELS_PER_ART_PIXEL` times the logical art pixel count of a reference sprite. Since adult pigs are 14 art pixels wide and occupy roughly 2 grid cells, each grid cell is about 7 art pixels = 28 points at @1x.

**Decision:** Terrain tiles are 8x8 art pixels, scaled to 32x32 points at @1x (with @2x and @3x variants). The slight overshoot (32 vs 28) ensures seamless tiling with no gaps. The tile size constant is centralized and adjustable.

---

## 5. Python Export Tool

### Location and Dependencies

**File:** `tools/export_sprites.py` (in the **mobile** repo, not the Python game repo)

The tool imports sprite data from the Python game repo. It requires:
- Python 3.10+
- Pillow (`pip install Pillow`)
- Access to the Python game repo at a configurable path

**Why in the mobile repo:** The export tool is part of the iOS build pipeline. It reads from the Python source but writes to the iOS asset catalog. Keeping it in the mobile repo means the iOS project is self-contained for asset generation.

### Command-Line Interface

```
usage: export_sprites.py [-h] --source SOURCE --output OUTPUT
                         [--scale SCALE] [--portrait-scale PORTRAIT_SCALE]
                         [--category {all,pigs,facilities,indicators,portraits,terrain}]

Export Big Pig Farm sprites from Python pixel data to PNG files.

required arguments:
  --source SOURCE       Path to the Python game repo root (e.g., ../big-pig-farm)
  --output OUTPUT       Output directory (e.g., BigPigFarm/Resources/Assets.xcassets/Sprites)

optional arguments:
  --scale SCALE         Pixels per art pixel at @1x (default: 4)
  --portrait-scale PORTRAIT_SCALE
                        Pixels per art pixel for portraits at @1x (default: 8)
  --category CATEGORY   Export only a specific category (default: all)
```

### Core Export Functions

```python
import sys
from pathlib import Path
from PIL import Image


def hex_to_rgba(hex_color: str) -> tuple[int, int, int, int]:
    """Convert '#RRGGBB' to (R, G, B, 255). None -> (0, 0, 0, 0) transparent."""
    if hex_color is None:
        return (0, 0, 0, 0)
    h = hex_color.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def render_grid_to_image(
    grid: list[list],
    palette: dict[str, str],
    scale: int = 1,
) -> Image.Image:
    """Render a PixelGrid to a Pillow RGBA Image.

    Args:
        grid: 2D array of palette keys (str) or None (transparent).
        palette: Mapping from palette key to hex color string.
        scale: Integer scale factor (each art pixel becomes scale x scale PNG pixels).

    Returns:
        Pillow Image in RGBA mode.
    """
    height = len(grid)
    width = max((len(row) for row in grid), default=0)

    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for y, row in enumerate(grid):
        for x, key in enumerate(row):
            if key is None:
                continue
            color_hex = palette.get(key)
            if color_hex is None and key in palette:
                color_hex = palette[key]
            elif color_hex is None:
                # Key not in palette -- use key as literal hex color
                color_hex = key
            img.putpixel((x, y), hex_to_rgba(color_hex))

    if scale > 1:
        img = img.resize(
            (width * scale, height * scale),
            resample=Image.NEAREST,
        )

    return img


def write_imageset(
    img_1x: Image.Image,
    output_dir: Path,
    name: str,
) -> None:
    """Write an Xcode image set with @1x, @2x, @3x variants.

    Creates:
        output_dir/name.imageset/Contents.json
        output_dir/name.imageset/name@1x.png
        output_dir/name.imageset/name@2x.png
        output_dir/name.imageset/name@3x.png
    """
    imageset_dir = output_dir / f"{name}.imageset"
    imageset_dir.mkdir(parents=True, exist_ok=True)

    w1, h1 = img_1x.size

    # @1x
    img_1x.save(imageset_dir / f"{name}@1x.png")

    # @2x
    img_2x = img_1x.resize((w1 * 2, h1 * 2), resample=Image.NEAREST)
    img_2x.save(imageset_dir / f"{name}@2x.png")

    # @3x
    img_3x = img_1x.resize((w1 * 3, h1 * 3), resample=Image.NEAREST)
    img_3x.save(imageset_dir / f"{name}@3x.png")

    # Contents.json
    contents = {
        "images": [
            {"filename": f"{name}@1x.png", "idiom": "universal", "scale": "1x"},
            {"filename": f"{name}@2x.png", "idiom": "universal", "scale": "2x"},
            {"filename": f"{name}@3x.png", "idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": False},
    }

    import json
    with open(imageset_dir / "Contents.json", "w") as f:
        json.dump(contents, f, indent=2)
```

### Palette Resolution

The `None` key in Python palettes (used for `T` / transparent fur wisps) maps to the `"fur"` color. The export tool resolves this:

```python
def resolve_palette(palette: dict) -> dict[str, str]:
    """Resolve a pig palette, mapping None key to 'T' for transparent wisps."""
    resolved = {}
    for key, value in palette.items():
        if key is None:
            # T (transparent wisps) maps to fur color
            resolved["T_fur"] = value
        else:
            resolved[key] = value
    return resolved
```

In the pixel grid data, `None` values are transparent pixels (alpha = 0). The sentinel `T` in the Python source is `None` -- these are already transparent. However, in palette entries, `T: "#444444"` means "fur wisps use the fur color." The export tool handles this by treating pixels with value `None` as transparent and resolving the palette `None` key only when a grid cell explicitly references it (which it does not -- wisps are part of the fur color in the palette definition, not referenced directly in grids).

**Simplification:** Since `T` is `None` in the Python source and grid cells with `T` are literally `None`, all transparent pixels export as alpha=0. The `None` palette entry is unused during export. The palette's `None -> hex_color` mapping only existed for the terminal renderer's edge case of rendering transparent-but-colored wisps; in SpriteKit, those pixels are simply transparent.

---

## 6. Export Pipeline: Pig Sprites

### Naming Convention

```
pig_{age}_{color}_{state}_{direction}[_{frame}]
```

Examples:
- `pig_adult_black_idle_right`
- `pig_adult_golden_walking_left_2`
- `pig_baby_cream_sleeping_right_1`

Where:
- `age`: `adult` or `baby`
- `color`: lowercase base color name (`black`, `chocolate`, `golden`, `cream`, `blue`, `lilac`, `saffron`, `smoke`)
- `state`: `idle`, `walking`, `eating`, `sleeping`, `happy`, `sad`
- `direction`: `right` or `left`
- `frame`: 1-indexed frame number (omitted for single-frame states like `idle`, `sad`)

### Export Logic

```python
def export_pig_sprites(source_path: Path, output_dir: Path, scale: int) -> int:
    """Export all pig sprites as PNG image sets.

    Returns the number of image sets created.
    """
    sys.path.insert(0, str(source_path))
    from big_pig_farm.data.sprite_engine import PALETTES
    from big_pig_farm.data.pig_sprites import PIG_PIXELS_ADULT, PIG_PIXELS_BABY

    count = 0
    pigs_dir = output_dir / "Pigs"

    for color_name, palette in PALETTES.items():
        resolved = dict(palette)  # Copy palette
        # Resolve None key (T) to fur color -- not needed for grid rendering
        # but keep palette clean
        if None in resolved:
            del resolved[None]

        for age_label, sprites in [("adult", PIG_PIXELS_ADULT), ("baby", PIG_PIXELS_BABY)]:
            for sprite_key, grid in sprites.items():
                asset_name = f"pig_{age_label}_{color_name.lower()}_{sprite_key}"
                img = render_grid_to_image(grid, resolved, scale=scale)
                write_imageset(img, pigs_dir, asset_name)
                count += 1

    return count
```

### Mirroring

The Python source stores both `_right` and `_left` variants explicitly (left variants are hand-crafted, not mirrored). The export tool exports every key from the sprite dictionary as-is -- no runtime mirroring needed.

**Note:** The close-zoom sprites in `pig_sprites_close.py` use `build_mirrored_dict()` to auto-generate left variants. Since we skip close-zoom sprites entirely, this mirroring utility is not needed in the export pipeline.

### Output Count Verification

- Adult: 22 keys x 8 colors = 176 image sets
- Baby: 12 keys x 8 colors = 96 image sets
- **Total pig image sets: 272**
- **Total PNG files: 272 x 3 scales = 816**

---

## 7. Export Pipeline: Facility Sprites

### Naming Convention

```
facility_{type}[_{state}]
```

Examples:
- `facility_food_bowl`
- `facility_food_bowl_empty`
- `facility_food_bowl_full`
- `facility_hideout`

### Export Logic

```python
def export_facility_sprites(source_path: Path, output_dir: Path, scale: int) -> int:
    """Export all facility sprites as PNG image sets."""
    sys.path.insert(0, str(source_path))
    from big_pig_farm.data.facility_pixels import FACILITY_PIXELS, FACILITY_PALETTES

    count = 0
    facilities_dir = output_dir / "Facilities"

    for sprite_key, grid in FACILITY_PIXELS.items():
        # Determine which palette to use (base facility type)
        base_type = sprite_key.rsplit("_", 1)[0] if "_empty" in sprite_key or "_full" in sprite_key else sprite_key
        palette = FACILITY_PALETTES.get(base_type)
        if palette is None:
            print(f"  WARNING: No palette for {base_type}, skipping {sprite_key}")
            continue

        asset_name = f"facility_{sprite_key}"
        img = render_grid_to_image(grid, palette, scale=scale)
        write_imageset(img, facilities_dir, asset_name)
        count += 1

    return count
```

### Output Count

25 facility sprite keys x 3 scales = 75 PNG files.

---

## 8. Export Pipeline: Indicator Sprites

### Naming Convention

```
indicator_{type}_{brightness}
```

Examples:
- `indicator_health_bright`
- `indicator_hunger_dim`
- `indicator_courting_bright`

### Export Logic

```python
def export_indicator_sprites(source_path: Path, output_dir: Path, scale: int) -> int:
    """Export all indicator sprites as PNG image sets."""
    sys.path.insert(0, str(source_path))
    from big_pig_farm.data.indicator_pixels import (
        INDICATOR_PALETTES,
        INDICATOR_PIXELS_NORMAL,
    )

    count = 0
    indicators_dir = output_dir / "Indicators"

    for indicator_name, grid in INDICATOR_PIXELS_NORMAL.items():
        for brightness in ["bright", "dim"]:
            palette = INDICATOR_PALETTES[indicator_name][brightness]
            asset_name = f"indicator_{indicator_name}_{brightness}"
            img = render_grid_to_image(grid, palette, scale=scale)
            write_imageset(img, indicators_dir, asset_name)
            count += 1

    return count
```

### Output Count

6 types x 2 brightness levels = 12 image sets x 3 scales = 36 PNG files.

---

## 9. Export Pipeline: Portraits

### Naming Convention

For Pigdex preview portraits (pre-rendered with fixed seed):

```
portrait_{color}_{pattern}_{intensity}_{roan}
```

Examples:
- `portrait_black_solid_full_none`
- `portrait_golden_dutch_chinchilla_roan`
- `portrait_cream_dalmatian_himalayan_none`

### Export Logic

```python
def export_portraits(source_path: Path, output_dir: Path, portrait_scale: int) -> int:
    """Export representative portraits for all 144 phenotype combinations."""
    sys.path.insert(0, str(source_path))
    from big_pig_farm.data.sprite_engine import PALETTES
    from big_pig_farm.data.pig_portraits import generate_portrait

    count = 0
    portraits_dir = output_dir / "Portraits"

    colors = ["BLACK", "CHOCOLATE", "GOLDEN", "CREAM", "BLUE", "LILAC", "SAFFRON", "SMOKE"]
    patterns = ["solid", "dutch", "dalmatian"]
    intensities = ["full", "chinchilla", "himalayan"]
    roan_states = ["none", "roan"]

    for color in colors:
        palette = dict(PALETTES[color])
        if None in palette:
            del palette[None]

        for pattern in patterns:
            for intensity in intensities:
                for roan in roan_states:
                    # Use fixed seed for deterministic Pigdex previews
                    pig_id = f"pigdex_{color}_{pattern}_{intensity}_{roan}"
                    grid = generate_portrait(color, pattern, intensity, roan, pig_id)
                    asset_name = f"portrait_{color.lower()}_{pattern}_{intensity}_{roan}"
                    img = render_grid_to_image(grid, palette, scale=portrait_scale)
                    write_imageset(img, portraits_dir, asset_name)
                    count += 1

    return count
```

### Output Count

8 colors x 3 patterns x 3 intensities x 2 roan = 144 image sets x 3 scales = 432 PNG files.

### Runtime Portrait Generation

For individual pig detail views, portraits are generated at runtime in Swift (see Section 12 -- Pattern Renderer). The pre-rendered portraits are only used for the Pigdex grid and other UI contexts where a representative image suffices.

---

## 10. Export Pipeline: Terrain Tiles

### Naming Convention

```
terrain_{biome}_{tiletype}
```

Examples:
- `terrain_meadow_floor`
- `terrain_burrow_wall`
- `terrain_crystal_post`

### Tile Generation

Terrain tiles are not stored as pixel grids in the Python source -- they are procedurally generated from biome color arrays. The export tool creates small tile images:

```python
import random

def export_terrain_tiles(source_path: Path, output_dir: Path, tile_size: int = 8) -> int:
    """Export terrain tiles for each biome.

    Each tile is tile_size x tile_size art pixels with subtle color variation.
    Scale factor is applied uniformly (same as sprites).
    """
    sys.path.insert(0, str(source_path))
    from big_pig_farm.entities.biomes import BIOMES, BiomeType
    from big_pig_farm.data.sprites import WALL_PLANK, WALL_GRAIN, WALL_POST

    count = 0
    terrain_dir = output_dir / "Terrain"

    for biome_type, biome_info in BIOMES.items():
        biome_name = biome_type.value  # e.g., "meadow"

        # Floor tile: biome's floor_bg with subtle variation from floor_colors
        floor_img = Image.new("RGBA", (tile_size, tile_size), (0, 0, 0, 0))
        bg_rgba = hex_to_rgba(biome_info.floor_bg)
        rng = random.Random(f"terrain_{biome_name}_floor")
        for y in range(tile_size):
            for x in range(tile_size):
                if rng.random() < 0.15:
                    # Occasional floor color variation
                    var_color = rng.choice(biome_info.floor_colors)
                    floor_img.putpixel((x, y), hex_to_rgba(var_color))
                else:
                    floor_img.putpixel((x, y), bg_rgba)
        write_imageset(floor_img, terrain_dir, f"terrain_{biome_name}_floor")
        count += 1

        # Wall tile: plank colors with grain variation
        wall_planks = biome_info.wall_tint_plank or WALL_PLANK
        wall_grains = biome_info.wall_tint_grain or WALL_GRAIN
        wall_img = Image.new("RGBA", (tile_size, tile_size), (0, 0, 0, 0))
        rng = random.Random(f"terrain_{biome_name}_wall")
        for y in range(tile_size):
            plank_color = hex_to_rgba(rng.choice(wall_planks))
            for x in range(tile_size):
                if rng.random() < 0.1:
                    wall_img.putpixel((x, y), hex_to_rgba(rng.choice(wall_grains)))
                else:
                    wall_img.putpixel((x, y), plank_color)
        write_imageset(wall_img, terrain_dir, f"terrain_{biome_name}_wall")
        count += 1

        # Wall post tile: darker accent
        post_color = hex_to_rgba(WALL_POST)
        post_img = Image.new("RGBA", (tile_size, tile_size), post_color)
        write_imageset(post_img, terrain_dir, f"terrain_{biome_name}_post")
        count += 1

    return count
```

### Output Count

8 biomes x 3 tile types = 24 image sets x 3 scales = 72 PNG files.

---

## 11. Asset Catalog Organization

### Directory Structure

```
BigPigFarm/Resources/Assets.xcassets/
  Contents.json
  AppIcon.appiconset/
    Contents.json
  Sprites/
    Contents.json                          # Provides namespace
    Pigs/
      Contents.json                        # Provides namespace
      pig_adult_black_idle_right.imageset/
        Contents.json
        pig_adult_black_idle_right@1x.png
        pig_adult_black_idle_right@2x.png
        pig_adult_black_idle_right@3x.png
      pig_adult_black_walking_right_1.imageset/
        ...
      pig_baby_cream_sleeping_left_2.imageset/
        ...
    Facilities/
      Contents.json
      facility_food_bowl.imageset/
        ...
      facility_food_bowl_empty.imageset/
        ...
    Indicators/
      Contents.json
      indicator_health_bright.imageset/
        ...
      indicator_hunger_dim.imageset/
        ...
    Portraits/
      Contents.json
      portrait_black_solid_full_none.imageset/
        ...
    Terrain/
      Contents.json
      terrain_meadow_floor.imageset/
        ...
    Patterns/
      Contents.json
      pattern_dutch_mask.imageset/
        ...
```

### Namespace Configuration

Each folder's `Contents.json` enables the `provides-namespace` flag so asset names don't collide:

```json
{
  "info": { "author": "xcode", "version": 1 },
  "properties": { "provides-namespace": true }
}
```

This means textures are loaded with qualified names: `"Sprites/Pigs/pig_adult_black_idle_right"`.

### Texture Atlas Grouping

SpriteKit can batch draw calls for textures in the same atlas. Group related sprites into texture atlas folders (`.spriteatlas` instead of nested `.imageset` directories) for performance.

**Decision: Use individual image sets, not sprite atlases.** The rationale:

1. Xcode automatically packs image sets into optimized texture atlases at build time when the "Build Texture Atlas" build setting is enabled.
2. Sprite atlases require a different folder structure and are harder to organize with 500+ assets.
3. Individual image sets are simpler to generate from the export tool and easier to debug (each asset is a named folder).
4. The build-time packing produces the same GPU batching benefit as manual sprite atlases.

**Build setting:** Set `ASSETCATALOG_COMPILER_OPTIMIZATION = space` in `project.yml` to enable automatic atlas packing.

---

## 12. Runtime Pattern Overlay System

### Overview

ROADMAP Decision 6 states: "Pre-render 8 base colors, apply patterns at runtime." This section specifies how patterns (Dutch, Dalmatian), intensity modifiers (Chinchilla, Himalayan), and Roan are applied to base-color sprites at runtime.

### Approach: Alpha-Composited Pattern Masks

Each pattern is a grayscale mask image at the same resolution as the pig sprite. The mask defines which pixels should be replaced with the `"white"` color (from the palette). At runtime, the mask is composited over the base-color sprite using `CIFilter` or direct pixel manipulation.

This approach was chosen over `SKShader` because:
- Pattern masks are easier to author and debug than GLSL/Metal shaders
- The number of unique patterns is small (3 + 2 modifiers)
- Mask compositing can be done once when a pig is created, then cached as an `SKTexture`

### Pattern Mask Definitions

**Dutch pattern (adults, 14x8):**

The Dutch pattern adds white markings to the belly/face area. The mask is derived from the Python `_apply_dutch_markings()` function, which whitens:
- Forehead center columns (columns 3-10, rows 0-3)
- Chin/belly area (rows 5-7)

**Dalmatian pattern (adults, 14x8):**

Dalmatian spots are seeded by pig UUID. The mask is generated at runtime per pig (not pre-baked). The algorithm mirrors `_apply_dalmatian_spots()`:
1. Identify "inner fur" pixels (fur pixels with all 4 neighbors also fur/body pixels)
2. Select ~25% as spot centers using a seeded RNG (`pig.id` hashed)
3. Expand each center by 1-2 neighbors with 50% probability
4. Mark all selected pixels as white

**Chinchilla intensity (adults, 14x8):**

Chinchilla replaces every 3rd inner fur pixel with white (checkerboard pattern). Mirrors `_apply_chinchilla()`: `if (row + col) % 3 == 0 { pixel = white }`.

**Himalayan intensity (adults, 14x8):**

Himalayan lightens body fur to the belly color, keeping ears/nose colored. Mirrors `_apply_himalayan()`: all fur pixels except ears become the `belly` palette color.

**Roan (adults, 14x8):**

Roan scatters white hairs through inner fur pixels. 30% of eligible pixels become white, seeded by pig UUID + `"_roan"`. Mirrors `_apply_roan()`.

### Pattern Mask Assets

Pre-baked masks for deterministic patterns:

| Mask | Resolution | Description |
|------|-----------|-------------|
| `pattern_dutch_adult_mask` | 14x8 | White pixels where Dutch markings apply |
| `pattern_dutch_baby_mask` | 8x6 | White pixels where Dutch markings apply (baby) |
| `pattern_chinchilla_adult_mask` | 14x8 | White pixels at `(row+col) % 3 == 0` positions |
| `pattern_chinchilla_baby_mask` | 8x6 | Same for baby |
| `pattern_himalayan_adult_mask` | 14x8 | White pixels for all non-ear fur positions |
| `pattern_himalayan_baby_mask` | 8x6 | Same for baby |

Dalmatian and Roan masks are **not** pre-baked assets -- they are generated at runtime per pig using the pig's UUID as a seed.

**Total pattern mask PNGs:** 6 masks x 3 scales = 18 PNG files.

The export tool generates these masks from the Python pixel grid data by analyzing which pixels are `"fur"` and applying the pattern algorithm to produce a binary mask.

### Swift Pattern Renderer

**File:** `BigPigFarm/Scene/PatternRenderer.swift`

```swift
import UIKit
import SpriteKit

/// Applies phenotype patterns to base-color pig sprite textures.
///
/// Maps from: data/pig_portraits.py (pattern application functions)
enum PatternRenderer {

    /// Composite a pattern onto a base-color pig sprite texture.
    ///
    /// - Parameters:
    ///   - baseTexture: The solid-color pig sprite texture.
    ///   - pattern: The pig's pattern phenotype.
    ///   - intensity: The pig's color intensity phenotype.
    ///   - roan: The pig's roan phenotype.
    ///   - pigID: The pig's UUID for seeded randomness.
    ///   - whiteColor: The "white" color from the pig's palette.
    ///   - bellyColor: The "belly" color for Himalayan intensity.
    ///   - isBaby: Whether this is a baby pig.
    /// - Returns: A new texture with the pattern applied.
    static func applyPattern(
        baseTexture: SKTexture,
        pattern: Pattern,
        intensity: ColorIntensity,
        roan: RoanType,
        pigID: UUID,
        whiteColor: UIColor,
        bellyColor: UIColor,
        isBaby: Bool
    ) -> SKTexture {
        // TODO: Implement in Phase 2
        // 1. Convert baseTexture to CGImage
        // 2. Create a CGContext at the same size
        // 3. Draw the base image
        // 4. Apply pattern modifications by reading/writing pixels
        // 5. Return new SKTexture from the context
        return baseTexture
    }

    /// Generate a Dalmatian spot mask for a specific pig.
    ///
    /// - Parameters:
    ///   - pigID: UUID seed for deterministic spot placement.
    ///   - width: Sprite width in art pixels.
    ///   - height: Sprite height in art pixels.
    ///   - innerFurPixels: Set of (row, col) coordinates that are "inner fur."
    /// - Returns: Set of (row, col) positions that should be white.
    static func generateDalmatianSpots(
        pigID: UUID,
        width: Int,
        height: Int,
        innerFurPixels: Set<GridPosition>
    ) -> Set<GridPosition> {
        // TODO: Implement -- mirrors _apply_dalmatian_spots() from pig_portraits.py
        return []
    }

    /// Generate a Roan scatter mask for a specific pig.
    ///
    /// - Parameters:
    ///   - pigID: UUID seed for deterministic scatter.
    ///   - innerFurPixels: Set of eligible pixel positions.
    /// - Returns: Set of (row, col) positions that should be white.
    static func generateRoanScatter(
        pigID: UUID,
        innerFurPixels: Set<GridPosition>
    ) -> Set<GridPosition> {
        // TODO: Implement -- mirrors _apply_roan() from pig_portraits.py
        return []
    }
}
```

### Inner Fur Pixel Maps

The pattern system needs to know which pixels in a sprite are "inner fur" (surrounded by other body pixels on all 4 sides). The export tool generates these maps alongside the sprites.

**File:** `BigPigFarm/Scene/SpriteFurMaps.swift`

This file contains `Set<GridPosition>` constants for each sprite size:

```swift
/// Pixel coordinate maps for pattern application.
///
/// Maps from: data/pig_portraits.py (_FUR_PIXELS, _INNER_FUR_PIXELS analysis)
enum SpriteFurMaps {

    /// Inner fur pixels for adult pig sprites (14x8).
    /// These are fur-keyed pixels where all 4 neighbors are also body pixels.
    static let adultInnerFur: Set<GridPosition> = [
        // Generated by the export tool from PIG_PIXELS_ADULT["idle_right"]
        // TODO: Populate during Phase 2 export
    ]

    /// Inner fur pixels for baby pig sprites (8x6).
    static let babyInnerFur: Set<GridPosition> = [
        // TODO: Populate during Phase 2 export
    ]

    /// All fur pixels for adult pig sprites (14x8).
    /// Used by Himalayan intensity (all fur except ears).
    static let adultAllFur: Set<GridPosition> = [
        // TODO: Populate during Phase 2 export
    ]

    /// All fur pixels for baby pig sprites (8x6).
    static let babyAllFur: Set<GridPosition> = [
        // TODO: Populate during Phase 2 export
    ]

    /// Ear pixels for adult pig sprites (14x8).
    /// Excluded from Himalayan intensity lightening.
    static let adultEarPixels: Set<GridPosition> = [
        // TODO: Populate during Phase 2 export
    ]

    /// Ear pixels for baby pig sprites (8x6).
    static let babyEarPixels: Set<GridPosition> = [
        // TODO: Populate during Phase 2 export
    ]
}
```

The export tool analyzes `PIG_PIXELS_ADULT["idle_right"]` to identify which pixels are fur, inner fur, ears, etc., and outputs a Swift file with these coordinate sets.

### Pattern Application Order

Patterns are layered in the same order as the Python source (`generate_portrait()`):

1. **Pattern** (Dutch or Dalmatian) -- replaces fur pixels with white
2. **Intensity** (Chinchilla or Himalayan) -- modifies fur/body pixels
3. **Roan** -- scatters white into remaining fur pixels

If `pattern == .solid` and `intensity == .full` and `roan == .none`, no pattern processing is needed -- the base-color texture is used directly. This is the common case and should be fast-pathed.

### Texture Caching

Pattern-modified textures are cached in a dictionary keyed by `(baseColor, pattern, intensity, roan, pigID)`. The cache is bounded by pig count (typically 50-100 pigs). Cache entries are evicted when a pig is sold or dies.

```swift
/// Cache for pattern-composited pig textures.
///
/// Keyed by pig UUID since Dalmatian/Roan patterns are pig-specific.
/// Non-patterned pigs (solid/full/none) share textures by base color.
final class SpriteTextureCache: @unchecked Sendable {

    private var cache: [UUID: [String: SKTexture]] = [:]
    private var solidCache: [String: SKTexture] = [:]

    /// Get or create a cached texture for a pig sprite frame.
    func texture(
        for pig: GuineaPig,
        state: String,
        direction: String,
        frame: Int
    ) -> SKTexture {
        // TODO: Implement -- check cache, apply pattern if miss, store and return
        fatalError("Not implemented")
    }

    /// Remove cached textures for a pig that no longer exists.
    func evict(pigID: UUID) {
        cache.removeValue(forKey: pigID)
    }
}
```

### Investigation Item: SKShader vs Alpha Compositing

The CHECKLIST lists "Determine `SKShader` vs alpha compositing for pattern overlays" as an open investigation item. This spec recommends alpha compositing via `CGContext` pixel manipulation as the primary approach, with `SKShader` as a fallback if compositing proves too slow.

**Rationale for CGContext compositing:**
- Patterns are applied once per pig (at creation/phenotype change), not every frame
- The result is cached as a standard `SKTexture` -- zero per-frame GPU cost
- CGContext pixel manipulation is well-documented and straightforward
- No shader compilation or Metal compatibility concerns

**When SKShader might be better:**
- If pig sprites change frequently (they do not -- phenotype is fixed at birth)
- If the game needs animated pattern effects (it does not)
- If CGContext operations prove to be a bottleneck on older devices (unlikely for 14x8 images)

**Recommendation:** Proceed with CGContext compositing. Close the investigation item unless profiling reveals issues during Phase 3.

---

## 13. Swift Loading API

### SpriteAssets Namespace

**File:** `BigPigFarm/Scene/SpriteAssets.swift`

```swift
import SpriteKit

/// Centralized sprite asset loading and lookup.
///
/// Maps from: data/sprites.py (get_pig_halfblock_sprite, get_facility_halfblock_sprite)
///
/// All texture names follow the conventions defined in Spec 03 Section 6-10.
/// Textures are loaded from the asset catalog by qualified name.
enum SpriteAssets {

    // MARK: - Constants

    /// Points per art pixel at @1x scale. Each pixel in the source art
    /// maps to a 4x4 point block in SpriteKit.
    static let pointsPerArtPixel: CGFloat = 4.0

    /// Adult pig sprite dimensions in art pixels.
    static let adultSpriteSize = CGSize(width: 14, height: 8)

    /// Baby pig sprite dimensions in art pixels.
    static let babySpriteSize = CGSize(width: 8, height: 6)

    // MARK: - Pig Sprites

    /// Load a pig sprite texture by phenotype and animation state.
    ///
    /// - Parameters:
    ///   - baseColor: The pig's base color (e.g., .black, .golden).
    ///   - state: Display state name (idle, walking, eating, sleeping, happy, sad).
    ///   - direction: Facing direction (left, right).
    ///   - isBaby: Whether this is a baby pig.
    ///   - frame: Animation frame (1-indexed). Omit for single-frame states.
    /// - Returns: The loaded SKTexture with nearest-neighbor filtering.
    static func pigTexture(
        baseColor: BaseColor,
        state: String,
        direction: String,
        isBaby: Bool,
        frame: Int? = nil
    ) -> SKTexture {
        let age = isBaby ? "baby" : "adult"
        let color = baseColor.rawValue  // e.g., "black"
        var name = "Sprites/Pigs/pig_\(age)_\(color)_\(state)_\(direction)"
        if let frame {
            name += "_\(frame)"
        }
        let texture = SKTexture(imageNamed: name)
        texture.filteringMode = .nearest
        return texture
    }

    /// Load all animation frames for a pig state as an ordered array.
    ///
    /// - Parameters:
    ///   - baseColor: The pig's base color.
    ///   - state: Display state name.
    ///   - direction: Facing direction.
    ///   - isBaby: Whether this is a baby pig.
    /// - Returns: Array of textures for animation. Single-frame states return [1 texture].
    static func pigAnimationFrames(
        baseColor: BaseColor,
        state: String,
        direction: String,
        isBaby: Bool
    ) -> [SKTexture] {
        let frameCount = AnimationData.frameCount(for: state)

        if frameCount <= 1 {
            // Single-frame state (idle, sad) -- no frame suffix
            return [pigTexture(
                baseColor: baseColor,
                state: state,
                direction: direction,
                isBaby: isBaby
            )]
        }

        return (1...frameCount).map { frame in
            pigTexture(
                baseColor: baseColor,
                state: state,
                direction: direction,
                isBaby: isBaby,
                frame: frame
            )
        }
    }

    // MARK: - Facility Sprites

    /// Load a facility sprite texture.
    ///
    /// - Parameters:
    ///   - facilityType: The facility type value string (e.g., "food_bowl").
    ///   - state: Optional state variant ("empty", "full"). Pass nil for default.
    /// - Returns: The loaded SKTexture with nearest-neighbor filtering.
    static func facilityTexture(
        facilityType: String,
        state: String? = nil
    ) -> SKTexture {
        var name = "Sprites/Facilities/facility_\(facilityType)"
        if let state {
            name += "_\(state)"
        }
        let texture = SKTexture(imageNamed: name)
        texture.filteringMode = .nearest
        return texture
    }

    // MARK: - Indicator Sprites

    /// Load an indicator sprite texture.
    ///
    /// - Parameters:
    ///   - indicatorType: The indicator name (health, hunger, thirst, energy, courting, pregnant).
    ///   - bright: True for bright pulse frame, false for dim.
    /// - Returns: The loaded SKTexture with nearest-neighbor filtering.
    static func indicatorTexture(
        indicatorType: String,
        bright: Bool
    ) -> SKTexture {
        let brightness = bright ? "bright" : "dim"
        let name = "Sprites/Indicators/indicator_\(indicatorType)_\(brightness)"
        let texture = SKTexture(imageNamed: name)
        texture.filteringMode = .nearest
        return texture
    }

    // MARK: - Portrait Sprites

    /// Load a pre-rendered Pigdex portrait texture.
    ///
    /// - Parameters:
    ///   - baseColor: The pig's base color.
    ///   - pattern: The pig's pattern (solid, dutch, dalmatian).
    ///   - intensity: The pig's color intensity (full, chinchilla, himalayan).
    ///   - roan: The pig's roan type (none, roan).
    /// - Returns: The loaded SKTexture.
    static func portraitTexture(
        baseColor: BaseColor,
        pattern: Pattern,
        intensity: ColorIntensity,
        roan: RoanType
    ) -> SKTexture {
        let color = baseColor.rawValue
        let pat = pattern.rawValue
        let int_ = intensity.rawValue
        let roanStr = roan.rawValue
        let name = "Sprites/Portraits/portrait_\(color)_\(pat)_\(int_)_\(roanStr)"
        let texture = SKTexture(imageNamed: name)
        texture.filteringMode = .nearest
        return texture
    }

    // MARK: - Terrain Tiles

    /// Load a terrain tile texture for SKTileMapNode.
    ///
    /// - Parameters:
    ///   - biome: The biome type value string (e.g., "meadow").
    ///   - tileType: The tile type ("floor", "wall", "post").
    /// - Returns: The loaded SKTexture with nearest-neighbor filtering.
    static func terrainTexture(
        biome: String,
        tileType: String
    ) -> SKTexture {
        let name = "Sprites/Terrain/terrain_\(biome)_\(tileType)"
        let texture = SKTexture(imageNamed: name)
        texture.filteringMode = .nearest
        return texture
    }
}
```

### Texture Filtering

All sprites use `SKTexture.filteringMode = .nearest` (nearest-neighbor) to preserve sharp pixel edges. This is critical for pixel art -- linear filtering would blur the pixels.

---

## 14. Animation Data

### Source Constants

From `data/sprite_engine.py`:

```python
ANIM_TICKS_PER_FRAME: dict[str, int] = {
    "walking": 3,
    "eating": 4,
    "happy": 3,
    "sleeping": 10,
}

ANIM_FRAME_COUNT: dict[str, int] = {
    "walking": 3,
    "eating": 2,
    "happy": 2,
    "sleeping": 2,
}
```

States not listed in `ANIM_TICKS_PER_FRAME` are static (idle, sad). States not listed in `ANIM_FRAME_COUNT` default to 2 frames.

### Swift Translation

**File:** `BigPigFarm/Scene/AnimationData.swift`

```swift
/// Animation timing and frame count data for pig sprite animations.
///
/// Maps from: data/sprite_engine.py (ANIM_TICKS_PER_FRAME, ANIM_FRAME_COUNT)
enum AnimationData {

    /// Number of simulation ticks each animation frame is displayed before advancing.
    /// States not listed are static (no animation).
    static let ticksPerFrame: [String: Int] = [
        "walking": 3,
        "eating": 4,
        "happy": 3,
        "sleeping": 10,
    ]

    /// Number of animation frames per state.
    /// States not listed here are static (1 frame, no animation).
    static let frameCounts: [String: Int] = [
        "walking": 3,
        "eating": 2,
        "happy": 2,
        "sleeping": 2,
    ]

    /// Returns the number of animation frames for a given state.
    /// Static states (idle, sad) return 1.
    static func frameCount(for state: String) -> Int {
        frameCounts[state] ?? 1
    }

    /// Returns the ticks-per-frame for a given state.
    /// Returns nil for static states (no animation cycling needed).
    static func ticksPerFrame(for state: String) -> Int? {
        ticksPerFrame[state]
    }

    /// Returns the total duration in ticks for one full animation cycle.
    /// Returns nil for static states.
    static func cycleDuration(for state: String) -> Int? {
        guard let tpf = ticksPerFrame[state],
              let fc = frameCounts[state] else { return nil }
        return tpf * fc
    }

    /// All animated states (those with frame cycling).
    static let animatedStates: Set<String> = Set(ticksPerFrame.keys)

    /// All static states (single frame, no cycling).
    static let staticStates: Set<String> = ["idle", "sad"]
}
```

### Animation State Coverage by Age

Not all animation states exist for baby pigs:

| State | Adult | Baby |
|-------|-------|------|
| idle | yes | yes |
| walking | yes (3 frames) | yes (3 frames) |
| eating | yes (2 frames) | no -- falls back to idle |
| sleeping | yes (2 frames) | yes (2 frames) |
| happy | yes (2 frames) | no -- falls back to idle |
| sad | yes (1 frame) | no -- falls back to idle |

The `SpriteAssets.pigTexture()` function returns the requested texture by name. If a baby pig is requested in a state it doesn't have (e.g., `pig_baby_black_eating_right_1`), the texture will not be found in the asset catalog. The calling code (in `PigNode`, Doc 06) must handle this fallback:

```swift
// In PigNode (Doc 06), when updating sprite:
let state = isBaby ? AnimationData.babyFallbackState(for: behaviorState) : behaviorState

// In AnimationData:
/// Returns the display state for a baby pig, falling back to idle
/// for states that babies don't have sprites for.
static func babyFallbackState(for state: String) -> String {
    switch state {
    case "eating", "happy", "sad":
        return "idle"
    default:
        return state
    }
}
```

---

## 15. Pig Palette Data

The 8 color palettes from `sprite_engine.py` need to be available at runtime for the pattern compositing system (which needs the `"white"` and `"belly"` hex colors). These values are also useful for UI tinting.

**File:** This data should be added to the existing `Config/GameConfig.swift` (or a new `Config/PigPalettes.swift` if `GameConfig.swift` exceeds 300 lines).

```swift
/// Color palette data for each base coat color.
///
/// Maps from: data/sprite_engine.py (PALETTES dictionary)
///
/// Used by PatternRenderer to look up "white" and "belly" colors
/// when compositing patterns onto base-color sprites.
enum PigPalettes {

    /// Palette key names used in pig sprite pixel grids.
    enum Key: String, CaseIterable, Sendable {
        case fur, shade, dark, belly, pupil, eye, nose, ear, paw, tooth, white, blush, tear
    }

    /// Hex color values for each palette key, keyed by BaseColor.
    static let palettes: [BaseColor: [Key: String]] = [
        .black: [
            .fur: "#444444", .shade: "#3a3a3a", .dark: "#262626",
            .belly: "#585858", .pupil: "#121212", .eye: "#ffffff",
            .nose: "#808080", .ear: "#4e4e4e", .paw: "#303030",
            .tooth: "#c0c0c0", .white: "#d0d0d0", .blush: "#d75f5f",
            .tear: "#05bce1",
        ],
        .chocolate: [
            .fur: "#875f00", .shade: "#8b4a00", .dark: "#870000",
            .belly: "#ffaf5f", .pupil: "#121212", .eye: "#ffffff",
            .nose: "#af8787", .ear: "#d75f5f", .paw: "#d75f00",
            .tooth: "#c0c0c0", .white: "#d0d0d0", .blush: "#ff8787",
            .tear: "#05bce1",
        ],
        .golden: [
            .fur: "#ffd700", .shade: "#d4a800", .dark: "#af8700",
            .belly: "#ffff5f", .pupil: "#121212", .eye: "#ffffff",
            .nose: "#d7af87", .ear: "#d7af00", .paw: "#af8700",
            .tooth: "#c0c0c0", .white: "#d0d0d0", .blush: "#ff8787",
            .tear: "#05bce1",
        ],
        .cream: [
            .fur: "#ffffaf", .shade: "#e6d0a8", .dark: "#d7af87",
            .belly: "#ffffd7", .pupil: "#121212", .eye: "#ffffff",
            .nose: "#ffd7d7", .ear: "#ffd7af", .paw: "#d7af87",
            .tooth: "#c0c0c0", .white: "#d0d0d0", .blush: "#ff5fd7",
            .tear: "#05bce1",
        ],
        .blue: [
            .fur: "#5fd7ff", .shade: "#5a7a9a", .dark: "#3a5a7a",
            .belly: "#afafff", .pupil: "#121212", .eye: "#ffffff",
            .nose: "#8a9aaa", .ear: "#6a8aaa", .paw: "#4a6a8a",
            .tooth: "#c0c0c0", .white: "#d0d0d0", .blush: "#d75f5f",
            .tear: "#05bce1",
        ],
        .lilac: [
            .fur: "#ffafff", .shade: "#b888c8", .dark: "#8a60a0",
            .belly: "#e8c8f8", .pupil: "#121212", .eye: "#ffffff",
            .nose: "#c8a8d8", .ear: "#b090c0", .paw: "#9070a8",
            .tooth: "#c0c0c0", .white: "#d0d0d0", .blush: "#ff5fd7",
            .tear: "#117d92",
        ],
        .saffron: [
            .fur: "#ff8700", .shade: "#c87830", .dark: "#a06020",
            .belly: "#e8a050", .pupil: "#121212", .eye: "#ffffff",
            .nose: "#d09060", .ear: "#c08040", .paw: "#b07838",
            .tooth: "#c0c0c0", .white: "#d0d0d0", .blush: "#ff8787",
            .tear: "#05bce1",
        ],
        .smoke: [
            .fur: "#9e9e9e", .shade: "#787878", .dark: "#606060",
            .belly: "#a0a0a0", .pupil: "#121212", .eye: "#ffffff",
            .nose: "#988890", .ear: "#908088", .paw: "#808080",
            .tooth: "#c0c0c0", .white: "#d0d0d0", .blush: "#ff5fd7",
            .tear: "#05bce1",
        ],
    ]

    /// Get a UIColor for a specific palette key and base color.
    static func color(for key: Key, baseColor: BaseColor) -> UIColor {
        guard let hex = palettes[baseColor]?[key] else {
            return .magenta  // Visible fallback for missing palette entries
        }
        return UIColor(hex: hex)
    }
}
```

**Note:** The `UIColor(hex:)` initializer is not built-in. Add a small extension:

```swift
extension UIColor {
    /// Initialize from a hex color string like "#FF8800".
    convenience init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
```

---

## 16. Validation and Testing

### Export Validation

The export tool performs self-validation after each category:

```python
def validate_export(output_dir: Path, expected_counts: dict[str, int]) -> bool:
    """Validate that the expected number of image sets were created."""
    all_ok = True
    for category, expected in expected_counts.items():
        category_dir = output_dir / category
        if not category_dir.exists():
            print(f"  FAIL: {category}/ directory missing")
            all_ok = False
            continue
        actual = sum(1 for d in category_dir.iterdir() if d.suffix == ".imageset")
        if actual != expected:
            print(f"  FAIL: {category}/ has {actual} image sets, expected {expected}")
            all_ok = False
        else:
            print(f"  OK: {category}/ has {actual} image sets")
    return all_ok
```

Expected counts:

```python
EXPECTED_COUNTS = {
    "Pigs": 272,         # 8 colors x (22 adult + 12 baby)
    "Facilities": 25,    # 17 types + 8 state variants
    "Indicators": 12,    # 6 types x 2 brightness
    "Portraits": 144,    # 8 colors x 3 patterns x 3 intensities x 2 roan
    "Terrain": 24,       # 8 biomes x 3 tile types
    "Patterns": 6,       # 3 pattern types x 2 ages
}
```

### Swift Integration Test

**File:** `BigPigFarmTests/SpriteAssetTests.swift`

```swift
import Testing
import SpriteKit
@testable import BigPigFarm

/// Verify all sprite assets load correctly from the asset catalog.
///
/// These tests will fail if any expected PNG is missing from Assets.xcassets.
struct SpriteAssetTests {

    @Test("All adult pig sprite textures load for every base color")
    func adultPigTexturesLoad() {
        let states = [
            ("idle", "right", nil), ("idle", "left", nil),
            ("walking", "right", 1), ("walking", "right", 2), ("walking", "right", 3),
            ("walking", "left", 1), ("walking", "left", 2), ("walking", "left", 3),
            ("eating", "right", 1), ("eating", "right", 2),
            ("eating", "left", 1), ("eating", "left", 2),
            ("sleeping", "right", 1), ("sleeping", "right", 2),
            ("sleeping", "left", 1), ("sleeping", "left", 2),
            ("happy", "right", 1), ("happy", "right", 2),
            ("happy", "left", 1), ("happy", "left", 2),
            ("sad", "right", nil), ("sad", "left", nil),
        ]

        for color in BaseColor.allCases {
            for (state, direction, frame) in states {
                let texture = SpriteAssets.pigTexture(
                    baseColor: color,
                    state: state,
                    direction: direction,
                    isBaby: false,
                    frame: frame
                )
                #expect(texture.size().width > 0,
                    "Missing texture: adult \(color.rawValue) \(state)_\(direction)_\(frame ?? 0)")
            }
        }
    }

    @Test("All baby pig sprite textures load for every base color")
    func babyPigTexturesLoad() {
        let states: [(String, String, Int?)] = [
            ("idle", "right", nil), ("idle", "left", nil),
            ("walking", "right", 1), ("walking", "right", 2), ("walking", "right", 3),
            ("walking", "left", 1), ("walking", "left", 2), ("walking", "left", 3),
            ("sleeping", "right", 1), ("sleeping", "right", 2),
            ("sleeping", "left", 1), ("sleeping", "left", 2),
        ]

        for color in BaseColor.allCases {
            for (state, direction, frame) in states {
                let texture = SpriteAssets.pigTexture(
                    baseColor: color,
                    state: state,
                    direction: direction,
                    isBaby: true,
                    frame: frame
                )
                #expect(texture.size().width > 0,
                    "Missing texture: baby \(color.rawValue) \(state)_\(direction)_\(frame ?? 0)")
            }
        }
    }

    @Test("All facility sprite textures load")
    func facilityTexturesLoad() {
        let types = [
            "food_bowl", "water_bottle", "hay_rack", "hideout",
            "exercise_wheel", "tunnel", "play_area", "breeding_den",
            "nursery", "veggie_garden", "grooming_station", "genetics_lab",
            "feast_table", "campfire", "therapy_garden", "hot_spring", "stage",
        ]
        for type_ in types {
            let texture = SpriteAssets.facilityTexture(facilityType: type_)
            #expect(texture.size().width > 0, "Missing facility texture: \(type_)")
        }

        // State variants for consumable facilities
        for type_ in ["food_bowl", "water_bottle", "hay_rack", "feast_table"] {
            for state in ["empty", "full"] {
                let texture = SpriteAssets.facilityTexture(facilityType: type_, state: state)
                #expect(texture.size().width > 0,
                    "Missing facility texture: \(type_)_\(state)")
            }
        }
    }

    @Test("All indicator sprite textures load")
    func indicatorTexturesLoad() {
        let types = ["health", "hunger", "thirst", "energy", "courting", "pregnant"]
        for type_ in types {
            for bright in [true, false] {
                let texture = SpriteAssets.indicatorTexture(
                    indicatorType: type_,
                    bright: bright
                )
                #expect(texture.size().width > 0,
                    "Missing indicator texture: \(type_)_\(bright ? "bright" : "dim")")
            }
        }
    }

    @Test("Animation data is consistent with sprite inventory")
    func animationDataConsistency() {
        // Walking has 3 frames
        #expect(AnimationData.frameCount(for: "walking") == 3)
        #expect(AnimationData.ticksPerFrame(for: "walking") == 3)
        #expect(AnimationData.cycleDuration(for: "walking") == 9)

        // Eating has 2 frames
        #expect(AnimationData.frameCount(for: "eating") == 2)
        #expect(AnimationData.ticksPerFrame(for: "eating") == 4)

        // Sleeping has 2 frames
        #expect(AnimationData.frameCount(for: "sleeping") == 2)
        #expect(AnimationData.ticksPerFrame(for: "sleeping") == 10)

        // Happy has 2 frames
        #expect(AnimationData.frameCount(for: "happy") == 2)
        #expect(AnimationData.ticksPerFrame(for: "happy") == 3)

        // Idle is static
        #expect(AnimationData.frameCount(for: "idle") == 1)
        #expect(AnimationData.ticksPerFrame(for: "idle") == nil)

        // Sad is static
        #expect(AnimationData.frameCount(for: "sad") == 1)
        #expect(AnimationData.ticksPerFrame(for: "sad") == nil)
    }
}
```

---

## 17. Files Created / Modified

### New Files

| File | Purpose |
|------|---------|
| `tools/export_sprites.py` | Python CLI tool to export all sprites as PNGs |
| `BigPigFarm/Scene/SpriteAssets.swift` | Swift texture loading API |
| `BigPigFarm/Scene/PatternRenderer.swift` | Runtime pattern compositing |
| `BigPigFarm/Scene/AnimationData.swift` | Animation frame counts and timing |
| `BigPigFarm/Scene/SpriteFurMaps.swift` | Pixel coordinate maps for pattern targeting |
| `BigPigFarm/Config/PigPalettes.swift` | Color palette data for all 8 base colors |
| `BigPigFarmTests/SpriteAssetTests.swift` | Integration test for asset loading |
| `Assets.xcassets/Sprites/` (nested dirs) | All exported PNG image sets |

### Modified Files

| File | Change |
|------|--------|
| `project.yml` | Add `ASSETCATALOG_COMPILER_OPTIMIZATION = space` build setting; add new Swift source files |
| `docs/CHECKLIST.md` | Check off "03 -- Sprite Pipeline" spec |

### Files Not Created (Deferred to Other Specs)

| File | Reason |
|------|--------|
| `BigPigFarm/Scene/PigNode.swift` | Existing stub; implementation specified in Doc 06 |
| `BigPigFarm/Scene/FacilityNode.swift` | Existing stub; implementation specified in Doc 06 |
| `BigPigFarm/Scene/FarmScene.swift` | Existing stub; implementation specified in Doc 06 |
| `BigPigFarm/Scene/CameraController.swift` | Existing stub; implementation specified in Doc 06 |

---

## 18. Open Questions and Decision Tracking

### Resolved Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Zoom levels to export | Normal only | SpriteKit camera handles zoom natively (ROADMAP note) |
| Color variant strategy | Pre-render 8 base colors | ROADMAP Decision 6 |
| Pattern application method | CGContext alpha compositing | Applied once at pig creation, cached; no per-frame cost |
| Asset organization | Individual image sets | Xcode auto-packs into atlases at build time |
| Portrait strategy | Pre-render 144 + runtime for individuals | Balances asset size vs visual variety |
| Texture filtering | `.nearest` on all sprites | Required for pixel art sharpness |
| Export tool location | `tools/export_sprites.py` in mobile repo | iOS pipeline is self-contained |
| Export scale factor | 4 points per art pixel at @1x | Tunable; produces visible pixel art on all devices |

### Investigation Items (Carry Forward)

| Item | Status | Notes |
|------|--------|-------|
| `SKShader` vs alpha compositing for patterns | Recommended: alpha compositing | Close unless CGContext proves slow in Phase 3 profiling |
| `PIXELS_PER_ART_PIXEL` tuning | Awaiting Phase 3 | May need adjustment once sprites are visible in-scene |
| Portrait scale factor tuning | Awaiting Phase 4 | May need adjustment once portrait views are built |

---

## Appendix A: Complete Sprite Key Reference

### Adult Pig Sprite Keys (22 total)

```
idle_right, idle_left
walking_right_1, walking_right_2, walking_right_3
walking_left_1, walking_left_2, walking_left_3
eating_right_1, eating_right_2
eating_left_1, eating_left_2
sleeping_right_1, sleeping_right_2
sleeping_left_1, sleeping_left_2
happy_right_1, happy_right_2
happy_left_1, happy_left_2
sad_right, sad_left
```

### Baby Pig Sprite Keys (12 total)

```
idle_right, idle_left
walking_right_1, walking_right_2, walking_right_3
walking_left_1, walking_left_2, walking_left_3
sleeping_right_1, sleeping_right_2
sleeping_left_1, sleeping_left_2
```

### Facility Sprite Keys (25 total)

```
food_bowl, food_bowl_empty, food_bowl_full
water_bottle, water_bottle_empty, water_bottle_full
hay_rack, hay_rack_empty, hay_rack_full
hideout
exercise_wheel
tunnel
play_area
breeding_den
nursery
veggie_garden
grooming_station
genetics_lab
feast_table, feast_table_empty, feast_table_full
campfire
therapy_garden
hot_spring
stage
```

### Indicator Sprite Keys (12 total)

```
health_bright, health_dim
hunger_bright, hunger_dim
thirst_bright, thirst_dim
energy_bright, energy_dim
courting_bright, courting_dim
pregnant_bright, pregnant_dim
```

### Base Color Names (8 total)

```
black, chocolate, golden, cream, blue, lilac, saffron, smoke
```
