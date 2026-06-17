# Needed Art Assets — Codex Handoff

Per ADR-0005, Codex owns all art under `battle_scene/assets/images/**` and
`run_system/assets/images/**`. Claude writes this list + the asset-spec contracts;
it does not generate art.

> **Status — 2026-06-17.** Re-audited with `scripts/check_missing_art.py` (now also
> flags relics that share one icon). After the card cull, the remaining gap is
> **1 card + 6 relics** that reuse another asset's image. Everything else is bespoke.
> (Orphaned art from the 10 deleted cards has been removed from disk.)

## Mandatory style anchor (paste into every prompt)

```
original Offbeat Adult Sci-Fi Cartoon Wasteland game art, matching the approved
in-game exemplars in battle_scene/assets/images/heroes/cowboy_bill/cowboy_bill_identity_offbeat_v2.png,
battle_scene/assets/images/backgrounds/wasteland_battlefield.png, and
run_system/assets/images/map/wasteland_route_map_pixel_bg.png, flat 2D adult
sci-fi TV-animation look, thick clean dark cartoon outlines, large simple shape
blocks, sparse interior lines, broad two-to-three value cel shading, weird sci-fi
western wasteland, dusty leather, brass, dented grey-green robot metal, patched
red cloth, hoses, antennas, bright toxic green / cyan / warm orange glow accents
used sparingly, clean game-ready edges, readable silhouettes, low texture noise,
no text, no labels, no UI frame, no logo
```

---

## 1. Card illustration — `512x320` landscape PNG, transparent bg

Path: `battle_scene/assets/images/cards/player/<name>.png`. No UI frame / text baked in.

| id | card | effect | currently reuses | art direction |
|---|---|---|---|---|
| `combat_stim` | 战斗兴奋剂 Combat Stim | Gain 2 Strength | `brace.png` | a stim syringe of glowing serum jabbed into a muscular arm, muscles flexing, warm orange power-surge glow |

---

## 2. Relic icons — square PNG (≈128×128), transparent bg

Path: `run_system/assets/images/relics/<id>.png`. These 6 relics currently point at
**another relic's** icon — give each its own and confirm the JSON `icon` path matches.

| id | relic | effect | currently reuses | art direction |
|---|---|---|---|---|
| `thorn_harness` | 尖刺挽具 Thorn Harness | Start combat with 3 Thorns | `barbed_plating.png` | a leather-and-scrap harness studded with jutting metal thorns |
| `vampiric_coupler` | 吸血联结器 Vampiric Coupler | First-turn Block + Thorns | `barbed_plating.png` | a hose coupler / connector dripping blood, red veins, cyan glow |
| `brutal_servo` | 残暴伺服 Brutal Servo | +1 Bleed whenever you apply Bleed | `sharpened_scrap.png` | a brutal servo-motor piston with serrated edges, flecked with blood |
| `bulwark_plating` | 壁垒镀装 Bulwark Plating | -1 incoming damage + first-turn Block | `signal_jammer.png` | a heavy fortified armor plate / riot bulwark panel, rivets, brass trim |
| `kinetic_hammer` | 动能锤 Kinetic Hammer | First-turn temporary Strength | `war_horn.png` | a scrap war-hammer head crackling with kinetic energy, orange sparks |
| `war_drum` | 战鼓 War Drum | Start each combat with 2 Strength | `war_horn.png` | a scrap-metal war drum, taut hide, beaters, brass studs |

---

## ✅ Delivered (verified present on disk — no action)

- **All other player cards** are bespoke (only `strike.png` / `defend.png` remain as
  themselves, which is correct).
- **Relic icons** — 25 / 25 files exist (the 6 above just need to stop sharing).
- **Equipment sprites** — 21 / 21.
- **Enemy sprites** — 15 / 15, each with 4 attack frames.
- **Hero (cowboy_bill)** — 8 idle + 8 attack frames + identity references.
- **Status icons** — incl. `hot_streak`, `all_in`, `hemorrhage`, `covering_reload`.

---

## Notes
- Re-run the audit any time: `python scripts/check_missing_art.py` (flags missing,
  placeholder, duplicate card art, AND relics sharing one icon).
- Use `/codex-handoff` to turn §1 / §2 into a full `asset-spec-*.md` + prompt contract.
