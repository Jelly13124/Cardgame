"""
Generate focused UI polish assets for the wasteland battle screen.

Outputs:
  - cards/ui/card_cost_badge.png
  - cards/ui/art_frame_common.png
  - cards/ui/art_frame_uncommon.png
  - cards/ui/art_frame_rare.png
  - ui/intent_attack.png
  - ui/intent_block.png
  - ui/intent_buff.png
  - ui/intent_charge.png
  - ui/energy_core.png
  - ui/energy_panel_frame.png
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
UI_DIR = ROOT / "assets" / "images" / "ui"
CARD_UI_DIR = ROOT / "assets" / "images" / "cards" / "ui"

INK = (12, 7, 4, 255)
INK_SOFT = (28, 16, 8, 235)
RUST = (150, 72, 24, 255)
RUST_HI = (230, 126, 38, 255)
BRASS = (205, 148, 56, 255)
BRASS_HI = (248, 207, 100, 255)
LEATHER = (54, 30, 14, 255)
PANEL = (35, 20, 12, 255)
PANEL_HI = (115, 62, 28, 255)
PANEL_SH = (18, 9, 5, 255)
CYAN = (42, 204, 238, 255)
CYAN_HI = (142, 239, 255, 255)
CYAN_SH = (17, 80, 106, 255)
RED = (226, 72, 44, 255)
RED_HI = (255, 154, 88, 255)
BLUE = (64, 174, 238, 255)
BLUE_HI = (162, 225, 255, 255)
GREEN = (118, 220, 86, 255)
GREEN_HI = (190, 255, 128, 255)
YELLOW = (244, 187, 48, 255)
YELLOW_HI = (255, 235, 120, 255)


def rect(d: ImageDraw.ImageDraw, box: tuple[int, int, int, int], fill) -> None:
    d.rectangle(box, fill=fill)


def line(d: ImageDraw.ImageDraw, pts, fill, width: int = 1) -> None:
    d.line(pts, fill=fill, width=width)


def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print(f"Saved {path}")


def make_cost_badge() -> None:
    img = Image.new("RGBA", (34, 34), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Drop shadow.
    d.polygon([(8, 2), (25, 2), (32, 9), (32, 25), (25, 32), (8, 32), (1, 25), (1, 9)], fill=(0, 0, 0, 120))

    outer = [(7, 1), (25, 1), (33, 9), (33, 25), (25, 33), (7, 33), (0, 25), (0, 9)]
    mid = [(8, 3), (24, 3), (31, 10), (31, 24), (24, 31), (8, 31), (3, 24), (3, 10)]
    inner = [(10, 6), (22, 6), (28, 12), (28, 22), (22, 28), (10, 28), (6, 22), (6, 12)]
    core = [(12, 9), (21, 9), (25, 13), (25, 21), (21, 25), (12, 25), (9, 21), (9, 13)]

    d.polygon(outer, fill=INK)
    d.polygon(mid, fill=RUST)
    d.line([(8, 3), (24, 3), (31, 10)], fill=RUST_HI, width=1)
    d.line([(31, 24), (24, 31), (8, 31), (3, 24)], fill=PANEL_SH, width=1)
    d.polygon(inner, fill=BRASS)
    d.line([(10, 6), (22, 6), (28, 12)], fill=BRASS_HI, width=1)
    d.line([(28, 22), (22, 28), (10, 28), (6, 22)], fill=(108, 62, 20, 255), width=1)
    d.polygon(core, fill=LEATHER)

    # Plain inset center; the numeric cost is the important read.
    d.rectangle([13, 12, 20, 21], fill=(24, 14, 9, 255))
    d.line([(13, 12), (20, 12)], fill=(96, 54, 20, 255), width=1)

    save(img, CARD_UI_DIR / "card_cost_badge.png")


def make_clean_art_frames() -> None:
    colors = {
        "common": ((122, 112, 96, 255), (178, 168, 142, 255), (66, 58, 50, 255)),
        "uncommon": ((54, 134, 188, 255), (126, 214, 248, 255), (25, 70, 112, 255)),
        "rare": ((204, 154, 42, 255), (255, 220, 92, 255), (118, 72, 12, 255)),
    }

    for rarity, (main, hi, sh) in colors.items():
        img = Image.new("RGBA", (144, 102), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)

        # Outer and inner rings only. No corner tabs/rivets.
        d.rectangle([0, 0, 143, 101], fill=INK)
        d.rectangle([2, 2, 141, 99], fill=main)
        d.rectangle([5, 5, 138, 96], fill=(0, 0, 0, 0))

        d.line([(2, 2), (141, 2), (141, 4)], fill=hi, width=1)
        d.line([(2, 2), (2, 99), (4, 99)], fill=hi, width=1)
        d.line([(2, 99), (141, 99), (141, 2)], fill=sh, width=1)
        d.rectangle([5, 5, 138, 96], outline=(18, 10, 6, 210))

        save(img, CARD_UI_DIR / f"art_frame_{rarity}.png")


def make_intent_attack() -> None:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Simple, readable red sword silhouette for enemy attack intent.
    outline = [(4, 25), (7, 28), (12, 24), (15, 27), (18, 24), (15, 21), (29, 7), (30, 2), (25, 3), (11, 17), (8, 14), (5, 17), (8, 20)]
    blade = [(10, 20), (14, 24), (28, 10), (29, 4), (23, 6)]
    guard = [(7, 15), (17, 25), (14, 28), (4, 18)]
    grip = [(4, 24), (7, 27), (12, 22), (9, 19)]
    d.polygon(outline, fill=INK)
    d.polygon(blade, fill=RED)
    d.line([(13, 21), (27, 7)], fill=RED_HI, width=2)
    d.polygon(guard, fill=INK)
    d.line([(7, 17), (15, 25)], fill=(242, 116, 62, 255), width=2)
    d.polygon(grip, fill=(44, 26, 18, 255))
    save(img, UI_DIR / "intent_attack.png")


def make_intent_block() -> None:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Simple blue shield silhouette for enemy block intent.
    outline = [(5, 3), (27, 3), (29, 6), (28, 18), (24, 24), (16, 30), (8, 24), (4, 18), (3, 6)]
    shield = [(7, 5), (25, 5), (27, 8), (26, 17), (22, 23), (16, 27), (10, 23), (6, 17), (5, 8)]
    d.polygon(outline, fill=INK)
    d.polygon(shield, fill=BLUE)
    d.polygon([(9, 8), (16, 7), (16, 25), (10, 20), (7, 16), (7, 9)], fill=BLUE_HI)
    d.polygon([(16, 7), (24, 8), (24, 16), (21, 21), (16, 25)], fill=(24, 118, 184, 255))
    d.line([(8, 6), (24, 6), (26, 9)], fill=(210, 244, 255, 255), width=1)
    d.line([(16, 8), (16, 25)], fill=(14, 72, 120, 210), width=1)
    save(img, UI_DIR / "intent_block.png")


def make_intent_buff() -> None:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(16, 3), (28, 15), (22, 15), (22, 28), (10, 28), (10, 15), (4, 15)], fill=INK_SOFT)
    d.polygon([(16, 5), (26, 15), (20, 15), (20, 26), (12, 26), (12, 15), (6, 15)], fill=GREEN)
    d.line([(16, 5), (26, 15), (20, 15)], fill=GREEN_HI, width=1)
    d.line([(20, 26), (12, 26), (12, 15)], fill=(48, 118, 36, 255), width=1)
    save(img, UI_DIR / "intent_buff.png")


def make_intent_charge() -> None:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(18, 2), (7, 18), (15, 17), (11, 30), (26, 12), (18, 13), (22, 2)], fill=INK_SOFT)
    d.polygon([(17, 3), (8, 17), (16, 16), (12, 28), (25, 12), (18, 12), (21, 3)], fill=YELLOW)
    d.line([(17, 3), (8, 17), (16, 16)], fill=YELLOW_HI, width=1)
    d.line([(12, 28), (25, 12), (18, 12)], fill=(154, 86, 10, 255), width=1)
    save(img, UI_DIR / "intent_charge.png")


def make_energy_core() -> None:
    img = Image.new("RGBA", (42, 42), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    d.ellipse([2, 2, 39, 39], fill=(0, 0, 0, 150))
    d.ellipse([3, 1, 38, 36], fill=INK)
    d.ellipse([5, 3, 36, 34], fill=PANEL_HI)
    d.ellipse([8, 6, 33, 31], fill=PANEL)
    d.ellipse([11, 9, 30, 28], fill=CYAN_SH)
    d.ellipse([14, 11, 27, 24], fill=CYAN)
    d.arc([7, 5, 35, 33], start=202, end=334, fill=BRASS_HI, width=2)
    d.arc([7, 5, 35, 33], start=18, end=148, fill=PANEL_SH, width=2)
    d.polygon([(22, 10), (15, 22), (21, 21), (18, 30), (28, 17), (22, 18)], fill=YELLOW)
    d.line([(22, 10), (15, 22), (21, 21)], fill=YELLOW_HI, width=1)

    save(img, UI_DIR / "energy_core.png")


def make_energy_panel() -> None:
    img = Image.new("RGBA", (156, 44), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Shadow.
    rect(d, (4, 5, 154, 43), (0, 0, 0, 140))

    # Pixel-cut metal plate.
    outer = [(7, 2), (150, 2), (154, 6), (154, 37), (149, 42), (6, 42), (1, 37), (1, 7)]
    inner = [(10, 6), (146, 6), (150, 10), (150, 34), (146, 38), (10, 38), (6, 34), (6, 10)]
    d.polygon(outer, fill=INK)
    d.polygon(inner, fill=PANEL_HI)
    rect(d, (12, 10, 144, 34), PANEL)
    rect(d, (49, 12, 140, 32), (18, 12, 8, 255))
    line(d, [(10, 6), (146, 6), (150, 10)], BRASS_HI, 1)
    line(d, [(150, 34), (146, 38), (10, 38), (6, 34)], PANEL_SH, 1)

    # Small circuit ticks to connect with the core.
    for x in (58, 72, 86, 100, 114, 128):
        rect(d, (x, 35, x + 6, 37), CYAN_SH if x % 28 else CYAN)
    line(d, [(44, 21), (52, 21)], CYAN, 1)
    line(d, [(44, 23), (52, 23)], CYAN_SH, 1)

    save(img, UI_DIR / "energy_panel_frame.png")


def main() -> None:
    make_cost_badge()
    make_clean_art_frames()
    make_intent_attack()
    make_intent_block()
    make_intent_buff()
    make_intent_charge()
    make_energy_core()
    make_energy_panel()


if __name__ == "__main__":
    main()
