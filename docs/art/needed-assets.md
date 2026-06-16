# Needed Art Assets — Codex Handoff

Per ADR-0005, Codex owns all art under `battle_scene/assets/images/**` and
`run_system/assets/images/**`. Claude writes this list + the asset-spec contracts;
it does not generate art.

> **Status — 2026-06-16.** Re-audited with `scripts/check_missing_art.py` (read-only
> cross-reference of every data-referenced PNG against disk). Codex's overnight pass
> delivered almost everything. What remains is **4 ability cards that all reuse
> `brace.png`** as a fallback and still need their own illustration. Everything below
> §1 (cards) is otherwise complete.

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

## 1. Card illustrations still needed — `512x320` landscape PNG, transparent bg

Path: `battle_scene/assets/images/cards/player/<name>.png`. No UI frame / text / cost
baked in. **These 4 ability cards currently all point at `player/brace.png`** — give
each its own art and the JSON already resolves (no Claude change needed).

| id | card | rarity | effect | art direction |
|---|---|---|---|---|
| `combat_stim` | 战斗兴奋剂 Combat Stim | uncommon | Gain 2 Strength | a stim syringe of glowing serum jabbed into a muscular arm, muscles flexing, warm orange power-surge glow |
| `pain_damper` | 痛觉抑制 Pain Damper | uncommon | Gain Block when a card is Exhausted | a shock-absorbing padded brace / damper rig soaking a blow, cushioned plates, cool blue numbing glow |
| `plating_loop` | 装甲循环 Plating Loop | uncommon | [Yin] Gain Block each turn | self-cycling layered armor plates spiralling into a protective shell, cool cyan "loop" motion lines |
| `salvage_loop` | 回收循环 Salvage Loop | rare | Draw when a card is Exhausted | a salvage hopper feeding scrap through a conveyor loop that comes back as fresh parts/cards, green recycle glow |

---

## ✅ Delivered (verified present on disk — no action)

- **All other 64 player cards** have bespoke art (only `strike.png` / `defend.png`
  remain as themselves, which is correct).
- **Relic icons** — 25 / 25 present, incl. `double_fire_clip`, `serrated_barbs`.
- **Equipment sprites** — 21 / 21 present (`battle_scene/assets/images/equipment/`).
- **Enemy sprites** — 15 / 15, each with 4 attack frames.
- **Hero (cowboy_bill)** — 8 idle + 8 attack frames + identity references.
- **Status-effect icons** — incl. the new `hot_streak`, `all_in`, `hemorrhage`,
  `covering_reload`.

---

## Notes
- Card art is a pure illustration; frame/cost/title/rarity are drawn by the card
  scene (`512x320`, no baked UI).
- Re-run the audit any time with `python scripts/check_missing_art.py`.
- Use `/codex-handoff` to turn §1 into a full `asset-spec-*.md` + prompt contract.
