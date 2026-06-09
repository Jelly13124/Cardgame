# Gems + In-Run Leveling + Reward Restructure — Design

**Date:** 2026-06-09
**Status:** Approved (overnight unattended: spec → plan → execute, no push)

## Goal

Replace the card-upgrade (`_plus`) growth axis with a **socketable gem system**, add
an **in-run XP/level** progression whose level-ups grant the card draft, and
**restructure combat rewards** around node type. One coherent RPG-flavoured refactor.

## Locked decisions (from brainstorming)

- **Gem = socketable keyword carrier.** Run-scoped (cleared on death). Equipment
  affixes are a SEPARATE system and are untouched by this spec.
- **2 sockets per card.** Gems are inserted **out of combat (map)**, and are
  **locked once inserted** (no removal/re-socket this run).
- **Card upgrades are fully removed** — all `_plus` cards + upgrade UI deleted.
  Card growth now comes only from gems.
- **In-run XP/level:** killing enemies grants XP; ~1 level per 1–2 fights. Level-up
  grants **only** a 3-choose-1 card draft (no heal/attribute). High Luck gives each
  draft slot a chance to be a gem instead of a card.
- **Rewards by node type:** normal `enemy` → gold only; `elite` → gem (3-choose-1)
  + equipment; `boss` → gem + relic. Equipment drops ONLY from elite/boss now.
- The existing `wealthy` keyword is refactored INTO the gem system as the first gem.

## Current architecture (verified)

- `RunManager.player_deck`: Array of dicts `{uid, card_id, bonus_attack, bonus_health}`
  — each card instance has a unique `uid`. We extend each entry with `gems: [String]`.
- `deck_manager.gd:131` sets `card.set_meta("uid", ...)` when building battle cards —
  we also set `card.set_meta("gems", [...])`.
- `combat_engine.resolve_card_effect(card,...)` resolves a card's `effects[]` then
  matched-bonus; we append gem-effect resolution here.
- `combat_engine._apply_effect(effect, target, player, mult)` is the shared effect
  handler — gem effects reuse it.
- `battle_scene._victory()` is the combat-win hook (awards caps by node type via
  `last_battle_node_type` ∈ {enemy, elite, boss}, then `_show_loot_modal()`).
- `loot_reward.gd` builds gold + card draft + equipment; has a `DraftOverlay` with
  `_open_card_draft()` / `_generate_draft_options()` / `_make_draft_card_slot()`.
- `RunManager.last_battle_node_type`, caps consts `CAPS_PER_COMBAT/ELITE/BOSS`.
- Keyword `wealthy`: currently `RunManager.wealthy_uids` + `battle_scene.on_card_played_wealthy`.

## Subsystem 1 — Gems + sockets

### Gem data (data-driven, JSON)
- New dir `run_system/data/gems/<id>.json`. Schema (validated in `data_validator.gd`,
  new `validate_gem` + `REQUIRED_GEM_KEYS` + `ALLOWED_GEM_TRIGGERS`):
  ```json
  { "id": "keen", "title": "Keen Gem", "trigger": "on_play",
    "effects": [ { "type": "deal_damage", "amount": 3 } ] }
  ```
- `trigger` ∈ `["on_play"]` for now (the only socket trigger). `effects[]` reuses the
  card `ALLOWED_EFFECT_TYPES` vocabulary so they run through `_apply_effect`.
- Gold needs a card-side effect: add **`gain_gold`** to `ALLOWED_EFFECT_TYPES` +
  `combat_engine._apply_effect` (routes to `RunManager.add_resources(amount,0)`),
  with an optional `"max_per_combat"` field (wealthy uses 3) tracked on battle_scene.

### Starter gem set (8, run-scoped, flat power)
| id | title (en/zh) | trigger | effect on the socketed card's play |
|----|---------------|---------|-------------------------------------|
| `wealthy` | Wealthy / 富裕 | on_play | gain_gold 5 (max 3/combat) |
| `keen` | Keen / 锋锐 | on_play | deal_damage 3 (to card target) |
| `bulwark` | Bulwark / 壁垒 | on_play | gain_block 4 |
| `swift` | Swift / 迅捷 | on_play | draw_cards 1 |
| `venom` | Venom / 毒囊 | on_play | apply_status bleed 2 (to target) |
| `brute` | Brute / 蛮力 | on_play | gain_strength 1 |
| `spark` | Spark / 电火花 | on_play | gain_energy 1 |
| `leech` | Leech / 吸血 | on_play | heal 2 |

(`deal_damage`/`apply_status` gems are no-ops when the card has no enemy target —
guarded like the existing effect handlers. `gem_pool` = all ids in the dir.)

### Card-instance sockets
- `player_deck` entry gains `gems: Array[String]` (≤2). `RunManager.add_card_to_deck`
  initialises it to `[]`.
- `RunManager.socket_gem(uid, gem_id) -> bool`: finds the deck entry by uid; if it has
  a free slot (`gems.size() < 2`) and `gem_id` is in `gem_inventory`, append to
  `gems`, remove one from `gem_inventory`, return true. Locked (no unsocket).
- `RunManager.gem_inventory: Array[String]` (run-scoped; cleared in `start_new_run`).
- `deck_manager` sets `card.set_meta("gems", entry.gems)` alongside uid.

