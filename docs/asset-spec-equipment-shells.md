# Generic Equipment Shell Runtime Contract

**Art direction:** `docs/art-style-reference.md`.

## Runtime model

Generic equipment uses shared art by `slot × rarity`. The 15 generic equipment
JSON files intentionally keep `sprite: ""`; `run_system/ui/equipment_icon.gd`
resolves them from:

`battle_scene/assets/images/ui/equipment/{slot}_{rarity}.png`

Set pieces are a separate class of asset. Their JSON files contain `set_id` and
an explicit `sprite`, so the 15 set-piece images are not part of this delivery
and must not be overwritten by generic-shell work.

## Shell matrix

Five slots × three production rarities = 15 PNGs:

| slot | common — 拾荒者 | uncommon — 游骑兵 | rare — 军官 |
|---|---|---|---|
| head | `head_common.png` | `head_uncommon.png` | `head_rare.png` |
| chest | `chest_common.png` | `chest_uncommon.png` | `chest_rare.png` |
| weapon | `weapon_common.png` | `weapon_uncommon.png` | `weapon_rare.png` |
| hands | `hands_common.png` | `hands_uncommon.png` | `hands_rare.png` |
| accessory | `accessory_common.png` | `accessory_uncommon.png` | `accessory_rare.png` |

Visual series language:

- **拾荒者 / common:** dusty brown leather, crude charcoal scrap, one large
  patch or repair, restrained bottle-cap brass.
- **游骑兵 / uncommon:** cleaner olive-grey field gear, simple utility shapes,
  one tiny cyan or amber technology accent.
- **军官 / rare:** charcoal structure, clean brass braces, muted red cloth and
  one warm-orange energy core.

Slot subjects remain readable across all three series:

- head: western field hat / scout hat / officer battle cap;
- chest: patched leather vest / tactical vest / simplified heavy armor;
- weapon: scavenged revolver / ranger revolver / charged revolver;
- hands: work gauntlet / ranger gauntlet / power gauntlet;
- accessory: fang necklace / blank dog tags / core medal.

## Technical contract

- **256×256 RGBA PNG**, transparent background.
- One centered object with a maximum visual extent of roughly 210–230 px.
- Transparent safety margin on all four edges; no non-transparent edge pixels.
- No baked UI frame, rarity border, text, number, logo or character hand/body.
- Thick clean dark-brown outline, large flat shape blocks, sparse interior
  lines and broad two-to-three-value cel shading.
- No pixel art, painterly rendering, photoreal material, gritty grain,
  crosshatching, dense scratches/rivets or dark-fantasy ornament.
- Equipment textures use **linear filtering** in inventory, drag preview,
  forge and market presentations.

## Set-piece boundary

The following three five-piece sets retain their existing bespoke images:

- `tank_engineer`
- `warden`
- `weak_hunter`

Do not infer set membership from rarity. Only a non-empty `set_id` identifies a
set piece.

## Cursed-state note

`cursed` is an instance rarity/state, not one of the 15 base shell definitions.
Dedicated `*_cursed.png` art is outside this contract. Any future cursed-art
decision must preserve the 15 base identities and must not modify set pieces.

## Validation

The equipment asset contract must verify all 15 files, their 256×256 size,
alpha channel, transparent edges, successful resolver loading and linear UI
filtering. Runtime review must include at least the market's large product cards
and the character/backpack presentation.
