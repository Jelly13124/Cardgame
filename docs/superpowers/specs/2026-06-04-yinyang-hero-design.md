# Yin/Yang Hero — 风水大师 (Feng Shui Master) — Design

> Overnight build. Replaces the existing hero **Jerry the Killer**
> (`hero_jerry_killer`) with a new polarity-driven hero. Card art comes from
> Codex later — card/relic logic must function with placeholder art (validator
> only checks the `front_image`/`icon` key, not the file).

**Goal:** A new hero whose deck is split into Yin (阴) and Yang (阳) cards. A
starting relic alternates the active polarity each turn; playing a card whose
polarity matches the active state triggers its bonus effects. Cards that flip
polarity let the player reach both polarities in one turn → **Yin-Yang Harmony**,
which lasts to end of turn and makes BOTH polarities count as matched.

**Architecture:** Polarity is a per-battle state on the player entity, driven at
turn start by the starting relic and mutated by `flip_polarity` card effects.
`combat_engine` reads the active state when resolving a card and, if the card's
polarity matches (or Harmony is active), additionally resolves the card's
`matched_bonus` effect list. New data fields (`polarity`, `matched_bonus`) and a
new effect type (`flip_polarity`) are registered in `data_validator` (the
two-place rule). A battle HUD indicator shows 阴/阳/调和.

**Tech Stack:** Godot 4.6, GDScript, JSON content, CSV i18n.

---

## Data model

### Card fields (additions, all optional/back-compat)
- `"polarity"`: `"yin"` | `"yang"` | `"neutral"` (absent = `"neutral"`).
- `"matched_bonus"`: an array of effect dicts (same schema as `effects`), applied
  ONLY when the card resolves while matched. Omit/empty = no bonus.

### New effect type
- `"flip_polarity"` — flips the active polarity (yin↔yang) when resolved. No
  amount/status. Registered in `combat_engine._apply_effect` AND
  `data_validator.ALLOWED_EFFECT_TYPES`. Also valid inside `matched_bonus`.

### Player battle state (`player.gd`)
- `var current_polarity: String = ""`   # "yin"/"yang"/"" (none, e.g. non-hero)
- `var _polarities_seen: Array = []`     # polarities active this turn
- `var harmony_active: bool = false`
- Methods:
  - `set_polarity(p: String)` — sets `current_polarity`, appends to
    `_polarities_seen` if new, then calls `_check_harmony()`.
  - `flip_polarity()` — yin→yang / yang→yin via `set_polarity`.
  - `reset_polarity_turn(p: String)` — start-of-turn: `current_polarity=p`,
    `_polarities_seen=[p]`, `harmony_active=false`.
  - `_check_harmony()` — if `_polarities_seen` contains BOTH "yin" and "yang"
    and not `harmony_active`: set `harmony_active=true` and return true (caller
    grants the entry reward). Else false.
  - `is_card_matched(polarity: String) -> bool` — returns
    `harmony_active or (polarity != "" and polarity != "neutral" and polarity == current_polarity)`.

## Turn-start polarity (the relic)

New relic **`yin_yang_compass`** (阴阳罗盘), the hero's `starting_relic`.
- JSON in `run_system/data/relics/` with an effect
  `{ "trigger": "player_turn_start", "type": "set_polarity_alternating" }`.
- `relic_effect_system.on_player_turn_started` handles the new type
  `set_polarity_alternating`: compute polarity from the round —
  `"yin" if round_number % 2 == 1 else "yang"` — and call
  `player.reset_polarity_turn(polarity)`. (round 1=Yin, 2=Yang, 3=Yin…)
- `relic_effect_system` already receives `(player, round_number)`; it has
  `_battle_scene` for any UI refresh. After setting polarity, call
  `_battle_scene.update_polarity_hud()` if present.

## Card resolution hook (`combat_engine._apply_effect` / `resolve_card_effect`)

When resolving a card (`resolve_card_effect`), after the normal `effects` loop,
check the card's polarity against the player:
- `var matched := player.is_card_matched(str(card.card_info.get("polarity","neutral")))`
- if `matched` and the card has a non-empty `matched_bonus` array → resolve each
  bonus effect through the SAME `_apply_effect` path (so bonus effects reuse all
  existing handlers incl. global STR/CON, dodge, thorns, etc.).
