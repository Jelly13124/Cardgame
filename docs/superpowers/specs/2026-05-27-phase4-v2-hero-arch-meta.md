# Phase 4 v2 — Hero Architecture + Meta Progression Expansion

**Status:** Approved 2026-05-27 — ready for implementation plan
**Owner:** Claude (overnight autonomous execution)
**Scope:** 7 slices closing out Phase 4 deferred items + opening Phase 5 hero variety

## Why

Phase 4 MVP shipped 5 base upgrades + a single hero (cowboy_bill). Two structural debts blocked deeper meta-progression:
1. `player.gd:HERO_ID = "cowboy_bill"` is hardcoded. Hero select shows Jerry as a button but RunManager / player ignore the selection — Jerry visually IS cowboy_bill.
2. PRD Phase 4 deferred "hero unlock via base upgrades" because there was only one hero to unlock to.

This v2 closes both, plus adds 4 meta features (Run history, Ascension difficulty, Starter Boost upgrade, Card pool gating) to give the home base genuine progression depth.

## Decisions (locked)

| Decision | Choice |
|---|---|
| Scope | 7 slices, single spec + plan, autonomous overnight execution |
| Hero 2 sprite | Bill sprite + red tint placeholder; codex generates real Jerry art separately |
| Card pool gating | Initial pool = 25 unlocked of 30; 5 rare-tier cards locked behind one 3-tier upgrade |
| Ascension cap | 5 levels; each grants a single negative modifier |
| Persistence | Extend existing `user://meta.json` schema additively |

## Slices

### S1 — Hero JSON schema + dynamic loader

**Files to create:**
- `run_system/data/heroes/cowboy_bill.json`
- `run_system/data/heroes/hero_jerry_killer.json`

**Schema:**
```json
{
  "id": "cowboy_bill",
  "name": "Cowboy Bill",
  "sprite_id": "cowboy_bill",
  "tint": "#ffffff",
  "max_health": 50,
  "starter_deck": ["strike", "strike", "strike", "strike", "weak_strike",
                   "defend", "defend", "defend", "defend"],
  "starting_attributes": {"strength": 3, "constitution": 3, "intelligence": 3, "luck": 3, "charm": 3},
  "description": "One-eyed gunslinger. Reliable, average across the board."
}
```

**Jerry differences:** `sprite_id: "cowboy_bill"`, `tint: "#dd5555"`, `max_health: 45`, starter deck weighted to AoE (`acid_splash`, `salvo`, `cascade`) over basic strikes, `starting_attributes: {strength: 4, constitution: 2, intelligence: 3, luck: 3, charm: 3}`.

**Files to modify:**
- `battle_scene/data_validator.gd` — new `validate_hero` + `HERO_DIR` constant, walked in `validate_all_data_at_startup`
- `run_system/core/run_manager.gd` — new `var current_hero_data: Dictionary = {}`. `start_new_run(hero_id, starter_deck)` now loads hero JSON, populates `current_hero_data`, applies `starting_attributes` to `base_attributes`, sets `max_health` from JSON
- `battle_scene/player.gd` — delete `const HERO_ID`. `_build_visual` reads `RunManager.current_hero_data.sprite_id` and `.tint` (modulate)
- `run_system/ui/hero_select.gd` — scan `HERO_DIR`, build buttons dynamically (1 per JSON), each button passes its hero_id to `RunManager.start_new_run`

### S2 — Jerry placeholder sprite

Already covered in S1: Jerry uses `cowboy_bill` sprite_id with `tint: "#dd5555"`. `player.gd._build_animated_visual` and `_build_fallback_visual` apply the tint via `_sprite.modulate = Color(tint_hex)`.

Add TODO comment in `hero_jerry_killer.json`: codex generates real sprite at `battle_scene/assets/images/heroes/hero_jerry_killer/` later.

### S3 — Jerry Unlock base upgrade

**Files:**
- Create `run_system/data/base_upgrades/jerry_unlock.json`:

