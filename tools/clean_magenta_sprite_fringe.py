#!/usr/bin/env python3
"""Remove obsolete magenta chroma spill only along transparent sprite edges.

The project enemy frames were keyed from magenta.  Their alpha is valid, but a
thin purple fringe remains outside the dark ink outline.  This tool deliberately
limits removal to saturated magenta pixels within a small radius of transparency
so interior palette colors and opaque line art are left untouched.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageFilter


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True, help="Directory containing PNG sprites.")
    parser.add_argument("--out-root", required=True, help="Directory for cleaned copies.")
    parser.add_argument("--edge-radius", type=int, default=3)
    return parser.parse_args()


def is_magenta_spill(red: int, green: int, blue: int, alpha: int) -> bool:
    if alpha <= 8 or red < 70 or blue < 70:
        return False
    if green > min(red, blue) * 0.65:
        return False
    return abs(red - blue) <= 115


def clean_image(source: Path, destination: Path, edge_radius: int) -> tuple[int, int]:
    image = Image.open(source).convert("RGBA")
    alpha = image.getchannel("A")
    transparent = alpha.point(lambda value: 255 if value <= 8 else 0)
    near_transparent = transparent.filter(ImageFilter.MaxFilter(edge_radius * 2 + 1))

    cleaned: list[tuple[int, int, int, int]] = []
    removed = 0
    visible = 0
    for rgba, near_edge in zip(image.getdata(), near_transparent.getdata()):
        red, green, blue, pixel_alpha = rgba
        if pixel_alpha > 8:
            visible += 1
        if near_edge and is_magenta_spill(red, green, blue, pixel_alpha):
            cleaned.append((0, 0, 0, 0))
            removed += 1
        else:
            cleaned.append(rgba)

    output = Image.new("RGBA", image.size)
    output.putdata(cleaned)
    destination.parent.mkdir(parents=True, exist_ok=True)
    output.save(destination)
    return removed, visible


def main() -> None:
    args = parse_args()
    if args.edge_radius < 1 or args.edge_radius > 8:
        raise SystemExit("--edge-radius must be between 1 and 8")

    root = Path(args.root).resolve()
    out_root = Path(args.out_root).resolve()
    sources = sorted(root.rglob("*.png"))
    if not sources:
        raise SystemExit(f"No PNG files found below {root}")

    total_removed = 0
    total_visible = 0
    changed = 0
    for source in sources:
        relative = source.relative_to(root)
        removed, visible = clean_image(source, out_root / relative, args.edge_radius)
        total_removed += removed
        total_visible += visible
        if removed:
            changed += 1
            print(f"{relative.as_posix()}: removed {removed} edge pixels")

    ratio = total_removed / max(1, total_visible)
    print(
        f"Processed {len(sources)} PNGs; changed {changed}; "
        f"removed {total_removed}/{total_visible} visible pixels ({ratio:.3%})."
    )


if __name__ == "__main__":
    main()
