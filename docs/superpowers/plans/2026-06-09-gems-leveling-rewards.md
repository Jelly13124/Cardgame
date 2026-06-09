# Gems + In-Run Leveling + Reward Restructure — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (or executing-plans). Steps use checkbox (`- [ ]`) syntax. **Verification gate is the headless smoke test, not unit tests** — this project has no pytest harness. After each task run:
> `GODOT_BIN="C:/Program Files/Godot/Godot.exe" bash scripts/smoke_test.sh` → expect `[OK] DataValidator: all schemas passed.` + `[OK] Headless boot clean.`
> Reimport translations when CSV changes: `"C:/Program Files/Godot/Godot.exe" --headless --path . --import`. Commit per task. **Never push. Never stage Codex art WIP / `*.import` / `*.uid` / `*.translation`.**

**Goal:** Replace the `_plus` card-upgrade axis with a run-scoped socketable gem system, add in-run XP/leveling whose level-ups grant the card draft, and restructure combat rewards by node type.

**Architecture:** Gems are JSON in `run_system/data/gems/`, each carrying `effects[]` that reuse the card effect vocabulary; a card instance stores ≤2 gem ids on its `player_deck` entry and surfaces them as `card` meta in battle, where `combat_engine` runs each gem's effects after the card resolves. XP/level live on `RunManager`; level-ups queue card drafts surfaced by `loot_reward`, which also routes loot by `last_battle_node_type`.

**Tech Stack:** Godot 4.6, GDScript (no `class_name` for new scripts — `preload`+`extends`), JSON data validated at boot by `battle_scene/data_validator.gd`.

Reference: `docs/superpowers/specs/2026-06-09-gems-leveling-rewards-design.md`.

---

## Phase 1 — Gem data model + effects on play

### Task 1.1: Gem schema in the validator

**Files:**
- Modify: `battle_scene/data_validator.gd` (add gem constants + `_validate_gem`, call it from the dir-scan boot validation like relics/cards)

- [ ] **Step 1:** Add near the other schema constants:
```gdscript
# ─── Gem schema ───────────────────────────────────────────────────────────────
const REQUIRED_GEM_KEYS = ["id", "title", "trigger", "effects"]
const ALLOWED_GEM_TRIGGERS = ["on_play"]
```
- [ ] **Step 2:** Add `gain_gold` to `ALLOWED_EFFECT_TYPES` (gems/cards may grant gold).
- [ ] **Step 3:** Add a `_validate_gem(data, prefix)` mirroring `_validate_relic`: require keys, check `trigger in ALLOWED_GEM_TRIGGERS`, and validate each `effects[]` entry through the SAME effect validation used for cards (reuse the card-effect validator helper; status-bearing gem effects need a `status` in `ALLOWED_STATUS_NAMES`).
- [ ] **Step 4:** Register a dir scan for `res://run_system/data/gems/` in the boot validation (copy the relics dir-scan block; only validate when the dir exists).
- [ ] **Step 5:** Smoke (no gems yet → dir empty/missing is fine). Commit: `feat(gems): gem JSON schema + gain_gold effect type`.

### Task 1.2: gain_gold effect handler (with per-combat cap)

**Files:**
- Modify: `battle_scene/combat_engine.gd` (add `gain_gold` case in `_apply_effect`)
- Modify: `battle_scene/battle_scene.gd` (per-combat gold-cap counter; replaces `_wealthy_gold_triggers`)

- [ ] **Step 1:** In `battle_scene.gd` rename `_wealthy_gold_triggers` → `_gold_effect_triggers` (reset 0 in `_start_new_game`) and DELETE `on_card_played_wealthy` + its `WEALTHY_*` consts (gold now flows through the gem effect). Add:
```gdscript
## Grant gold from a card/gem effect, capped per combat when `cap > 0` (wealthy=3).
func try_gain_gold(amount: int, cap: int) -> void:
	if cap > 0 and _gold_effect_triggers >= cap:
		return
	if cap > 0:
		_gold_effect_triggers += 1
	RunManager.add_resources(amount, 0)
	show_notification(tr("UI_COMBAT_WEALTHY").format({"n": amount}), Color(1.0, 0.82, 0.29))
```
- [ ] **Step 2:** In `combat_engine._apply_effect`, before the `_:` default, add:
```gdscript
		"gain_gold":
			if main and main.has_method("try_gain_gold"):
				main.try_gain_gold(amount, int(effect.get("max_per_combat", 0)))
			await get_tree().create_timer(0.1).timeout
```
- [ ] **Step 3:** Remove the `on_card_played_wealthy(card)` call from `combat_engine.resolve_card_effect` (it is deleted; gems handle gold — see Task 1.4).
- [ ] **Step 4:** Smoke green. Commit: `feat(combat): gain_gold card/gem effect with per-combat cap`.