```json
{
  "id": "jerry_unlock",
  "name": "JERRY UNLOCK",
  "description": "Unlock a second playable hero — Jerry the wasteland killer.",
  "effect_key": "unlock_hero",
  "tiers": [
    {"level": 1, "cost": 100, "effect_value": {"hero_id": "hero_jerry_killer"}, "effect_text": "Permanently unlock Jerry"}
  ]
}
```

- `run_system/ui/home_base_scene.gd` — add `jerry_unlock` to `UPGRADE_ORDER`; UI grid grows to 6 panels (still 3 cols × 2 rows)
- `data_validator.gd` `ALLOWED_BASE_UPGRADE_EFFECT_KEYS` — add `"unlock_hero"`
- `hero_select.gd` — query `MetaProgress.get_upgrade_level("jerry_unlock")`. If 0, Jerry button is `disabled = true` with label "🔒 JERRY (UNLOCK 100 CORE)".

### S4 — Run history panel

**MetaProgress additions:**
- `var run_history: Array = []` (each entry: `{hero_id, outcome, floor, core_earned, timestamp_unix}`)
- `func append_run_history(entry: Dictionary)` — trim to last 50, save
- `save_progress` / `load_progress` extended to round-trip `run_history`

**RunManager.run_ended signal extension:**
- Current: `signal run_ended(victory: bool)`
- New: `signal run_ended(victory: bool, summary: Dictionary)` where summary = `{hero_id, floor, core_earned}`
- `end_run_victory(core_earned: int)` and `_handle_run_loss(core_earned: int = 0)` take the param, build summary, emit
- Callers: `battle_scene._victory` (boss) passes `BOSS_VICTORY_CORE`; `_on_extract_chosen` passes `rewards.extract`; `_handle_run_loss` passes 0

**MetaProgress listens to RunManager.run_ended → appends history entry.**

**Home base UI:**
- `home_base_scene.gd` — new "RECENT RUNS" panel on the right side of the upgrade grid. Shows last 5 entries: outcome icon + hero name + "Floor N / +M Core / Mon DD"
- 5 rows max, scrollable if more shown

### S5 — Ascension difficulty mode

**MetaProgress additions:**
- `var max_ascension: int = 0` (highest unlocked)
- Listens to run_ended(true, summary): if summary's outcome is full victory (final boss kill, not extract), `max_ascension = mini(max_ascension + 1, 5)`
- Distinguish full-victory from extract: `summary["outcome"]` is one of `"victory"`, `"extracted"`, `"defeat"` — full victory only bumps ascension

**RunManager additions:**
- `var ascension: int = 0`
- `start_new_run(hero_id, starter_deck, ascension)` — new param, default 0

**Hero select UI:**
- After hero picked, show ascension slider 0..max_ascension if max > 0
- Default = max_ascension (encourage playing highest)

**Modifier effects (per ascension level, cumulative):**
- A1: All enemies +10% max HP
- A2: Player starts each run with -5 max HP (before Med Bay)
- A3: First turn of each combat: -1 energy
- A4: Shop prices +10%
- A5: Elite encounter rate +50% (more dangerous map)

**Application points:**
- A1: `enemy_entity._build_from_json` after setting max_health, multiply by `1.0 + 0.1 * RunManager.ascension`
- A2: `_apply_meta_upgrades` subtracts `5 * RunManager.ascension` from max_health
- A3: `battle_scene.turn_manager` first-turn energy budget reads `3 - (1 if ascension >= 3 else 0)`
- A4: `shop_scene._discounted_price` multiplies by `1.0 + 0.1 * (1 if ascension >= 4 else 0)` AFTER scrap_workshop discount
- A5: `run_manager.generate_map._pick_node_type` boost elite roll if ascension >= 5

### S6 — Starter Boost upgrade

