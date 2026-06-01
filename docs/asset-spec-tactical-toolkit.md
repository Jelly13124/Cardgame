# Asset Spec — Tactical Toolkit Content Slice

**Audience:** codex (asset generation pipeline)
**Owner of code/JSON:** Claude (already implemented)
**Project:** Cardgame (Godot 4.6, Rick-and-Morty-like Offbeat Adult Sci-Fi Cartoon Wasteland roguelite)

This document is the contract that tells codex which sprites and card illustrations to generate for the Tactical Toolkit content slice. All gameplay code and JSON are already in place; the only thing blocking the slice from looking right in-game is the art listed here.

**Current style as of 2026-05-31:** this spec inherits `docs/art-style-reference.md` and ADR-0012. New generations must use the Rick-and-Morty-like Offbeat Adult Sci-Fi Cartoon Wasteland prompt anchor from `docs/project-rules.md` section 1. File dimensions below are output sizes only, not pixel-art style constraints.

If a sprite is missing, the game falls back to a colored `ColorRect` placeholder (enemies) or a missing-texture warning (cards). Nothing crashes — but it looks bad.

---

## 0. Style Preamble (Non-Negotiable)

Every prompt for every asset in this doc must preserve the current art direction from `docs/art-style-reference.md` and `docs/project-rules.md` section 1:

```text
original offbeat adult sci-fi cartoon wasteland game art, Rick-and-Morty-like broad adult sci-fi animation energy without copying named characters or exact show designs, thick dark rubbery outlines, flat bright color blocks, simple cel shading, exaggerated asymmetrical proportions, weird junk-tech silhouette, dusty western leather and brass, dented steel, exposed springs, patched cloth, one or two small glowing neon accents, crisp sprite-ready edges, solid #FF00FF magenta background for cleanup or transparent final PNG, no text, no UI frame, no logo
```

Style notes:
- File dimensions in the tables below are output-size requirements only; they do not imply pixel art.
- Use clean cartoon silhouettes, thick dark outlines, flat bright color blocks, and simple cel shading.
- Keep the wasteland-western junk-tech materials: dusty leather, brass, dented steel, exposed springs, patched cloth, rubber hoses, cracked glass.
- Use one or two small neon accents per item or character; do not flood the asset with glow.
- Keep designs original and do not copy named characters or exact show-specific designs.

---

## 1. Pipeline Reminders

Per `docs/project-rules.md` §2 and §3:

- **Sheet generation background:** solid `#FF00FF` (magenta) so chroma-keying can cleanly cut transparent backgrounds.
- **Final output:** transparent PNG, per-frame, named as specified below.
- **Card art:** scene-ready PNG — NO text, NO logos, NO UI elements baked in.
- **Side-view full body** for combat units; heroes face right, enemies face left.
- **Enemy facing:** final enemy PNG frames must face left toward the player. Normalize the source frames during post-processing rather than using a blanket runtime flip.
- **Frame counts (per entity):** 4 attack frames; frame 0 doubles as the static rest pose. Do not generate separate idle frames.
- **Frame size:** standard combat units use 128×128 native frames. Boss uses 192×192 native frames unless a later spec overrides it.
- **`.import` files:** Godot auto-generates these on first import. Do not write them manually.
- **Intermediate sheets** may stay in a `generated_sheet/` subfolder, but final per-frame PNGs are what gameplay loads.

---

## 2. Player Card Art (12 cards)

**Output folder:** `battle_scene/assets/images/cards/player/`
**File naming:** `{card_id}.png` — must match the `name` field in the matching JSON at `battle_scene/card_info/player/{card_id}.json`
**Reference for dimensions/composition:** existing `strike.png` in the same folder.
**Card art rules:** no text, no UI, no card frame — just the illustration. The in-game card frame is composed at runtime around the art.