- `flip_polarity` handler in `_apply_effect`: call `player.flip_polarity()`; if
  that newly triggers harmony (`_check_harmony` returned true), grant the entry
  reward: `player.pay_energy(-1)` (gain 1 energy) + `main.deck_manager.draw_cards(1)`
  + a notification; refresh the HUD.

Matching is evaluated at resolve time (after any flips earlier in the same card's
effects). Neutral cards never match (no bonus) and never flip unless they carry
`flip_polarity`.

## HUD indicator

`battle_scene` shows the active polarity. Add `update_polarity_hud()` that renders
a small label/badge ("阴" / "阳" / "阴阳调和") near the player HUD, colored
(yin = cool blue, yang = warm orange, harmony = gold). Only visible when
`player.current_polarity != ""`. Called on turn start, on flip, and on harmony.
**This is UI — owner verifies visually in the morning.**

## The hero

`run_system/data/heroes/hero_fengshui_master.json`:
- `id`: `hero_fengshui_master`
- `name`: `Feng Shui Master`  (zh `风水大师` via i18n)
- `sprite_id`: `cowboy_bill`  (reuse until Codex delivers art; same pattern Jerry used)
- `tint`: `#7fb6c4`  (jade/teal)
- `max_health`: `52`
- `starting_attributes`: `{strength: 3, constitution: 3, intelligence: 4, luck: 3, charm: 3}` (balanced, INT-flavored)
- `starting_relic`: `yin_yang_compass`
- `starter_deck` (10): `["strike","strike","defend","defend","yin_crescent_cut","yin_still_water","yang_solar_strike","yang_ember_will","taiji_shift","taiji_pivot"]`
- `description`: balance/polarity flavor.

**Remove** `hero_jerry_killer.json` and rewire references (see Wiring).

## New cards (logic now, art later)

All cost 1 unless noted. `front_image` points at the expected (not-yet-existing)
PNG path. Numbers are starting points for the `content-balance` pass.

| id | polarity | type | base effect | matched_bonus |
|---|---|---|---|---|
| `yin_crescent_cut` | yin | attack | deal_damage 6 | gain_block 4 |
| `yin_still_water` | yin | skill | gain_block 6 | draw_cards 1 |
| `yang_solar_strike` | yang | attack | deal_damage 8 | deal_damage 4 |
| `yang_ember_will` | yang | skill | gain_energy 1 (cost 0) | gain_strength 1 |
| `taiji_shift` | neutral | skill | flip_polarity + gain_block 4 | — |
| `taiji_pivot` | neutral | attack | flip_polarity + deal_damage 5 | — |

`_plus` variants for each new card (bump the base + bonus numbers modestly), per
the project's upgrade convention. Add the six base ids to
`MetaProgress.INITIAL_CARD_POOL` so they appear in drafts too. zh/en i18n for all
titles/descs. Descriptions should read the polarity + bonus clearly (e.g.
"[阴] Deal 6. If Yin: gain 4 Block.").

## Wiring (the half that's easy to forget)

1. **Hero roster / select** — `run_system/ui/hero_select.gd` (and any hero list):
   replace `hero_jerry_killer` with `hero_fengshui_master`.
2. **Unlock** — the `jerry_unlock` base upgrade (100 Core) unlocked Jerry. Repoint
   it to unlock `hero_fengshui_master` (rename id to `fengshui_unlock` + update
   `UPGRADE_ORDER`/consumer, OR keep the id and just change the granted hero —
   pick the lower-churn path; update i18n label to 风水大师). Confirm `RunManager`
   hero-unlock gating reads the new id.
3. **Relic pool** — `yin_yang_compass` is a STARTING relic only; do NOT add it to
   the droppable relic pool (it's hero-specific). Confirm it won't roll as loot.
4. **Validator** — `polarity` (enum), `matched_bonus` (array of valid effects),
   `flip_polarity` effect type, `set_polarity_alternating` relic effect type.
5. **i18n** — hero name/desc, 6 cards × (title+desc) × (base+plus), relic
   title/desc, HUD strings (阴/阳/阴阳调和), harmony notification. Reimport.

## Smoke / gates

`bash scripts/smoke_test.sh` after each task. New cards/relic pass
`content-balance` + `gdscript-reviewer` before their commit. Commit per task. No push.

## Out of scope
- Dedicated hero/card art (Codex). - Polarity for the OTHER hero (Cowboy Bill stays
  non-polarity; `current_polarity` stays "" for him, mechanic dormant).
- AI/enemy polarity.