**File:**
- `run_system/data/base_upgrades/starter_boost.json`:
```json
{
  "id": "starter_boost",
  "name": "STARTER BOOST",
  "description": "Distribute extra attribute points at the start of each run.",
  "effect_key": "starter_attributes",
  "tiers": [
    {"level": 1, "cost": 30, "effect_value": {"points": 1}, "effect_text": "+1 random attribute point at run start"},
    {"level": 2, "cost": 60, "effect_value": {"points": 2}, "effect_text": "+2 random attribute points at run start"},
    {"level": 3, "cost": 100, "effect_value": {"points": 3}, "effect_text": "+3 random attribute points at run start"}
  ]
}
```

- `data_validator.gd` `ALLOWED_BASE_UPGRADE_EFFECT_KEYS` — add `"starter_attributes"`
- `run_manager._apply_meta_upgrades` — reads starter_boost level, distributes N random points to `base_attributes` from the 5-attr pool (each point picks a random attr and increments by 1)
- `home_base_scene UPGRADE_ORDER` — add `starter_boost`

### S7 — Card pool gating

**MetaProgress additions:**
- `var unlocked_cards: Array[String] = []` — initialized empty
- `func get_unlocked_card_pool() -> Array[String]` — returns the union of `INITIAL_CARD_POOL` (a hardcoded list of 25 base cards) + `unlocked_cards` (anything added via card_research upgrade)

**Locked cards (5 rare-tier):**
- `flash_bang`, `last_breath`, `bone_breaker`, `junk_bomb`, `preemptive_strike` (covers crowd-control, 0-cost panic, heavy nuke, AoE burst, double-damage prep)

**INITIAL_CARD_POOL** — the remaining 25 base ids: `strike, weak_strike, defend, stun_baton, static_coil, tinker, hot_swap, adrenaline, brace, double_tap, scrap_strike, siphon, override, charged_shot, emp_burst, salvo, cascade, last_stand, acid_splash, focus, chain_link, iron_will, overdrive, overload, carapace`

**File:**
- `run_system/data/base_upgrades/card_research.json` — 3 tiers cost 30/60/100:
  - Lv1 unlocks `flash_bang`, `bone_breaker`
  - Lv2 adds `last_breath`, `preemptive_strike`
  - Lv3 adds `junk_bomb`

- `data_validator.gd` ALLOWED → add `"card_pool_unlock"`
- `loot_reward.gd::draft_pool` — replaced with runtime computation: union of base 25 + MetaProgress unlocked
- `purchase_upgrade` for card_research applies the unlock to `MetaProgress.unlocked_cards`

**Effect_value format:** `{"unlocks": ["card_id_1", "card_id_2"]}`. `MetaProgress.purchase_upgrade` reads this and appends to `unlocked_cards`.

### Boot sequence after all slices

```
APP BOOT
  ↓
MetaProgress _ready → load meta.json (core, upgrades, run_history, max_ascension, unlocked_cards)
  ↓
home_base_scene → CORE: N | Recent Runs panel (last 5) | 8 upgrade panels (3 cols × 3 rows) | START
  ↓
hero_select → scan heroes/*.json → render buttons (Jerry locked if jerry_unlock=0)
            → if max_ascension > 0, show ascension slider
  ↓
RunManager.start_new_run(hero_id, ascension):
  - load hero JSON → current_hero_data
  - apply starting_attributes → base_attributes
  - apply ascension modifier (A2 max HP, etc.)
  - apply meta upgrades (Med Bay, Arsenal, Command Center gold, Starter Boost random points)
  ↓
battle_scene → player reads hero sprite/tint from current_hero_data
            → enemies apply A1 HP multiplier
            → turn_manager applies A3 energy on first turn
  ↓
boss kill / extract / death:
  → end_run_victory(core_earned) / _handle_run_loss
  → emit run_ended(victory, {hero_id, floor, core_earned, outcome})
  → MetaProgress appends history; if full victory, max_ascension++
```

## Components

### MetaProgress (autoload) — extended schema

