#!/usr/bin/env python3
"""Export Big Pig Farm sprites from Python pixel data to PNG image sets.

Usage:
    python tools/export_sprites.py \\
        --source ../big-pig-farm \\
        --output BigPigFarm/Resources/Assets.xcassets/Sprites \\
        [--scale 4] \\
        [--portrait-scale 8] \\
        [--category {all,pigs,facilities,indicators,portraits,terrain,patterns}]

Reads pixel grid data from the Python game repo and writes Xcode .imageset
directories (with @1x/@2x/@3x PNG variants and Contents.json) to the output path.

Requires: Pillow (pip install Pillow)
"""

import argparse
import json
import random
import sys
from pathlib import Path

from PIL import Image


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
            The None key must already be removed before calling.
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
                continue  # Transparent pixel
            color_hex = palette.get(key)
            if color_hex is None:
                # Key not found in palette — treat key as literal hex color string.
                # This handles portrait grids that embed raw hex values for background pixels.
                color_hex = key
            img.putpixel((x, y), hex_to_rgba(color_hex))

    if scale > 1:
        img = img.resize(
            (width * scale, height * scale),
            resample=Image.NEAREST,
        )

    return img


def write_imageset(img_1x: Image.Image, output_dir: Path, name: str) -> None:
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
# Export functions
# ---------------------------------------------------------------------------

def export_pig_sprites(source_path: Path, output_dir: Path, scale: int) -> int:
    """Export all pig sprites as PNG image sets.

    Returns the number of image sets created.
    """
    from big_pig_farm.data.pig_sprites import PIG_PIXELS_ADULT, PIG_PIXELS_BABY
    from big_pig_farm.data.sprite_engine import PALETTES

    pigs_dir = output_dir / "Pigs"
    write_namespace_contents_json(pigs_dir)
    count = 0

    for color_name, raw_palette in PALETTES.items():
        # Remove None key — grid cells with None are transparent, not the wisp color.
        palette = {k: v for k, v in raw_palette.items() if k is not None}

        for age_label, sprites in [("adult", PIG_PIXELS_ADULT), ("baby", PIG_PIXELS_BABY)]:
            for sprite_key, grid in sprites.items():
                asset_name = f"pig_{age_label}_{color_name.lower()}_{sprite_key}"
                img = render_grid_to_image(grid, palette, scale=scale)
                write_imageset(img, pigs_dir, asset_name)
                count += 1

    return count


def export_facility_sprites(source_path: Path, output_dir: Path, scale: int) -> int:
    """Export all facility sprites as PNG image sets.

    Returns the number of image sets created.
    """
    from big_pig_farm.data.facility_pixels import FACILITY_PALETTES, FACILITY_PIXELS

    facilities_dir = output_dir / "Facilities"
    write_namespace_contents_json(facilities_dir)
    count = 0

    for sprite_key, grid in FACILITY_PIXELS.items():
        # State variants (food_bowl_empty, food_bowl_full) use the base type palette.
        base_type = sprite_key
        for suffix in ("_empty", "_full"):
            if sprite_key.endswith(suffix):
                base_type = sprite_key[: -len(suffix)]
                break

        palette = FACILITY_PALETTES.get(base_type)
        if palette is None:
            print(f"  WARNING: No palette for '{base_type}', skipping '{sprite_key}'")
            continue

        asset_name = f"facility_{sprite_key}"
        img = render_grid_to_image(grid, palette, scale=scale)
        write_imageset(img, facilities_dir, asset_name)
        count += 1

    return count


def export_indicator_sprites(source_path: Path, output_dir: Path, scale: int) -> int:
    """Export all indicator sprites as PNG image sets.

    Returns the number of image sets created.
    """
    from big_pig_farm.data.indicator_pixels import (
        INDICATOR_PALETTES,
        INDICATOR_PIXELS_NORMAL,
    )

    indicators_dir = output_dir / "Indicators"
    write_namespace_contents_json(indicators_dir)
    count = 0

    for indicator_name, grid in INDICATOR_PIXELS_NORMAL.items():
        for brightness in ["bright", "dim"]:
            palette = INDICATOR_PALETTES[indicator_name][brightness]
            asset_name = f"indicator_{indicator_name}_{brightness}"
            img = render_grid_to_image(grid, palette, scale=scale)
            write_imageset(img, indicators_dir, asset_name)
            count += 1

    return count


