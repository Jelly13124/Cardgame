"""
Generate pixel art card UI frame assets for the Wasteland roguelite card game.
Produces:
  - card_bg.png             : Full card background (160x220) - teal border + dark interior
  - art_frame_common.png    : Art frame border, tan/grey (Common rarity)
  - art_frame_uncommon.png  : Art frame border, blue (Uncommon rarity)
  - art_frame_rare.png      : Art frame border, gold (Rare rarity)
  - card_back.png           : Card back face with wasteland emblem (Draw/Discard piles)
"""

from PIL import Image, ImageDraw
import os

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "images", "cards", "ui")
os.makedirs(OUTPUT_DIR, exist_ok=True)

CARD_W, CARD_H = 160, 220

# ─── Palette ──────────────────────────────────────────────────────────────────
# Card character theme (Cowboy Bill — wasteland teal)
CARD_OUTER     = (40,  25,  10)    # 1px outermost dark shadow
CARD_BORDER    = (140,  95,  55)   # Main warm brown border (4px)
CARD_BORDER_HI = (185, 140,  90)   # Top/left highlight
CARD_BORDER_SH = ( 85,  55,  25)   # Bottom/right shadow
CARD_BG_DARK   = (22,  16,  10)    # Dark mahogany card fill
CARD_BG_INNER  = (34,  25,  15)    # Slightly lighter inner area

# Name banner
BANNER_BG   = (45, 34, 20)
BANNER_LINE = (90, 70, 40)

# Description box
DESC_BG     = (228, 220, 192)
DESC_TOP    = (100,  82,  50)    # top line of desc box
DESC_SIDE   = ( 60,  45,  28)    # border sides

# Rarity frame palettes  [main, highlight, shadow]
RARITY_COLORS = {
    "common":   [(135, 135, 135), (175, 175, 175), ( 90,  90,  90)],  # Gray
    "uncommon": [( 60, 140, 230), (110, 180, 255), ( 35,  95, 170)],  # Blue
    "rare":     [(220, 185,   0), (255, 235,  80), (160, 130,   0)],  # Gold
}


def fill_rect(draw, x0, y0, x1, y1, color):
    draw.rectangle([x0, y0, x1, y1], fill=color)


def pixel_border(draw, x0, y0, x1, y1, main, hi, sh, thick=4):
    """Draw a thick pixel-art border with highlight top-left and shadow bottom-right."""
    # Fill border area with main color
    for t in range(thick):
        draw.rectangle([x0 + t, y0 + t, x1 - t, y1 - t], outline=main)
    # 1px highlight (top, left)
    draw.line([(x0, y0), (x1, y0)], fill=hi)
    draw.line([(x0, y0), (x0, y1)], fill=hi)
    # 1px shadow (bottom, right)
    draw.line([(x0, y1), (x1, y1)], fill=sh)
    draw.line([(x1, y0), (x1, y1)], fill=sh)


