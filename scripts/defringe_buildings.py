#!/usr/bin/env python3
"""Clean the AI-cutout halo off the home-base building sprites and regenerate their
hover / pressed variants from the cleaned base, so all three share one clean alpha.

The runtime building PNGs (`buildings_runtime/<id>.png`) had a semi-transparent
edge fringe (background not cleanly cut) and a broken hover (globally semi-transparent).
This:
  1. Colour-bleeds opaque colour outward so the fringe isn't background-coloured.
  2. Trims the faintest edge alpha.
  3. Rebuilds <id>_hover.png (brighter) and <id>_pressed.png (darker) from the cleaned
     base, inheriting its clean alpha.

  python scripts/defringe_buildings.py

NOTE: this is image *processing* of existing assets, not authored art — a stopgap until
Codex can redeliver clean cutouts (ADR-0005). Reversible via git.
"""
import sys
import numpy as np
from PIL import Image

RT = "run_system/assets/images/home/buildings_runtime/"
BUILDINGS = ["forge", "clinic", "market", "outpost", "warehouse"]
HOVER_MULT = 1.22
PRESSED_MULT = 0.80
TRIM_ALPHA = 28  # edge pixels fainter than this are dropped to fully clear


def despill_and_trim(arr: np.ndarray) -> np.ndarray:
    rgb = arr[:, :, :3].copy()
    alpha = arr[:, :, 3]
    h, w = alpha.shape
    known = alpha >= 200
    fill = rgb.copy()
    # Iteratively flood opaque colour into the non-opaque region (4-neighbour) so the
    # translucent fringe takes the building's colour instead of the old background's.
    for _ in range(14):
        if known.all():
            break
        unknown = ~known
        acc = np.zeros_like(fill)
        cnt = np.zeros((h, w), dtype=np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ks = np.roll(known, (-dy, -dx), axis=(0, 1))
            fs = np.roll(fill, (-dy, -dx), axis=(0, 1))
            m = ks & unknown
            acc[m] += fs[m]
            cnt[m] += 1.0
        newly = (cnt > 0) & unknown
        fill[newly] = acc[newly] / cnt[newly, None]
        known |= newly
    out = arr.copy()
    out[:, :, :3] = fill
    a = out[:, :, 3].copy()
    a[a < TRIM_ALPHA] = 0
    out[:, :, 3] = a
    return out


def main() -> None:
    for b in BUILDINGS:
        base_path = RT + b + ".png"
        arr = np.array(Image.open(base_path).convert("RGBA")).astype(np.float32)
        clean = despill_and_trim(arr)
        Image.fromarray(np.clip(clean, 0, 255).astype(np.uint8)).save(base_path)
        for suffix, mult in ((b + "_hover.png", HOVER_MULT), (b + "_pressed.png", PRESSED_MULT)):
            v = clean.copy()
            v[:, :, :3] = np.clip(v[:, :, :3] * mult, 0, 255)
            Image.fromarray(v.astype(np.uint8)).save(RT + suffix)
        # report remaining edge fringe
        a = clean[:, :, 3]
        semi = int(((a > 0) & (a < 255)).sum())
        print(f"{b}: defringed + rebuilt hover/pressed  (semi-alpha now {semi}px)")


if __name__ == "__main__":
    main()