| # | card_id | Theme prompt (append the §0 style suffix) | Neon accent |
|---|---|---|---|
| 1 | `stun_baton` | Rusted steel cattle-prod baton wrapped in copper wire, electric arcs crackling between two prongs at the tip, leather grip stained with grease | electric blue |
| 2 | `static_coil` | Forearm-mounted tesla coil device made of salvaged car parts, copper coils glowing, sparks arcing to a small junk shield | electric blue |
| 3 | `emp_burst` | A welded scrap grenade mid-throw, expanding rings of pale-blue electromagnetic shockwave radiating outward, debris caught in the wave | pale electric blue |
| 4 | `overload` | A jury-rigged pipe-rifle weapon firing with its barrel glowing white-hot, arcs of electricity surging up the wielder's arm | hot yellow-white |
| 5 | `cascade` | A wall of stacked muzzle-flashes overlapping in a horizontal sweep, three rusted weapons firing in sequence, brass casings flying | hot-orange |
| 6 | `salvo` | A three-barrel improvised cannon mounted on a forearm, all three barrels firing at once, smoke plumes and shell casings | hot-orange |
| 7 | `tinker` | Greasy scrapper hands welding/wrenching on a small geared mechanism, sparks from the weld, tools on a leather apron | yellow-green |
| 8 | `hot_swap` | A weathered hand snapping a fresh ammo drum into a junk-rifle in a blur of motion, spent magazine flying out the side | electric blue |
| 9 | `overdrive` | A wasteland warrior's silhouette pushed past their limit — body steaming, glowing reactor implant in chest about to crack, veins lit | hot-orange |
| 10 | `charged_shot` | A heavy improvised rifle fully charged — barrel wreathed in coiled cables, a brilliant pulse of energy forming at the muzzle | electric blue |
| 11 | `junk_bomb` | A welded mess of pipes, fuel cans, and rusted ordnance lashed together — a thrown improvised bomb mid-flight, fuse sparking | toxic-green |
| 12 | `adrenaline` | A battered hypodermic injector stabbed into a forearm vein, glowing chemical pushing into the bloodstream | toxic-green |

---

## 3. Enemy Sprite Sheets (4 normal + 1 elite + 1 boss)

For each enemy below, generate:
- **4 attack frames** (frame 0 is static rest pose, then build-up -> strike -> recovery)

**Output folders (per-animation subfolders, NOT loose at entity root):**
- `battle_scene/assets/images/enemies/{sprite_id}/attack/{sprite_id}_attack_0..3.png`
- `battle_scene/assets/images/enemies/{sprite_id}/charge/{sprite_id}_charge_0..3.png` (Boss only — telegraph)

**Frame size:** 128×128 native, transparent PNG, side view, baseline-aligned (feet at bottom of frame for normal enemies).

The `sprite_id` is identical to the value in the enemy's JSON `sprite_id` field at `battle_scene/card_info/enemy/{enemy_id}.json`.

### 3.1 `scrap_rat` (HP 12, swarmer)
- **Silhouette:** small low-to-ground robot rat, ~50% the height of a human, on six skittering legs
- **Materials:** salvaged scrap metal plates, exposed wiring along the spine, broken antenna ears
- **Rest pose:** crouched, head twitching implied by silhouette, occasional spark from antenna
- **Attack:** lunges forward biting with a steel-jaw mouth
- **Neon accent:** glowing red dot-eyes
- **Style suffix:** §0

### 3.2 `riot_hound` (HP 25, applies Weak)
- **Silhouette:** dog-sized armored attack drone shaped like a doberman, heavy plated head, low stance
- **Materials:** armored chest plate, riveted leg armor, a muzzle-mounted electric prod that arcs when it bites
- **Rest pose:** standing growl-stance, head lowered, prod-tip sparking
- **Attack:** lunges and bites with prod-arc discharging on impact
- **Neon accent:** electric-blue prod arcs and eye visor
- **Style suffix:** §0

### 3.3 `rust_brute` (HP 40, tank)
- **Silhouette:** hulking 2.2m humanoid covered in welded boilerplate, slow but massive
- **Materials:** patchwork plate armor, exposed pipe-arm hammer, leather-strap harness, ammo belts across chest
- **Rest pose:** wide stance, hammer-arm resting
- **Attack:** big overhead pipe-hammer slam
- **Neon accent:** glowing yellow welding-helmet visor
- **Style suffix:** §0

