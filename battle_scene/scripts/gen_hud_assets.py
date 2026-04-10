"""
Generate pixel art HUD assets for the Wasteland card game.
Produces:
  - hp_bar_frame.png : Gritty brown frame for the HP bar.
  - hp_bar_fill.png  : Green fill texture for the HP bar.
  - block_badge.png  : Pixel-art shield icon background.
  - intent_attack.png : Jagged red sword icon.
  - intent_block.png  : Steel blue shield icon.
  - intent_buff.png   : Upward green arrow icon.
"""

from PIL import Image, ImageDraw
import os

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "images", "ui")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# ─── Palette ──────────────────────────────────────────────────────────────────
COLOR_FRAME_OUTER = (40, 30, 20)  # Dark shadow
COLOR_FRAME_MAIN  = (100, 75, 50) # Gritty brown
COLOR_FRAME_HI    = (150, 120, 90)# Highlight
COLOR_BG          = (20, 15, 10)  # Near black background

COLOR_HP_FILL     = (40, 180, 60) # Main green
COLOR_HP_HI       = (80, 220, 100)# Green highlight
COLOR_HP_SH       = (20, 100, 30) # Green shadow

COLOR_BLOCK_MAIN  = (50, 120, 220)# Blue
COLOR_BLOCK_HI    = (120, 180, 255)# Light blue
COLOR_BLOCK_SH    = (20, 60, 140) # Dark blue

def draw_nine_patch(draw, w, h, main, hi, sh, thick=2):
    # Base fill
    draw.rectangle([0, 0, w-1, h-1], fill=main)
    # Highlights (Top/Left)
    for i in range(thick):
        draw.line([(i, i), (w-1-i, i)], fill=hi)
        draw.line([(i, i), (i, h-1-i)], fill=hi)
    # Shadows (Bottom/Right)
    for i in range(thick):
        draw.line([(i, h-1-i), (w-1-i, h-1-i)], fill=sh)
        draw.line([(w-1-i, i), (w-1-i, h-1-i)], fill=sh)

# ─── 1. HP Bar Frame ──────────────────────────────────────────────────────────
def build_hp_bar_frame():
    # We'll make it small (24x12) for NinePatch scaling
    w, h = 24, 12
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    
    # Outer dark shadow
    d.rectangle([0, 0, w-1, h-1], fill=COLOR_FRAME_OUTER)
    # Main frame
    draw_nine_patch(d, w, h, COLOR_FRAME_MAIN, COLOR_FRAME_HI, COLOR_FRAME_OUTER, thick=1)
    # Dark background center
    d.rectangle([2, 2, w-3, h-3], fill=COLOR_BG)
    
    out = os.path.join(OUTPUT_DIR, "hp_bar_frame.png")
    img.save(out)
    print(f"  Saved: {out}")

# ─── 2. HP Bar Fill ───────────────────────────────────────────────────────────
def build_hp_bar_fill():
    # Just a small pattern tile
    w, h = 8, 8
    img = Image.new("RGBA", (w, h), COLOR_HP_FILL)
    d = ImageDraw.Draw(img)
    # Add a little "pixel highlight" at top
    d.line([(0,0), (w-1, 0)], fill=COLOR_HP_HI)
    # Dark shadow at bottom
    d.line([(0,h-1), (w-1, h-1)], fill=COLOR_HP_SH)
    
    out = os.path.join(OUTPUT_DIR, "hp_bar_fill.png")
    img.save(out)
    print(f"  Saved: {out}")

# ─── 3. Block Badge ───────────────────────────────────────────────────────────
def build_block_badge():
    w, h = 32, 32
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    
    # Simple shield shape (crude pixel art)
    points = [
        (4, 2), (w-5, 2), # Top
        (w-3, 6), (w-3, 16), # Right
        (16, h-3), (2, 16), (2, 6) # Bottom point and left
    ]
    d.polygon(points, fill=COLOR_BLOCK_MAIN)
    
    # Edge lines
    d.line([(4, 2), (w-5, 2)], fill=COLOR_BLOCK_HI)
    d.line([(4, 2), (2, 6), (2, 16), (16, h-3)], fill=COLOR_BLOCK_HI) # Left/Top side
    d.line([(w-5, 2), (w-3, 6), (w-3, 16), (16, h-3)], fill=COLOR_BLOCK_SH) # Right/Bottom side
    
    out = os.path.join(OUTPUT_DIR, "block_badge.png")
    img.save(out)
    print(f"  Saved: {out}")

# ─── 4. Intent Icons ──────────────────────────────────────────────────────────
def build_intent_icons():
    # Icons are 24x24
    def start_img():
        return Image.new("RGBA", (24, 24), (0, 0, 0, 0))

    # Attack Icon (Sword)
    img = start_img()
    d = ImageDraw.Draw(img)
    pts = [(4,20), (20,4), (22,3), (18,6), (4,20)]
    d.polygon(pts, fill=(200, 40, 40))
    d.line([(4,20), (20,4)], fill=(255,100,100), width=1)
    d.rectangle([2,18,6,22], fill=(120,80,40)) 
    img.save(os.path.join(OUTPUT_DIR, "intent_attack.png"))
    
    # Block Icon (Shield)
    img = start_img()
    d = ImageDraw.Draw(img)
    pts = [(4,4), (20,4), (20,14), (12,22), (4,14)]
    d.polygon(pts, fill=COLOR_BLOCK_MAIN)
    d.line([(4,4), (20,4), (20,14), (12,22), (4,14), (4,4)], fill=COLOR_BLOCK_HI)
    img.save(os.path.join(OUTPUT_DIR, "intent_block.png"))
    
    # Buff Icon (Arrow)
    img = start_img()
    d = ImageDraw.Draw(img)
    d.polygon([(12,2), (22,12), (18,12), (18,22), (6,22), (6,12), (2,12)], fill=(40, 180, 60))
    d.line([(12,2), (22,12), (18,12), (18,22), (6,22), (6,12), (2,12), (12,2)], fill=(150, 255, 150))
    img.save(os.path.join(OUTPUT_DIR, "intent_buff.png"))
    
    print("  Saved: intent icons")

if __name__ == "__main__":
    print("Generating pixel art HUD assets...")
    build_hp_bar_frame()
    build_hp_bar_fill()
    build_block_badge()
    build_intent_icons()
    print("Done!")