### Task 1.3: Gem JSON files + get_gem_data + gem_inventory + player_deck gems

**Files:**
- Create: `run_system/data/gems/{wealthy,keen,bulwark,swift,venom,brute,spark,leech}.json`
- Modify: `run_system/core/run_manager.gd` (`get_gem_data`, `gem_pool`, `gem_inventory`, `socket_gem`, `add_card_to_deck` gems init, reset in `start_new_run`; remove `wealthy_uids`/`_apply_relic_on_pickup` wealthy path → see Phase 5 for bounty_tags)

- [ ] **Step 1:** Write the 8 gem JSONs. Example `wealthy.json`:
```json
{ "id": "wealthy", "title": "Wealthy Gem", "trigger": "on_play",
  "effects": [ { "type": "gain_gold", "amount": 5, "max_per_combat": 3 } ] }
```
Others (trigger `on_play`): keen `[{deal_damage,3}]`, bulwark `[{gain_block,4}]`, swift `[{draw_cards,1}]`, venom `[{apply_status,bleed,2}]` (use `"stacks":2`), brute `[{gain_strength,1}]`, spark `[{gain_energy,1}]`, leech `[{heal,2}]`. (heal effect: add a `heal` card-effect handler in combat_engine if absent — route to `player.heal(amount)`; also add `heal` to `ALLOWED_EFFECT_TYPES`.)
- [ ] **Step 2:** In `run_manager.gd` add (mirror `get_relic_data`):
```gdscript
var gem_inventory: Array[String] = []
var _gem_cache: Dictionary = {}
func get_gem_data(gem_id: String) -> Dictionary:
	if _gem_cache.has(gem_id): return _gem_cache[gem_id]
	var path := "res://run_system/data/gems/%s.json" % gem_id
	var d := {}
	if FileAccess.file_exists(path):
		var p = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
		if typeof(p) == TYPE_DICTIONARY: d = p
	_gem_cache[gem_id] = d
	return d
func gem_pool() -> Array[String]:
	var ids: Array[String] = []
	var dir := DirAccess.open("res://run_system/data/gems")
	if dir:
		for f in dir.get_files():
			if f.ends_with(".json"): ids.append(f.trim_suffix(".json"))
	return ids
func socket_gem(uid: String, gem_id: String) -> bool:
	if not gem_id in gem_inventory: return false
	for entry in player_deck:
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("uid","")) == uid:
			var gems: Array = entry.get("gems", [])
			if gems.size() >= 2: return false
			gems.append(gem_id); entry["gems"] = gems
			gem_inventory.erase(gem_id)
			return true
	return false
```
- [ ] **Step 3:** `add_card_to_deck`: ensure created entry has `"gems": []`. In `start_new_run`: `gem_inventory.clear()` and remove the `wealthy_uids.clear()` line (delete the `wealthy_uids` var entirely; bounty_tags is reworked in Phase 5).
- [ ] **Step 4:** Smoke green. Commit: `feat(gems): 8 starter gems + gem_inventory/socket_gem/get_gem_data`.

### Task 1.4: Gem effects fire on card play

**Files:**
- Modify: `battle_scene/deck_manager.gd:~131` (set `gems` meta)
- Modify: `battle_scene/combat_engine.gd` (`resolve_card_effect` gem loop)

- [ ] **Step 1:** In `deck_manager.gd` where `card.set_meta("uid", ...)` is set, also `card.set_meta("gems", item.get("gems", []))`.
- [ ] **Step 2:** In `combat_engine.resolve_card_effect`, after the matched-bonus block (and after removing the old wealthy call), add:
```gdscript
	# Socketed gems: each gem's effects resolve after the card's own effects,
	# reusing _apply_effect (so they get the same target / global STR-CON / dodge).
	var gems: Array = card.get_meta("gems") if card.has_meta("gems") else []
	for gem_id in gems:
		var gdata: Dictionary = RunManager.get_gem_data(str(gem_id))
		for ge in gdata.get("effects", []):
			if typeof(ge) == TYPE_DICTIONARY:
				await _apply_effect(ge, target, player, card_mult)
```
- [ ] **Step 3:** Smoke green. Manual reasoning: a card with `gems:["keen"]` deals +3; with `["wealthy"]` grants 5 gold (≤3×/combat). Commit: `feat(gems): socketed gem effects resolve on card play`.

