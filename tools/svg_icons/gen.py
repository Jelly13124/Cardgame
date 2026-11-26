"""Hand-inked SVG icon generator: the source of truth for the UI icon set.

Run:  python tools/svg_icons/gen.py      (writes tools/svg_icons/svg/*.svg + manifest.json)
Then: godot --headless --path . --script res://tools/svg_icons/rasterize.gd
      godot --headless --path . --import
The rasteriser renders each SVG with Godot's own SVG renderer (ThorVG) into the
existing PNG path listed in MANIFEST, so scenes, uids and tests keep working.

Each icon is built from simple shapes in a 64x64 box. Every outline is
resampled and nudged along its normal by smooth deterministic noise, then
drawn as a Catmull-Rom curve, so lines wobble like the enemy roster's ink.

Layer recipe per filled shape (matches the roster's flat cel look):
  1. ink "drop": the silhouette in ink, offset down-right -> heavier line on
     the shadow side;
  2. shade colour clipped to the silhouette;
  3. base colour, same silhouette shifted up-left, clipped -> one shadow
     crescent on the lower-right;
  4. ink outline stroke on top.
"""
import math
import random
import pathlib

import json

OUT = pathlib.Path(__file__).parent / "svg"
OUT.mkdir(exist_ok=True)
CREAM = "#efe2c4"     # map "stamp" icons: paper fill + ink, so the legend can tint them
CREAM_SH = "#d3be92"

INK = "#1d1611"
LINE = 3.0      # main outline width in the 64 box
DETAIL = 1.7    # interior line width
DROP = (1.1, 1.3)


# ---------------------------------------------------------------- geometry
def circle_pts(cx, cy, rx, ry=None, n=48, rot=0.0):
    ry = rx if ry is None else ry
    out = []
    for i in range(n):
        a = rot + 2 * math.pi * i / n
        out.append((cx + rx * math.cos(a), cy + ry * math.sin(a)))
    return out


def resample(pts, step, closed=True):
    seq = pts + [pts[0]] if closed else list(pts)
    out = []
    for (x0, y0), (x1, y1) in zip(seq, seq[1:]):
        d = math.hypot(x1 - x0, y1 - y0)
        n = max(1, int(round(d / step)))
        for k in range(n):
            t = k / n
            out.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t))
    if not closed:
        out.append(seq[-1])
    return out


def wobble(pts, rng, amp=0.55, closed=True, step=2.2):
    pts = resample(pts, step, closed)
    n = len(pts)
    f1, f2 = rng.uniform(1.5, 3.0), rng.uniform(5.0, 8.0)
    p1, p2 = rng.uniform(0, 6.3), rng.uniform(0, 6.3)
    out = []
    for i, (x, y) in enumerate(pts):
        a = pts[i - 1] if (closed or i > 0) else pts[i]
        b = pts[(i + 1) % n] if (closed or i < n - 1) else pts[i]
        tx, ty = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(tx, ty) or 1.0
        nx, ny = -ty / ln, tx / ln
        t = i / n
        d = amp * (0.65 * math.sin(2 * math.pi * f1 * t + p1) + 0.35 * math.sin(2 * math.pi * f2 * t + p2))
        if not closed:  # taper the ends so strokes start/stop clean
            d *= min(1.0, 4 * min(t, 1 - t) + 0.2)
        out.append((x + nx * d, y + ny * d))
    return out


def curve(pts, closed=True):
    """Catmull-Rom through pts -> SVG path data."""
    n = len(pts)
    f = lambda p: f"{p[0]:.2f},{p[1]:.2f}"
    d = [f"M{f(pts[0])}"]
    rng_ = range(n) if closed else range(n - 1)
    for i in rng_:
        p0 = pts[i - 1] if (closed or i > 0) else pts[i]
        p1 = pts[i]
        p2 = pts[(i + 1) % n]
        p3 = pts[(i + 2) % n] if (closed or i + 2 < n) else p2
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d.append(f"C{f(c1)} {f(c2)} {f(p2)}")
    if closed:
        d.append("Z")
    return "".join(d)


def xform(pts, rot_deg=0.0, cx=32, cy=32, dx=0, dy=0, sx=1.0, sy=1.0):
    a = math.radians(rot_deg)
    ca, sa = math.cos(a), math.sin(a)
    out = []
    for x, y in pts:
        x, y = (x - cx) * sx, (y - cy) * sy
        out.append((cx + x * ca - y * sa + dx, cy + x * sa + y * ca + dy))
    return out


