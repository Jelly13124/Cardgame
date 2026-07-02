# Asset Spec — Equipment shell icons + set-piece icons

**Owner:** Codex (ADR-0005 — Codex generates all PNGs under `**/assets/images/**`).
**Status:** Requested 2026-07-02.
**Design:** `docs/superpowers/specs/2026-07-01-equipment-affix-shell-redesign-design.md`.
**Companion:** `docs/asset-spec-ui-icons.md` (slot icons, same size/treatment).

## Context

The equipment system was reworked to **generic shells + rolled affixes**. Equipment no
longer has one bespoke art per item; instead **the same icon is shared per slot × rarity**.
`equipment_icon.gd` now resolves art in three tiers:
1. a bespoke `sprite` (set pieces only),
2. else a shared shell icon at `battle_scene/assets/images/ui/equipment/{slot}_{rarity}.png`,
3. else the slot fallback icon.

Tier 2 art does not exist yet — the code falls back to slot icons until Codex delivers.

## Deliverables

### A. Generic shell icons — 20 PNGs, **64×64**, into `battle_scene/assets/images/ui/equipment/`

5 slots × 4 tiers. File = `{slot}_{tier}.png`:

| slot \ tier | common | uncommon | rare | cursed |
|---|---|---|---|---|
| head | `head_common.png` | `head_uncommon.png` | `head_rare.png` | `head_cursed.png` |
| chest | `chest_common.png` | … | … | `chest_cursed.png` |
| weapon | `weapon_common.png` | … | … | `weapon_cursed.png` |
| hands | `hands_common.png` | … | … | `hands_cursed.png` |
| accessory | `accessory_common.png` | … | … | `accessory_cursed.png` |

**Subject per slot:** head = salvage helmet/visor; chest = patched plate/vest; weapon =
salvaged revolver (Bill's sidearm silhouette); hands = work glove/gauntlet; accessory =
charm/trinket (gear-token motif).

**Tier reads through material/finish + a tier tint** (the UI already draws a rarity-colored
BORDER around the cell, so the icon itself just needs a readable tier feel, not a frame):
- **common** — dull scrap, grey/graphite, plain.
- **uncommon** — cleaner metal, steel-blue accents.
- **rare** — polished, brass-gold accents, one bright glint.
- **cursed** — corrupted/rusted-red, a sickly red glow accent.

Same slot across tiers should be clearly the SAME object family, just upgraded/corrupted —
so the player reads "rare helmet" vs "common helmet" at a glance.

### B. Set-piece icons — 15 PNGs, **64×64**, bespoke

3 sets × 5 slots, into the path each set-piece JSON's `sprite` field points to (under
`battle_scene/assets/images/equipment/…`). Sets are the green "collect the set" gear, so
each set has its own distinct silhouette/theme with a **green** tier tint:
- **tank_engineer** — heavy riveted industrial armor.
- **warden** — ember-scarred plate (now bleed-themed; barbed/blood accents, not fire).
- **weak_hunter** — lean scavenger kit.
(5 pieces each: head / chest / weapon / hands / accessory.)

## Hard requirements

- **PNG with alpha, transparent background**, centered subject, even padding, reads at ~44px.
- **ONE clear silhouette** + thick dark cartoon outline; 2–3 value cel shading; low texture noise.
- **NO text / number / letter / UI frame / border** baked in (the cell draws the rarity border).
- Style = locked **Offbeat Adult Sci-Fi Cartoon Wasteland** (match Cowboy Bill + existing
  `ui/attributes/*.png` / `ui/slots/*.png`). 64×64 is an output contract only — never pixel art.
- Use the mandatory prompt anchor from `docs/art-style-reference.md` (§Prompt Anchor) plus:
  `single game UI equipment icon, one clear silhouette, no text, no number, no frame, transparent background, 64x64`.

## Wiring after delivery (code side — already done)

- Shell icons: `equipment_icon.gd` already resolves `ui/equipment/{slot}_{rarity}.png` (tier 2).
  Dropping the 20 files in is enough — no code change.
- Set pieces: keep pointing at their JSON `sprite` path (tier 1). Dropping the 15 files in is enough.

## Review gate

Deliver a SAMPLE first — one full slot across all 4 tiers (e.g. `weapon_common/uncommon/rare/cursed.png`)
plus one set piece — to `docs/art/previews/equipment_shells_<date>/` for approval before batching
the rest. Same discipline as the other art (don't batch a full set unattended).
