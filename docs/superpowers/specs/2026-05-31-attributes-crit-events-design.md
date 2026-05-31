# Attributes Matter — Luck/Charm, Crit Clip, Random Events (design)

**Date:** 2026-05-31
**Status:** Design locked by owner (overnight autonomous build). Numbers are
first-pass and live in named constants for retuning.
**Owner decisions captured:** crit curve = luck×3% cap 40%; tuning = Moderate;
events = upgrade the existing "?" node into a full event scene + 4 events;
priority if time runs short = attributes+crit+relic FIRST, events LAST.

## Context

`luck` and `charm` are currently **dead stats** — set/displayed/gainable but read
by zero gameplay math (only `strength`/`constitution`/`intelligence` feed card
`scaling`). This makes them meaningful, adds a luck-driven crit via Cowboy Bill's
starting relic, and upgrades the "?" map node into a data-driven random-event
scene whose options key off luck/charm.

All integration points below are verified against the current code (file:line).

## Goals

1. **Luck** affects: crit (via Crit Clip relic), loot rarity, post-battle gold.
2. **Charm** affects: shop prices, and unlocks high-charm options in events.
3. **Cowboy Bill** starts with the **Crit Clip** relic.
4. The **"?" node** opens a real event scene: 2-3 choices, some attribute-gated.
5. Bosses / existing systems untouched except at the named hooks.

## Non-Goals

- New art (relic icon / event art) — falls back to letter/placeholder; a Codex
  art contract is a follow-up (ADR-0005). Do NOT hand-author PNGs.
- Rebalancing existing cards/enemies/upgrades.
- Crit for enemies (player-only this pass).

---

## Locked numbers (Moderate tuning)

| Lever | Formula | Source attribute |
|---|---|---|
| Crit chance | `clamp(luck * 0.03, 0, 0.40)` | luck |
| Crit multiplier | `1.5×` (only when Crit Clip relic owned) | — |
| Post-battle gold | `gold * (1 + luck * 0.03)`, rounded | luck |
| Loot rarity promote | `+luck * 0.015` extra promote chance | luck |
| Shop price | `price * (1 - charm * 0.02)`, floored at `0.60×` | charm |

Helpers live on `RunManager` so they're unit-testable and single-sourced:
`crit_chance() -> float`, `luck_gold_mult() -> float`,
`luck_rarity_bonus() -> float`, `charm_shop_mult() -> float`. Each reads
`player_attributes` (luck/charm) with safe defaults.

---

## A. Attribute foundation (Phase 1)

Add to `run_system/core/run_manager.gd` (near `recompute_attributes`, ~line 884):
```gdscript
const CRIT_PER_LUCK := 0.03
const CRIT_CAP := 0.40
const CRIT_MULT := 1.5
const GOLD_PER_LUCK := 0.03
const RARITY_PER_LUCK := 0.015
const SHOP_PER_CHARM := 0.02
const SHOP_FLOOR := 0.60

func _attr(name: String) -> int:
    return int(player_attributes.get(name, 0))

func crit_chance() -> float:
    return clampf(_attr("luck") * CRIT_PER_LUCK, 0.0, CRIT_CAP)

func luck_gold_mult() -> float:
    return 1.0 + _attr("luck") * GOLD_PER_LUCK

func luck_rarity_bonus() -> float:
    return _attr("luck") * RARITY_PER_LUCK

func charm_shop_mult() -> float:
    return maxf(SHOP_FLOOR, 1.0 - _attr("charm") * SHOP_PER_CHARM)
```
Pure functions, no consumers wired in this phase. Tested via temp boot scene.

---

## B. Crit Clip relic + crit hook (Phase 2)

**Relic JSON** `run_system/data/relics/crit_clip.json`:
```json
{ "id": "crit_clip", "title": "Crit Clip",
  "description": "Bill's attack cards have a luck-scaled chance to deal 1.5x damage.",
  "icon": "res://run_system/assets/images/relics/crit_clip.png",
  "rarity": "common",
  "effects": [ { "trigger": "player_attack_damage", "type": "crit_chance" } ] }
```
(`validate_relic` only requires id/title/effects + each effect has a `trigger` —
no validator change needed. The icon PNG may not exist yet; UI falls back to a
letter. Flag a Codex art contract as follow-up.)