def rrect(x0, y0, x1, y1, r, n=4):
    pts = []
    for cx, cy, a0 in [(x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)]:
        for k in range(n + 1):
            a = math.radians(a0 + 90 * k / n)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def star_pts(cx, cy, R, r, n=5, rot=-90.0):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot + 180.0 * i / n)
        rad = R if i % 2 == 0 else r
        pts.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))
    return pts


def mirror(pts, cx=32):
    return [(2 * cx - x, y) for x, y in reversed(pts)]


# ---------------------------------------------------------------- icon doc
class Icon:
    def __init__(self, name, seed):
        self.name = name
        self.rng = random.Random(seed)
        self.defs = []
        self.body = []
        self._clip = 0

    def shape(self, outlines, base, shade=None, shift=(-2.2, -2.4), line=LINE, amp=0.55, drop=True):
        """outlines: list of point loops (first = outer, rest = holes)."""
        loops = [wobble(o, self.rng, amp) for o in outlines]
        d = "".join(curve(l) for l in loops)
        if drop:
            self.body.append(
                f'<path d="{d}" fill="{INK}" fill-rule="evenodd" transform="translate({DROP[0]},{DROP[1]})"/>'
            )
        if shade:
            self._clip += 1
            cid = f"c{self._clip}"
            self.defs.append(f'<clipPath id="{cid}"><path d="{d}" clip-rule="evenodd"/></clipPath>')
            self.body.append(f'<g clip-path="url(#{cid})">')
            self.body.append(f'<path d="{d}" fill="{shade}" fill-rule="evenodd"/>')
            self.body.append(
                f'<path d="{d}" fill="{base}" fill-rule="evenodd" transform="translate({shift[0]},{shift[1]})"/>'
            )
            self.body.append("</g>")
        else:
            self.body.append(f'<path d="{d}" fill="{base}" fill-rule="evenodd"/>')
        self.body.append(
            f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="{line}" stroke-linejoin="round"/>'
        )
        return d

    def flat(self, outline, color, amp=0.35):
        d = curve(wobble(outline, self.rng, amp))
        self.body.append(f'<path d="{d}" fill="{color}"/>')

    def line(self, pts, width=DETAIL, color=INK, amp=0.35, cap="round"):
        d = curve(wobble(pts, self.rng, amp, closed=False, step=1.8), closed=False)
        self.body.append(
            f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linecap="{cap}" stroke-linejoin="round"/>'
        )

    def glyph_stroke(self, pts, width=7.0, closed=False):
        """Mono glyph: a fat ink stroke (tintable with modulate)."""
        d = curve(wobble(pts, self.rng, 0.45, closed=closed, step=1.8), closed=closed)
        self.body.append(
            f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"/>'
        )

    def glyph_fill(self, pts):
        d = curve(wobble(pts, self.rng, 0.45))
        self.body.append(f'<path d="{d}" fill="{INK}" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>')

    def outlined_stroke(self, pts, color, inner=6.5, ink=11.0, amp=0.35):
        """A fat coloured stroke with an ink rim (question marks, Z letters)."""
        d = curve(wobble(pts, self.rng, amp, closed=False, step=1.8), closed=False)
        style = f'fill="none" stroke-linecap="round" stroke-linejoin="round"'
        self.body.append(f'<path d="{d}" {style} stroke="{INK}" stroke-width="{ink}" transform="translate({DROP[0] * 0.6},{DROP[1] * 0.6})"/>')
        self.body.append(f'<path d="{d}" {style} stroke="{INK}" stroke-width="{ink}"/>')
        self.body.append(f'<path d="{d}" {style} stroke="{color}" stroke-width="{inner}"/>')

    def save(self, plate=False):
        inner = "".join(self.body)
        if plate:
            # cream button plate (same colours as button_secondary_base), icon inset
            pr = random.Random(sum(map(ord, self.name)))
            d = curve(wobble(rrect(4, 4, 60, 60, 7), pr, 0.45))
            inner = (
                f'<path d="{d}" fill="{INK}" transform="translate(1.0,1.4)"/>'
                f'<path d="{d}" fill="#f4e8cb" stroke="{INK}" stroke-width="2.6" stroke-linejoin="round"/>'
                f'<g transform="translate(13.5,13.5) scale(0.58)">{inner}</g>'
            )
        svg = (
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">'
            + (f"<defs>{''.join(self.defs)}</defs>" if self.defs else "")
            + inner
            + "</svg>\n"
        )
        (OUT / f"{self.name}.svg").write_text(svg, encoding="utf-8")


