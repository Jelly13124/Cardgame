# Needed Art Assets — Codex Handoff

Per ADR-0005, **Codex owns all art** under `battle_scene/assets/images/**` and
`run_system/assets/images/**`. Claude writes this contract + does any JSON/code
wiring; Claude does not generate art.

> **Status — 2026-06-18.** The demo-visible art backlog is DELIVERED: the bleed
> status icon, all 4 remaining relic icons, the starter-card polish art
> (`strike` / `defend`), and a dedicated title-screen key-art backdrop are present.
> Run `python scripts/check_missing_art.py` to re-confirm.
>
> **Delivered ? demo-visible (priority):**
> - **`bleed` status icon** ? `64?64` transparent PNG ? `battle_scene/assets/images/ui/status/bleed.png`.
>   Delivered as a red blood-drop / laceration motif. The old top-level
>   `poison.png` status icon was removed because runtime data now uses `bleed`.
> - **4 relic icons** ? `128?128` transparent PNG ? `run_system/assets/images/relics/<id>.png`
>   (all reachable in the demo via relic rewards / the Act 2 upgrade node):
>   - `ricochet_loader` ? delivered as a bespoke ricochet ammo-feeder icon.
>   - `crit_clip_volatile`, `crit_clip_deadeye` ? delivered as Crit Clip upgrade variants.
>   - `double_fire_clip_burst` ? delivered as a Double-Fire Clip burst upgrade variant.
>
> **Optional polish delivered:** a real title-screen key-art backdrop replaced the
> main-menu reuse of `wasteland_battlefield.png`; `strike` / `defend` now have
> fresh starter-card illustrations.
>
> **Full game only (NOT in the Bill-only demo):**
> - **Enemy redo** is owner-driven and in flight — keep the new style consistent.
>
> (The 2nd hero "Feng Shui Master" was removed from the project on 2026-06-18,
> so its character-art gap no longer applies.)

## Mandatory style anchor (paste into EVERY prompt)

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

## §1 — Card illustration · `512×320` landscape PNG · transparent bg

Path: `battle_scene/assets/images/cards/player/<id>.png`. Pure illustration (the
frame / cost / title are drawn by the card scene). The JSON `front_image` already
points here — no wiring needed once delivered.

| id | card | effect | now reuses | art direction |
|---|---|---|---|---|
| `combat_stim` | 战斗兴奋剂 Combat Stim | Gain 2 Strength | `brace.png` | a stim syringe of glowing serum jabbed into a muscular arm, muscles flexing, warm orange power-surge glow |

---

## §2 — Relic icons · `128×128` square PNG · transparent bg

Path: `run_system/assets/images/relics/<id>.png`. These 6 relics currently point at
**another relic's** icon. Deliver a bespoke icon at the SAME path (the file already
exists as a borrowed copy — overwrite it); the JSON `icon` field is already correct.

| id | relic | effect | now reuses | art direction |
|---|---|---|---|---|
| `thorn_harness` | 尖刺挽具 | Start combat with 3 Thorns | `barbed_plating.png` | a leather-and-scrap harness studded with jutting metal thorns |
| `vampiric_coupler` | 吸血联结器 | First-turn Block + Thorns | `barbed_plating.png` | a hose/pipe coupler dripping blood, red veins, faint cyan glow |
| `brutal_servo` | 残暴伺服 | +1 Bleed when you apply Bleed | `sharpened_scrap.png` | a brutal servo-motor piston with serrated edges, flecked with blood |
| `bulwark_plating` | 壁垒镀装 | −1 incoming damage + first-turn Block | `signal_jammer.png` | a heavy fortified armor plate / riot-bulwark panel, rivets, brass trim |
| `kinetic_hammer` | 动能锤 | First-turn temporary Strength | `war_horn.png` | a scrap war-hammer head crackling with kinetic energy, orange sparks |
| `war_drum` | 战鼓 | Start each combat with 2 Strength | `war_horn.png` | a scrap-metal war drum, taut hide, beaters, brass studs |
| `ricochet_loader` | 跳弹供弹器 (rare) | On Crit, add a Reload card to hand | (new — no icon yet) | a brass bullet ricocheting off a spring-loaded ammo feeder, cyan spark, lucky/ammo feel |
| `crit_clip_volatile` | 易爆暴击弹夹 (unique upgrade) | Crits deal 1.75x | reuses `crit_clip.png` | the Crit Clip but charged/overloaded — cracked casing, volatile orange-red energy leaking, danger glow |
| `crit_clip_deadeye` | 神射暴击弹夹 (unique upgrade) | First attack each turn auto-Crits | reuses `crit_clip.png` | the Crit Clip with a precision/scope motif — crosshair etched on the clip, single steady cyan targeting glint |
| `double_fire_clip_burst` | 爆发弹夹 (unique upgrade) | Replay 1 + 2 attacks on turn 1 | reuses `double_fire_clip.png` | the Double-Fire Clip enlarged to a triple/burst magazine — three rounds chambered, muzzle-burst spark |

