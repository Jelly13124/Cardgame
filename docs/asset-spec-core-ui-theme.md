# Asset Spec — Core UI Theme Frame Kit (bespoke 9-slice)

**Owner:** Codex (ADR-0005). **Status:** ❌ REJECTED on review 2026-06-25. The panel+button
sample (`docs/art/previews/ui_frame_kit_20260625/`) was wired into the theme and rendered
in-context (black market): the corner-bolt salvage frames read **busier and worse than the
plain Kenney-tinted placeholder** — the chrome started competing with the card/item art on a
content-dense screen with many small buttons/tiles/40 slots. **Decision: keep the existing
clean tinted-Kenney chrome.** Do NOT batch A–D. Lesson kept here so we don't re-pitch ornate
UI frames: on this UI the win is layout/spacing/hierarchy, not fancier frames.
**Replaces:** the placeholder **Kenney UI Pack** 9-slice textures that
`run_system/ui/theme/wasteland_theme.gd` currently loads + tints
(`run_system/assets/images/ui/kenney/{panel,panel_recessed,button_normal,button_hover,button_pressed}.png`).
**Companion spec:** `docs/asset-spec-ui-frame-kit.md` — the *heavier ornate map-HUD*
frames. This kit is the **base UI language**; the HUD frames are its richer cousins.
They MUST share the same material, palette, and line weight so the whole game reads
as one kit.

---

## 1. Why this exists

Today every panel and button in the game is a **generic Kenney 9-slice** recolored to
brown/brass via `modulate_color`. It's clean but generic — it doesn't share the
salvage-metal, flat-cartoon language of the building sprites, card art, and Cowboy Bill.
This kit replaces those placeholders with **bespoke frames in the locked art style** so
the chrome stops reading as a stock asset pack.