# ---------------------------------------------------------------- icons
def gear(name="gear", plate=False):
    ic = Icon(name, 11)
    teeth, R, r = 8, 27.0, 20.5
    pts = []
    for i in range(teeth):
        a0 = 2 * math.pi * i / teeth - math.pi / 2
        w = 0.17
        rr = R - (3.0 if i == 3 else 0.0)   # one chipped tooth
        tilt = 0.06 if i == 3 else 0.0
        for a, rad in [(a0 - 0.27, r), (a0 - w + tilt, rr), (a0 + w + tilt, rr), (a0 + 0.27, r)]:
            pts.append((32 + rad * math.cos(a), 32 + rad * math.sin(a)))
    pts = xform(pts, rot_deg=-6)
    hole = list(reversed(circle_pts(32.5, 31.5, 8.2, 7.6, n=28)))
    ic.shape([pts, hole], "#b4ab99", "#7c7466")
    # a welded seam and a bolt: the "purposeful dents / seams" accent
    ic.line([(17.5, 40.5), (21.5, 37.5)], width=1.6)
    ic.line([(19.0, 42.5), (23.0, 39.5)], width=1.6)
    ic.flat(circle_pts(43.5, 22.0, 1.7, n=10), INK)
    ic.save(plate)


def globe(name="globe", plate=False):
    ic = Icon(name, 23)
    ball = circle_pts(32, 32, 24.5, 24.0, n=52)
    ic.shape([ball], "#74b7b6", "#4b8c90")
    # land: two flat blobs, clipped by being inside the ball outline
    ic.flat([(20, 16), (29, 13), (33, 19), (28, 26), (31, 32), (24, 36), (17, 30), (13, 23)], "#a6bf5d")
    ic.flat([(37, 34), (46, 31), (51, 38), (46, 47), (39, 50), (35, 44)], "#a6bf5d")
    # meridian + parallels, slightly crooked
    ic.line([(32.5, 8.5), (28.5, 20), (27.8, 32), (29, 44), (32, 55.5)], width=1.4)
    ic.line([(9.5, 28.5), (22, 26.5), (34, 26.2), (46, 27.2), (55, 29.5)], width=1.4)
    ic.line([(12, 42), (24, 41.5), (36, 41.8), (51, 43)], width=1.4)
    ic.line([(16, 15.5), (12.5, 18)], width=1.5)
    # outline on top again so the land edges sit under the ink rim
    ic.body.append(
        f'<path d="{curve(wobble(ball, random.Random(5), 0.55))}" fill="none" stroke="{INK}" stroke-width="{LINE}"/>'
    )
    ic.save(plate)


def card_rect(x0, y0, x1, y1):
    return [(x0, y0), ((x0 + x1) / 2, y0), (x1, y0), (x1, (y0 + y1) / 2), (x1, y1), ((x0 + x1) / 2, y1), (x0, y1), (x0, (y0 + y1) / 2)]


def deck():
    ic = Icon("deck", 37)
    under2 = xform(card_rect(17, 11, 49, 55), rot_deg=12, dx=3, dy=1)
    under1 = xform(card_rect(17, 11, 49, 55), rot_deg=5, dx=1.5, dy=0.5)
    top = xform(card_rect(17, 11, 49, 55), rot_deg=-6, dx=-2.5)
    ic.shape([under2], "#e6d3a8", "#bca57a", line=2.6)
    ic.shape([under1], "#e6d3a8", "#bca57a", line=2.6)
    ic.shape([top], "#c75a3b", "#97412b")
    inner = xform(card_rect(21.5, 16, 44.5, 50), rot_deg=-6, dx=-2.5)
    ic.line(inner + [inner[0]], width=1.5, color="#f1dfb8", amp=0.3)
    cap = []
    for i in range(16):  # tiny crimped bottlecap emblem
        a = 2 * math.pi * i / 16
        rad = 7.0 if i % 2 == 0 else 5.6
        cap.append((33 + rad * math.cos(a), 33 + rad * math.sin(a)))
    cap = xform(cap, rot_deg=-6, dx=-2.5)
    ic.shape([cap], "#f1dfb8", "#d1b98a", shift=(-1.2, -1.2), line=1.8, drop=False, amp=0.25)
    ic.flat(xform(circle_pts(33, 33, 2.4, n=10), rot_deg=-6, dx=-2.5), "#97412b", amp=0.15)
    ic.save()