---

## Phase 2 — Remove card upgrades

### Task 2.1: Delete _plus cards + upgrade UI

**Files:**
- Delete: `battle_scene/card_info/player/*_plus.json` (all)
- Delete: `run_system/ui/card_upgrade_modal.gd` (+ `.tscn` if present); `run_system/ui/upgrade_panel.gd` IF upgrade-only (grep its usages first)
- Modify: `run_system/ui/outpost_screen.gd`, `run_system/ui/buildings/outpost_screen.gd`, `market_screen.gd`, `run_deck_viewer_modal.gd`, `play_card.gd`, `run_manager.gd`, `meta_progress.gd`, `data_validator.gd`, `assets/translations/content_cards.csv`

- [ ] **Step 1:** `git rm battle_scene/card_info/player/*_plus.json`.
- [ ] **Step 2:** Grep `_plus` and `upgrade` across `run_system` + `battle_scene`. For each hit, remove the upgrade affordance/branch: the outpost deck-editor "upgrade" action, market upgrade, `run_manager` `upgrade_card_in_deck` (and any `_plus` id derivation), `play_card` `_plus` display, `meta_progress.starter_deck_override` `_plus` sanitisation. Keep deck SWAP/editing; only remove UPGRADE.
- [ ] **Step 3:** Remove `CARD_*_plus_*` rows from `content_cards.csv`.
- [ ] **Step 4:** Delete `card_upgrade_modal.gd`/`.tscn`; delete `upgrade_panel.gd` only if it has no non-upgrade use.
- [ ] **Step 5:** Reimport + smoke green (no dangling preload/`_plus` reference). Commit: `refactor: remove card upgrade (_plus) system — gems replace card growth`.

---

## Phase 3 — Socket UI

### Task 3.1: Gem-socket screen + map entry

**Files:**
- Modify: `run_system/ui/run_deck_viewer_modal.gd` (add socket interaction + gem-inventory panel)
- Modify: `run_system/ui/map_scene.gd` (a "DECK / GEMS" button opening the viewer)
- Modify: `assets/translations/ui_*.csv` (button + panel strings)

- [ ] **Step 1:** In the deck viewer, render each card row with two slot widgets: filled slot shows the gem (icon/name, non-interactive = locked); empty slot shows ➕ and is clickable. Add a side panel listing `RunManager.gem_inventory` (clickable gem chips).
- [ ] **Step 2:** Interaction: click an empty slot → enter "choose gem" state highlighting the inventory; click a gem → `RunManager.socket_gem(card_uid, gem_id)`; on success, rebuild the view. Read each card's uid + gems from `RunManager.player_deck`.
- [ ] **Step 3:** Add a map button (reuse map UI patterns) opening this viewer. Placeholder gem icon = an existing small icon; write asset-spec later.
- [ ] **Step 4:** Smoke green. Commit: `feat(gems): on-map gem-socket UI (insert, locked-after)`.

---

## Phase 4 — In-run XP / level

### Task 4.1: XP/level state + gain on victory

**Files:**
- Modify: `run_system/core/run_manager.gd` (`xp`, `level`, consts, `gain_xp`, reset)
- Modify: `battle_scene/battle_scene.gd:_victory` (call `gain_xp`)

- [ ] **Step 1:** In `run_manager.gd` add:
```gdscript
var xp: int = 0
var level: int = 1
const XP_PER_KILL := {"enemy": 6, "elite": 14, "boss": 30}
func xp_to_next(lvl: int) -> int: return 10 + lvl * 4
## Add XP for a combat win; returns the number of levels gained.
func gain_xp(node_type: String) -> int:
	xp += int(XP_PER_KILL.get(node_type, XP_PER_KILL["enemy"]))
	var gained := 0
	while xp >= xp_to_next(level):
		xp -= xp_to_next(level); level += 1; gained += 1
	return gained
```
Reset `xp=0`, `level=1` in `start_new_run`.
- [ ] **Step 2:** In `battle_scene._victory()`, alongside the caps award, compute
`var levels_gained := RunManager.gain_xp(RunManager.last_battle_node_type)` and stash it on RunManager (`var pending_level_draws: int`) so loot_reward can read it: `RunManager.pending_level_draws = levels_gained`.
- [ ] **Step 3:** Smoke green. Commit: `feat(progression): in-run XP/level, XP per kill by node type`.

---

