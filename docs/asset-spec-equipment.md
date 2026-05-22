# Asset Spec — Equipment v1 Content Slice

**Audience:** codex (asset generation pipeline)
**Owner of code/JSON:** Claude (already implemented)
**Project:** Cardgame (Godot 4.6, Hardcore 128 Pixel Wasteland Art roguelite)

This document is the contract that tells codex which equipment item icons to
generate for the Equipment v1 slice. Gameplay code, JSON data files, and the
equipment panel UI are all in place. The only thing missing is the per-item
PNG icons — until those land, the equipment panel renders colored placeholder
panels with slot letters (`H`, `C`, `W`, `Hd`, `Ac`) instead of real art.

If an icon PNG is missing, the game falls back to the placeholder. Nothing
crashes; it just looks bare.

---

## 0. Style Preamble (Non-Negotiable)

Every prompt for every asset in this doc **must** preserve the approved
Hardcore 128 Pixel Wasteland Art prompt anchor from
`docs/project-rules.md` §1 and `docs/art-style-reference.md`:

```
hardcore 128 pixel wasteland art style, native 128x128 pixel game sprite readability,
bold black pixel outlines, gritty rusted scrap metal, worn leather and patched cloth,
dusty desert palette, controlled pixel shading, salvaged bolts dents tubes and cracked glass,
one small neon accent, transparent background, no high-resolution cartoon brushwork
```

Color palette guidance:
- **Base:** leather brown, rusted orange, dusty tan, muted olive, dark steel, faded brass
- **Each item gets ONE neon accent color** — listed per asset below
- Outlines: bold black pixel outlines
- Shading: controlled pixel shading, not high-res cartoon brushwork

---

## 1. Pipeline Reminders

- **Frame size:** 128×128 native PNG (single frame, no animation)
- **Composition:** the ITEM only — no character holding it, no UI frame, no
  background scene. Item centered in frame, mostly side-on or three-quarter
  view depending on what reads best for that item type
- **Sheet generation background:** `#FF00FF` (magenta) for chroma-key cleanup
- **Final output:** transparent PNG, single frame per item
- **No text, no logos, no rarity badges baked in** — the UI composes those
- **`.import` files:** Godot auto-generates on first import; do not write manually

---

## 2. Output Path & Naming

```
battle_scene/assets/images/equipment/{item_id}.png
```

`item_id` MUST match the JSON's `id` field exactly. The runtime loads the path
as `res://battle_scene/assets/images/{sprite_field_from_JSON}` where the JSON's
`sprite` field is already set to `equipment/{item_id}.png`. Wrong filename = no
icon shown (placeholder fallback).

---

## 3. Item Roster (18 PNGs)

The items are organized by set affiliation. Each row lists: `item_id`, slot,
rarity, theme description (paraphrase from the JSON `description`), and the
required neon accent color.

### 3.1 Weak Hunter set — "scavenged kit that punishes the vulnerable"

Common visual thread: stalker / poacher aesthetic. Stained leather, predator
totems, kill-counts notched into things. Neon accent: **toxic-green** for all
5 pieces (sickly, weakness-themed glow).

| item_id | slot | rarity | theme |
|---|---|---|---|
| `weak_hunter_helm` | head | common | Cracked goggles or visor with one lens missing or scratched; sees what others ignore |
| `weak_hunter_vest` | chest | common | Lightweight scout vest, layered leather and patched cloth, dusty and oiled |
| `weak_hunter_gun` | weapon | uncommon | Sidearm pistol/revolver with notched grip — visible tally marks carved into the wood/bone handle |
| `weak_hunter_gloves` | hands | common | Worn leather fingerless gloves, dark stains, frayed cuffs |
| `weak_hunter_trinket` | accessory | common | Pendant or amulet carved from chipped bone, hung on dirty cord |

### 3.2 Tank Engineer set — "heavy plating welded from junkyard salvage"

