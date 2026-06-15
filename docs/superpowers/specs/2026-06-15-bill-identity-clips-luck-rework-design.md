# Bill Class Identity — Clip Choice, Replay Keyword, Luck Rework — Design

**Date:** 2026-06-15
**Status:** Design (awaiting owner review before plan)
**Motivation:** Cowboy Bill currently plays as a generic StS-Ironclad bruiser with no
class identity (his "luck/crit" hook lives in a single relic, no card build supports
it). This reworks Bill into a **clip-choice class**: at the first map node he commits
to one of two playstyles — **Crit** (high-variance burst) or **Double-Fire** (a
guaranteed-replay, ammo-gated single-shot build) — and **Luck** is repurposed from a
crit stat into a pure loot/economy stat.

## Locked decisions (owner-approved, 2026-06-15)

| # | Decision |
|---|---|
| Clip choice | Map **floor-0** node (Bill only) becomes a fixed **2-choose-1**: `crit_clip` (暴击弹夹) vs `double_fire_clip` (双发弹夹). The unchosen clip is **removed from all relic pools for the rest of the run** (mutually exclusive). Other heroes keep the existing random 3-choose-1. |
| Crit exclusivity | **Strong (option B).** `crit_pct` is removed from the equipment affix pool; crit chance comes **only from Luck**, and only **converts to crit when `crit_clip` is held** (option 2). Crit becomes a formal **keyword** (暴击) — Bill's, via the crit clip. |
| Luck rework | Luck **no longer advertises/【generically grants】crit.** Luck = loot stat: post-battle gold (existing), loot rarity (existing, kept), **+ gem drops** (new — see Component C). The crit clip is what re-couples Luck→crit for the crit build. |
| Replay | New keyword **重放 N (Replay N)**: a card resolves its **full effects N extra times** (Echo / Double-Tap style — damage re-hits same target, gems/status/draw all re-trigger). |
| Double-Fire clip | Attacks gain **Replay 1**; you may play **only 1 attack card per turn** (attack allowance = 1); on pickup, **add 2 `reload` cards** to the deck. |
| Reload card | `reload` (装弹), **0-cost skill**: **+1 attack allowance this turn, draw 1** (cantrip — never a dead draw). |
| Allowance | Per-turn counter, **active only while `double_fire_clip` is held**. Resets to 1 each turn; playing an attack −1; reload +1; **replay does not consume**; at 0, attack cards are **unplayable**. |

## Components

### A. Clip-choice map node (Bill only)
- `map_scene.gd` floor-0 handling (`_open_relic_choice(..., "starting")`, currently
  `rm.roll_relic_choices(3)`): when the run hero is `cowboy_bill`, offer a **fixed pair**
  `[crit_clip, double_fire_clip]` instead of the random roll. Non-Bill heroes unchanged.
- On selection, the **other** clip is excluded from this run's relic pool (treasure / shop /
  boss). Implement via a run-scoped exclusion set the relic-roll reads.

### B. Crit as a Bill keyword (strong exclusivity)
- `run_manager.gd` `crit_chance()` (currently `luck*CRIT_PER_LUCK + equipment_crit_pct_bonus()`):
  - **Drop the `equipment_crit_pct_bonus()` term.** Crit chance = `luck * CRIT_PER_LUCK`
    (cap unchanged).
  - Attack crit already only fires through the `crit_clip` relic trigger
    (`player_attack_damage` → `crit_chance`), so "Luck→crit only with the clip" already
    holds for attacks. Keep that; just stop equipment from feeding it.
- `affix_pool.gd`: **remove `crit_pct`** from the affix pool. Any equipment JSON that rolls a
  fixed `crit_pct` bonus is re-pointed to an equivalent stat (e.g. `luck` or `strength`) so
  no dangling crit affixes remain. Remove/neutralize `_equipment_crit_pct_bonus` plumbing.
- **Glossary/keyword:** add 暴击 (Crit) as a formal keyword (keyword glossary + card/relic
  tooltip): "Crit: a Luck-scaled chance (only with a crit clip) to deal 1.5× damage."
- Update the **Luck attribute description/tooltip** to drop any crit mention.
- `crit_plating` (block-crit relic) keeps using `crit_chance()` as its own opt-in — it is a
  separate relic that converts Luck→block-crit, consistent with the "crit comes from a
  crit-granting relic" model. (No change required; note for QA.)

### C. Luck rework — loot/economy stat
Luck keeps: post-battle gold (`luck_gold_mult`), loot rarity (`luck_rarity_bonus`). Adds:
1. **Level-up attribute pick → gem chance (NEW).** The level-up 3-of-5 attribute pick
   (`loot_reward.gd` `_open_attr_choice` / `_generate_attr_options` / `_make_attr_slot`) is
   currently pure attributes. Add a per-slot **`luck_gem_chance()` roll** that replaces a slot
   with a gem option (reusing the existing gem-slot rendering from the card-draft path).
2. **Normal-battle gem drop (REVIEW — may already be covered).** The normal **card-draft**
   already converts a slot to a gem via `luck_gem_chance()` (`loot_reward.gd:495`). Decision
   for review: treat that as satisfying "普通战斗概率掉宝石", **or** add a *separate* Luck-rolled
   gem drop alongside the card draft. Default in this spec: **reuse the existing draft-slot
   conversion** (no separate drop) — flagged for owner confirmation.