def bottlecap():
    ic = Icon("bottlecap", 41)
    # crimped skirt: deep teeth all round, seen from slightly above
    skirt = []
    n = 42
    for i in range(n):
        a = 2 * math.pi * i / n
        rad = 25.8 if i % 2 == 0 else 23.6
        skirt.append((32 + rad * math.cos(a), 37 + rad * 0.74 * math.sin(a)))
    ic.shape([skirt], "#c4452f", "#8f2c1e", shift=(-1.2, -2.8), amp=0.3)
    # ridges on the front of the skirt
    for deg in range(14, 175, 17):
        a = math.radians(deg)
        x0, y0 = 31.5 + 21.5 * math.cos(a), 31 + 15.5 * math.sin(a)
        x1, y1 = 32 + 24.5 * math.cos(a), 37 + 24.5 * 0.74 * math.sin(a)
        ic.line([(x0, y0), (x1, y1)], width=1.5, amp=0.15)
    top = circle_pts(31.5, 31, 22, 16, n=44, rot=0.2)
    ic.shape([top], "#e05a40", "#b8432f", shift=(-2.0, -2.0), line=2.6, drop=False)
    # highlight streak + a dent mark
    ic.line([(16.5, 28), (20.5, 22.5), (27, 19.5)], width=2.2, color="#f6b29a", amp=0.2)
    ic.line([(39.5, 35), (43.5, 33.2)], width=1.5)
    ic.save()


def heart():
    ic = Icon("heart", 53)
    pts = []
    for i in range(60):
        t = 2 * math.pi * i / 60
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        pts.append((32 + x * 1.48, 31 + y * 1.48))
    pts = xform(pts, rot_deg=-5)
    ic.shape([pts], "#dc4a3b", "#a62f28")
    # stitched patch across one lobe
    patch = xform(card_rect(35, 17, 47, 27), rot_deg=-28)
    ic.shape([patch], "#ead3a3", "#c7ab78", shift=(-1, -1), line=1.8, drop=False)
    for k in range(3):
        x = 37.5 + k * 3.6
        ic.line(xform([(x, 15.5), (x, 18.6)], rot_deg=-28), width=1.3)
    ic.line([(16, 24), (18.5, 18.5), (23.5, 16)], width=2.2, color="#f2a194", amp=0.2)
    ic.save()


# ---- mono glyphs (button symbols, tinted at runtime)
def close_glyph():
    ic = Icon("glyph_close", 61)
    ic.glyph_stroke([(17, 16), (32, 31.5), (47.5, 47)], width=8.0)
    ic.glyph_stroke([(47, 17), (32.5, 32.5), (16.5, 48)], width=8.0)
    ic.save()


def refresh_glyph():
    ic = Icon("glyph_refresh", 67)
    arc1 = [(32 + 17 * math.cos(a), 32 + 17 * math.sin(a)) for a in [math.radians(d) for d in range(200, 345, 15)]]
    arc2 = [(32 + 17 * math.cos(a), 32 + 17 * math.sin(a)) for a in [math.radians(d) for d in range(20, 165, 15)]]
    ic.glyph_stroke(arc1, width=6.5)
    ic.glyph_stroke(arc2, width=6.5)
    ic.glyph_fill([(53, 18), (54.5, 33.5), (40.5, 29)])
    ic.glyph_fill([(11, 46), (9.5, 30.5), (23.5, 35)])
    ic.save()


def lock_glyph():
    ic = Icon("glyph_lock", 71)
    ic.glyph_stroke([(22, 30), (21.5, 21), (26, 13.5), (32, 11.5), (38.5, 13.5), (42.5, 20.5), (42, 30)], width=6.0)
    ic.glyph_fill([(14.5, 29), (49.5, 28.5), (50.5, 53), (14, 53.5)])
    ic.body.append('<circle cx="32" cy="39.5" r="3.6" fill="#e8d6b0"/>')
    ic.body.append('<path d="M30.6,41 L33.4,41 L34,47.5 L30,47.5 Z" fill="#e8d6b0"/>')
    ic.save()


def arrow_glyph():
    ic = Icon("glyph_arrow", 73)
    ic.glyph_fill([(10, 26), (34, 26.5), (33.5, 14), (55, 32), (34, 50.5), (34.5, 38), (10.5, 38.5)])
    ic.save()


# ---------------------------------------------------------------- top bar extras
def clock():
    ic = Icon("clock", 81)
    for cx in (16.5, 47.5):  # bells behind the body
        ic.shape([circle_pts(cx, 16, 8.5, 7.5, n=24)], "#d9a441", "#a8742a")
    ic.line([(20, 54), (15.5, 59.5)], width=3.4)
    ic.line([(44, 54), (48.5, 59.5)], width=3.4)
    ic.shape([circle_pts(32, 36, 23, 22.5, n=48)], "#d9a441", "#a8742a")
    ic.shape([circle_pts(31.5, 35.5, 17, 16.5, n=40)], "#f1e2c0", "#d6c094", shift=(-1.5, -1.6), line=2.4, drop=False)
    for k in range(12):
        a = math.radians(k * 30)
        r0 = 13.0 if k % 3 == 0 else 14.2
        ic.line([(31.5 + r0 * math.cos(a), 35.5 + r0 * math.sin(a)),
                 (31.5 + 15.2 * math.cos(a), 35.5 + 15.2 * math.sin(a))], width=1.4, amp=0.05)
    ic.line([(31.5, 35.5), (31.5, 24.5)], width=2.6, amp=0.2)
    ic.line([(31.5, 35.5), (39.5, 39.5)], width=2.6, amp=0.2)
    ic.flat(circle_pts(31.5, 35.5, 2.2, n=10), INK, amp=0.1)
    ic.shape([rrect(29, 8, 35, 13.5, 1.5)], "#a8742a", line=2.0, drop=False)
    ic.save()


