# Spec — Equipment Economy + A0 Combat Balance Pass (2026-06-22)

Overnight `/goal`. Two coupled bodies of work, executed autonomously, smoke-gated +
MCP-verified per phase, committed per phase (NOT pushed — owner verifies in the
morning). Locked via discussion; this is the build sheet.

## Goals

1. **Equipment economy** — replace "equipment only from bosses" (which stranded 3/5
   gear slots and killed set bonuses) with a Luck-driven drop matrix, mirroring the
   tool system. Equipment becomes a steady-but-premium drop again.
2. **A0 difficulty target** — tune cards + enemies so Ascension 0 reads:
   - A player **with ~5 equipment pieces + ~5 attribute points** clears the 2-act
     demo with some strategic deckbuilding.
   - A **fresh, ungeared** player — after learning the mechanics — beats the **Act-1
     boss (rust_titan)** in **2–3 attempts** (the early skill gate).
   - A0 must be hard enough to **drive meta-progression + gear collection**.
   - Lever: enemies lean offensive (fewer block actions), and the over-statted
     "win-button" cards get deflated. **Nerf-first**, then raise enemy pressure.

### The A0 math this is sized against (verified in combat_engine.gd / run_manager.gd)
- Player: 50 HP, 3 energy/turn, **0 starting attributes**. Starter = 4×strike(3) +
  weak_strike(3) + 4×defend(3).
- **+1 STR = +1 damage on every `deal_damage` instance; +1 CON = +1 block on every
  `gain_block`** (combat_engine.gd:257-259). So a geared+leveled `+5 STR / +5 CON`
  Bill does ~**+20-25 dmg/turn** and mitigates ~**+10-15/turn** vs a fresh Bill —
  gear/levels roughly **double** effective combat power. That ~2× headroom is what
  lets us push A0 ~30-50% harder against the ungeared baseline while keeping the
  geared player on-curve.
- Act multipliers (run_manager.gd:312-313): Act1 ×1.0/1.0, Act2 ×1.25/1.15. **Bosses
  are EXEMPT** — boss numbers below are final/raw.

---

## Phase 1 — Equipment economy (drop matrix)

Mirror the tool drop system. Files: `run_system/ui/loot_reward.gd`,
`run_system/core/run_manager.gd`, `battle_scene/battle_scene.gd`, `assets/translations/`.

**Drop matrix (final):**

| Node | Drops |
|---|---|
| Normal | gold + 3-choose-1 card + **tool** (`0.25+0.03·Luck`, ≤0.60) + **equipment** (`0.12+0.02·Luck`, ≤0.35, **common**) — independent rolls |
| Elite | gem 3-choose-1 + **equipment** (Luck chance, **uncommon**). **NO tool.** |
| Boss | **equipment guaranteed (rare)** + gem (both already exist) |
| Shop | cards + relics + tools + remove (no equipment — unchanged from P4) |

Implementation:
- `RunManager.luck_equip_chance() -> float` = `clampf(0.12 + 0.02*luck, 0.0, 0.35)`. [tunable]
- `RunManager.equip_rarity_for_node(node_type)` → normal=`common`, elite=`uncommon`
  (boss handled in battle_scene as `rare`).
- `loot_reward._generate_loot()`:
  - Normal: keep the existing tool roll; ADD an independent equipment roll
    (`randf() < luck_equip_chance()` → `roll_equipment_drop("common")` → an
    `"equipment"` loot row via the existing `_claim_equipment_drop` path).
  - Elite: REMOVE the guaranteed tool (was P4). Keep the gem draft. ADD an equipment
    roll at `uncommon` (Luck-gated, NOT guaranteed).
- Boss equipment (battle_scene.gd) already grants guaranteed `rare` — unchanged.
- Luck tooltip already mentions "gem & tool find"; extend to "gem / tool / equipment".
- **Watch-item (note in code comment, not a blocker):** equipment + gems + gold now
  share the 10-cell backpack; more equipment = more backpack pressure. The
  inventory-full modal already handles equip overflow (discard-to-take).

Verify: normal fight can roll a common equip row; elite shows gem + (chance) uncommon
equip and NO tool; boss still grants rare equip; high-Luck raises equip frequency.

---

## Phase 2 — Deck deflation (card nerfs + tool tweaks)

The inflated 1-cost economy is the biggest difficulty leak (an ungeared deck already
has the power gear is meant to provide). Anchors: strike 1c=3, piston_jab 1c=4,
defend 1c=3. Files: `battle_scene/card_info/player/*.json`, `run_system/data/tools/*.json`.

**Card nerfs:**