```gdscript
var core: int = 0
var upgrades: Dictionary = {}                # existing
var run_history: Array = []                  # NEW — list of run summary dicts
var max_ascension: int = 0                   # NEW — highest unlocked difficulty
var unlocked_cards: Array[String] = []       # NEW — cards unlocked via card_research

const INITIAL_CARD_POOL: Array[String] = [...25 ids...]  # the always-available base

func get_unlocked_card_pool() -> Array[String]:
    var pool = INITIAL_CARD_POOL.duplicate()
    for c in unlocked_cards:
        if not c in pool:
            pool.append(c)
    return pool
```

### RunManager — extended `start_new_run`

```gdscript
func start_new_run(hero_id: String, starter_deck: Array[String] = [], ascension: int = 0) -> void:
    current_hero_id = hero_id
    var hero_data = _load_hero_def(hero_id)
    current_hero_data = hero_data
    ascension = clampi(ascension, 0, 5)
    self.ascension = ascension
    # ... existing reset ...
    if hero_data.has("max_health"):
        max_health = int(hero_data["max_health"])
    if hero_data.has("starting_attributes"):
        base_attributes = hero_data["starting_attributes"].duplicate()
    var deck: Array = hero_data.get("starter_deck", starter_deck)
    for card_id in deck:
        add_card_to_deck(card_id)
    # ... existing tail with _apply_meta_upgrades ...
```

### `run_ended` signal extension

```gdscript
signal run_ended(victory: bool, summary: Dictionary)

func end_run_victory(core_earned: int = 0) -> void:
    var summary = {
        "hero_id": current_hero_id,
        "floor": current_floor,
        "core_earned": core_earned,
        "outcome": "victory" if current_floor == _final_boss_floor() else "extracted",
        "timestamp": int(Time.get_unix_time_from_system()),
    }
    _teardown_run(true, summary)

func _handle_run_loss(core_earned: int = 0) -> void:
    var summary = {
        "hero_id": current_hero_id,
        "floor": current_floor,
        "core_earned": core_earned,
        "outcome": "defeat",
        "timestamp": int(Time.get_unix_time_from_system()),
    }
    _teardown_run(false, summary)

func _teardown_run(victory: bool, summary: Dictionary) -> void:
    if not is_run_active: return
    is_run_active = false
    emit_signal("run_ended", victory, summary)
```

## Out of scope

- Real Jerry sprite art (codex slice after this lands)
- More than 5 ascension levels
- Daily challenges / seeded runs
- Multi-save-slot
- Achievement system
- New card content for S7 (uses existing cards)
- Per-hero starter relic
- Stat-altering hero ability cards

## Testing

### Headless
- `bash scripts/smoke_test.sh` after each slice
- Validator passes new hero + base_upgrade schemas

### Manual smoke (next morning)
1. Boot → home base shows 8 upgrade panels (5 existing + jerry_unlock + starter_boost + card_research)
2. hero_select shows Bill + Jerry (locked, 🔒 100 Core)
3. Pick Bill → ascension slider hidden (max_ascension=0) → run starts with current stats
4. Beat F3 final boss → home base; max_ascension now 1
5. New run → ascension slider 0/1 visible
6. Buy jerry_unlock (100 Core) → Jerry button unlocks
7. Buy starter_boost Lv1 → next run starts with +1 random attribute
8. Buy card_research Lv1 → flash_bang + bone_breaker appear in loot drafts
9. Beat a battle, check `meta.json` has updated `run_history[]`
10. Home base panel shows "Last 5 runs" with correct entries

## Risks

| Risk | Mitigation |
|---|---|
| run_ended signal new shape breaks subscribers | Search callsites; today only MetaProgress listens (new) — no break |
| ascension stacking interacts oddly with meta upgrades | Apply order: ascension FIRST (negatives), meta upgrades AFTER (positives that can offset); document |
| Card pool initialized empty in old saves → no cards | MetaProgress.load_progress: if `unlocked_cards` absent from JSON, default to [] (no special init needed — INITIAL_CARD_POOL is the floor) |
| Jerry's tint clashes with Bill's sprite palette | Acceptable for placeholder; codex's real Jerry sprite resolves |
| Ascension UI on hero_select adds friction | Default slider to max_ascension (highest unlocked) — single click skips it |
