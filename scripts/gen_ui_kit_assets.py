#!/usr/bin/env python3
"""Generate the requested windowed UI kit PNG assets.

The spec in docs/asset-spec-ui-kit.md asks for exact bitmap contracts with
transparent backgrounds and 9-slice-safe mid sections. This generator keeps the
assets deterministic and reproducible.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "run_system" / "assets" / "images" / "ui_kit"
PREVIEW_DIR = ROOT / "docs" / "art" / "previews"
CONTACT = PREVIEW_DIR / "ui_kit_20260704_contact.png"
SCALE = 4


def rgba(hex_color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    hex_color = hex_color.lstrip("#")
    return (
        int(hex_color[0:2], 16),
        int(hex_color[2:4], 16),
        int(hex_color[4:6], 16),
        alpha,
    )


OUTLINE = rgba("#100a06")
OUTLINE_SOFT = rgba("#1a120a")
BLACK = rgba("#050403")
WINDOW_BG = rgba("#14100a")
TITLE_BG = rgba("#221610")
INSET_BG = rgba("#0e0b07")
INSET_SHADOW = rgba("#080604")
PLATE = rgba("#2a1c11")
PLATE_LIGHT = rgba("#352415")
PLATE_DARK = rgba("#1a1009")
BRASS = rgba("#9a7334")
BRASS_LIGHT = rgba("#d1a052")
BRASS_DARK = rgba("#4a3519")
BRASS_DIM = rgba("#6b5228")
CYAN = rgba("#49d1e6")
TOXIC = rgba("#82cf4c")
RED_CLAY = rgba("#743026")
RED_CLAY_LIGHT = rgba("#9a4534")
RED_CLAY_DARK = rgba("#431b17")
LOCK_BODY = rgba("#6e5427")


class Canvas:
    def __init__(self, width: int, height: int) -> None:
        self.width = width
        self.height = height
        self.image = Image.new("RGBA", (width * SCALE, height * SCALE), (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.image)

    def xy(self, values) -> tuple[int, ...]:
        return tuple(int(round(v * SCALE)) for v in values)

    def rr(
        self,
        box,
        radius: int,
        fill,
        outline=None,
        width: int = 1,
    ) -> None:
        self.draw.rounded_rectangle(
            self.xy(box),
            radius=radius * SCALE,
            fill=fill,
            outline=outline,
            width=max(1, width * SCALE),
        )

    def rect(self, box, fill, outline=None, width: int = 1) -> None:
        self.draw.rectangle(
            self.xy(box),
            fill=fill,
            outline=outline,
            width=max(1, width * SCALE),
        )

    def ellipse(self, box, fill, outline=None, width: int = 1) -> None:
        self.draw.ellipse(
            self.xy(box),
            fill=fill,
            outline=outline,
            width=max(1, width * SCALE),
        )

    def line(self, points, fill, width: int = 1) -> None:
        self.draw.line(self.xy(points), fill=fill, width=max(1, width * SCALE), joint="curve")

    def polygon(self, points, fill, outline=None) -> None:
        self.draw.polygon([self.xy(p) for p in points], fill=fill, outline=outline)

    def save(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        self.image = self.image.resize((self.width, self.height), Image.Resampling.LANCZOS)
        self.image.save(path)


def add_corner_bolts(c: Canvas, w: int, h: int, inset_x: int, inset_y: int, r: int = 7) -> None:
    for cx, cy in (
        (inset_x, inset_y),
        (w - inset_x, inset_y),
        (inset_x, h - inset_y),
        (w - inset_x, h - inset_y),
    ):
        c.ellipse((cx - r, cy - r, cx + r, cy + r), OUTLINE)
        c.ellipse((cx - r + 2, cy - r + 2, cx + r - 2, cy + r - 2), BRASS)
        c.ellipse((cx - 2, cy - 2, cx + 2, cy + 2), BRASS_DARK)


def add_corner_brackets(c: Canvas, w: int, h: int, size: int = 18, inset: int = 13) -> None:
    pairs = [
        ((inset, inset), (inset + size, inset), (inset, inset + size)),
        ((w - inset, inset), (w - inset - size, inset), (w - inset, inset + size)),
        ((inset, h - inset), (inset + size, h - inset), (inset, h - inset - size)),
        ((w - inset, h - inset), (w - inset - size, h - inset), (w - inset, h - inset - size)),
    ]
    for corner, horizontal, vertical in pairs:
        c.line((*corner, *horizontal), BRASS_LIGHT, 3)
        c.line((*corner, *vertical), BRASS_DARK, 3)


def panel_window() -> None:
    c = Canvas(192, 192)
    c.rr((2, 2, 190, 190), 18, OUTLINE)
    c.rr((7, 7, 185, 185), 14, BRASS_DARK)
    c.rr((12, 12, 180, 180), 11, PLATE)
    c.rr((23, 23, 169, 169), 7, WINDOW_BG)
    c.line((24, 24, 168, 24), BRASS_LIGHT, 2)
    c.line((24, 168, 168, 168), BLACK, 3)
    c.line((24, 25, 24, 168), BRASS_DIM, 2)
    c.line((168, 25, 168, 168), BLACK, 2)
    add_corner_bolts(c, 192, 192, 31, 31, 7)
    add_corner_brackets(c, 192, 192, 14, 16)
    c.save(OUT_DIR / "panel_window.png")


def panel_titlebar() -> None:
    c = Canvas(192, 64)
    c.rr((2, 2, 190, 62), 12, OUTLINE)
    c.rr((7, 7, 185, 57), 9, BRASS_DARK)
    c.rr((12, 10, 180, 52), 7, TITLE_BG)
    c.rect((16, 40, 176, 47), BRASS_DIM)
    c.line((18, 13, 174, 13), BRASS_LIGHT, 2)
    c.line((18, 51, 174, 51), BLACK, 3)
    for cx in (28, 164):
        for cy in (18, 46):
            c.ellipse((cx - 5, cy - 5, cx + 5, cy + 5), OUTLINE)
            c.ellipse((cx - 3, cy - 3, cx + 3, cy + 3), BRASS)
    c.save(OUT_DIR / "panel_window_titlebar.png")


def panel_inset() -> None:
    c = Canvas(192, 192)
    c.rr((2, 2, 190, 190), 18, OUTLINE)
    c.rr((8, 8, 184, 184), 14, BRASS_DARK)
    c.rr((16, 16, 176, 176), 9, INSET_BG)
    c.line((18, 18, 174, 18), INSET_SHADOW, 6)
    c.line((18, 18, 18, 174), INSET_SHADOW, 6)
    c.line((18, 174, 174, 174), BRASS_DIM, 2)
    c.line((174, 18, 174, 174), BRASS_DIM, 2)
    for cx, cy in ((31, 31), (161, 31), (31, 161), (161, 161)):
        c.ellipse((cx - 5, cy - 5, cx + 5, cy + 5), OUTLINE_SOFT)
        c.ellipse((cx - 3, cy - 3, cx + 3, cy + 3), rgba("#3b2d17"))
    add_corner_brackets(c, 192, 192, 13, 17)
    c.save(OUT_DIR / "panel_inset.png")


def panel_bottom_bar() -> None:
    c = Canvas(384, 96)
    c.rr((2, 4, 382, 92), 15, OUTLINE)
    c.rr((8, 10, 376, 86), 11, BRASS_DARK)
    c.rr((15, 18, 369, 80), 8, TITLE_BG)
    c.rect((16, 18, 368, 25), BRASS)
    c.line((18, 25, 366, 25), BRASS_LIGHT, 2)
    c.line((18, 79, 366, 79), BLACK, 3)
    for cx in (34, 350):
        for cy in (31, 66):
            c.ellipse((cx - 6, cy - 6, cx + 6, cy + 6), OUTLINE)
            c.ellipse((cx - 4, cy - 4, cx + 4, cy + 4), BRASS)
    c.save(OUT_DIR / "panel_bottom_bar.png")


def button(path: str, accent: bool, state: str) -> None:
    c = Canvas(144, 56)
    if accent:
        body = RED_CLAY
        body_light = RED_CLAY_LIGHT
        body_dark = RED_CLAY_DARK
        rim = rgba("#bd8c3e")
        rim_light = rgba("#efbd62")
    else:
        body = PLATE
        body_light = PLATE_LIGHT
        body_dark = PLATE_DARK
        rim = BRASS
        rim_light = BRASS_LIGHT
    if state == "hover":
        rim = rim_light
        top_accent = CYAN if not accent else TOXIC
        body = body_light
    elif state == "pressed":
        rim = BRASS_DARK
        top_accent = None
        body = body_dark
    else:
        top_accent = None

    c.rr((1, 2, 143, 54), 12, OUTLINE)
    c.rr((5, 6, 139, 50), 9, rim)
    c.rr((10, 11, 134, 44), 6, body)
    lip_top = 36 if state != "pressed" else 39
    c.rect((11, lip_top, 133, 45), body_dark)
    c.line((13, 13, 131, 13), rim_light if state != "pressed" else BRASS_DIM, 2)
    c.line((13, 45, 131, 45), BLACK, 3)
    if top_accent:
        c.line((19, 9, 125, 9), top_accent, 2)
    for cx in (19, 125):
        for cy in (20, 36):
            c.ellipse((cx - 4, cy - 4, cx + 4, cy + 4), OUTLINE_SOFT)
            c.ellipse((cx - 2, cy - 2, cx + 2, cy + 2), rim_light if state == "hover" else rim)
    c.save(OUT_DIR / path)


def slot(path: str, state: str) -> None:
    c = Canvas(96, 96)
    rim = BRASS if state != "normal" else BRASS_DIM
    if state == "hover":
        rim = BRASS_LIGHT
    c.rr((2, 2, 94, 94), 10, OUTLINE)
    c.rr((7, 7, 89, 89), 7, rim)
    c.rr((14, 14, 82, 82), 5, INSET_BG)
    c.line((16, 16, 80, 16), BLACK, 4)
    c.line((16, 80, 80, 80), BRASS_DIM, 2)
    add_corner_brackets(c, 96, 96, 9, 12)
    if state == "hover":
        c.line((18, 12, 78, 12), CYAN, 2)
    if state == "locked":
        c.rr((17, 35, 79, 65), 4, rgba("#2f2517"), OUTLINE_SOFT, 2)
        c.line((22, 42, 74, 58), BRASS_DARK, 4)
        c.line((22, 58, 74, 42), rgba("#533d1d"), 3)
        draw_lock(c, 48, 52, 30, 30)
    c.save(OUT_DIR / path)


def draw_lock(c: Canvas, cx: int, cy: int, w: int, h: int) -> None:
    left = cx - w // 2
    top = cy - h // 2
    # Shackle.
    c.line((left + 7, top + 14, left + 7, top + 9), OUTLINE, 6)
    c.line((left + 7, top + 9, cx, top + 4), OUTLINE, 6)
    c.line((cx, top + 4, left + w - 7, top + 9), OUTLINE, 6)
    c.line((left + w - 7, top + 9, left + w - 7, top + 14), OUTLINE, 6)
    c.line((left + 8, top + 14, left + 8, top + 10), BRASS_LIGHT, 3)
    c.line((left + 8, top + 10, cx, top + 7), BRASS_LIGHT, 3)
    c.line((cx, top + 7, left + w - 8, top + 10), BRASS_LIGHT, 3)
    c.line((left + w - 8, top + 10, left + w - 8, top + 14), BRASS_LIGHT, 3)
    # Body.
    c.rr((left + 3, top + 13, left + w - 3, top + h - 2), 4, OUTLINE)
    c.rr((left + 7, top + 17, left + w - 7, top + h - 5), 3, LOCK_BODY)
    c.ellipse((cx - 3, top + 23, cx + 3, top + 29), BLACK)
    c.rect((cx - 1, top + 27, cx + 1, top + 34), BLACK)


def icon_lock() -> None:
    c = Canvas(48, 48)
    draw_lock(c, 24, 25, 34, 36)
    c.save(OUT_DIR / "icon_lock.png")


def arrow(name: str, direction: int) -> None:
    c = Canvas(48, 48)
    if direction < 0:
        pts = [(30, 9), (14, 24), (30, 39), (35, 33), (25, 24), (35, 15)]
    else:
        pts = [(18, 9), (34, 24), (18, 39), (13, 33), (23, 24), (13, 15)]
    c.polygon(pts, OUTLINE)
    inner = [(x + (2 if direction < 0 else -2), y) for x, y in pts]
    c.polygon(inner, BRASS_LIGHT)
    c.line((24, 11, 24, 37), BRASS_DARK, 2)
    c.save(OUT_DIR / name)


def contact_sheet() -> None:
    files = [
        "panel_window.png",
        "panel_window_titlebar.png",
        "panel_inset.png",
        "panel_bottom_bar.png",
        "btn_brass_normal.png",
        "btn_brass_hover.png",
        "btn_brass_pressed.png",
        "btn_accent_normal.png",
        "btn_accent_hover.png",
        "btn_accent_pressed.png",
        "slot_normal.png",
        "slot_hover.png",
        "slot_locked.png",
        "icon_lock.png",
        "icon_arrow_left.png",
        "icon_arrow_right.png",
    ]
    cell_w, cell_h = 220, 150
    sheet = Image.new("RGBA", (cell_w * 4, cell_h * 4), rgba("#20160d"))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("arial.ttf", 13)
    except OSError:
        font = ImageFont.load_default()
    for idx, file_name in enumerate(files):
        x = (idx % 4) * cell_w
        y = (idx // 4) * cell_h
        draw.rectangle((x + 8, y + 8, x + cell_w - 8, y + cell_h - 8), fill=rgba("#0c0906"))
        img = Image.open(OUT_DIR / file_name).convert("RGBA")
        scale = min((cell_w - 42) / img.width, (cell_h - 48) / img.height, 1.6)
        preview = img.resize(
            (max(1, int(img.width * scale)), max(1, int(img.height * scale))),
            Image.Resampling.LANCZOS,
        )
        px = x + (cell_w - preview.width) // 2
        py = y + 16
        sheet.alpha_composite(preview, (px, py))
        draw.text((x + 14, y + cell_h - 24), file_name, fill=rgba("#e8c887"), font=font)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(CONTACT)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    panel_window()
    panel_titlebar()
    panel_inset()
    panel_bottom_bar()
    for state in ("normal", "hover", "pressed"):
        button(f"btn_brass_{state}.png", False, state)
        button(f"btn_accent_{state}.png", True, state)
    slot("slot_normal.png", "normal")
    slot("slot_hover.png", "hover")
    slot("slot_locked.png", "locked")
    icon_lock()
    arrow("icon_arrow_left.png", -1)
    arrow("icon_arrow_right.png", 1)
    contact_sheet()


if __name__ == "__main__":
    main()