### Gem effects on play
- In `combat_engine.resolve_card_effect`, after the matched-bonus block, read
  `card.get_meta("gems")` (default `[]`) and for each gem id load its JSON (cached via
  a `RunManager.get_gem_data(id)` like `get_relic_data`) and `await _apply_effect` each
  gem effect with the same `target`/`player`/`card_mult`.
- Replace the `wealthy_uids` path: `on_card_played_wealthy` is deleted; the `gain_gold`
  effect (with per-combat cap) handles wealthy as a normal gem. battle_scene keeps the
  per-combat gold-trigger counter, now keyed by the `gain_gold` effect's `max_per_combat`.

### Socket UI
- Extend `run_deck_viewer_modal.gd` (the on-map deck viewer) into a socketing screen:
  list deck cards with their 2 slots (filled = gem icon, empty = ➕); a side panel lists
  `gem_inventory`. Click empty slot → pick a gem from inventory → `socket_gem`. Locked
  slots are non-interactive. Placeholder gem icons reuse an existing small icon; real art
  via asset-spec (Codex). Reachable from the map (a "DECK / GEMS" button).

## Subsystem 2 — Remove card upgrades

- Delete every `*_plus.json` under `battle_scene/card_info/player/`.
- Delete `run_system/ui/card_upgrade_modal.gd` (+ `.tscn` if present) and
  `run_system/ui/upgrade_panel.gd` if it is upgrade-only.
- Remove upgrade entry points / references in: `outpost_screen.gd` (deck editor
  upgrade), `market_screen.gd`, `run_deck_viewer_modal.gd`, `play_card.gd`
  (any `_plus` display/upgrade affordance), `run_manager.gd`
  (`upgrade_card_in_deck`/`_plus` logic), `meta_progress.gd` (`starter_deck_override`
  may reference `_plus` — sanitise). Grep `_plus` and `upgrade` to find them all.
- `data_validator.gd`: drop any `_plus`-specific assumptions.
- The deck-editor (outpost) stays as a swap-only editor (no upgrade button).

## Subsystem 3 — In-run XP / level

- `RunManager`: `xp: int`, `level: int` (both reset in `start_new_run`; level starts 1).
  `XP_PER_KILL = {"enemy": 6, "elite": 14, "boss": 30}` and a level curve
  `xp_to_next(level) = 10 + level*4` (≈ 1 level per 1–2 normal fights early). 
- `gain_xp(node_type)` called from `battle_scene._victory()` (alongside caps). Returns the
  number of levels gained this combat so the loot flow can show that many drafts.
- A level-up does NOT heal or grant attributes — only queues a card draft.

## Subsystem 4 — Reward restructure (loot_reward)

- `loot_reward._generate_loot()` keyed by `RunManager.last_battle_node_type`:
  - `enemy`: gold only.
  - `elite`: gold + **gem 3-choose-1** + equipment drop.
  - `boss`: gold + **gem** + relic.
- **Card draft moves to level-up:** loot shows `levels_gained` sequential 3-choose-1
  card drafts (reuse the existing DraftOverlay). With high Luck, each draft slot has a
  `RunManager.luck_gem_chance()` probability to be a **gem** option instead of a card.
- **Gem 3-choose-1 (elite):** new gem-draft overlay (or reuse DraftOverlay with gem
  slots); picking adds the gem to `gem_inventory`.
- Equipment drop logic stays but is gated to elite/boss only (normal no longer drops gear).
- Selected cards go to `add_card_to_deck` (with empty `gems`).

## Data flow

kill → `_victory()` → `gain_xp(node_type)` + caps → `_show_loot_modal()` →
loot_reward: gold (+gem/equip/relic by node) → then `levels_gained` card drafts →
back to map → (optional) open deck/gem socket screen → socket gems into cards →
next combat: cards resolve their effects + each socketed gem's effects.

## Validation / workflow

- Smoke gate each phase: `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh`.
- CSV reimport for new gem/UI strings; `python scripts/gen_catalog_html.py` (add a
  **gems** catalog page + update keywords page: remove the standalone "wealthy" card
  keyword now that it's a gem).
- Commit per phase. **Do not push.** Never stage Codex art WIP / sidecars.
- Asset-spec for gem icons (Codex).

## Phasing (implementation order; each smoke-green before next)

1. **Gem data model + effects on play** (gems dir + schema + `gain_gold` effect +
   `get_gem_data` + player_deck `gems` + deck_manager meta + resolve_card_effect gem
   loop + migrate wealthy → gem). Validates the core feel.
2. **Remove upgrades** (delete `_plus` + upgrade UI/refs).
3. **Socket UI** (deck/gem screen + map entry + `gem_inventory`/`socket_gem`).
4. **XP/level** (RunManager xp/level + `gain_xp` in `_victory`).
5. **Reward restructure** (loot_reward by node type + level-up drafts + gem draft + luck).
6. **Catalogs + CSV + asset-spec.**

## Out of scope / deferred

- Permanent (cross-run) gems / gem stash.
- Expanding equipment affix pool (freed design space — later spec).
- Gem rarity tiers (flat for now).
- Re-socketing / gem removal.