### 3.4 `mortar_cart` (HP 28, telegraphs big AoE)
- **Silhouette:** wheeled artillery cart, mortar-tube angled up, two big spoked junkyard wheels
- **Materials:** rusted iron cart, shells stacked behind the tube, leather straps and chains
- **Rest pose:** cart braced in place, smoke trickling from tube
- **Attack:** tube recoils violently as it fires (the big-AoE frame); show flash and smoke
- **Neon accent:** glowing toxic-green chemical shell loaded in the breach (visible in attack frame 0)
- **Style suffix:** §0

### 3.5 `armored_patrol` (Elite, HP 50)
- **Silhouette:** armored riot guard, ~human height + 30%, riot shield in one hand, shock baton in the other
- **Materials:** scavenged police riot armor riveted with extra plates, helmet visor, ballistic shield with painted faction sigil
- **Rest pose:** combat stance behind shield, baton resting on shield rim
- **Attack:** swings the baton over the shield with a downward strike
- **Neon accent:** magenta visor-glow and faint magenta sigil paint on shield
- **Style suffix:** §0

### 3.6 `junkyard_tyrant` (Boss, HP 110)
**This is the boss — bigger and more distinctive than normal enemies.**

- **Frame size:** **192×192 native** (renders at 1.5× the scale of normal enemies)
- **Silhouette:** 2.5m tyrant in welded scrap-king armor, asymmetric one shoulder pauldron made from a car door, the other arm a massive piston-driven sledge
- **Materials:** dented car panels, chain mail of bottle caps and washers, a crown of bent rebar
- **Rest pose:** menacing stance, sledge resting on shoulder
- **Attack (4 frames):** wind-up → overhead sledge swing → impact crater → settle
- **Optional charge frames (`junkyard_tyrant_charge_0..3.png`)** for the telegraph action: 4 frames of the boss raising the sledge over its head with growing electric/orange energy at the head of the sledge. *(If charge frames are not generated, the engine keeps the static attack_0 rest pose — non-blocking.)*
- **Neon accent:** hot-orange sparks at the joints of the piston-arm; sledge head glows orange when charging
- **Style suffix:** §0

---

## 4. Existing Heroes / FX — Do Not Regenerate

Codex should NOT touch:
- `battle_scene/assets/images/heroes/cowboy_bill/*` (already present)
- `battle_scene/assets/images/enemies/trash_robot/*` (already present)
- `battle_scene/assets/images/enemies/wasteland_killer/*` (already present)
- `battle_scene/assets/images/fx/*` (already present)
- `battle_scene/assets/images/cards/player/{strike,defend,override,preemptive_strike,weak_strike}.png` (already present)
- `battle_scene/assets/images/cards/ui/*` (already present)

---

## 5. Delivery Checklist

When this slice is "art-complete," the project tree should contain:

```
battle_scene/assets/images/cards/player/
  stun_baton.png
  static_coil.png
  emp_burst.png
  overload.png
  cascade.png
  salvo.png
  tinker.png
  hot_swap.png
  overdrive.png
  charged_shot.png
  junk_bomb.png
  adrenaline.png

battle_scene/assets/images/enemies/scrap_rat/
  attack/  scrap_rat_attack_0..3.png

battle_scene/assets/images/enemies/riot_hound/
  attack/  riot_hound_attack_0..3.png

battle_scene/assets/images/enemies/rust_brute/
  attack/  rust_brute_attack_0..3.png

battle_scene/assets/images/enemies/mortar_cart/
  attack/  mortar_cart_attack_0..3.png

battle_scene/assets/images/enemies/armored_patrol/
  attack/  armored_patrol_attack_0..3.png

battle_scene/assets/images/enemies/junkyard_tyrant/
  attack/  junkyard_tyrant_attack_0..3.png
  charge/  junkyard_tyrant_charge_0..3.png   (optional — for telegraph)
```

Total: **12 card PNGs + 20 enemy PNGs + 4 boss attack PNGs (+ 4 optional charge PNGs) = 36-40 assets.**

---

## 6. Cross-References

- Gameplay design (what each thing does in-game): `C:\Users\Jerry\.claude\plans\clever-frolicking-pixel.md`
- Card JSON definitions (already written): `battle_scene/card_info/player/*.json`
- Enemy JSON definitions (already written): `battle_scene/card_info/enemy/*.json`
- Art rules of record: `docs/project-rules.md`
- PRD (broader product context): `docs/PRD.md`