**Scale of impact (why it's worth doing right):**

| Surface | How it's themed today | Uses |
|---|---|---|
| **Buttons** (every themed button) | `apply_button_theme` → Kenney button 9-slice | **56 call sites** |
| **Textured panels** | `panel_textured()` → Kenney panel 9-slice | **29** |
| **Drawn panels/boards** | `panel_with_shadow()` → flat `StyleBoxFlat` (no texture) | **32** |
| **Slot / icon cells** | `icon_frame_style()` → flat `StyleBoxFlat` | many (e.g. 40 warehouse slots) |
| **Pill buttons / tiles** | `rounded_button()` → flat `StyleBoxFlat` | 7 |

So a button frame alone re-skins 56 sites. The code side (Claude) will also migrate the
**drawn** `panel_with_shadow` / `icon_frame_style` / `rounded_button` helpers onto the new
textures after delivery, so the *whole* UI — not just buttons + half the panels — gets the
bespoke look. **You (Codex) only deliver the art listed in §5.**

---

## 2. Locked art style

**Offbeat Adult Sci-Fi Cartoon Wasteland** (ADR-0017). The binding written rules +
mandatory prompt anchor live in `docs/art-style-reference.md`; the approved exemplars are
`heroes/cowboy_bill/cowboy_bill_identity_offbeat_v2.png`,
`backgrounds/wasteland_battlefield.png`, and the player card art under
`battle_scene/assets/images/cards/player/*.png`. Match those first.

**Reading the style for FRAMES specifically** (frames are chrome, not icons — they may carry
a little material that small intent-icons may not, but the low-noise rule still rules):

- Flat 2D TV-animation salvage **metal plate** with a **thick dark cartoon outline** and
  **two-to-three value cel shading** — a beveled rim catching one soft top-light, a broad
  flat interior, a darker bottom edge.
- Material: **dusty grey-green / warm-brown scrap metal** with a **brass / bronze trim** on
  the rim. Think a cut-down hull panel or an ammo-crate lid, not a fantasy scroll and not a
  realistic military hull.
- **A few big, simple rivets or corner brackets** — placed **in the four corners only**
  (see §4). NOT a dense rivet field, NOT panel-seam clutter, NOT crosshatching. The
  art-style guide explicitly forbids "heavy rivet fields, dense panel seams, realistic
  hard-surface rendering."
- **One** small accent per asset, used sparingly: a **toxic-green / cyan / warm-orange** bolt
  glow or edge tick. Optional on the panel; meaningful on button hover (see §5C).
- **Low texture noise.** No grunge overlay, no scratches field, no dithering, no pixel art.
- **Transparent background** outside the plate's rounded silhouette. **No text, no numbers,
  no labels** baked in — ever (same mistake as the currency icons).

---

## 3. Format & technical contract (read this — it makes or breaks a 9-slice)

- **PNG, RGBA, straight (non-premultiplied) alpha.**
- **Full final color.** Deliver the frame already brass/brown/weathered. The theme will set
  `modulate_color = white` for this kit (the old grey-then-tint trick is retired). Do **not**
  deliver greyscale.
- **No outer drop-shadow or outer glow.** A soft shadow that bleeds past the plate edge
  *cannot* 9-slice — it smears when stretched. The plate fills its own bounds; the theme adds
  drop-shadows separately in code. Alpha transparency appears **only** in the rounded corners
  *outside* the plate silhouette.
- **Texture filtering is linear** (smooth upscale). Keep edges clean but you don't need
  pixel-perfect 1px lines.
- **Power-of-two not required**; the sizes in §5 are output contracts only and never imply
  pixel art.

---

## 4. The 9-slice grid — the single most important rule

Each frame is sliced into a 3×3 grid by a fixed **border margin** (given per asset in §5):

```
 ┌────────┬──────────────┬────────┐
 │ corner │  top edge →  │ corner │   corners = FIXED (never stretch)
 ├────────┼──────────────┼────────┤   edges   = stretch in ONE direction
 │ left   │              │ right  │   center  = stretches in BOTH directions
 │  edge  │    CENTER    │  edge  │
 │   ↓    │   (tiles)    │   ↓    │
 ├────────┼──────────────┼────────┤
 │ corner │  bottom →    │ corner │
 └────────┴──────────────┴────────┘
```

Therefore:

1. **All decoration lives in the four CORNERS** (rivets, brackets, the bevel turn). The
   four edges and the center must be **plain and uniform** so they tile/stretch invisibly.
   A rivet on an edge will smear into a streak; a rivet in a corner stays a crisp rivet.
2. **The center must be flat / seamless.** Any interior wear, vignette, or gradient must sit
   **inside the border band**, not the stretched center — otherwise a board stretched to
   1840 px shows an ugly seam down the middle.
3. **Border width is consistent and matches the margin** in §5 (so my `texture_margin`
   lines up). If you draw a 40 px brass rim, the slice margin is 40.
4. **Mirror symmetry:** left↔right and top↔bottom should mirror so stretching is even
   (bottom edge may be a touch heavier — see buttons).
5. **It must read at both extremes.** Panels stretch from ~150 px (a shop tile) to
   ~1840×980 px (a fullscreen building board); slots render at ~64–74 px; buttons from
   ~80 px to ~420 px wide. Keep corner motifs **large and few** so they survive the small
   sizes and don't multiply at the large ones.

---

## 5. Deliverables

Drop all files in a new bespoke dir: **`run_system/assets/images/ui/wasteland/`**
(parallel to the placeholder `ui/kenney/`). Filenames are exact — the code preloads them.

### A. `panel.png` — main panel / board / section frame
- **Output:** 256×256. **9-slice border:** 40 px all sides.
- **Look:** a salvage-metal plate — beveled brass-ish rim catching a soft top-left light,
  a broad **flat dark interior** (so text/content reads on top), one **rivet or bracket in
  each corner**. Muted, dusty, low-noise. This is the most-used frame; keep it calm.
- **Wire:** `_K_PANEL` → `panel_textured("default")`, `texture_margin = 40`. Also becomes the
  texture the migrated `panel_with_shadow` boards point at.

### B. `panel_recessed.png` — sunken / inset variant
- **Output:** 256×256. **9-slice border:** 40 px all sides.
- **Look:** same plate, but reads **inset / pushed-in** — a darker interior with a soft
  **inner top-left shadow** and a thin bottom-right highlight (the opposite of A's bevel).
  Used for inset wells and the "dark" panels behind content.
- **Wire:** `_K_PANEL_RECESSED` → `panel_textured("dark")`, `texture_margin = 40`.

### C. `button_normal.png` / `button_hover.png` / `button_pressed.png` — button, 3 states
- **Output:** 256×96 each (all three identical footprint). **9-slice border:** left/right 30,
  top 24, **bottom 36** (the chunky bottom lip needs room).
- **Look:** a salvage-metal / riveted-brass **key** with a clear pressable bevel. Same shape
  across states; only the lighting/accent changes so they swap with no layout shift:
  - **normal** — neutral brass-brown, soft top light, defined bottom lip (sits "out").
  - **hover** — brighter/warmer, a **thin toxic-green or cyan rim-light** along the top edge
    (one small accent), lip unchanged.
  - **pressed** — darker overall, top light flattened, bottom lip compressed so it reads
    **pushed in**. No accent.
- **Wire:** `_K_BTN_NORMAL/HOVER/PRESSED` → `button_textured()`. I'll set `texture_margin`
  to match (≈ 30/30/24/36).

### D. `slot_frame.png` — small square socket cell  *(high visibility — do not skip)*
- **Output:** 96×96. **9-slice border:** 22 px all sides.
- **Look:** a small **recessed socket** — a dark inset square with a thin brass edge and a
  tiny bracket tick in each corner; empty interior transparent-to-dark so an item icon sits
  inside it cleanly. This is the equipment / tool / gem cell and the **40 warehouse stash
  slots** + shop-shelf icon tiles, so it tiles a LOT — keep it minimal and crisp.
- **Wire:** I'll convert `icon_frame_style()` from a drawn `StyleBoxFlat` to a
  `StyleBoxTexture` of this. *(Optional bonus: `slot_frame_empty.png`, a dimmer/no-brass
  version, for vacant slots — nice-to-have, not required.)*

### E. *(optional, low priority)* `divider.png` — horizontal separator
- **Output:** 256×16, 9-slice border 24/24/0/0 (stretches horizontally only).
- A thin salvage strip (a riveted bar) for `HSeparator`. Skip unless A–D land well.

---

## 6. Palette anchors

Pull from the building sprites / card frames; these hexes are guidance, not law:

- **Plate base:** dusty warm brown / grey-green metal — around `#4a3a26`→`#6b5436` body,
  not saturated.
- **Brass rim / trim:** `#b58a3e`–`#d8a64a` with a dark cartoon outline `#1a120a`.
- **Recessed interior:** `#221a12`-ish, darker than the plate.
- **Accent (one, sparingly):** toxic green `#7fd04a`, cyan `#4fd0e0`, or warm orange
  `#ff9a3c` — only as a small bolt/edge tick (button hover, or one corner bolt).
- Keep everything **muted + dusty** to match the wasteland scenes; avoid candy saturation.

---

## 7. Integration plan (code side — Claude, after delivery)

Small + contained, all in `wasteland_theme.gd`:

1. Repoint the 5 `_K_*` preloads to `ui/wasteland/…`.
2. Set the 5 `_TINT_*` consts to ~white (bespoke art is final-colored).
3. Set `texture_margin`s to the per-asset borders in §5 (panel 40; button 30/30/24/36).
4. Convert `icon_frame_style()` to a `StyleBoxTexture` of `slot_frame.png`.
5. **Migration pass** so the drawn frames also get the look: route `panel_with_shadow()`
   (32 sites) and `rounded_button()` (7) through `panel_textured`/`button_textured` variants
   where a textured frame is wanted, keeping a cheap flat fallback for tiny/perf-sensitive
   spots. (This is the only non-trivial code work; ~half a day, reversible.)

No content/JSON/validator changes. Smoke + an MCP screenshot pass per surface, as usual.

---

## 8. Prompt anchor

Use the mandatory anchor from `docs/art-style-reference.md`, plus this **UI-frame tail**:

```text
game UI 9-slice frame, single flat salvage-metal plate, thick dark cartoon outline,
two-to-three value cel shading, dusty brown / grey-green metal body with a brass beveled rim,
a few big simple rivets in the four corners only, flat uniform interior and edges (tileable),
one small toxic-green/cyan/orange accent at most, low texture noise,
straight-on front view, centered, symmetric, fills the frame to its rounded edge,
transparent background outside the plate, no outer drop shadow, no outer glow,
no text, no numbers, no labels, no icons inside, no UI screenshot, no character,
not a fantasy scroll, not realistic military hardware, no dense rivet field, no pixel art
```

---

## 9. Acceptance checklist (the QA gate)

A deliverable passes only if **all** hold:

- [ ] 9-slices cleanly: stretched to a 1840×980 board **and** a 150 px tile, corners stay
      crisp, edges/center show **no seam, streak, or duplicated rivet**.
- [ ] Slot frame reads at 64–74 px; button reads at 80 px **and** 420 px wide.
- [ ] All decoration is in the corners; edges + center are plain.
- [ ] Transparent **only** outside the rounded plate; **no** outer shadow/glow baked in.
- [ ] Full final color; looks right with `modulate = white` (no tinting needed).
- [ ] Button 3 states share one footprint and swap with no layout shift; pressed reads inset.
- [ ] **Zero** baked text/numbers/labels.
- [ ] Sits beside a building sprite + a player card without looking like a different game
      (matches the ADR-0017 exemplars: flatness, line weight, dusty palette, low noise).

---

## 10. Delivery & review gate

- **Sample first, batch second.** Deliver **one `panel.png` + one `button_normal.png`**
  sample to `docs/art/previews/ui_frame_kit_<date>/` for owner approval **before** generating
  the full A–D set. (Same review-gate discipline as enemy art — don't batch a UI language
  unattended.)
- On approval, deliver A–D (and E if desired) into `run_system/assets/images/ui/wasteland/`.
- Ping the code side; wiring per §7 is quick. Keep the old `ui/kenney/` files in place until
  the swap is verified, so rollback is a one-line revert.