**Crit hook** — `battle_scene/relic_effect_system.gd` `modify_player_attack_damage`
(lines 39-49) currently only handles `add_damage`. Add a `crit_chance` arm:
```gdscript
        "crit_chance":
            if randf() < RunManager.crit_chance():
                amount = int(round(amount * RunManager.CRIT_MULT))
                if main:
                    main.show_notification("CRIT!", Color(1, 0.85, 0.2))
```
`amount` is the post-add_damage running value. Crit is rolled per player
damage-resolution (all player damage routes through
`combat_engine.calculate_attack_damage` → `modify_player_attack_damage`). This
applies to attack cards in practice (block/draw never call it). `main` is the
battle_scene reference the relic system already holds; guard it. Crit is gated by
OWNING the relic (no relic → the `crit_chance` arm never runs).

**Starting-relic mechanism** (new — none exists today):
- `run_manager.gd` `start_new_run()` after `relics.clear()` (~line 568):
  ```gdscript
  var starting_relic: String = str(current_hero_data.get("starting_relic", ""))
  if starting_relic != "":
      add_relic(starting_relic)
  ```
- `cowboy_bill.json`: add `"starting_relic": "crit_clip"`.
- `data_validator.gd` `validate_hero` (lines 549-572): add `starting_relic` to the
  hero's known-optional keys (so it doesn't fail unknown-key checks; if the
  validator has no unknown-key check for heroes, no change needed — verify).

Tested: crit math via `RunManager.crit_chance()` at known luck; relic grant via
`start_new_run` populating `relics` with `crit_clip`; 1.5× applied when forced.

---

## C. Luck → loot rarity + gold (Phase 3)

**Rarity** — `run_system/ui/loot_reward.gd` `_generate_draft_options()` (lines
292-324). After `_apply_research_lab_bias(picked_rarity)`, add a luck promote:
```gdscript
    picked_rarity = _apply_research_lab_bias(picked_rarity)
    if picked_rarity != "rare" and randf() < RunManager.luck_rarity_bonus():
        picked_rarity = "rare" if picked_rarity == "uncommon" else "uncommon"
```
(One-step promotion gated by luck; never demotes.)

**Gold** — `loot_reward.gd` `_generate_loot()` line 72 (`var gold_amount = 10`):
```gdscript
    var gold_amount = int(round(10 * RunManager.luck_gold_mult()))
```

Tested: `luck_gold_mult()` / `luck_rarity_bonus()` return expected values at
several luck levels (Phase 1 covers the math; Phase 3 verifies the wiring +
smoke). Rarity promotion is probabilistic — test the helper, not the RNG.

---

## D. Charm → shop pricing (Phase 4)

`run_system/ui/shop_scene.gd` `_discounted_price()` (lines 48-55). Fold the charm
multiplier in before `ceil`:
```gdscript
func _discounted_price(base_cost: int) -> int:
    var bias = RunManager._get_meta_effect_value("scrap_workshop")
    var multiplier := float(bias.get("multiplier", 1.0))
    var price: float = float(base_cost) * multiplier * RunManager.charm_shop_mult()
    if RunManager.ascension >= 4:
        price *= 1.10
    return int(ceil(price))
```
Stacks with the Scrap Workshop discount. Read at `_roll_stock` time (charm is
fixed for the run by then). Tested: `charm_shop_mult()` values + that a sample
base price drops at high charm (helper-level), plus smoke.

---

## E. Random events (Phases 5-7) — upgrade the "?" node

### Data schema — `run_system/data/random_events/*.json`
```json
{
  "id": "stranded_trader",
  "title": "Stranded Trader",
  "description": "A trader's rig is dead in the dust. He eyes your gear.",
  "options": [
    { "text": "Help repair it (+40 gold later)",
      "effects": [ { "type": "gain_gold", "amount": 40 } ],
      "result": "He pays you for the fix." },
    { "text": "[Charm 5] Charm a discount token from him",
      "requires": { "charm": 5 },
      "effects": [ { "type": "gain_relic", "id": "lucky_cog" } ],
      "result": "Your smile does the work." },
    { "text": "[Luck] Gamble on his dice (luck check)",
      "luck_check": true,
      "effects_success": [ { "type": "gain_core", "amount": 30 } ],
      "effects_fail": [ { "type": "lose_hp", "amount": 6 } ],
      "result_success": "The dice love you.", "result_fail": "Snake eyes." }
  ]
}
```

**Option fields:** `text` (required), `requires` (optional `{luck?,charm?}` —
option shown but DISABLED with a lock hint if unmet), `effects` (applied on
pick), OR `luck_check`+`effects_success`/`effects_fail`+`result_success`/
`result_fail` (a `randf() < crit_chance()`-style luck roll using
`RunManager.crit_chance()` reused as the success prob, or a dedicated
`luck_check_chance()` = `clamp(0.35 + luck*0.04, 0, 0.9)` — define in Phase 5),
`result`/`result_text` (popup shown after).

