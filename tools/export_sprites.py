#!/usr/bin/env python3
"""Export Big Pig Farm sprites from pixel data to PNG image sets.

Usage:
    python tools/export_sprites.py \\
        --output BigPigFarm/Resources/Assets.xcassets/Sprites \\
        [--source ../big-pig-farm] \\
        [--scale 4] \\
        [--portrait-scale 8] \\
        [--category {all,pigs,facilities,indicators,portraits,terrain,patterns}]

Reads sprite pixel data from tools/sprite-editor/sprite-data.json (pigs,
facilities, indicators, patterns) and optionally from the Python game repo
(portraits, terrain — these use algorithmic generation not in the JSON).

Requires: Pillow (pip install Pillow)
"""

import argparse
import json
import random
import sys
from pathlib import Path

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parent.parent
SPRITE_DATA_FILE = REPO_ROOT / "tools" / "sprite-editor" / "sprite-data.json"


# ---------------------------------------------------------------------------
# Sprite data loading from JSON
# ---------------------------------------------------------------------------

def load_sprite_data() -> dict:
    """Load and prepare sprite data from sprite-data.json.

    Returns a dict with keys:
        pig_palettes: {COLOR_NAME: {key: hex, ...}, ...}
        pig_adult_sprites: {sprite_key: pixel_grid, ...}  (with left variants)
        pig_baby_sprites: {sprite_key: pixel_grid, ...}  (with left variants)
        facility_palettes: {facility_type: {key: hex, ...}, ...}
        facility_sprites: {sprite_key: pixel_grid, ...}
        indicator_palettes: {name: {"bright": {...}, "dim": {...}}, ...}
        indicator_sprites: {indicator_name: pixel_grid, ...}
        pig_adult_idle_right: pixel_grid  (for pattern masks)
        pig_baby_idle_right: pixel_grid   (for pattern masks)
    """
    if not SPRITE_DATA_FILE.exists():
        raise FileNotFoundError(
            f"Sprite data not found: {SPRITE_DATA_FILE}\n"
            "Run the sprite data seed step first."
        )

    with open(SPRITE_DATA_FILE) as f:
        data = json.load(f)

    pig_palettes = {}
    for color_name, palette in data["palettes"]["pig"].items():
        pig_palettes[color_name] = {k: v for k, v in palette.items() if k != "T"}

    pig_adult_sprites = {k: v["pixels"] for k, v in data["sprites"]["pig_adult"].items()}
    pig_baby_sprites = {k: v["pixels"] for k, v in data["sprites"]["pig_baby"].items()}

    facility_palettes = data["palettes"]["facility"]
    facility_sprites = {k: v["pixels"] for k, v in data["sprites"]["facility_normal"].items()}

    indicator_palettes = data["palettes"]["indicator"]
    indicator_sprites = {k: v["pixels"] for k, v in data["sprites"]["indicator_normal"].items()}

    pig_adult_idle = data["sprites"]["pig_adult"]["idle_right"]["pixels"]
    pig_baby_idle = data["sprites"]["pig_baby"]["idle_right"]["pixels"]

    return {
        "pig_palettes": pig_palettes,
        "pig_adult_sprites": pig_adult_sprites,
        "pig_baby_sprites": pig_baby_sprites,
        "facility_palettes": facility_palettes,
        "facility_sprites": facility_sprites,
        "indicator_palettes": indicator_palettes,
        "indicator_sprites": indicator_sprites,
        "pig_adult_idle_right": pig_adult_idle,
        "pig_baby_idle_right": pig_baby_idle,
    }


# ---------------------------------------------------------------------------
# Core helpers
# ---------------------------------------------------------------------------