# ─── 1. Card Background ───────────────────────────────────────────────────────
def build_card_bg():
    img = Image.new("RGBA", (CARD_W, CARD_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Solid dark fill
    fill_rect(d, 0, 0, CARD_W - 1, CARD_H - 1, CARD_BG_DARK)

    # Slightly lighter inner (2px inset from border)
    fill_rect(d, 6, 6, CARD_W - 7, CARD_H - 7, CARD_BG_INNER)

    # Brown border (4px)
    pixel_border(d, 0, 0, CARD_W - 1, CARD_H - 1, CARD_BORDER, CARD_BORDER_HI, CARD_BORDER_SH, thick=4)

    # Extra 1px outermost dark
    d.rectangle([0, 0, CARD_W - 1, CARD_H - 1], outline=CARD_OUTER)

    # ── Name banner (top, y=6..26) ──
    fill_rect(d, 6, 6, CARD_W - 7, 26, BANNER_BG)
    d.line([(6, 26), (CARD_W - 7, 26)], fill=CARD_BORDER_SH)   # bottom separator
    d.line([(6, 7),  (CARD_W - 7,  7)], fill=BANNER_LINE)       # inner top line

    # ── Description box (y=130..202) ──
    fill_rect(d, 6, 130, CARD_W - 7, 202, DESC_BG)
    # Top divider line
    d.line([(6, 130), (CARD_W - 7, 130)], fill=CARD_BORDER_SH)
    d.line([(6, 131), (CARD_W - 7, 131)], fill=DESC_TOP)
    # Side lines
    d.line([(6,  130), (6,  202)], fill=DESC_SIDE)
    d.line([(CARD_W - 7, 130), (CARD_W - 7, 202)], fill=DESC_SIDE)
    # Bottom line
    d.line([(6, 202), (CARD_W - 7, 202)], fill=DESC_SIDE)

    out = os.path.join(OUTPUT_DIR, "card_bg.png")
    img.save(out)
    print(f"  Saved: {out}")
    return img


# ─── 2. Art Frame (rarity border, hollow center, transparent outside) ─────────
ART_X0, ART_Y0 = 8, 26   # Position on card where art frame sits
ART_X1, ART_Y1 = 152, 128  # Right/bottom edge
ART_W = ART_X1 - ART_X0   # = 144
ART_H = ART_Y1 - ART_Y0   # = 102
FRAME_THICK = 4

def build_art_frame(rarity, colors):
    main, hi, sh = [c + (255,) for c in colors]
    img = Image.new("RGBA", (ART_W, ART_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Fill frame ring with main color
    d.rectangle([0, 0, ART_W - 1, ART_H - 1], fill=main)

    # Cut out transparent center
    cx0, cy0 = FRAME_THICK, FRAME_THICK
    cx1, cy1 = ART_W - FRAME_THICK - 1, ART_H - FRAME_THICK - 1
    d.rectangle([cx0, cy0, cx1, cy1], fill=(0, 0, 0, 0))

    # Pixel-art 1px highlight (top, left outer edge)
    d.line([(0, 0), (ART_W - 1, 0)], fill=hi)
    d.line([(0, 0), (0, ART_H - 1)], fill=hi)
    # Shadow (bottom, right outer edge)
    d.line([(0, ART_H - 1), (ART_W - 1, ART_H - 1)], fill=sh)
    d.line([(ART_W - 1, 0), (ART_W - 1, ART_H - 1)], fill=sh)

    # Inner edge dark inset line
    inner_sh = tuple(max(0, c - 60) for c in colors[0]) + (180,)
    d.rectangle([cx0, cy0, cx1, cy1], outline=inner_sh)

    out = os.path.join(OUTPUT_DIR, f"art_frame_{rarity}.png")
    img.save(out)
    print(f"  Saved: {out}")
    return img


# ─── 3. Card Back ─────────────────────────────────────────────────────────────
def build_card_back():
    """
    Draws a pixel-art card back (160x220) with the wasteland theme.
    Design: warm brown border (same as front) + dark interior with a
    centred diamond-and-star emblem in rusted gold.
    """
    img = Image.new("RGBA", (CARD_W, CARD_H), (0, 0, 0, 0))
    d   = ImageDraw.Draw(img)

    # ── Base fill (dark mahogany) ──────────────────────────────────────────────
    fill_rect(d, 0, 0, CARD_W - 1, CARD_H - 1, CARD_BG_DARK)
    fill_rect(d, 6, 6, CARD_W - 7, CARD_H - 7, CARD_BG_INNER)

    # ── Border (identical to card front so they look like a matching pair) ─────
    pixel_border(d, 0, 0, CARD_W - 1, CARD_H - 1, CARD_BORDER, CARD_BORDER_HI, CARD_BORDER_SH, thick=4)
    d.rectangle([0, 0, CARD_W - 1, CARD_H - 1], outline=CARD_OUTER)

    # ── Diagonal crosshatch pattern (subtle) ───────────────────────────────────
    HATCH  = (50, 36, 20)        # dark brown lines, barely visible
    HATCH2 = (42, 30, 16)
    gap = 14
    for i in range(-CARD_H, CARD_W + CARD_H, gap):
        d.line([(max(6, i), 6), (min(CARD_W - 7, i + CARD_H), min(CARD_H - 7, 6 + CARD_H - max(0, 6 - i)))], fill=HATCH)
    for i in range(CARD_W + CARD_H, -CARD_H, -gap):
        x0 = max(6, i - CARD_H)
        y0 = max(6, CARD_H - i)
        x1 = min(CARD_W - 7, i)
        y1 = min(CARD_H - 7, CARD_H - (i - CARD_W))
        d.line([(x0, y0), (x1, y1)], fill=HATCH2)

    # ── Central emblem: a diamond frame ───────────────────────────────────────
    cx, cy = CARD_W // 2, CARD_H // 2  # 80, 110
    GOLD   = (210, 160,  30)
    GOLD_H = (255, 220,  80)
    GOLD_S = (140, 100,  10)
    RUST   = ( 90,  50,  15)

    # Diamond outline (rotated square)
    DR = 42   # diamond radius
    diamond = [(cx, cy - DR), (cx + DR, cy), (cx, cy + DR), (cx - DR, cy)]
    d.polygon(diamond, outline=GOLD)
    d.polygon([(cx, cy - DR + 2), (cx + DR - 2, cy), (cx, cy + DR - 2), (cx - DR + 2, cy)], outline=GOLD_S)

    # Inner filled diamond (slightly smaller)
    DR2 = 30
    d.polygon([(cx, cy - DR2), (cx + DR2, cy), (cx, cy + DR2), (cx - DR2, cy)], fill=RUST)

    # ── 6-point star inside diamond ───────────────────────────────────────────
    import math
    def star_pts(ox, oy, r_outer, r_inner, n=6):
        pts = []
        for i in range(n * 2):
            angle = math.pi / n * i - math.pi / 2
            r = r_outer if i % 2 == 0 else r_inner
            pts.append((int(ox + r * math.cos(angle)), int(oy + r * math.sin(angle))))
        return pts

    d.polygon(star_pts(cx, cy, 22, 10), fill=GOLD)
    # Star highlight
    d.polygon(star_pts(cx, cy, 20,  8), fill=GOLD_H, outline=GOLD_S)
    # Centre dot
    d.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=RUST, outline=GOLD_S)

    # ── Corner pip diamonds (small) ────────────────────────────────────────────
    for px, py in [(20, 20), (CARD_W - 20, 20), (20, CARD_H - 20), (CARD_W - 20, CARD_H - 20)]:
        pr = 6
        d.polygon([(px, py - pr), (px + pr, py), (px, py + pr), (px - pr, py)], fill=GOLD)
        d.polygon([(px, py - pr + 1), (px + pr - 1, py), (px, py + pr - 1), (px - pr + 1, py)], fill=RUST)

    # ── Top / Bottom text bands ────────────────────────────────────────────────
    fill_rect(d, 6, 6, CARD_W - 7, 22, BANNER_BG)
    d.line([(6, 22), (CARD_W - 7, 22)], fill=CARD_BORDER_SH)
    fill_rect(d, 6, CARD_H - 23, CARD_W - 7, CARD_H - 7, BANNER_BG)
    d.line([(6, CARD_H - 23), (CARD_W - 7, CARD_H - 23)], fill=CARD_BORDER_SH)

    # "W" brand mark centred in each band (tiny pixel letters)
    # Top — draw a simple gold horizontal line accent
    d.line([(cx - 20, 14), (cx + 20, 14)], fill=GOLD)
    d.line([(cx -  8, 12), (cx +  8, 12)], fill=GOLD_H)
    d.line([(cx - 20, CARD_H - 16), (cx + 20, CARD_H - 16)], fill=GOLD)
    d.line([(cx -  8, CARD_H - 14), (cx +  8, CARD_H - 14)], fill=GOLD_H)

    out = os.path.join(OUTPUT_DIR, "card_back.png")
    img.save(out)
    print(f"  Saved: {out}")
    return img


# ─── Main ─────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("Generating pixel art card UI assets...")
    build_card_bg()
    for rarity, colors in RARITY_COLORS.items():
        build_art_frame(rarity, colors)
    build_card_back()
    print("Done! Assets saved to:", OUTPUT_DIR)
    print()
    print("Art frame position on card:")
    print(f"  x={ART_X0}, y={ART_Y0}  to  x={ART_X1}, y={ART_Y1}  ({ART_W}x{ART_H}px)")