def cards_fan():
    ic = Icon("cards_fan", 83)
    card = rrect(21, 12, 43, 46, 3)
    for rot in (-20, 18):
        ic.shape([xform(card, rot_deg=rot, cx=32, cy=52)], "#e6d3a8", "#bca57a", line=2.6)
    ic.shape([xform(card, rot_deg=-1, cx=32, cy=52)], "#f1e2c0", "#cdb688")
    ic.shape([xform(star_pts(32, 29, 8.5, 3.8), rot_deg=-1, cx=32, cy=52)], "#c75a3b", "#97412b",
             shift=(-1.2, -1.2), line=2.0, drop=False, amp=0.2)
    ic.save()


# ---------------------------------------------------------------- enemy intents (64 px, colour)
def sword_pts(scale, wide=1.0):
    parts = {
        "blade": [(32, 4), (32 + 4.5 * wide, 11), (32 + 4.5 * wide, 42), (32 - 4.5 * wide, 42), (32 - 4.5 * wide, 11)],
        "guard": rrect(19, 41.5, 45, 47, 2),
        "grip": rrect(29.3, 46.5, 34.7, 56.5, 1.5),
        "pommel": circle_pts(32, 59, 3.4, n=14),
    }
    return {k: xform(v, rot_deg=45, sx=scale, sy=scale) for k, v in parts.items()}


def attack(tier):
    ic = Icon(f"intent_attack_{tier}", 90 + tier)
    sc, wide = {1: (0.68, 1.0), 2: (0.84, 1.15), 3: (1.0, 1.45)}[tier]
    p = sword_pts(sc, wide)
    ic.shape([p["grip"]], "#5b3a24", line=2.4)
    ic.shape([p["pommel"]], "#d9a441", "#a8742a", shift=(-1, -1), line=2.2)
    ic.shape([p["blade"]], "#d64a3a", "#9e2f26", shift=(-1.6, -1.8))
    ic.line(xform([(32, 12), (32, 38)], rot_deg=45, sx=sc, sy=sc), width=1.6, color="#f3a08f", amp=0.1)
    ic.shape([p["guard"]], "#7a5232", "#553620", shift=(-1, -1.2), line=2.6)
    if tier == 3:  # two speed marks sell the heavy hit
        ic.line([(6, 40), (14, 33)], width=2.2)
        ic.line([(9, 47), (17, 40)], width=2.2)
    ic.save()


def block():
    ic = Icon("intent_block", 95)
    sh = [(11, 12), (22, 9), (32, 6.5), (42, 9), (53, 12), (53, 30), (47, 44), (32, 57), (17, 44), (11, 30)]
    ic.shape([sh], "#4f8fc0", "#2f6a99")
    ic.line([(32, 9), (32, 54)], width=1.8, color="#2f6a99", amp=0.25)
    ic.line([(40, 18), (43.5, 23)], width=1.6)
    ic.line([(16.5, 15), (19, 30), (21, 37)], width=2.2, color="#a9d3f0", amp=0.2)
    ic.save()


def arrow(name, color, shade, down=False):
    ic = Icon(name, 97 if down else 96)
    pts = [(32, 5), (55, 30), (42, 30), (42, 58), (22, 58), (22, 30), (9, 30)]
    if down:
        pts = [(x, 64 - y) for x, y in pts]
    ic.shape([pts], color, shade)
    ic.save()


def charge():
    ic = Icon("intent_charge", 98)
    ic.shape([[(32, 6), (59, 55), (5, 55)]], "#eba13a", "#b87420", amp=0.5)
    ic.line([(32, 22), (32, 38)], width=6.0, amp=0.2)
    ic.flat(circle_pts(32, 46.5, 3.4, n=12), INK, amp=0.1)
    ic.save()


def card_debuff():
    ic = Icon("intent_card_debuff", 99)
    ic.shape([rrect(15, 7, 49, 57, 4)], "#ecdcb6", "#c8b083")
    ic.shape([rrect(20, 12, 44, 52, 2)], "#9b59c6", "#6a3a93", shift=(-1, -1), line=1.8, drop=False, amp=0.3)
    ic.line([(35, 7.5), (29.5, 21), (37, 30), (28.5, 42), (33.5, 56.5)], width=2.6, amp=0.2)
    ic.save()


