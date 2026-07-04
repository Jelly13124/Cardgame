# Asset Spec — Windowed-UI kit (16 PNGs, 9-slice panels + buttons + slot frames)

**Owner:** Codex (ADR-0005 — Codex generates all PNGs under
`run_system/assets/images/**`). **Status:** REVISION 2 REQUESTED 2026-07-04
(v1 delivered but REJECTED by the owner as too ornate — parked at
`run_system/assets/images/ui_kit_ref_v1/` for structure reference only).

## Revision 2 — what was wrong with v1 (read before regenerating)

v1 inverted the game's outline language: it used **bright saturated gold as the
frame/outline**, so the whole UI reads as gilded fantasy chrome that competes
with the content. The world art (buildings, heroes) uses **near-black thick
outlines with muted grey-brown metal bodies** — UI chrome must do the same and
visually RECEDE. Concrete corrections, applied to every file below:

1. **Outlines** = near-black dark brown (#1a120a-ish), thick, exactly like the
   building sprites. NEVER gold/brass as the outer contour.
2. **Plate bodies** = desaturated dark iron-brown (#241a10 → #3a2c1c range),
   flat cel, worn but muted.
3. **Brass is a garnish, not a frame**: corner bolts, a single thin inner seam
   line, small hinge details — at most ~10% of the visible area. No full brass
   rims.
4. **Hover/pressed = value shift only** (edges warm up / darken). NO colored
   stripes (v1's teal/green top bars are gone).
5. **Accent (START) button**: worn desaturated red-clay (#8f3a28-ish), dark
   outline, thin muted trim — not glossy red with a gold rim.
6. Corner radius small (4-6px feel) — chunkier, squarer, more industrial.

### Mandatory workflow for rev2 (both are hard requirements)

- **Style anchors — match these exact files, same world, same hand:** open and
  visually match `run_system/assets/images/home/buildings_runtime/clinic.png`,
  `forge.png`, `outpost.png` and `run_system/assets/images/home/home_base_bg.png`
  (outline weight, value range, wear language). The UI must look like it was
  cut from the same sheet as these buildings. v1 (parked at
  `run_system/assets/images/ui_kit_ref_v1/`) shows correct STRUCTURE/layout per
  file — copy its shapes, replace its palette/outline language entirely.
- **Contact-sheet approval gate:** before writing anything into
  `run_system/assets/images/ui_kit/`, deliver a single preview contact sheet
  (all 16 pieces on one image, on a dark bg swatch AND overlaid on a crop of
  the home-base screenshot) to `docs/art/previews/` and STOP for owner
  approval. Only after the owner approves does the kit land in `ui_kit/`
  (which auto-activates in-game).
**Consumer:** `run_system/ui/theme/wasteland_theme.gd` — the code ships with
programmatic StyleBoxFlat fallbacks TODAY; every file below is loaded via
`ResourceLoader.exists` with warn-only fallback, so delivery is drop-in with
zero code change. Delivery dir: `run_system/assets/images/ui_kit/`.

## Style (non-negotiable — project-rules.md §1)

Original **Offbeat Adult Sci-Fi Cartoon Wasteland** UI chrome, same world as the
building sprites: flat 2D adult sci-fi TV-animation look, **thick clean dark
cartoon outlines**, large simple shape blocks, sparse interior linework, broad
2–3 value cel shading, **no painterly rendering, no pixel-art, no photo
texture, no gradients**. Palette: dark oiled scrap-metal browns
(#14100a–#221610 range) with warm brass trim, plus sparing toxic accents only
where stated. Motifs: riveted salvage plates, welded seams, worn brass edging —
big readable shapes, not dense greebles. All PNGs transparent-background.

## Files

### 9-slice panels (must have clean stretchable mid-sections; corner
ornaments only in the 48px corner zone so 9-slice margins at 48px work)

1. `panel_window.png` — 192×192. Main floating-window body: dark riveted
   scrap-metal plate, thick dark outline, brass corner bolts. This skins the
   character / stash / forge windows.
2. `panel_window_titlebar.png` — 192×64. Title-bar strip variant: slightly
   lighter plate, bottom brass seam. Horizontal 9-slice (margins 48/16).
3. `panel_inset.png` — 192×192. Recessed inner well (paper-doll spotlight,
   backpack area): near-black plate with an inner shadow lip drawn as a flat
   darker band (cel style, not a soft gradient).
4. `panel_bottom_bar.png` — 384×96. The home-base bottom HUD bar: long riveted
   metal strip with a top brass edge. Horizontal 9-slice (margins 64/24).

### Buttons (each 144×56, 9-slice margins 24; three states per set —
same silhouette, state changes by value shift only, cel style)

5. `btn_brass_normal.png` / 6. `btn_brass_hover.png` / 7. `btn_brass_pressed.png`
   — default button: dark plate, brass rim; hover = brighter rim, pressed =
   darkened + rim flush.
8. `btn_accent_normal.png` / 9. `btn_accent_hover.png` / 10. `btn_accent_pressed.png`
   — accent button (the giant START button): worn red-clay plate with gold rim
   (matches Bill's red scarf tone), same three-state logic.

### Slot frames (96×96 squares, NOT 9-sliced — drawn as-is)

11. `slot_normal.png` — equipment/backpack cell: dark well + metal frame,
    thick outline.
12. `slot_hover.png` — same frame with a brighter brass rim (hover/selected).
13. `slot_locked.png` — same well with a **welded-shut plate + chunky padlock**
    drawn across it (for un-unlocked backpack cells). Flat cel, readable at 56px.

### Small glyphs (transparent, single-color-friendly)

14. `icon_lock.png` — 48×48 chunky cartoon padlock (also used standalone).
15. `icon_arrow_left.png` / 16. `icon_arrow_right.png` — 48×48 thick chevron
    arrows for the hero-switcher widget (‹ ›), brass on transparent.

## Prompt language anchor (per project-rules.md §5 — do not deviate)

> original Offbeat Adult Sci-Fi Cartoon Wasteland game art, flat 2D adult
> sci-fi TV-animation look, thick clean near-black cartoon outlines, large
> simple shape blocks, sparse interior lines, broad two-to-three value cel
> shading, muted desaturated dark iron-brown scrap-metal UI panel, tiny worn
> brass bolt accents only, understated and dark so the UI recedes behind the
> game content, transparent background, no text, no watermark

## Verification checklist (Codex, before marking delivered)

- [ ] 9-slice panels stretch cleanly (no ornament crossing the margin lines).
- [ ] Button state trio reads at 40px height; silhouettes identical per set.
- [ ] `slot_locked` reads as "locked" at 56×56.
- [ ] All PNGs transparent bg, no baked text/numbers, consistent outline weight.
- [ ] Files land exactly at `run_system/assets/images/ui_kit/<name>.png`.

## Wiring after delivery

None required to ship (fallbacks stay). To activate: `wasteland_theme.gd`
swaps its programmatic styleboxes for `StyleBoxTexture` at the paths above —
one file, single review pass (Claude's job, tracked separately).
