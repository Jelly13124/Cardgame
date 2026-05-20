"""
Palette extraction tool — scans every game-art PNG under battle_scene/assets/images
and counts the dominant colors, then writes a markdown report.

Use this to derive the canonical UI palette from the actual sprites Codex
generated, so the theme constants match the art with no drift.

Usage:
    python tools/extract_palette.py                  # default scan, 30 buckets reported
    python tools/extract_palette.py --top 50         # report more buckets
    python tools/extract_palette.py --bucket 8       # finer color granularity (1..32; default 16)

Output:
    tools/palette_report.md  — markdown table of top-N color buckets

Excluded automatically:
    - Fully transparent pixels
    - Near-black outlines (V < ~25, treated as outline ink)
    - `generated_sheet/` folders (pipeline intermediates, not final art)
    - `.import` files
"""

from __future__ import annotations

import argparse
import os
import sys
from collections import Counter
from pathlib import Path
from typing import Iterable

from PIL import Image

PROJECT_ROOT = Path(__file__).resolve().parent.parent

SCAN_ROOTS = [
    "battle_scene/assets/images/cards/player",
    "battle_scene/assets/images/enemies",
    "battle_scene/assets/images/heroes",
    "battle_scene/assets/images/fx",
    "battle_scene/assets/images/backgrounds",
    "run_system/assets/images",
]

EXCLUDE_DIRS = {"generated_sheet", "raw", "ref"}
# Filename prefixes/keywords that mark a pipeline intermediate (still has chroma-key bg)
EXCLUDE_FILENAME_KEYWORDS = ("raw-", "raw_", "sheet-clean", "sheet-transparent", "raw-sheet")
# Pixels with alpha < this are skipped entirely (transparent edge / fully transparent)
ALPHA_MIN = 200
# Pixels with max(R,G,B) below this are treated as outline ink and dropped
INK_VALUE_MAX = 25
# Skip the #FF00FF chroma-key background and very close shades
def _is_chroma_magenta(r: int, g: int, b: int) -> bool:
    return r >= 200 and g <= 60 and b >= 200


def iter_image_files(roots: Iterable[Path]) -> Iterable[Path]:
    for root in roots:
        if not root.exists():
            continue
        for p in root.rglob("*.png"):
            # Skip pipeline intermediates by directory
            if any(part in EXCLUDE_DIRS for part in p.parts):
                continue
            # Skip pipeline intermediates by filename (raw-*.png lives at the
            # root of some fx folders alongside final transparent frames)
            name_lower = p.name.lower()
            if any(kw in name_lower for kw in EXCLUDE_FILENAME_KEYWORDS):
                continue
            yield p


