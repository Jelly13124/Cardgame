# Asset Spec — Shop Scene Content Slice

**Audience:** codex (asset generation pipeline)
**Owner of code/scene:** Claude (already implemented)
**Project:** Cardgame (Godot 4.6, Hardcore 128 Pixel Wasteland Art roguelite)
**Status:** All-optional. The shop scene is functional with a plain dark background; these assets are visual polish.

This document tells codex what art assets would make the shop scene feel
finished. The gameplay code, scene file, and stock-rolling logic are all in
place. If a sprite is missing, the shop falls back to a plain dark background
with no shopkeeper — still fully playable.

---

## 0. Style Preamble (Non-Negotiable)

Every prompt for every asset must preserve the approved Hardcore 128 Pixel
Wasteland Art prompt anchor from `docs/project-rules.md` §1 and
`docs/art-style-reference.md`:

```
hardcore 128 pixel wasteland art style, native 128x128 pixel game sprite readability,
bold black pixel outlines, gritty rusted scrap metal, worn leather and patched cloth,
dusty desert palette, controlled pixel shading, salvaged bolts dents tubes and cracked glass,
one small neon accent, transparent background, no high-resolution cartoon brushwork
```

For background assets, drop "transparent background" — backgrounds are opaque
scene wallpaper.

---

## 1. Pipeline Reminders

- Generation background for character/object sprites: `#FF00FF` magenta → chroma-key cleanup → transparent PNG
- Background scenery: opaque PNG, no chroma key needed
- `.import` files: Godot auto-generates on first import — do not write manually

---

## 2. Deliverables (2 PNGs, both optional)

### 2.1 Shop interior background

**Path:** `run_system/assets/images/shop/shop_interior_bg.png`
**Dimensions:** 1920×1080 (matches game's design resolution)
**Style:**
- Dim, lantern-lit junkyard trader shack interior
- Wooden / scrap-metal shelves along walls stocked with mysterious junk, ammo crates, rusted tools, glass jars of glowing fluid
- Counter or workbench in the foreground (left or right side, leaves center clear for UI overlay)
- Hanging chains, exposed wires, oil lamp casting warm orange glow
- Neon accent: one warm-amber lantern glow + maybe a green CRT screen in the corner
- Dust motes in air; gritty, lived-in feel
- Composition leaves CENTRAL/UPPER area visually quieter so the UI panel reads clearly on top

**Composition reference:** Think Fallout: New Vegas trading post interior, or STS-style screen layer with bias toward atmospheric backdrop rather than playable scene.

### 2.2 Shopkeeper NPC sprite

**Path:** `run_system/assets/images/shop/shopkeeper.png`
**Dimensions:** 256×384 native (taller than wide for a standing figure)
**Style:**
- Wasteland trader figure — scrap-leather coat, goggles or hood, weathered face, weapon slung over back
- Standing pose, facing the player (or three-quarter front)
- Holding/leaning on the counter or arms crossed
- One neon accent — maybe a glowing pendant or rifle scope tint
- Single static frame, no animation
- Transparent background after chroma-key

**Placement:** UI script can position this in the bottom-left or bottom-right
of the shop scene as a decorative overlay. The shopkeeper does not animate
or speak; pure flavor.

---

## 3. Integration

Once both PNGs exist, codex should drop a note. Claude will add the load +
display logic to `shop_scene.gd` in a small follow-up commit:

```gdscript
# In _build_ui, before the dim bg:
if ResourceLoader.exists("res://run_system/assets/images/shop/shop_interior_bg.png"):
    var bg_img := TextureRect.new()
    bg_img.texture = load("res://run_system/assets/images/shop/shop_interior_bg.png")
    bg_img.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg_img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    add_child(bg_img)
    # Replace the dim ColorRect with a translucent overlay instead
```

Codex does NOT need to touch `.gd` or `.tscn` files (per ADR-0005 art-only).

---

## 4. Don't touch

- `battle_scene/assets/images/*` — combat sprites, owned by other slices
- `run_system/assets/images/relics/*`, `equipment/*`, `map/*`, `loot_ui/*`
- Any `.gd`, `.tscn`, or `.json` file
- Any `.import` file (Godot manages these)

---

## 5. When you're done

1. Print a delivery summary listing the PNGs written and their sizes.
2. If you skipped either asset (e.g., out of budget for this round), say so —
   the shop scene works fine without them.
3. Do NOT commit. Human will review in-game (`merchant` map node → opens
   shop) and commit.