Common visual thread: industrial / brutalist welder gear. Riveted steel,
exposed bolts, hazard stripes. Neon accent: **electric-blue** for all 5 pieces
(arc-weld / power-coil glow).

| item_id | slot | rarity | theme |
|---|---|---|---|
| `tank_engineer_helm` | head | common | Steel-banded hardhat, dented, with a small visor or lamp; bold rivets |
| `tank_engineer_vest` | chest | uncommon | Plated vest of welded scrap iron over leather core, thick chest plate |
| `tank_engineer_hammer` | weapon | common | Heavy pipe hammer — length of capped steel pipe with weighted head |
| `tank_engineer_gauntlets` | hands | common | Iron-plated gauntlets, knuckle ridges, leather inner |
| `tank_engineer_coil` | accessory | uncommon | Hand-sized power coil — copper wire wrapped on iron core, faint glow |

### 3.3 Plain pieces (no set) — 4 items

Stat-stick items with no set theme. Each gets its own accent.

| item_id | slot | rarity | theme | neon accent |
|---|---|---|---|---|
| `old_hat` | head | common | Battered wasteland cowboy/civilian hat, broad brim, sun-bleached and torn | **hot-orange** (sunset/dusty glow) |
| `scrap_breastplate` | chest | common | Crude armor plate, rivets going every which way, mismatched scrap pieces bolted together | **faded brass** (muted, no strong neon — almost no glow) |
| `rusted_dagger` | weapon | common | Short blade, mostly rust, with one polished sharpened edge catching light | **magenta** (cursed-edge glow on the sharpened side) |
| `lucky_charm` | accessory | uncommon | Hung trinket — could be a rabbit's foot, dice, or coin on a chain, faintly glowing | **yellow-green** (luck-aura glow) |

### 3.4 Rare pieces (boss/treasure drops) — 2 items

Higher-impact visual presence — these are the "wow" rewards.

| item_id | slot | rarity | theme | neon accent |
|---|---|---|---|---|
| `wasteland_revolver` | weapon | rare | Six-shot revolver, weathered but well-maintained, etched grip with two centuries of stories visible in the wear | **hot-orange** (muzzle-glow ember on the cylinder) |
| `old_world_relic` | accessory | rare | Mysterious pre-collapse artifact — small device or sphere with cryptic markings, softly humming light from within | **magenta** (otherworldly inner glow) |

---

## 4. Composition Tips

- **Centered in frame** — the icon will render in a 48×48 panel slot, so
  silhouette readability matters more than detail
- **Side-on or three-quarter view** — match what reads best per item (e.g.
  weapons usually side-on profile; helmets three-quarter; trinkets straight-on)
- **No held hands, no character body parts** — just the item floating
  isolated against transparent background (the magenta sheet bg gets keyed out)
- **Strong silhouette** — even at 48×48 the shape should be identifiable
- **Wear and damage are good** — chipped paint, dents, rust, frayed edges
  reinforce the wasteland aesthetic
- **One neon accent only** — a small glowing detail in the specified color;
  don't paint the whole item neon

---

## 5. Deliverables Summary

**Total: 18 equipment PNGs**

- 5 × `weak_hunter_*` items
- 5 × `tank_engineer_*` items
- 4 × plain items (`old_hat`, `scrap_breastplate`, `rusted_dagger`, `lucky_charm`)
- 2 × rare items (`wasteland_revolver`, `old_world_relic`)

All output to `battle_scene/assets/images/equipment/{item_id}.png`.

---

## 6. Verification

After all 18 PNGs land, the equipment panel (right-click `⚔ CHARACTER` button
on the map screen) should render every item with its real icon instead of the
colored slot-letter placeholder. The placeholder renderer
(`run_system/ui/equipment_icon.gd`) automatically falls back to the PNG via
`ResourceLoader.exists()` — no code change needed once the files are in place.

To verify a single icon loads, run the game, force the item into inventory
via the editor console (`RunManager.add_to_inventory("weak_hunter_helm")`),
open the equipment panel — the slot-letter placeholder should be replaced by
the new PNG.