### D. Replay keyword (重放 N)
- New card/effect concept resolved in `combat_engine.gd`. When a card is played, after its
  `effects[]` resolve, if it carries **Replay N** (via a card field or a relic-applied
  modifier), re-run the full `effects[]` resolution **N more times** against the same target.
- Register in `data_validator.gd` (the schema is the source of truth): the Replay marker
  (card field and/or the relic effect/trigger that grants it) goes in the matching `ALLOWED_*`
  list, and the handler goes in `combat_engine`.
- Guardrails: replay re-runs the **same resolved targeting**; it does **not** re-pay energy and
  does **not** consume attack allowance (it is part of the same play). Cards that draw on play
  will draw again on replay — acceptable and bounded by the 1-attack/turn cap.

### E. Double-Fire clip relic (`double_fire_clip`)
- JSON relic, rarity `unique` (Bill), mirroring `crit_clip`'s shape.
- Effects:
  - Grant **Replay 1 to attack cards** (a relic modifier the combat engine reads when
    resolving an attack — analogous to how `sharpened_scrap` adds bleed to attacks).
  - Enable the **attack-allowance** rule (base 1/turn).
  - **`on_pickup`**: add 2 `reload` cards to the deck via the existing `add_card_to_deck()` /
    `on_pickup` relic hook (`run_manager.gd:1483`).

### F. Reload card (`reload` / 装弹)
- New card JSON, `type: skill`, `cost: 0`, side `player` (Bill pool / colourless as
  appropriate). Effects: **+1 attack allowance this turn** (new effect type) **+ draw 1**.
- Not an attack → unaffected by the allowance limit and by Replay.

### G. Attack-allowance system
- New run/turn state (combat-scoped): `attacks_remaining_this_turn`. Only **armed when
  `double_fire_clip` is held**; otherwise attack play is unrestricted (current behavior).
- Reset to **1** at the start of each player turn (`turn_manager` turn-start hook).
- **Playing an attack card** decrements it; reaching 0 makes attack cards **unplayable**
  (`play_card.gd` / the play-validation path rejects the play and returns the card to hand).
- **Reload** increments it; **Replay** does not.

### H. UI
- A small **"attacks left this turn"** indicator, shown **only while the allowance is armed**
  (double-fire run), near the End-Turn button. Updates on play/reload/turn-start.
- Card tooltips show the **重放** and **暴击** keyword definitions.

## Wiring / integration points (grounded)
- `run_system/ui/map_scene.gd` — floor-0 clip pair + run-scoped clip exclusion.
- `run_system/core/run_manager.gd` — `crit_chance()`, equipment-crit removal, clip-exclusion
  set, `add_card_to_deck`/`on_pickup` (1474/1483), allowance state + turn reset.
- `run_system/core/affix_pool.gd` — remove `crit_pct`.
- `battle_scene/combat_engine.gd` — Replay resolution; attack-Replay from the clip.
- `battle_scene/relic_effect_system.gd` — `double_fire_clip` effect.
- `battle_scene/play_card.gd` + `turn_manager` — allowance enforcement + per-turn reset.
- `run_system/ui/loot_reward.gd` — luck→gem on the level-up attribute pick.
- `battle_scene/data_validator.gd` — register Replay + the new effect types + new card/relic.
- Data: `run_system/data/relics/double_fire_clip.json`, `battle_scene/card_info/player/reload.json`.
- i18n CSVs (en+zh) + `scripts/gen_catalog_html.py` regen + glossary update.
- Equipment JSON carrying `crit_pct` → re-point to another stat.

## Balance levers to watch
- **Chained double-shots:** 2 reloads → up to 3 doubled attacks in one turn. Bounded by only 2
  reload cards in-deck; if reloads later become buyable/draftable, cap reload's allowance grant
  per turn or add an escalating cost. **Log any cap** rather than silently limiting.
- **Replay + draw/gem stacking:** full-card replay re-draws and re-fires gems; the 1-attack/turn
  cap is the primary throttle — keep it.
- **Crit clip vs double-fire parity:** crit = variance burst (Luck-scaled, capped 40%);
  double-fire = guaranteed 2× on one attack/turn. Tune the crit cap / double-fire numbers so
  neither dominates floor-1 picks.

## Out of scope
- A full ammo/reload **subsystem** beyond this relic (more reload sources, ammo UI economy) —
  the 2 cantrip reloads are the seed; expansion is a later feature.
- Feng Shui Master changes.
- New crit-payoff cards for the crit build (this spec keeps crit on the existing clip; a crit
  card package is a possible follow-up).

## Open items for owner review
1. **Component C.2** — does reusing the existing card-draft slot→gem conversion satisfy
   "普通战斗概率掉宝石", or do you want a *separate* Luck-rolled gem drop on normal wins?
2. **Reload pool placement** — is `reload` strictly added by the clip (deck-only, never drafted),
   or should it also appear in Bill's draft/shop pool as a build-around?
3. **Loot rarity from Luck** — keep (assumed) or drop now that Luck is being refocused?