| Card | Cost/Rarity | Change | Why |
|---|---|---|---|
| `hemo_drive` | 1 / uncommon | `deal_damage 15 → 9` | 1-cost out-damaged every 2-cost attack; worst offender |
| `breach_charge` | 1 / common | `deal_damage_all 9 → 6` | a common beating the uncommon AoE (sweep_arc 8) |
| `bulkhead_bleed` | 2 / uncommon | `gain_block 16 → 12` | one card negated a telegraphed boss slam |
| `vent_plating` | 1 / common | `gain_block 8 → 6` | strictly-better defend that cantrips (draw 1), no Exhaust |
| `pipe_swing` | 2 / common | `deal_damage 12 → 9` | common out-damaging uncommon attacks, +Weak rider |
| `siphon_valve` | 0 / uncommon | add `exhaust_self` | repeatable +2 energy battery = rare effect with no gate |

**Tool tweaks:**
- `shock_charge`: `apply_status vulnerable 2 + weak 2` → **vulnerable 2 + weak 1**
  (rare-tier value at uncommon cost).
- `smoke_bomb`: `gain_block 12 → 10` (edged past the common card block ceiling). [tunable]
- `frag_grenade`: **unchanged** — on-curve (breach_charge prints comparable on a common).

**Leave alone (verified safe):** ammo/reload cards (no-op without Double-Fire Clip
relic), bleed (front-loaded + self-halving), focusing_blow/incinerate (on-rarity-curve),
combat_stim/limit_break STR line (intended rare payoff — monitor only).

Verify: smoke (validator) + the numbers land in the catalog regen.

---

## Phase 3 — Enemy aggression (fewer blocks, more attacks)

Roster is too passive (median standard DPT ≈4.5 vs 50 HP). Convert block actions to
attacks so the ungeared deck feels real pressure. Files:
`battle_scene/card_info/enemy/*.json`. Target: standard DPT floor ~5, elite ~7.

| Enemy | Tier | Change |
|---|---|---|
| `armored_patrol` | elite | one `block 12 → attack 10` (was 50% block turns) |
| `chrome_hound` | std | `block 10 → attack 8` (keep the dodge — good counterplay) |
| `slag_walker` | std | one `block 6 → attack 7` |
| `riot_hound` | std | `block 4 → attack 5` |
| `mortar_cart` | std | cut one `block 4`; bump AoE `12 → 14` |

**Keep block on:** `rust_brute` (brute-wall identity, already ~5.6 DPT) and all
**telegraph→interruptible** big hits (the sanctioned counterplay). Don't touch enemies
already aggressive (scrap_rat, acid_spitter, trash_robot, riot_hound_alpha, wasteland_killer).

Verify: MCP — spawn each changed enemy, confirm its intents now lean attack and it
parses/acts without error.

---

## Phase 4 — Act-1 boss skill gate (`rust_titan`)

The early gate. Currently 75 HP and two phase-1 block turns that *help the player
stall* — brute-forceable, doesn't teach the interrupt. File:
`battle_scene/card_info/enemy/rust_titan.json`.

| Change | From → To | Why |
|---|---|---|
| HP | `75 → 90` | survives a single good-draw burst; ~8-turn fight (still < ash_warden 95) |
| Phase-1 post-slam `block 8` | → `attack 10` | phase-1 DPT 6.9 → ~8.3; unmitigated turns now bite |
| `slam` | `18 → 20` (keep interruptible) | teaches the interrupt without being unfair |
| Phase-2 enrage Thorns | `4 → 6` | the enrage actually punishes spam-attack lines |

Net: ~90 HP / ~8 DPT / 20 telegraphed slam / 6-Thorns enrage = geared player clears
comfortably, ungeared loses 1-2× while learning to interrupt + stop face-tanking
phase 2 = the "2-3 attempts" target.

Verify: MCP — fight rust_titan with a fresh starter deck; confirm phase transition,
the 20 slam, 6 Thorns on enrage; sanity-check it's threatening but not unwinnable.

---

## Phase 5 — Verification + sync

- `python scripts/gen_catalog_html.py` (cards/enemies changed → keep catalogs in sync).
- Full `bash scripts/smoke_test.sh` green.
- MCP combat spot-checks: (a) a fresh-deck normal fight vs a buffed standard enemy —
  confirm the deflated deck no longer trivializes it; (b) the rust_titan gate.
- Write a short **A0 damage-model note** (ungeared vs +5/+5 geared, turns-to-kill
  rust_titan both ways) into the spec's appendix so the morning review has the math.
- Per phase: commit with `[overnight PN]`. Do NOT push.

---

## Tunable knobs (all flagged for post-playtest tuning)
Equip drop `0.12+0.02·Luck` cap `0.35`; tool drop `0.25+0.03·Luck` cap `0.60`; every
card/enemy/boss number above; rust_titan HP 90; smoke_bomb 10. The owner playtests A0
and dials from here.

## Out of scope (this run)
Shop equipment (stays tools-only); buffing weak cards (focus is nerf + enemy pressure);
Ascension 1-5 retune (A0 first); second hero.