---

## §3 — Gem icons · `64×64` square PNG · transparent bg  (NEW)

Path: `run_system/assets/images/gems/<id>.png` (new folder). Renders in a **30×30**
socket on the card top-right, so keep the silhouette bold and centred, readable when
tiny. Theme each as a small glowing faceted gem with a motif for its effect.
**Wiring:** after delivery, Claude adds `"icon": "res://run_system/assets/images/gems/<id>.png"`
to each gem JSON (the card scene already loads `gem_data.icon`).

| id | gem | effect | art direction |
|---|---|---|---|
| `brute` | 蛮力宝石 | +1 Strength | red/orange faceted gem, clenched-fist or muscle motif, aggressive |
| `bulwark` | 壁垒宝石 | +4 Block | steel-blue faceted gem, shield motif, defensive |
| `keen` | 锋锐宝石 | Deal 3 damage | white/silver gem, sharp blade-edge facets |
| `leech` | 吸血宝石 | Heal 2 | crimson gem with a blood-drop highlight, life-steal feel |
| `spark` | 电火花宝石 | +1 Energy | cyan/electric gem crackling with little arcs |
| `swift` | 迅捷宝石 | Draw 1 card | green/teal gem, motion-streak / arrow motif |
| `venom` | 毒囊宝石 | Apply Poison | toxic-green gem, dripping-poison or skull motif |
| `wealthy` | 富裕宝石 | +5 Gold | gold/amber gem, coin or `$` glint motif |

---

## §4 — Status icon · `64×64` square PNG · transparent bg  (NEW)

Path: `battle_scene/assets/images/ui/status/<name>.png`. Renders at ~30px next to the
unit; bold single-glyph readability. Matches the existing status-icon set.

| name | status | currently | art direction |
|---|---|---|---|
| `bullet` | 装弹 / remaining attacks | a `●` dot glyph (warm gold) | a single brass rifle cartridge / bullet, warm gold (#ffc759), slight cyan rim-light |
| `bleed` | 流血 / Bleed | text glyph fallback | a red blood-drop / laceration slash motif |

---

## §5 — Attribute icons · `64×64` square PNG · transparent bg  (NEW)

Path: `battle_scene/assets/images/ui/attributes/<id>.png` (new folder). Small HUD
icons for the 5 character attributes — shown on the character page and next to stat
readouts. Bold single-shape silhouette, readable when small, tinted to each
attribute's accent colour. **Wiring:** Claude points the attribute UI at these after
delivery.

| id | attribute | effect | accent | art direction |
|---|---|---|---|---|
| `strength` | 力量 Strength | +1 attack damage / point | orange `#ff8033` | a flexed muscular arm / clenched fist |
| `constitution` | 体质 Constitution | +1 Block / point | blue `#4da6ff` | a sturdy heart-plate / armored torso |
| `intelligence` | 智力 Intelligence | +5% combat XP / point | purple `#b366ff` | a gear-brain / circuit sigil |
| `luck` | 幸运 Luck | +crit / loot rarity | yellow `#ffe14d` | a horseshoe or four-leaf clover with a sparkle |
| `charm` | 魅力 Charm | −shop prices, event options | pink `#ff80c4` | a winking star / charm pendant |

---

## Deliverables checklist

**Delivered 2026-06-18 (remaining demo-visible gaps):**
- [x] §4 ui/status/`bleed`.png
- [x] §2 relics/`ricochet_loader`.png
- [x] §2 relics/`crit_clip_volatile`.png
- [x] §2 relics/`crit_clip_deadeye`.png
- [x] §2 relics/`double_fire_clip_burst`.png

**Optional polish delivered 2026-06-18:**
- [x] title-screen key-art backdrop (`battle_scene/assets/images/backgrounds/title_key_art.png`)
- [x] fresh `strike` / `defend` starter-card illustrations

**Delivered 2026-06-18 (`f07b58f`):** §1 combat_stim · §2 thorn_harness, vampiric_coupler,
brutal_servo, bulwark_plating, kinetic_hammer, war_drum · §3 all 8 gems · §4 bullet · §5 all 5 attributes.

## Notes
- Re-run the audit any time: `python scripts/check_missing_art.py` (flags missing /
  placeholder / duplicate card art / relics sharing one icon).
- Claude wiring after delivery: add the `icon` field to the 8 gem JSONs (§3) and
  point the attribute UI at §5. Cards, relics and the status icon need no wiring —
  they load from their fixed paths.
