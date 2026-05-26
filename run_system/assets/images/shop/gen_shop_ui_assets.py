"""
Generate deterministic project-native shop UI art.

Outputs:
  - shop_interior_bg.png: 960x540 pixel wasteland merchant backdrop.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


OUT_DIR = Path(__file__).resolve().parent

INK = (13, 8, 5, 255)
DARK = (24, 13, 8, 255)
PANEL = (42, 24, 13, 255)
RUST = (126, 58, 24, 255)
RUST_HI = (194, 108, 42, 255)
TAN = (188, 138, 72, 255)
SAND = (224, 194, 132, 255)
STEEL = (88, 86, 76, 255)
STEEL_HI = (150, 142, 118, 255)
NEON = (52, 204, 226, 255)
GOLD = (242, 202, 70, 255)


def rect(d: ImageDraw.ImageDraw, box, color) -> None:
    d.rectangle(box, fill=color)


def line(d: ImageDraw.ImageDraw, points, color, width: int = 1) -> None:
    d.line(points, fill=color, width=width)


def build_shop_background() -> None:
    w, h = 960, 540
    img = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    d = ImageDraw.Draw(img)

    # Dark interior gradient bands.
    for y in range(h):
        t = y / h
        r = int(20 + 18 * t)
        g = int(10 + 10 * t)
        b = int(6 + 6 * t)
        line(d, [(0, y), (w, y)], (r, g, b, 255))

    # Back wall panels.
    rect(d, (34, 46, 926, 350), (27, 15, 9, 255))
    for x in range(52, 918, 74):
        line(d, [(x, 54), (x - 22, 342)], (41, 23, 13, 180), 2)
    for y in (84, 150, 216, 282):
        line(d, [(44, y), (916, y)], (75, 38, 17, 180), 2)
        line(d, [(44, y + 3), (916, y + 3)], INK, 1)

    # Top canvas awning.
    rect(d, (72, 18, 888, 62), INK)
    rect(d, (78, 20, 882, 56), (86, 42, 18, 255))
    for x in range(78, 882, 46):
        rect(d, (x, 20, x + 23, 56), (112, 54, 22, 255))
        line(d, [(x, 20), (x + 23, 56)], (144, 72, 28, 120), 1)
    line(d, [(78, 20), (882, 20)], RUST_HI, 2)
    line(d, [(78, 56), (882, 56)], INK, 3)

    # Shelves with silhouettes of goods.
    for shelf_y in (144, 238):
        rect(d, (92, shelf_y, 868, shelf_y + 18), INK)
        rect(d, (98, shelf_y, 862, shelf_y + 10), RUST)
        line(d, [(98, shelf_y), (862, shelf_y)], RUST_HI, 1)

    # Left goods.
    goods = [
        (130, 104, 176, 143, STEEL),
        (196, 94, 242, 143, RUST),
        (280, 102, 320, 143, TAN),
        (126, 196, 160, 238, STEEL_HI),
        (196, 198, 248, 238, (80, 40, 18, 255)),
        (290, 188, 330, 238, GOLD),
    ]
    for x0, y0, x1, y1, c in goods:
        rect(d, (x0 - 3, y0 + 3, x1 + 3, y1 + 3), INK)
        rect(d, (x0, y0, x1, y1), c)
        line(d, [(x0, y0), (x1, y0)], tuple(min(255, v + 42) for v in c[:3]) + (255,), 1)

    # Right silhouettes and hanging scrap.
    for x in (650, 704, 766, 820):
        rect(d, (x, 104, x + 34, 143), INK)
        rect(d, (x + 3, 107, x + 31, 143), STEEL if x % 2 == 0 else RUST)
        line(d, [(x + 5, 110), (x + 28, 110)], SAND, 1)
    for x in (634, 714, 792):
        line(d, [(x, 68), (x, 104)], STEEL, 2)
        rect(d, (x - 10, 102, x + 10, 122), GOLD if x == 714 else STEEL_HI)

    # Merchant counter foreground.
    rect(d, (0, 364, 960, 540), INK)
    rect(d, (36, 356, 924, 530), (48, 26, 13, 255))
    rect(d, (52, 374, 908, 512), (73, 38, 17, 255))
    line(d, [(52, 374), (908, 374)], RUST_HI, 3)
    line(d, [(52, 512), (908, 512)], INK, 4)
    for x in range(68, 900, 86):
        rect(d, (x, 390, x + 50, 494), (38, 21, 12, 255))
        line(d, [(x, 390), (x + 50, 390)], (106, 58, 28, 255), 1)

    # Neon lamp and small glow.
    rect(d, (444, 72, 516, 80), INK)
    rect(d, (452, 74, 508, 77), NEON)
    for glow in range(1, 7):
        d.rectangle((452 - glow * 4, 74 - glow * 3, 508 + glow * 4, 77 + glow * 3), outline=(52, 204, 226, max(10, 70 - glow * 10)))

    # Vignette.
    for i in range(34):
        alpha = int(5 + i * 3)
        d.rectangle((i, i, w - i - 1, h - i - 1), outline=(0, 0, 0, alpha))

    img.save(OUT_DIR / "shop_interior_bg.png")
    print(OUT_DIR / "shop_interior_bg.png")


if __name__ == "__main__":
    build_shop_background()