**Allowed effect types** (validated): `gain_gold`, `lose_hp`, `heal`,
`gain_core`, `gain_relic` (needs `id`), `gain_equipment` (needs `rarity`),
`gain_attribute` (needs `attr`+`amount`). Each maps to an existing RunManager
method (`add_gold`, `modify_health`, `add_core_to_backpack`, `add_relic`,
`add_equip_to_backpack` via `roll_equipment_drop`, and a base_attributes bump).

### Validator (Phase 5)
- `data_validator.gd`: add `RANDOM_EVENT_DIR` const, `ALLOWED_EVENT_EFFECT_TYPES`,
  `validate_event()` (require `id`,`title`,`options`; each option has `text` and
  either `effects` or the luck_check trio; each effect `type` in allowed list +
  required params), and one `_validate_dir(RANDOM_EVENT_DIR, ...)` line inside
  `validate_all_data_at_startup()` (lines 125-143).

### RunManager event API (Phase 5)
- `load_random_events()` (cache all event JSONs), `pick_random_event() -> Dictionary`
  (uniform random; returns {} if none), `option_unlocked(option) -> bool`
  (checks `requires` vs current attrs), `apply_event_effects(effects: Array)`
  (dispatch each effect to the right RunManager method), `luck_check_chance()`.

### Event scene/modal (Phase 6) — `run_system/ui/event_modal.gd`
Follow the `ExtractChoiceModal` pattern: `extends Control`, `signal resolved`,
public `event_data: Dictionary`. `_build()` renders title + description + one
button per option (locked options disabled with the `[Charm N]` hint visible).
On pick: if `luck_check`, roll `RunManager.luck_check_chance()`, apply the
matching effects, set result text; else apply `effects`. Emit `resolved`,
`queue_free`. Owner (`map_scene`) wraps it in a `CanvasLayer(layer≈120)`.

### Map wiring (Phase 6) — `run_system/ui/map_scene.gd`
`_on_node_clicked` "unknown" arm (lines 275-276) currently calls
`_resolve_unknown_node`. Change to: pick a random event; if one exists, open the
event modal (release `_node_click_pending` in the resolve callback, mirroring
`_on_relic_choice_selected` line 525); if none, fall back to
`_resolve_unknown_node` (kept as the safety net). Legend/icon stays "unknown"
(the "?" node) — no new node type, per owner decision.

### Content (Phase 7) — 4 events
Author 4 wasteland-flavored events in `random_events/`, each with 2-3 options,
at least: one plain-effect option, one `requires.charm` gated option, one
`requires.luck` or `luck_check` option. Add their `result`/title strings (events
carry their own English text in JSON; i18n CSV optional this pass — keep text in
JSON `title/description/text/result` and render directly, matching how enemy
`name` falls back).

---

## Testing (every phase)

- Headless smoke gate green after each phase.
- Temp boot-scene logic tests (deleted after) for: crit/gold/rarity/shop-charm
  helper math; starting-relic grant; event pick + option-unlock + effect
  dispatch + luck_check branches; validator accepts the 4 event JSONs.
- UI-only behavior (event modal rendering, crit notification) is smoke + the
  morning manual playtest checklist.

## Build order (priority — owner: attributes/crit/relic FIRST)

1. Phase 1 — attribute helpers (foundation)
2. Phase 2 — Crit Clip relic + crit hook + starting-relic mechanism
3. Phase 3 — luck → rarity + gold
4. Phase 4 — charm → shop pricing
5. Phase 5 — event data schema + validator + RunManager event API
6. Phase 6 — event modal UI + "?" node wiring
7. Phase 7 — 4 event JSONs
8. Phase 8 — integration review

If the run is cut short, Phases 1-4 (the owner's named asks) are self-contained
and shippable on their own; Phases 5-7 (events) layer on top.

## Risks / notes

- Crit lives in the relic hook, so it can't see card `type`; it applies to all
  player damage-resolutions. In practice only attack cards deal damage, so this
  matches "attack cards crit." Documented intentionally.
- `crit_clip.png` / event art absent → letter/placeholder fallback; functional,
  not pretty. Codex art contract is a follow-up.
- Autonomous run will produce many commits on `hero-refinement-v2`, mixing with
  Codex's uncommitted WIP in shared files (owner has accepted mixed commits).