## Phase 5 — Reward restructure (loot_reward) + bounty_tags rework

### Task 5.1: Loot by node type + level-up drafts + gem draft

**Files:**
- Modify: `run_system/ui/loot_reward.gd` (`_generate_loot`, draft flow), `run_system/core/run_manager.gd` (`luck_gem_chance`, bounty_tags), `assets/translations/ui_loot.csv`

- [ ] **Step 1:** `_generate_loot()` keyed on `RunManager.last_battle_node_type`:
  - `enemy`: gold only.
  - `elite`: gold + a **gem 3-choose-1** entry + equipment drop.
  - `boss`: gold + a **single gem** + relic.
  Remove the unconditional `cards` loot entry.
- [ ] **Step 2:** Card draft → level-up: after loot is claimed, run `RunManager.pending_level_draws` sequential card drafts using the existing DraftOverlay (`_open_card_draft`/`_generate_draft_options`). Each draft slot: with probability `RunManager.luck_gem_chance()` roll a GEM option (adds to `gem_inventory` on pick) instead of a card. Reset `pending_level_draws=0` after.
- [ ] **Step 3:** Gem 3-choose-1 (elite): reuse DraftOverlay with gem slots from `RunManager.gem_pool()`; pick → `gem_inventory.append`. Boss: grant 1 random gem directly + relic choice.
- [ ] **Step 4:** `run_manager.gd`: add `func luck_gem_chance() -> float: return clampf(0.04 * float(player_attributes.get("luck",3)), 0.0, 0.5)`. Rework `bounty_tags`: since `wealthy_uids` is gone, change its `on_pickup` effect to grant a `wealthy` gem to `gem_inventory` (update `_apply_relic_on_pickup` `grant_card_keyword` → push gem id to `gem_inventory`; update relic JSON/desc accordingly).
- [ ] **Step 5:** Reimport + smoke green. Commit: `feat(rewards): loot by node type + level-up card drafts + elite gem drops`.

---

## Phase 6 — Catalogs + CSV + asset-spec

### Task 6.1: Catalog generator + gem page + keyword page + CSV

**Files:**
- Modify: `scripts/gen_catalog_html.py` (add gems page; drop the standalone "wealthy" card keyword now it is a gem)
- Modify: `assets/translations/content_*.csv` (gem titles/descs `GEM_<id>_TITLE/_DESC`)
- Create: `docs/asset-spec-gems.md`

- [ ] **Step 1:** Add `GEM_<id>_TITLE` + `GEM_<id>_DESC` rows (en+zh) for the 8 gems to a `content_gems.csv` (new translation file, mirror `content_relics.csv` + register in project import if needed) OR append to `content_cards.csv`. Wire gem display names through `Settings.t("GEM_%s_TITLE", fallback)`.
- [ ] **Step 2:** `gen_catalog_html.py`: add `build_gems()` producing `docs/catalog_html/gems.html` (id, name, effect humanised). Remove the `Wealthy` card-keyword glossary entry (it is a gem now) → Card Keywords back to (2) and total back to 24.
- [ ] **Step 3:** Run `python scripts/gen_catalog_html.py`; verify gems.html written.
- [ ] **Step 4:** Write `docs/asset-spec-gems.md` (8 gem icon contracts: `run_system/assets/images/gems/<id>.png`, theme colours, target path).
- [ ] **Step 5:** Reimport + smoke green. Commit: `docs: gem catalog page + CSV + asset-spec; drop wealthy keyword glossary`.

---

## Self-Review notes

- **Spec coverage:** Gems(1,3,4)+sockets(3)+remove-upgrade(2)+XP/level(4)+rewards(5)+catalogs(6) — all spec sections mapped. Wealthy migration covered in 1.1–1.4 (gain_gold) and bounty_tags rework in 5.4.
- **Type consistency:** `gems` array on player_deck entries + `card` meta "gems" used in 1.3/1.4/3; `gain_xp` returns levels → `pending_level_draws` consumed in 5.2; `gain_gold` cap via `max_per_combat` (1.1/1.2) used by wealthy gem (1.3).
- **Edge:** gem damage/status effects no-op without an enemy target (existing `_apply_effect` guards). `heal` effect handler added in 1.3 if missing. Equipment drops gated to elite/boss in 5.1 (normal loses gear drops — intended).
- **Risk (unattended):** Phases 3 & 5 are UI-heavy; build functional, reuse DraftOverlay/deck-viewer patterns, smoke-gate. If a UI task can't be verified headless, ship the logic + minimal UI and note it.
