# Asset Spec — Tool Icons (Codex)

> **For Codex (ADR-0005).** 8 one-time battle tools (StS2-style consumables).
> They sit in the battle top bar's **tool shelf** (`run_system/ui/run_top_bar.gd`
> `_make_tool_slot`). Today each slot renders a 1–2 char glyph fallback
> (`_short_label`) because the icon PNGs don't exist yet. This spec is for those
> per-tool icons; the loader already points at the paths below.

## Deliverable

One PNG per tool id below.

- **Target path:** `run_system/assets/images/ui/tools/<id>.png`
  (matches the `"icon"` field already in each `run_system/data/tools/<id>.json`).
- **Source size:** 64×64, transparent background. Displayed small (~34×34 in the
  shelf), so the silhouette must read at tiny size — one bold object, high
  contrast, thick dark outline so it stays legible on the dark top-bar strip.
- **Style:** match the existing wasteland / salvaged-tech look of the currency and
  status icons — hand-painted, slightly grimy, warm metal + worn paint. Each tool
  is a physical scavenged gadget, not a flat UI glyph.
- **Rarity tint (subtle):** commons lean grey/steel; uncommons get a faint warm
  rim-light or brass accent so the player can feel "uncommon" at a glance. Don't
  add gem-frames or borders — the shelf slot draws its own frame.

## No wiring needed after art lands

The shelf already calls `load(tool.icon)` and only falls back to the glyph when the
texture is missing, so dropping the PNGs in is enough — no code or JSON change.
(If a path is wrong the slot silently shows the glyph again, never errors.)

## Tools

| id | name (en / zh) | rarity | effect | current glyph | icon direction |
|----|----------------|--------|--------|---------------|----------------|
| `med_kit` | Med Kit / 医疗包 | common | Heal 6 | 医 | first-aid tin / red-cross kit, lid ajar |
| `energy_cell` | Energy Cell / 能量电池 | common | +2 Energy this turn | 能 | salvaged battery cell, glowing bolt mark |
| `adrenaline_shot` | Adrenaline Shot / 肾上腺素 | common | Draw 2 cards | 抽 | auto-injector / syringe, amber fluid |
| `frag_grenade` | Frag Grenade / 碎片手雷 | common | Deal 10 to one enemy | 手 | pineapple grenade, pin + lever |
| `smoke_bomb` | Smoke Bomb / 烟雾弹 | common | Gain 12 Block | 烟 | thrown canister venting grey smoke |
| `combat_stim` | Combat Stim / 战斗兴奋剂 | uncommon | +2 Strength | 力 | stim vial w/ up-arrow / flexed bolt, brass cap |
| `toxin_vial` | Toxin Vial / 毒素瓶 | uncommon | Apply 4 Bleed to one enemy | 毒 | green poison vial, dripping skull-tint |
| `shock_charge` | Shock Charge / 电击装置 | uncommon | Apply 2 Vulnerable + 2 Weak to one enemy | 电 | sparking EMP puck / arcing electrodes |

Display names + descriptions live in `assets/translations/content_cards.csv` as
`TOOL_<ID>_TITLE` / `TOOL_<ID>_DESC` (zh-primary). Enemy-target tools
(`frag_grenade`, `toxin_vial`, `shock_charge`) read as offensive; the rest are
self/utility.