def death_blow():
    ic = Icon("intent_death_blow", 100)
    ring = [circle_pts(32, 32, 23, n=48), list(reversed(circle_pts(32, 32, 17.5, n=40)))]
    ic.shape(ring, "#d64a3a", "#9e2f26", shift=(-1.2, -1.4))
    for (x0, y0, x1, y1) in [(29.5, 2.5, 34.5, 15), (29.5, 49, 34.5, 61.5), (2.5, 29.5, 15, 34.5), (49, 29.5, 61.5, 34.5)]:
        ic.shape([rrect(x0, y0, x1, y1, 1.2)], "#d64a3a", line=2.2, drop=False, amp=0.2)
    # a cracked heart in the sights (the spec's meaning; the no-skull rule applies)
    hp = []
    for k in range(40):
        t = 2 * math.pi * k / 40
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        hp.append((32 + x * 0.72, 31.5 + y * 0.72))
    ic.shape([hp], "#f1e2c0", "#cdb688", shift=(-1, -1), line=2.2)
    ic.line([(31, 24.5), (34, 29.5), (30.5, 33.5), (33, 38.5)], width=1.6, amp=0.05)
    ic.save()


def heal():
    ic = Icon("intent_heal", 101)
    rot = -45
    ic.shape([xform(rrect(29, 4, 35, 10, 1), rot_deg=rot)], "#a9a294", line=2.2)
    ic.line(xform([(32, 10), (32, 16)], rot_deg=rot), width=2.6, amp=0)
    ic.line(xform([(32, 46), (32, 59)], rot_deg=rot), width=2.0, amp=0)
    ic.shape([xform(rrect(25, 15, 39, 47, 3), rot_deg=rot)], "#d7ecee", "#a7c6cb", shift=(-1, -1))
    ic.flat(xform(rrect(27.5, 28, 36.5, 44.5, 1.5), rot_deg=rot), "#d64a3a", amp=0.15)
    for y in (21, 27, 33):
        ic.line(xform([(35, y), (38, y)], rot_deg=rot), width=1.3, amp=0)
    plus = [(44, 34), (51, 34), (51, 41), (58, 41), (58, 48), (51, 48), (51, 55), (44, 55), (44, 48), (37, 48), (37, 41), (44, 41)]
    ic.shape([plus], "#8cc152", "#5c9535", shift=(-1, -1.2), line=2.4)
    ic.save()


def zee(x, y, s):
    return [(x, y), (x + s, y), (x, y + s), (x + s, y + s)]


def sleep():
    ic = Icon("intent_sleep", 102)
    for (x, y, s, w) in [(7, 33, 20, 6.5), (31, 18, 14, 5.2), (47, 7, 10, 4.2)]:
        ic.outlined_stroke(zee(x, y, s), "#9fc4e8", inner=w, ink=w + 4.6, amp=0.2)
    ic.save()


def status():
    ic = Icon("intent_status", 103)
    page = [(15, 7), (39, 7), (49, 17), (49, 57), (15, 57)]
    ic.shape([page], "#ecdcb6", "#c8b083")
    ic.shape([[(39, 7.5), (39, 17), (48.5, 17)]], "#c8b083", line=2.2, drop=False, amp=0.1)
    for y, x1 in [(27, 42), (35, 40), (43, 43)]:
        ic.line([(21, y), (x1, y)], width=2.0, color="#8a7458", amp=0.3)
    ic.save()


def stun():
    ic = Icon("intent_stun", 104)
    ring = circle_pts(32, 34, 24, 10, n=40)
    ic.line(ring + [ring[0]], width=2.6, amp=0.3)
    for (cx, cy, R, rot) in [(13, 30, 12, -80), (34, 45, 13, -95), (52, 26, 11, -70)]:
        ic.shape([star_pts(cx, cy, R, R * 0.47, rot=rot)], "#f2c84b", "#c9962a", shift=(-1.2, -1.2), line=2.4, amp=0.3)
    ic.save()


def summon():
    ic = Icon("intent_summon", 105)
    ic.shape([[(28, 22), (36, 22), (46, 59), (18, 59)]], "#a9a294", "#7c7466")
    for (a, b) in [((27, 30), (40, 41)), ((37, 30), (24, 41)), ((24, 43), (43, 55)), ((40, 43), (21, 55))]:
        ic.line([a, b], width=1.6, amp=0.15)
    ic.shape([circle_pts(32, 16, 5, n=16)], "#d64a3a", "#9e2f26", shift=(-1, -1), line=2.4)
    for r in (11, 18):
        arc_r = [(32 + r * math.cos(math.radians(d)), 16 + r * math.sin(math.radians(d))) for d in range(-50, 51, 10)]
        ic.line(arc_r, width=2.6, amp=0.2)
        ic.line(mirror(arc_r), width=2.6, amp=0.2)
    ic.save()