def bucketize(value: int, bucket: int) -> int:
    """Round a 0..255 channel value to the nearest bucket center."""
    if bucket <= 1:
        return value
    return (value // bucket) * bucket


def hex_for(r: int, g: int, b: int) -> str:
    return f"#{r:02x}{g:02x}{b:02x}"


def luminance(r: int, g: int, b: int) -> float:
    # Rec. 709
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def scan(roots: list[Path], bucket: int, top_n: int) -> tuple[Counter, dict[tuple[int, int, int], set[str]]]:
    """Returns (color_counter, color -> set of relative file paths)."""
    counter: Counter = Counter()
    where: dict[tuple[int, int, int], set[str]] = {}

    for img_path in iter_image_files(roots):
        try:
            img = Image.open(img_path).convert("RGBA")
        except Exception as exc:
            print(f"  warn: cannot open {img_path}: {exc}", file=sys.stderr)
            continue

        relpath = str(img_path.relative_to(PROJECT_ROOT)).replace(os.sep, "/")

        for (r, g, b, a) in img.getdata():
            if a < ALPHA_MIN:
                continue
            if max(r, g, b) < INK_VALUE_MAX:
                continue
            if _is_chroma_magenta(r, g, b):
                continue
            key = (bucketize(r, bucket), bucketize(g, bucket), bucketize(b, bucket))
            counter[key] += 1
            where.setdefault(key, set()).add(relpath)

    return counter, where


def write_report(counter: Counter, where: dict[tuple[int, int, int], set[str]], out_path: Path, top_n: int, bucket: int, image_count: int) -> None:
    total_pixels = sum(counter.values())
    if total_pixels == 0:
        out_path.write_text("# Palette report — no opaque pixels found\n")
        return

    lines: list[str] = []
    lines.append("# Palette Extraction Report")
    lines.append("")
    lines.append(f"- Source: {image_count} game-art PNGs under `battle_scene/assets/images/` + `run_system/assets/images/`")
    lines.append(f"- Bucket size: {bucket} (each RGB channel rounded to nearest multiple)")
    lines.append(f"- Excluded: transparent pixels (alpha<{ALPHA_MIN}), outline ink (max RGB<{INK_VALUE_MAX}), `generated_sheet/` subfolders")
    lines.append(f"- Total opaque pixels analyzed: {total_pixels:,}")
    lines.append("")
    lines.append("## Top color buckets (by frequency)")
    lines.append("")
    lines.append("Pick **8-12** of these as the canonical Wasteland Pixel palette. Aim for: 4-5 earth-tone base colors, 2-3 neon accents, 2-3 UI neutrals (panel bg / borders).")
    lines.append("")
    lines.append("| Rank | Swatch | Hex | Pct | Luminance | Sample assets (≤3) |")
    lines.append("|---:|:---:|:---|---:|---:|:---|")
    for rank, ((r, g, b), count) in enumerate(counter.most_common(top_n), start=1):
        pct = 100.0 * count / total_pixels
        lum = luminance(r, g, b)
        hex_code = hex_for(r, g, b)
        # Sample up to 3 files that contain this color
        files = sorted(where.get((r, g, b), []))[:3]
        sample = ", ".join(f"`{Path(f).name}`" for f in files)
        # Use HTML span as the swatch — markdown renderers that ignore HTML show the hex
        swatch = f'<span style="background:{hex_code};display:inline-block;width:24px;height:14px;border:1px solid #000"></span>'
        lines.append(f"| {rank} | {swatch} | `{hex_code}` | {pct:5.2f}% | {lum:6.1f} | {sample} |")
    lines.append("")
    lines.append("## Suggested split (manual pick)")
    lines.append("")
    lines.append("Replace `?` after you pick from the table above:")
    lines.append("")
    lines.append("```")
    lines.append("BASE (4-5 earth tones):")
    lines.append("  RUST_PRIMARY     = ?  # most-used warm orange/brown")
    lines.append("  LEATHER_DARK     = ?  # dark structural color")
    lines.append("  SAND_LIGHT       = ?  # light highlight")
    lines.append("  STEEL_GREY       = ?  # cool mid tone")
    lines.append("  OLIVE_MUTED      = ?  # secondary warm")
    lines.append("")
    lines.append("ACCENT (2-3 neon highlights):")
    lines.append("  ACCENT_NEON_A    = ?  # primary highlight (e.g. electric blue)")
    lines.append("  ACCENT_NEON_B    = ?  # secondary (e.g. toxic green)")
    lines.append("  ACCENT_DANGER    = ?  # red / hot orange for damage / warning")
    lines.append("")
    lines.append("UI NEUTRALS (2-3 panel / border colors):")
    lines.append("  PANEL_BG         = ?  # dark base for panels")
    lines.append("  PANEL_BORDER     = ?  # mid warm for borders")
    lines.append("  TEXT_MAIN        = ?  # high-contrast text")
    lines.append("```")
    lines.append("")

    out_path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--top", type=int, default=30, help="how many buckets to report")
    parser.add_argument("--bucket", type=int, default=16, help="channel rounding (1..32)")
    parser.add_argument("--out", default="tools/palette_report.md", help="output markdown path")
    args = parser.parse_args()

    if not (1 <= args.bucket <= 32):
        print("--bucket must be in [1, 32]", file=sys.stderr)
        return 2

    roots = [PROJECT_ROOT / r for r in SCAN_ROOTS]
    out_path = PROJECT_ROOT / args.out

    print(f"Scanning under {len(roots)} roots, bucket={args.bucket}, top={args.top}...")
    image_count = sum(1 for _ in iter_image_files(roots))
    if image_count == 0:
        print("No PNGs found.", file=sys.stderr)
        return 1
    print(f"Found {image_count} PNG files. Counting pixels...")

    counter, where = scan(roots, args.bucket, args.top)
    print(f"Distinct color buckets: {len(counter):,}")
    print(f"Writing report to {out_path}...")
    write_report(counter, where, out_path, args.top, args.bucket, image_count)
    print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
