#!/usr/bin/env python3
"""Generate placeholder treat sprites for the asset catalog.

Usage:
    python tools/generate_treat_placeholders.py \
        --output BigPigFarm/Resources/Assets.xcassets/Sprites

Creates 4 treat sprite image sets under Sprites/Treats/ with distinct shapes
and colors matching each TreatType. These are temporary placeholders — the
export_sprites.py pipeline will eventually produce final pixel-art versions.

Requires: Pillow (pip install Pillow)
"""

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw

SCALE = 4
ART_SIZE = 6


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


def draw_fresh_veggies(draw: ImageDraw.Draw, size: int) -> None:
    """Green circle — leafy veggie."""
    margin = 1
    draw.ellipse(
        [margin, margin, size - margin - 1, size - margin - 1],
        fill=(76, 217, 100, 255),
    )


def draw_fruit_slices(draw: ImageDraw.Draw, size: int) -> None:
    """Orange diamond — fruit wedge."""
    mid = size // 2
    draw.polygon(
        [(mid, 0), (size - 1, mid), (mid, size - 1), (0, mid)],
        fill=(255, 149, 0, 255),
    )


def draw_herb_bundle(draw: ImageDraw.Draw, size: int) -> None:
    """Teal triangle — herb sprig."""
    draw.polygon(
        [(size // 2, 0), (size - 1, size - 1), (0, size - 1)],
        fill=(102, 212, 207, 255),
    )


def draw_hay_sampler(draw: ImageDraw.Draw, size: int) -> None:
    """Yellow square with horizontal line — hay bale."""
    margin = 1
    draw.rectangle(
        [margin, margin, size - margin - 1, size - margin - 1],
        fill=(255, 204, 0, 255),
    )
    mid_y = size // 2
    draw.line([(margin, mid_y), (size - margin - 1, mid_y)], fill=(200, 160, 0, 255))


TREATS = [
    ("treat_fresh_veggies", draw_fresh_veggies),
    ("treat_fruit_slices", draw_fruit_slices),
    ("treat_herb_bundle", draw_herb_bundle),
    ("treat_hay_sampler", draw_hay_sampler),
]


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate placeholder treat sprites")
    parser.add_argument(
        "--output",
        required=True,
        help="Sprites output directory (e.g. BigPigFarm/Resources/Assets.xcassets/Sprites)",
    )
    args = parser.parse_args()

    output_dir = Path(args.output)
    treats_dir = output_dir / "Treats"
    write_namespace_contents_json(treats_dir)

    count = 0
    for asset_name, draw_fn in TREATS:
        img = Image.new("RGBA", (ART_SIZE, ART_SIZE), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        draw_fn(draw, ART_SIZE)

        scaled = img.resize(
            (ART_SIZE * SCALE, ART_SIZE * SCALE), resample=Image.NEAREST
        )
        write_imageset(scaled, treats_dir, asset_name)
        count += 1

    print(f"Generated {count} treat placeholder sprites in {treats_dir}")


if __name__ == "__main__":
    main()