def escape():
    ic = Icon("intent_escape", 106)
    boot = [(21, 6), (40, 6), (39, 33), (52, 39), (58, 47), (58, 55), (13, 55), (13, 45), (20, 37)]
    ic.shape([boot], "#8a5a3a", "#5e3a24")
    ic.line([(13, 50), (58, 50)], width=1.8, amp=0.15)
    ic.line([(21, 13), (39.5, 13)], width=1.8, amp=0.15)
    ic.shape([star_pts(10, 47, 6.5, 3.2, n=6)], "#d9a441", line=1.8, drop=False, amp=0.15)
    ic.line([(4, 22), (14, 22)], width=2.2)
    ic.line([(2, 30), (13, 30)], width=2.2)
    ic.save()


QMARK = [(20, 21), (22, 13), (30, 8.5), (39, 9.5), (45, 16), (44, 24), (37, 30), (33, 35), (32.5, 41)]


def unknown_intent():
    ic = Icon("intent_unknown", 107)
    ic.outlined_stroke(QMARK, "#f1e2c0", inner=7.5, ink=13.0, amp=0.25)
    ic.shape([circle_pts(32.5, 53, 5, n=16)], "#f1e2c0", line=2.8, amp=0.2)
    ic.save()


# ---------------------------------------------------------------- currencies (with the bottlecap)
def scrap():
    ic = Icon("scrap", 131)
    plate = [(21, 13), (29, 8), (33, 14), (39, 8.5), (45, 15), (54, 12), (57, 22), (52, 29), (57, 38), (45, 46),
             (34, 43), (25, 40), (19, 28)]
    ic.shape([plate], "#9a957f", "#6b6753", shift=(-1.8, -2.0))
    ic.line([(29, 18), (35, 26), (47, 27)], width=1.6, amp=0.25)   # a bend in the sheet
    ic.line([(48, 18), (51, 21)], width=1.4)
    teeth = []
    for i in range(16):
        a = 2 * math.pi * i / 16 + 0.1
        r = 13.5 if (i // 1) % 2 == 0 else 10.2
        teeth.append((20 + r * math.cos(a), 42 + r * math.sin(a)))
    hole = list(reversed(circle_pts(20, 42, 4.2, n=16)))
    ic.shape([teeth, hole], "#d9a441", "#a8742a", amp=0.3)
    bolt = xform(rrect(33, 42, 43, 58, 2), rot_deg=-30, cx=38, cy=50)
    ic.shape([bolt], "#b4ab99", "#7c7466", shift=(-1, -1.2), line=2.6)
    for k in range(3):
        y = 48 + k * 3.4
        ic.line(xform([(34.5, y), (41.5, y)], rot_deg=-30, cx=38, cy=50), width=1.3, amp=0.05)
    ic.save()


def core():
    ic = Icon("core", 132)
    ring = [(48 + 8 * math.cos(math.radians(d)), 45 + 8 * math.sin(math.radians(d))) for d in range(-80, 200, 20)]
    ic.outlined_stroke(ring, "#8a8473", inner=3.4, ink=6.6, amp=0.15)
    shard = [(38, 4), (53, 17), (38, 60), (21, 46), (27, 20)]
    ic.shape([shard], "#5fd0e0", "#2f98ad", shift=(-2.0, -2.0))
    ic.line([(38, 5), (36, 30), (38, 59)], width=1.5, color="#2f98ad", amp=0.2)
    ic.line([(30, 20), (28, 33)], width=2.4, color="#c8f4fa", amp=0.15)
    for (cx, cy, rot) in [(25.5, 32, 70), (49, 29, -68)]:
        ic.shape([xform(rrect(cx - 5, cy - 3, cx + 5, cy + 3, 1.2), rot_deg=rot, cx=cx, cy=cy)], "#d9a441", "#a8742a",
                 shift=(-0.8, -0.8), line=2.2)
        ic.flat(circle_pts(cx, cy, 1.2, n=8), INK, amp=0.02)
    ic.save()


def slider_knob():
    """Settings slider grabber: a bottle cap seen from above (crimped rim, lighter top)."""
    ic = Icon("slider_knob", 71)
    rim = []
    n = 28
    for i in range(n):
        a = 2 * math.pi * i / n
        rad = 25.5 if i % 2 == 0 else 22.0
        rim.append((32 + rad * math.cos(a), 32 + rad * math.sin(a)))
    ic.shape([rim], "#c4452f", "#8f2c1e", shift=(-1.4, -1.8), line=3.4, amp=0.25)
    ic.shape([circle_pts(31.5, 31.5, 15.5, n=40)], "#e05a40", "#b8432f", shift=(-1.6, -1.6), line=2.8, drop=False)
    ic.line([(22, 29), (25, 24), (30, 21.5)], width=2.6, color="#f6b29a", amp=0.2)
    ic.save()


# ---------------------------------------------------------------- build + manifest
ALL = [
    (gear, {}), (globe, {}), (deck, {}), (bottlecap, {}), (heart, {}),
    (close_glyph, {}), (refresh_glyph, {}), (lock_glyph, {}), (arrow_glyph, {}),
    (gear, {"name": "menu_settings", "plate": True}), (globe, {"name": "menu_language", "plate": True}),
    (clock, {}), (cards_fan, {}),
    (attack, {"tier": 1}), (attack, {"tier": 2}), (attack, {"tier": 3}), (block, {}),
    (arrow, {"name": "intent_buff", "color": "#8cc152", "shade": "#5c9535"}),
    (arrow, {"name": "intent_debuff", "color": "#9b59c6", "shade": "#6a3a93", "down": True}),
    (charge, {}), (card_debuff, {}), (death_blow, {}), (heal, {}), (sleep, {}), (status, {}),
    (stun, {}), (summon, {}), (escape, {}), (unknown_intent, {}),
    (scrap, {}), (core, {}), (slider_knob, {}),
]

LL = "res://run_system/assets/images/ui_kit_lightline/"
INTENTS = "res://battle_scene/assets/images/ui/combat/intents/"
# svg name -> existing PNG targets [path, width, height, ("trim")]. Sizes match the PNGs
# they replace so every layout stays the same; "trim" crops the empty margin and fills
# the target like the old art did (not for intents: their size carries the attack tier).
# The status icons and the map nodes are Codex's roster-style art and are intentionally
# NOT listed here (owner decision 2026-11-25: map nodes keep the hand-drawn art).
MANIFEST = {
    "heart": [[LL + "icon_heart.png", 120, 114, "trim"]],
    "bottlecap": [["res://run_system/assets/images/home/currency/caps.png", 128, 128, "trim"]],
    "scrap": [["res://run_system/assets/images/home/currency/scrap.png", 128, 128, "trim"]],
    "core": [["res://run_system/assets/images/home/currency/core.png", 128, 128, "trim"]],
    "gear": [[LL + "icon_gear.png", 134, 135, "trim"]],
    "deck": [[LL + "iconb_deck_stack.png", 336, 352, "trim"]],
    "clock": [[LL + "iconb_clock.png", 307, 330, "trim"]],
    "cards_fan": [[LL + "iconb_cards_fan.png", 363, 346, "trim"]],
    "glyph_lock": [[LL + "icon_lock.png", 101, 139, "trim"], ["res://run_system/assets/images/ui_v2/icons/lock.png", 128, 128]],
    "glyph_close_white": [[LL + "glyph_close.png", 96, 96]],
    "slider_knob": [[LL + "slider_knob.png", 40, 40, "trim"]],
    "menu_settings": [["res://run_system/assets/images/ui/start_screen/icon_button_settings.png", 207, 197]],
    "menu_language": [["res://run_system/assets/images/ui/start_screen/icon_button_language.png", 208, 197]],
}
for _t in (1, 2, 3):
    MANIFEST[f"intent_attack_{_t}"] = [[INTENTS + f"attack_{_t}.png", 64, 64]]
for _n in ("block", "buff", "debuff", "charge", "card_debuff", "death_blow", "heal", "sleep", "status", "stun",
           "summon", "escape", "unknown"):
    MANIFEST[f"intent_{_n}"] = [[INTENTS + f"{_n}.png", 64, 64]]

if __name__ == "__main__":
    for fn, kw in ALL:
        fn(**kw)
    # white copy of the close glyph: the button tints it (ink, rust on hover)
    (OUT / "glyph_close_white.svg").write_text(
        (OUT / "glyph_close.svg").read_text(encoding="utf-8").replace(INK, "#ffffff"), encoding="utf-8")
    missing = [k for k in MANIFEST if not (OUT / f"{k}.svg").exists()]
    assert not missing, missing
    (pathlib.Path(__file__).parent / "manifest.json").write_text(json.dumps(MANIFEST, indent=1), encoding="utf-8")
    print("ok", len(list(OUT.glob("*.svg"))), "svgs,", sum(len(v) for v in MANIFEST.values()), "targets")