def export_portraits(source_path: Path, output_dir: Path, portrait_scale: int) -> int:
    """Export representative portraits for all 144 phenotype combinations.

    Uses a fixed seed per combination so output is deterministic (Pigdex previews).
    Returns the number of image sets created.
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
                    # Fixed seed for deterministic Pigdex previews
                    pig_id = f"pigdex_{color}_{pattern}_{intensity}_{roan}"
                    grid = generate_portrait(color, pattern, intensity, roan, pig_id)
                    asset_name = f"portrait_{color.lower()}_{pattern}_{intensity}_{roan}"
                    img = render_grid_to_image(grid, palette, scale=portrait_scale)
                    write_imageset(img, portraits_dir, asset_name)
                    count += 1

    return count


def export_terrain_tiles(source_path: Path, output_dir: Path, scale: int) -> int:
    """Export terrain tiles for each biome.

    Each tile is 8x8 art pixels with subtle color variation for visual texture.
    Returns the number of image sets created.
    """
    from big_pig_farm.data.sprites import WALL_GRAIN, WALL_PLANK, WALL_POST
    from big_pig_farm.entities.biomes import BIOMES, BiomeType

    terrain_dir = output_dir / "Terrain"
    write_namespace_contents_json(terrain_dir)
    tile_size = 8
    count = 0

    for biome_type, biome_info in BIOMES.items():
        biome_name = biome_type.value

        # Floor tile: base floor_bg with 15% variation from floor_colors
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

        # Wall tile: plank rows with 10% grain variation
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

        # Post tile: solid WALL_POST color
        post_color = hex_to_rgba(WALL_POST)
        post_img = Image.new("RGBA", (tile_size * scale, tile_size * scale), post_color)
        write_imageset(post_img, terrain_dir, f"terrain_{biome_name}_post")
        count += 1

    return count


def export_pattern_masks(source_path: Path, output_dir: Path, scale: int) -> int:
    """Export pre-baked pattern mask PNGs for Dutch, Chinchilla, and Himalayan patterns.

    Each mask is white where the pattern applies, transparent elsewhere.
    Dalmatian and Roan masks are NOT pre-baked (they are seeded per pig UUID at runtime).
    Returns the number of image sets created.
    """
    from big_pig_farm.data.pig_sprites import PIG_PIXELS_ADULT, PIG_PIXELS_BABY

    patterns_dir = output_dir / "Patterns"
    write_namespace_contents_json(patterns_dir)
    count = 0

    white_pixel = (255, 255, 255, 255)
    transparent = (0, 0, 0, 0)

    # Body pixel set — pixels that count as "inner body" for pattern analysis
    body_keys = {"fur", "nose", "eye", "pupil", "belly", "paw", "tooth", "ear", "blush", "tear"}

    for age_label, reference_grid in [
        ("adult", PIG_PIXELS_ADULT["idle_right"]),
        ("baby", PIG_PIXELS_BABY["idle_right"]),
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
            """Fur pixel with all 4 cardinal neighbors being body pixels."""
            return (
                at(row, col) == "fur"
                and is_body(at(row - 1, col))
                and is_body(at(row + 1, col))
                and is_body(at(row, col - 1))
                and is_body(at(row, col + 1))
            )

        # Dutch mask: forehead center (cols 3–10, rows 0–3) + chin/belly (rows 5–7)
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

        # Chinchilla mask: every fur pixel where (row + col) % 3 == 0
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

        # Himalayan mask: all non-ear fur pixels (ears keep their color)
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
# Validation
# ---------------------------------------------------------------------------

EXPECTED_COUNTS = {
    "pigs": 272,       # 8 colors x (22 adult + 12 baby)
    "facilities": 25,  # 17 base + 8 state variants
    "indicators": 12,  # 6 types x 2 brightness levels
    "portraits": 144,  # 8 colors x 3 patterns x 3 intensities x 2 roan
    "terrain": 24,     # 8 biomes x 3 tile types
    "patterns": 6,     # 3 patterns x 2 ages
}


def validate_export(output_dir: Path, counts: dict[str, int]) -> bool:
    """Count .imageset directories per category and verify expected counts."""
    subdirs = {
        "pigs": "Pigs",
        "facilities": "Facilities",
        "indicators": "Indicators",
        "portraits": "Portraits",
        "terrain": "Terrain",
        "patterns": "Patterns",
    }
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
        description="Export Big Pig Farm sprites from Python pixel data to PNG files."
    )
    parser.add_argument(
        "--source",
        required=True,
        help="Path to the Python game repo root (e.g., ../big-pig-farm)",
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

    source_path = Path(args.source).resolve()
    if not source_path.exists():
        print(f"ERROR: Source path does not exist: {source_path}")
        sys.exit(1)

    sys.path.insert(0, str(source_path))

    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    write_namespace_contents_json(output_dir)

    print(f"Source:   {source_path}")
    print(f"Output:   {output_dir.resolve()}")
    print(f"Scale:    {args.scale}x")
    print(f"Portraits: {args.portrait_scale}x")
    print()

    category_funcs = {
        "pigs": lambda: export_pig_sprites(source_path, output_dir, args.scale),
        "facilities": lambda: export_facility_sprites(source_path, output_dir, args.scale),
        "indicators": lambda: export_indicator_sprites(source_path, output_dir, args.scale),
        "portraits": lambda: export_portraits(source_path, output_dir, args.portrait_scale),
        "terrain": lambda: export_terrain_tiles(source_path, output_dir, args.scale),
        "patterns": lambda: export_pattern_masks(source_path, output_dir, args.scale),
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
    validate_export(output_dir, EXPECTED_COUNTS)

    print()
    print(f"Done. {total} image sets, {total * 3} PNG files.")


if __name__ == "__main__":
    main()