def hex_to_rgba(hex_color: str | None) -> tuple[int, int, int, int]:
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
        Pillow Image in RGBA mode, scaled by `scale`.
    """
    height = len(grid)
    width = max((len(row) for row in grid), default=0)

    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for y, row in enumerate(grid):
        for x, key in enumerate(row):
            if key is None:
                continue
            color_hex = palette.get(key)
            if color_hex is None:
                color_hex = key
            img.putpixel((x, y), hex_to_rgba(color_hex))

    if scale > 1:
        img = img.resize(
            (width * scale, height * scale),
            resample=Image.NEAREST,
        )

    return img


def write_imageset(img_1x: Image.Image, output_dir: Path, name: str) -> None:
    """Write an Xcode image set with @1x, @2x, @3x variants."""
    imageset_dir = output_dir / f"{name}.imageset"
    imageset_dir.mkdir(parents=True, exist_ok=True)

    w1, h1 = img_1x.size

    img_1x.save(imageset_dir / f"{name}@1x.png")

    img_2x = img_1x.resize((w1 * 2, h1 * 2), resample=Image.NEAREST)
    img_2x.save(imageset_dir / f"{name}@2x.png")

    img_3x = img_1x.resize((w1 * 3, h1 * 3), resample=Image.NEAREST)
    img_3x.save(imageset_dir / f"{name}@3x.png")

    contents = {
        "images": [
            {"filename": f"{name}@1x.png", "idiom": "universal", "scale": "1x"},
            {"filename": f"{name}@2x.png", "idiom": "universal", "scale": "2x"},
            {"filename": f"{name}@3x.png", "idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": False},
    }
    with open(imageset_dir / "Contents.json", "w") as f:
        json.dump(contents, f, indent=2)


def write_namespace_contents_json(directory: Path) -> None:
    """Write a namespace Contents.json so Xcode provides-namespace for the folder."""
    directory.mkdir(parents=True, exist_ok=True)
    contents = {
        "info": {"author": "xcode", "version": 1},
        "properties": {"provides-namespace": True},
    }
    with open(directory / "Contents.json", "w") as f:
        json.dump(contents, f, indent=2)


# ---------------------------------------------------------------------------
# Export functions — JSON-backed (no Python repo needed)
# ---------------------------------------------------------------------------

def export_pig_sprites(sprite_data: dict, output_dir: Path, scale: int) -> int:
    """Export all pig sprites as PNG image sets."""
    pigs_dir = output_dir / "Pigs"
    write_namespace_contents_json(pigs_dir)
    count = 0

    for color_name, palette in sprite_data["pig_palettes"].items():
        for age_label, sprites in [
            ("adult", sprite_data["pig_adult_sprites"]),
            ("baby", sprite_data["pig_baby_sprites"]),
        ]:
            for sprite_key, grid in sprites.items():
                asset_name = f"pig_{age_label}_{color_name.lower()}_{sprite_key}"
                img = render_grid_to_image(grid, palette, scale=scale)
                write_imageset(img, pigs_dir, asset_name)
                count += 1

    return count


def export_facility_sprites(sprite_data: dict, output_dir: Path, scale: int) -> int:
    """Export all facility sprites as PNG image sets."""
    facilities_dir = output_dir / "Facilities"
    write_namespace_contents_json(facilities_dir)
    count = 0

    for sprite_key, grid in sprite_data["facility_sprites"].items():
        base_type = sprite_key
        for suffix in ("_empty", "_full"):
            if sprite_key.endswith(suffix):
                base_type = sprite_key[: -len(suffix)]
                break

        palette = sprite_data["facility_palettes"].get(base_type)
        if palette is None:
            raise ValueError(
                f"No palette for facility type '{base_type}' "
                f"(from sprite key '{sprite_key}'). "
                f"Available: {sorted(sprite_data['facility_palettes'].keys())}"
            )

        asset_name = f"facility_{sprite_key}"
        img = render_grid_to_image(grid, palette, scale=scale)
        write_imageset(img, facilities_dir, asset_name)
        count += 1

    return count


def export_indicator_sprites(sprite_data: dict, output_dir: Path, scale: int) -> int:
    """Export all indicator sprites as PNG image sets."""
    indicators_dir = output_dir / "Indicators"
    write_namespace_contents_json(indicators_dir)
    count = 0

    for indicator_name, grid in sprite_data["indicator_sprites"].items():
        if indicator_name not in sprite_data["indicator_palettes"]:
            raise ValueError(
                f"No palette for indicator '{indicator_name}'. "
                f"Available: {sorted(sprite_data['indicator_palettes'].keys())}"
            )
        for brightness in ["bright", "dim"]:
            if brightness not in sprite_data["indicator_palettes"][indicator_name]:
                raise ValueError(
                    f"No '{brightness}' variant for indicator '{indicator_name}'"
                )
            palette = sprite_data["indicator_palettes"][indicator_name][brightness]
            asset_name = f"indicator_{indicator_name}_{brightness}"
            img = render_grid_to_image(grid, palette, scale=scale)
            write_imageset(img, indicators_dir, asset_name)
            count += 1

    return count


def export_pattern_masks(sprite_data: dict, output_dir: Path, scale: int) -> int:
    """Export pre-baked pattern mask PNGs for Dutch, Chinchilla, and Himalayan."""
    patterns_dir = output_dir / "Patterns"
    write_namespace_contents_json(patterns_dir)
    count = 0

    white_pixel = (255, 255, 255, 255)
    transparent = (0, 0, 0, 0)
    body_keys = {"fur", "nose", "eye", "pupil", "belly", "paw", "tooth", "ear", "blush", "tear"}

    for age_label, reference_grid in [
        ("adult", sprite_data["pig_adult_idle_right"]),
        ("baby", sprite_data["pig_baby_idle_right"]),
    ]:
        height = len(reference_grid)
        width = max(len(row) for row in reference_grid)

        def at(row: int, col: int) -> str | None:
            if 0 <= row < height and 0 <= col < len(reference_grid[row]):
                return reference_grid[row][col]
            return None

        def is_body(key: str | None) -> bool:
            return key is not None and key in body_keys

        def is_inner_fur(row: int, col: int) -> bool:
            """Fur pixel with all 4 cardinal neighbors being body pixels.

            Edge pixels (neighbors out-of-bounds) return None from at(), which
            fails is_body(), so edge fur is intentionally excluded from the mask.
            """
            return (
                at(row, col) == "fur"
                and is_body(at(row - 1, col))
                and is_body(at(row + 1, col))
                and is_body(at(row, col - 1))
                and is_body(at(row, col + 1))
            )

        dutch_img = Image.new("RGBA", (width, height), transparent)
        for row in range(height):
            for col in range(width):
                key = at(row, col)
                if key != "fur":
                    continue
                in_forehead = row <= 3 and 3 <= col <= 10
                in_belly = row >= 5
                if in_forehead or in_belly:
                    dutch_img.putpixel((col, row), white_pixel)
        dutch_scaled = dutch_img.resize(
            (width * scale, height * scale), resample=Image.NEAREST
        )
        write_imageset(dutch_scaled, patterns_dir, f"pattern_dutch_{age_label}_mask")
        count += 1

        chinchilla_img = Image.new("RGBA", (width, height), transparent)
        for row in range(height):
            for col in range(width):
                if at(row, col) == "fur" and (row + col) % 3 == 0:
                    chinchilla_img.putpixel((col, row), white_pixel)
        chinchilla_scaled = chinchilla_img.resize(
            (width * scale, height * scale), resample=Image.NEAREST
        )
        write_imageset(
            chinchilla_scaled, patterns_dir, f"pattern_chinchilla_{age_label}_mask"
        )
        count += 1

        himalayan_img = Image.new("RGBA", (width, height), transparent)
        for row in range(height):
            for col in range(width):
                if is_inner_fur(row, col):
                    himalayan_img.putpixel((col, row), white_pixel)
        himalayan_scaled = himalayan_img.resize(
            (width * scale, height * scale), resample=Image.NEAREST
        )
        write_imageset(
            himalayan_scaled, patterns_dir, f"pattern_himalayan_{age_label}_mask"
        )
        count += 1

    return count


# ---------------------------------------------------------------------------
# Export functions — Python-repo-backed (require --source)
# ---------------------------------------------------------------------------

def export_portraits(source_path: Path, output_dir: Path, portrait_scale: int) -> int:
    """Export representative portraits for all 144 phenotype combinations.

    Requires --source (uses generate_portrait from the Python repo).
    """
    from big_pig_farm.data.pig_portraits import generate_portrait
    from big_pig_farm.data.sprite_engine import PALETTES

    portraits_dir = output_dir / "Portraits"
    write_namespace_contents_json(portraits_dir)
    count = 0

    colors = ["BLACK", "CHOCOLATE", "GOLDEN", "CREAM", "BLUE", "LILAC", "SAFFRON", "SMOKE"]
    patterns = ["solid", "dutch", "dalmatian"]
    intensities = ["full", "chinchilla", "himalayan"]
    roan_states = ["none", "roan"]

    for color in colors:
        palette = {k: v for k, v in PALETTES[color].items() if k is not None}

        for pattern in patterns:
            for intensity in intensities:
                for roan in roan_states:
                    pig_id = f"pigdex_{color}_{pattern}_{intensity}_{roan}"
                    grid = generate_portrait(color, pattern, intensity, roan, pig_id)
                    asset_name = f"portrait_{color.lower()}_{pattern}_{intensity}_{roan}"
                    img = render_grid_to_image(grid, palette, scale=portrait_scale)
                    write_imageset(img, portraits_dir, asset_name)
                    count += 1

    return count


def export_terrain_tiles(source_path: Path, output_dir: Path, scale: int) -> int:
    """Export terrain tiles for each biome.

    Requires --source (uses BIOMES data from the Python repo).
    """
    from big_pig_farm.data.sprites import WALL_GRAIN, WALL_PLANK, WALL_POST
    from big_pig_farm.entities.biomes import BIOMES, BiomeType

    terrain_dir = output_dir / "Terrain"
    write_namespace_contents_json(terrain_dir)
    tile_size = 8
    count = 0

    for biome_type, biome_info in BIOMES.items():
        biome_name = biome_type.value

        floor_img = Image.new("RGBA", (tile_size, tile_size), (0, 0, 0, 0))
        bg_rgba = hex_to_rgba(biome_info.floor_bg)
        rng = random.Random(f"terrain_{biome_name}_floor")
        for y in range(tile_size):
            for x in range(tile_size):
                if biome_info.floor_colors and rng.random() < 0.15:
                    var_color = rng.choice(biome_info.floor_colors)
                    floor_img.putpixel((x, y), hex_to_rgba(var_color))
                else:
                    floor_img.putpixel((x, y), bg_rgba)
        scaled_floor = floor_img.resize(
            (tile_size * scale, tile_size * scale), resample=Image.NEAREST
        )
        write_imageset(scaled_floor, terrain_dir, f"terrain_{biome_name}_floor")
        count += 1

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
        scaled_wall = wall_img.resize(
            (tile_size * scale, tile_size * scale), resample=Image.NEAREST
        )
        write_imageset(scaled_wall, terrain_dir, f"terrain_{biome_name}_wall")
        count += 1

        post_color = hex_to_rgba(WALL_POST)
        post_img = Image.new("RGBA", (tile_size * scale, tile_size * scale), post_color)
        write_imageset(post_img, terrain_dir, f"terrain_{biome_name}_post")
        count += 1

    tunnel_floor_bg = "#3a3a3a"
    tunnel_floor_colors = ["#808080", "#707070", "#909090", "#757575"]
    floor_img = Image.new("RGBA", (tile_size, tile_size), (0, 0, 0, 0))
    rng = random.Random("terrain_tunnel_floor")
    for y in range(tile_size):
        for x in range(tile_size):
            if rng.random() < 0.15:
                floor_img.putpixel((x, y), hex_to_rgba(rng.choice(tunnel_floor_colors)))
            else:
                floor_img.putpixel((x, y), hex_to_rgba(tunnel_floor_bg))
    scaled_floor = floor_img.resize(
        (tile_size * scale, tile_size * scale), resample=Image.NEAREST
    )
    write_imageset(scaled_floor, terrain_dir, "terrain_tunnel_floor")
    count += 1

    tunnel_wall_planks = ["#505050", "#585858", "#484848", "#555555", "#4a4a4a"]
    tunnel_wall_grains = ["#303030", "#282828", "#383838"]
    wall_img = Image.new("RGBA", (tile_size, tile_size), (0, 0, 0, 0))
    rng = random.Random("terrain_tunnel_wall")
    for y in range(tile_size):
        plank_color = hex_to_rgba(rng.choice(tunnel_wall_planks))
        for x in range(tile_size):
            if rng.random() < 0.1:
                wall_img.putpixel((x, y), hex_to_rgba(rng.choice(tunnel_wall_grains)))
            else:
                wall_img.putpixel((x, y), plank_color)
    scaled_wall = wall_img.resize(
        (tile_size * scale, tile_size * scale), resample=Image.NEAREST
    )
    write_imageset(scaled_wall, terrain_dir, "terrain_tunnel_wall")
    count += 1

    tunnel_post_color = hex_to_rgba("#2a2a2a")
    post_img = Image.new("RGBA", (tile_size, tile_size), tunnel_post_color)
    scaled_post = post_img.resize(
        (tile_size * scale, tile_size * scale), resample=Image.NEAREST
    )
    write_imageset(scaled_post, terrain_dir, "terrain_tunnel_post")
    count += 1

    return count


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

EXPECTED_COUNTS = {
    "pigs": 272,       # 8 colors x (22 adult + 12 baby)
    "facilities": 25,  # 17 base + 8 state variants
    "indicators": 12,  # 6 types x 2 brightness levels
    "portraits": 144,  # 8 colors x 3 patterns x 3 intensities x 2 roan
    "terrain": 27,     # 8 biomes x 3 tile types (24) + tunnel x 3 tile types (3)
    "patterns": 6,     # 3 patterns x 2 ages
}

PYTHON_REPO_CATEGORIES = {"portraits", "terrain"}


def validate_export(
    output_dir: Path,
    counts: dict[str, int],
    categories: list[str] | None = None,
) -> bool:
    """Count .imageset directories per category and verify expected counts."""
    subdirs = {
        "pigs": "Pigs",
        "facilities": "Facilities",
        "indicators": "Indicators",
        "portraits": "Portraits",
        "terrain": "Terrain",
        "patterns": "Patterns",
    }
    if categories is not None:
        subdirs = {k: v for k, v in subdirs.items() if k in categories}
    all_ok = True
    for category, subdir in subdirs.items():
        category_dir = output_dir / subdir
        if not category_dir.exists():
            print(f"  MISSING: {subdir}/")
            all_ok = False
            continue
        actual = sum(1 for p in category_dir.iterdir() if p.suffix == ".imageset")
        expected = counts[category]
        status = "OK" if actual == expected else "MISMATCH"
        print(f"  {status}: {subdir}/ — {actual}/{expected} image sets")
        if actual != expected:
            all_ok = False
    return all_ok


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Export Big Pig Farm sprites to PNG image sets."
    )
    parser.add_argument(
        "--source",
        default=None,
        help="Path to the Python game repo root (only needed for portraits and terrain)",
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Output directory (e.g., BigPigFarm/Resources/Assets.xcassets/Sprites)",
    )
    parser.add_argument(
        "--scale",
        type=int,
        default=4,
        help="Pixels per art pixel at @1x (default: 4)",
    )
    parser.add_argument(
        "--portrait-scale",
        type=int,
        default=8,
        help="Pixels per art pixel for portraits at @1x (default: 8)",
    )
    parser.add_argument(
        "--category",
        choices=["all", "pigs", "facilities", "indicators", "portraits", "terrain", "patterns"],
        default="all",
        help="Export only a specific category (default: all)",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    requested = (
        list(EXPECTED_COUNTS.keys()) if args.category == "all"
        else [args.category]
    )
    needs_source = PYTHON_REPO_CATEGORIES & set(requested)

    source_path = None
    if args.source:
        source_path = Path(args.source).resolve()
        if not source_path.exists():
            print(f"ERROR: Source path does not exist: {source_path}")
            sys.exit(1)
        sys.path.insert(0, str(source_path))
    elif needs_source:
        print(f"ERROR: --source is required for: {', '.join(sorted(needs_source))}")
        print("These categories use algorithmic generation from the Python repo.")
        print("Other categories (pigs, facilities, indicators, patterns) read from")
        print(f"  {SPRITE_DATA_FILE}")
        sys.exit(1)

    needs_json = set(requested) - PYTHON_REPO_CATEGORIES
    sprite_data = load_sprite_data() if needs_json else None

    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    write_namespace_contents_json(output_dir)

    if source_path:
        print(f"Source:    {source_path}")
    if sprite_data:
        print(f"Data:      {SPRITE_DATA_FILE}")
    print(f"Output:    {output_dir.resolve()}")
    print(f"Scale:     {args.scale}x")
    print(f"Portraits: {args.portrait_scale}x")
    print()

    category_funcs = {
        "pigs": lambda: export_pig_sprites(sprite_data, output_dir, args.scale),
        "facilities": lambda: export_facility_sprites(sprite_data, output_dir, args.scale),
        "indicators": lambda: export_indicator_sprites(sprite_data, output_dir, args.scale),
        "portraits": lambda: export_portraits(source_path, output_dir, args.portrait_scale),
        "terrain": lambda: export_terrain_tiles(source_path, output_dir, args.scale),
        "patterns": lambda: export_pattern_masks(sprite_data, output_dir, args.scale),
    }

    total = 0
    if args.category == "all":
        for cat_name, func in category_funcs.items():
            print(f"Exporting {cat_name}...")
            cat_count = func()
            print(f"  {cat_count} image sets")
            total += cat_count
    else:
        print(f"Exporting {args.category}...")
        total = category_funcs[args.category]()
        print(f"  {total} image sets")

    print()
    print("Validating export...")
    categories_to_validate = None if args.category == "all" else [args.category]
    if not validate_export(output_dir, EXPECTED_COUNTS, categories_to_validate):
        print("ERROR: Validation failed — one or more categories have unexpected counts.")
        sys.exit(1)

    print()
    print(f"Done. {total} image sets, {total * 3} PNG files.")


if __name__ == "__main__":
    main()
