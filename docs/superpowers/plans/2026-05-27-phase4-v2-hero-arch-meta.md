# Phase 4 v2 Implementation Plan — Hero Arch + Meta Expansion

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close Phase 4 deferred items (hero JSON schema + Jerry unlock) and add 4 meta features (Run history, Ascension difficulty, Starter Boost upgrade, Card pool gating) in one autonomous overnight run.

**Architecture:** Hero stats / starter deck / sprite move to `run_system/data/heroes/*.json` loaded by RunManager at run start; `player.gd` drops its hardcoded `HERO_ID`. MetaProgress autoload gains run history, max_ascension, and unlocked_cards persistence. 3 new base upgrades (`jerry_unlock`, `starter_boost`, `card_research`) plug into the existing UpgradePanel grid. `run_ended` signal extended with a summary dict.

**Tech Stack:** Godot 4.6, GDScript. No test framework — verification per task is `godot --headless --quit-after 5` via `scripts/smoke_test.sh`, which fails loudly on SCRIPT ERROR / parse failure / DataValidator schema failure.

**Note on TDD adaptation:** Same pattern as the Phase 4 MVP plan — substitute "headless parse + smoke" for "write failing test → make it pass". Each task ends with a smoke + commit.

---

## File map

**Create:**
- `run_system/data/heroes/cowboy_bill.json` (S1)
- `run_system/data/heroes/hero_jerry_killer.json` (S1)
- `run_system/data/base_upgrades/jerry_unlock.json` (S3)
- `run_system/data/base_upgrades/starter_boost.json` (S6)
- `run_system/data/base_upgrades/card_research.json` (S7)

**Modify:**
- `battle_scene/data_validator.gd` — add HERO_DIR + validate_hero + 3 new effect_keys (S1, S3, S6, S7)
- `run_system/core/run_manager.gd` — `current_hero_data`, hero loader, ascension field, `start_new_run` signature, run_ended signal shape, summary builders (S1, S5)
- `run_system/core/meta_progress.gd` — `run_history`, `max_ascension`, `unlocked_cards`, `INITIAL_CARD_POOL`, `get_unlocked_card_pool`, `append_run_history`, run_ended listener, `purchase_upgrade` extended (S4, S5, S7)
- `battle_scene/player.gd` — delete HERO_ID const, read from RunManager.current_hero_data, apply tint (S1)
- `run_system/ui/hero_select.gd` — scan dir, Jerry lock UI, ascension slider (S1, S3, S5)
- `run_system/ui/home_base_scene.gd` — UPGRADE_ORDER grows to 8, Recent Runs panel (S3, S4, S6, S7)
- `battle_scene/battle_scene.gd` — pass core_earned to end_run paths (S4)
- `battle_scene/enemy_entity.gd` — ascension HP multiplier (S5)
- `battle_scene/turn_manager.gd` — ascension first-turn energy penalty (S5)
- `run_system/ui/shop_scene.gd` — ascension price tax (S5)
- `run_system/ui/loot_reward.gd` — draft_pool from MetaProgress (S7)
- `run_system/ui/map_scene.gd` (project.godot or generate_map for ascension elite rate) (S5)

---

## Task 1: S1.a — Cowboy Bill hero JSON

**Files:**
- Create: `run_system/data/heroes/cowboy_bill.json`

- [ ] **Step 1: Create the JSON**

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

- [ ] **Step 2: Smoke (no validator yet, just parse check)**

Run: `bash scripts/smoke_test.sh`
Expected: `[OK] Headless boot clean.`

- [ ] **Step 3: Commit**

```bash
git add run_system/data/heroes/cowboy_bill.json
git commit -m "Hero JSON: cowboy_bill (existing stats)"
```

---

## Task 2: S1.b — Jerry hero JSON

**Files:**
- Create: `run_system/data/heroes/hero_jerry_killer.json`

- [ ] **Step 1: Create the JSON**

```json
{
  "id": "hero_jerry_killer",
  "name": "Jerry the Killer",
  "sprite_id": "cowboy_bill",
  "tint": "#dd5555",
  "max_health": 45,
  "starter_deck": ["strike", "strike", "strike", "weak_strike", "weak_strike",
                   "defend", "defend", "acid_splash"],
  "starting_attributes": {"strength": 4, "constitution": 2, "intelligence": 3, "luck": 3, "charm": 3},
  "description": "Wasteland predator. Lower HP, harder hits, opens with poison.",
  "_codex_todo": "Generate dedicated sprite folder at battle_scene/assets/images/heroes/hero_jerry_killer/ then update sprite_id."
}
```

- [ ] **Step 2: Smoke**

Run: `bash scripts/smoke_test.sh`
Expected: `[OK]`

- [ ] **Step 3: Commit**

```bash
git add run_system/data/heroes/hero_jerry_killer.json
git commit -m "Hero JSON: jerry_killer (red-tinted Bill placeholder + AoE-leaning starter)"
```

---

## Task 3: S1.c — DataValidator hero schema

**Files:**
- Modify: `battle_scene/data_validator.gd:15-17` (add HERO_DIR const), `:78-86` (add dir walk), end-of-file (validate_hero)

- [ ] **Step 1: Add HERO_DIR constant**

Find this block in `data_validator.gd` (around line 15):
```gdscript
const SET_DIR       = "res://run_system/data/equipment_sets/"
const BASE_UPGRADE_DIR = "res://run_system/data/base_upgrades/"
```

Insert one line after `BASE_UPGRADE_DIR`:
```gdscript
const HERO_DIR      = "res://run_system/data/heroes/"
```

- [ ] **Step 2: Add hero schema constants**

After the BASE_UPGRADE constants (around line 60-66), append:

```gdscript
# ─── Hero schema ─────────────────────────────────────────────────────────────
const REQUIRED_HERO_KEYS = ["id", "name", "sprite_id", "max_health", "starter_deck", "starting_attributes"]
const HERO_ATTRIBUTE_KEYS = ["strength", "constitution", "intelligence", "luck", "charm"]
```

- [ ] **Step 3: Wire into validate_all_data_at_startup**

Find the line `failures += _validate_dir(BASE_UPGRADE_DIR, Callable(DataValidator, "validate_base_upgrade"))` and add immediately after it:

```gdscript
	failures += _validate_dir(HERO_DIR, Callable(DataValidator, "validate_hero"))
```

- [ ] **Step 4: Add validate_hero at end of file**

Append after the last existing `static func`:

```gdscript
static func validate_hero(data: Dictionary, path: String) -> bool:
	var prefix := "Hero '%s'" % path
	var ok := true
	for key in REQUIRED_HERO_KEYS:
		if not data.has(key):
			push_error("%s: missing required key '%s'" % [prefix, key])
			ok = false
	if not ok:
		return false

	if typeof(data["max_health"]) != TYPE_FLOAT and typeof(data["max_health"]) != TYPE_INT:
		push_error("%s: max_health must be a number" % prefix)
		ok = false
	if typeof(data["starter_deck"]) != TYPE_ARRAY:
		push_error("%s: starter_deck must be an Array" % prefix)
		ok = false
	if typeof(data["starting_attributes"]) != TYPE_DICTIONARY:
		push_error("%s: starting_attributes must be a Dictionary" % prefix)
		return false
	for attr in HERO_ATTRIBUTE_KEYS:
		if not data["starting_attributes"].has(attr):
			push_error("%s: starting_attributes missing '%s'" % [prefix, attr])
			ok = false
	return ok
```

- [ ] **Step 5: Smoke**

Run: `bash scripts/smoke_test.sh`
Expected: `[OK] DataValidator: all schemas passed.`

- [ ] **Step 6: Commit**

```bash
git add battle_scene/data_validator.gd
git commit -m "DataValidator: walk run_system/data/heroes and validate hero schema"
```

---

## Task 4: S1.d — RunManager loads hero + applies stats

**Files:**
- Modify: `run_system/core/run_manager.gd` — `var current_hero_data` field; `_load_hero_def`; rewrite `start_new_run`

- [ ] **Step 1: Add current_hero_data field + ascension field**

Find the line `var current_hero_id: String = ""` (around line 14) and add immediately after:

```gdscript
## Loaded hero JSON, populated by start_new_run. Empty until first run.
var current_hero_data: Dictionary = {}
## Active difficulty modifier this run (0..5). Stored on RunManager so any
## subsystem can read it without going back to MetaProgress.
var ascension: int = 0
```

- [ ] **Step 2: Add _load_hero_def helper**

Find `func _load_upgrade_def(id: String) -> Dictionary:` (around line 660 area) and insert this function immediately BEFORE it:

```gdscript
## Load a hero definition JSON. Returns {} if missing/invalid.
func _load_hero_def(id: String) -> Dictionary:
	var path := "res://run_system/data/heroes/" + id + ".json"
	if not FileAccess.file_exists(path):
		push_warning("RunManager: hero JSON not found at %s" % path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
```

- [ ] **Step 3: Rewrite start_new_run**

Find the existing function signature `func start_new_run(hero_id: String, starter_deck: Array[String]) -> void:` and REPLACE the whole function body with:

```gdscript
func start_new_run(hero_id: String, starter_deck: Array[String] = [], asc: int = 0) -> void:
	current_hero_id = hero_id
	current_hero_data = _load_hero_def(hero_id)
	ascension = clampi(asc, 0, 5)

	player_deck.clear()
	# Prefer the hero's starter deck if present; fall back to the explicit
	# argument; fall back to DEFAULT_STARTER_DECK if neither given.
	var deck_to_use: Array = starter_deck
	if current_hero_data.has("starter_deck") and current_hero_data["starter_deck"] is Array:
		deck_to_use = current_hero_data["starter_deck"]
	if deck_to_use.is_empty():
		deck_to_use = DEFAULT_STARTER_DECK
	for card_id in deck_to_use:
		add_card_to_deck(str(card_id))

	# Reset resources and health (hero max_health overrides default 50).
	gold = 0
	core = 0
	current_floor = 0
	max_health = int(current_hero_data.get("max_health", 50))
	current_health = max_health
	for slot in EQUIPMENT_SLOTS:
		equipped_items[slot] = ""
	inventory_items.clear()
	relics.clear()
	current_encounter = ["trash_robot"]
	last_battle_node_type = "enemy"
	generate_map(12, 4)

	# Base attributes: hero JSON's starting_attributes overrides the default.
	var attrs: Dictionary = current_hero_data.get("starting_attributes", {})
	base_attributes = {
		"strength": int(attrs.get("strength", 3)),
		"constitution": int(attrs.get("constitution", 3)),
		"intelligence": int(attrs.get("intelligence", 3)),
		"luck": int(attrs.get("luck", 3)),
		"charm": int(attrs.get("charm", 3)),
	}
	player_attributes = base_attributes.duplicate()
	is_run_active = true
	_apply_meta_upgrades()
	_emit_all_state()
```

- [ ] **Step 4: Smoke**

Run: `bash scripts/smoke_test.sh`
Expected: `[OK]`

- [ ] **Step 5: Commit**

```bash
git add run_system/core/run_manager.gd
git commit -m "RunManager: load hero JSON in start_new_run, apply max_health + starter_deck + attributes; add ascension field"
```

---

## Task 5: S1.e — player.gd reads hero data + applies tint

**Files:**
- Modify: `battle_scene/player.gd:23-27` (drop HERO_ID const, read from RunManager), `_build_animated_visual` + `_build_fallback_visual` (apply tint)

- [ ] **Step 1: Replace HERO_ID with hero-data accessors**

Find this block:
```gdscript
const HUD_SCRIPT = preload("res://battle_scene/ui/character_hud.gd")
const STATUS_SYS = preload("res://battle_scene/status_effect_system.gd")
const COMBAT_FX = preload("res://battle_scene/combat_fx.gd")
const HERO_DIR = "res://battle_scene/assets/images/heroes/"
const HERO_ID = "cowboy_bill"
```

Replace `const HERO_ID = "cowboy_bill"` with:

```gdscript
const DEFAULT_HERO_SPRITE_ID = "cowboy_bill"  # fallback when no hero data loaded
```

- [ ] **Step 2: Add helpers to read hero from RunManager**

Insert these two functions just before `func _ready() -> void:`:

```gdscript
## Sprite folder id for the current run's hero. Falls back to cowboy_bill
## if no hero data is loaded (e.g. battle scene opened standalone in editor).
func _hero_sprite_id() -> String:
	if RunManager.current_hero_data.has("sprite_id"):
		return str(RunManager.current_hero_data["sprite_id"])
	return DEFAULT_HERO_SPRITE_ID


## Modulate tint to apply to the sprite. Hero JSON's `tint` is a hex
## string like "#dd5555" — invalid / missing → white (no tint).
func _hero_tint() -> Color:
	if not RunManager.current_hero_data.has("tint"):
		return Color.WHITE
	var hex := str(RunManager.current_hero_data["tint"])
	if hex == "" or not hex.begins_with("#"):
		return Color.WHITE
	return Color.html(hex) if Color.html_is_valid(hex) else Color.WHITE
```

- [ ] **Step 3: Update visual builders to use the helpers**

Search for every occurrence of `HERO_ID` in player.gd and replace each with `_hero_sprite_id()`.

After the line that assigns `_sprite.sprite_frames = ...` (or wherever the AnimatedSprite2D is finalized in `_build_animated_visual`), add:

```gdscript
	_sprite.modulate = _hero_tint()
```

After the line that assigns `_fallback_sprite.texture = ...` in `_build_fallback_visual`, add:

```gdscript
	_fallback_sprite.modulate = _hero_tint()
```

- [ ] **Step 4: Smoke**

Run: `bash scripts/smoke_test.sh`
Expected: `[OK]`

- [ ] **Step 5: Commit**

```bash
git add battle_scene/player.gd
git commit -m "player.gd: drop hardcoded HERO_ID, read sprite + tint from RunManager.current_hero_data"
```

---

## Task 6: S1.f — hero_select.gd scans heroes dir + dynamic buttons

**Files:**
- Modify: `run_system/ui/hero_select.gd` — rewrite to scan `run_system/data/heroes/` and build one button per hero

- [ ] **Step 1: Replace the file**

Open `run_system/ui/hero_select.gd` and replace ENTIRE file with:

```gdscript
extends Control

const MAP_PACKED = preload("res://run_system/ui/map_scene.tscn")
const HERO_DIR := "res://run_system/data/heroes/"

@onready var bill_btn = $HBoxContainer/BillButton
@onready var jerry_btn = $HBoxContainer/JerryButton

# Map from hero_id → Button so we can lock/unlock individually.
var _hero_buttons: Dictionary = {}


func _ready() -> void:
	_setup_buttons()


func _setup_buttons() -> void:
	# Discover heroes from JSON dir. The existing scene has BillButton and
	# JerryButton hardcoded; we keep them as anchors and rebind to the heroes
	# we actually find, in alphabetical id order.
	var hero_ids := _list_hero_ids()
	hero_ids.sort()

	_hero_buttons.clear()

	# Bill always exists; Jerry is gated on the jerry_unlock meta upgrade.
	for hero_id in hero_ids:
		var hero_data := _load_hero(hero_id)
		var btn: Button = _button_for_hero(hero_id)
		if not btn:
			continue
		_hero_buttons[hero_id] = btn
		_apply_button_state(btn, hero_id, hero_data)


func _list_hero_ids() -> Array[String]:
	var ids: Array[String] = []
	var dir := DirAccess.open(HERO_DIR)
	if dir == null:
		return ids
	for file_name in dir.get_files():
		if file_name.ends_with(".json"):
			ids.append(file_name.get_basename())
	return ids


func _load_hero(hero_id: String) -> Dictionary:
	var path := HERO_DIR + hero_id + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## Map well-known hero ids to the existing scene buttons. Heroes beyond
## these two need a UI redesign — flag at runtime.
func _button_for_hero(hero_id: String) -> Button:
	if hero_id == "cowboy_bill":
		return bill_btn
	if hero_id == "hero_jerry_killer":
		return jerry_btn
	push_warning("hero_select: no button slot for hero '%s' — add to scene if you want it visible" % hero_id)
	return null


func _apply_button_state(btn: Button, hero_id: String, hero_data: Dictionary) -> void:
	var hero_name := str(hero_data.get("name", hero_id))
	# Jerry-style lock: gated on the jerry_unlock meta upgrade.
	if hero_id == "hero_jerry_killer":
		var unlocked: bool = MetaProgress.get_upgrade_level("jerry_unlock") > 0
		if not unlocked:
			btn.text = "🔒 %s\n(UNLOCK 100 CORE)" % hero_name.to_upper()
			btn.disabled = true
			# Disconnect any existing handler — we don't want clicks to fire.
			for cb in btn.pressed.get_connections():
				btn.pressed.disconnect(cb["callable"])
			return
	# Unlocked path
	btn.text = hero_name.to_upper()
	btn.disabled = false
	for cb in btn.pressed.get_connections():
		btn.pressed.disconnect(cb["callable"])
	btn.pressed.connect(func(): _select_hero(hero_id))


func _select_hero(hero_id: String) -> void:
	print("Selected Commander: ", hero_id)
	# Ascension defaults to highest unlocked. UI slider added in S5.
	var asc: int = MetaProgress.max_ascension
	RunManager.start_new_run(hero_id, [], asc)
	get_tree().change_scene_to_packed(MAP_PACKED)
```

- [ ] **Step 2: Smoke**

Run: `bash scripts/smoke_test.sh`
Expected: `[OK]`

- [ ] **Step 3: Commit**

```bash
git add run_system/ui/hero_select.gd
git commit -m "hero_select: dynamic button binding from heroes/*.json; Jerry locked unless jerry_unlock owned"
```

---

## Task 7: S3.a — jerry_unlock base upgrade JSON

**Files:**
- Create: `run_system/data/base_upgrades/jerry_unlock.json`
- Modify: `battle_scene/data_validator.gd` (add `unlock_hero` to ALLOWED_BASE_UPGRADE_EFFECT_KEYS)

- [ ] **Step 1: Create the JSON**

Write file `run_system/data/base_upgrades/jerry_unlock.json`:

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

- [ ] **Step 2: Add unlock_hero to validator allowed list**

Find the line `const ALLOWED_BASE_UPGRADE_EFFECT_KEYS = [` in `data_validator.gd` and update the array. The current value:

```gdscript
const ALLOWED_BASE_UPGRADE_EFFECT_KEYS = [
	"max_hp_bonus", "starter_inventory", "loot_rarity_bias",
	"shop_discount", "starting_gold",
]
```

Replace with:

```gdscript
const ALLOWED_BASE_UPGRADE_EFFECT_KEYS = [
	"max_hp_bonus", "starter_inventory", "loot_rarity_bias",
	"shop_discount", "starting_gold",
	"unlock_hero", "starter_attributes", "card_pool_unlock",
]
```

(Adds the 3 new effect_keys this plan needs — `unlock_hero` for this task, `starter_attributes` for S6, `card_pool_unlock` for S7.)

- [ ] **Step 3: Smoke**

Run: `bash scripts/smoke_test.sh`
Expected: `[OK]`

- [ ] **Step 4: Commit**

```bash
git add run_system/data/base_upgrades/jerry_unlock.json battle_scene/data_validator.gd
git commit -m "Base upgrade: jerry_unlock (100 Core, single tier) + 3 new effect_keys whitelisted"
```

---

## Task 8: S3.b — home_base_scene shows jerry_unlock panel

**Files:**
- Modify: `run_system/ui/home_base_scene.gd` UPGRADE_ORDER

- [ ] **Step 1: Extend UPGRADE_ORDER**

Find:

```gdscript
const UPGRADE_ORDER := ["med_bay", "arsenal", "research_lab", "scrap_workshop", "command_center"]
```

Replace with:

```gdscript
const UPGRADE_ORDER := [
	"med_bay", "arsenal", "research_lab", "scrap_workshop", "command_center",
	"jerry_unlock", "starter_boost", "card_research",
]
```

(All three new upgrades land in S3 / S6 / S7. UPGRADE_ORDER references the JSON ids; if a JSON is missing at load time, `_load_upgrade` returns {} and the loop skips it with a push_warning — so this is safe to set up-front before S6 / S7 JSONs exist.)

- [ ] **Step 2: Smoke (will warn about starter_boost + card_research missing — that's expected, fixed in S6/S7)**

Run: `bash scripts/smoke_test.sh`
Expected: `[OK]` — push_warning lines about missing upgrade JSONs are OK at this point, smoke fails only on push_error.

- [ ] **Step 3: Commit**

```bash
git add run_system/ui/home_base_scene.gd
git commit -m "home_base: extend UPGRADE_ORDER with jerry_unlock + future starter_boost/card_research slots"
```

---

## Task 9: S4.a — RunManager run_ended signal extended with summary

**Files:**
- Modify: `run_system/core/run_manager.gd` — `signal run_ended`, `_handle_run_loss`, `end_run_victory`, `_teardown_run`

- [ ] **Step 1: Update signal declaration**

Find:

```gdscript
signal run_ended(victory: bool)
```

Replace with:

```gdscript
## Emitted when the run ends, win or lose. `summary` is the run-history
## payload for MetaProgress (and any future listener):
##   { hero_id: String, floor: int, core_earned: int, outcome: String,
##     timestamp: int (unix seconds) }
## outcome is one of "victory" (final boss kill), "extracted", "defeat".
signal run_ended(victory: bool, summary: Dictionary)
```

- [ ] **Step 2: Rewrite end_run_victory + _handle_run_loss + _teardown_run**

Find this block (near end of file):

```gdscript
func _handle_run_loss() -> void:
	_teardown_run(false)
	# TODO: Trigger base-building retention logic (e.g. keep 30% of Core)
	print("Player Hero defeated! Run ended.")


## Mark the run as ended cleanly (boss victory or extract). Mirrors
## _handle_run_loss's bookkeeping but emits run_ended(true). Idempotent —
## calling twice is a no-op the second time.
func end_run_victory() -> void:
	_teardown_run(true)


## Shared run-teardown: flips is_run_active false and emits run_ended.
## Both win and loss paths funnel through here so any future bookkeeping
## (clear run-scoped state, save run-history snapshot, etc.) added in ONE
## place automatically applies to both outcomes. Idempotent.
func _teardown_run(victory: bool) -> void:
	if not is_run_active:
		return
	is_run_active = false
	emit_signal("run_ended", victory)
```

Replace with:

```gdscript
func _handle_run_loss(core_earned: int = 0) -> void:
	_teardown_run(false, "defeat", core_earned)
	# TODO: Trigger base-building retention logic (e.g. keep 30% of Core)
	print("Player Hero defeated! Run ended.")


## Mark the run as ended cleanly. `core_earned` is the Core grant for
## THIS run (e.g. 150 for final boss, 50 for extract). `outcome` is
## "victory" for final boss kill, "extracted" for mid-act extract.
## Idempotent — calling twice is a no-op the second time.
func end_run_victory(core_earned: int = 0, outcome: String = "victory") -> void:
	_teardown_run(true, outcome, core_earned)


## Shared run-teardown. Builds the summary dict, flips is_run_active false,
## emits run_ended(victory, summary). Both win and loss paths funnel here
## so future bookkeeping added once applies to both outcomes. Idempotent.
func _teardown_run(victory: bool, outcome: String, core_earned: int) -> void:
	if not is_run_active:
		return
	is_run_active = false
	var summary := {
		"hero_id": current_hero_id,
		"floor": current_floor,
		"core_earned": core_earned,
		"outcome": outcome,
		"timestamp": int(Time.get_unix_time_from_system()),
	}
	emit_signal("run_ended", victory, summary)
```

- [ ] **Step 3: Smoke**

Run: `bash scripts/smoke_test.sh`
Expected: `[OK]`

- [ ] **Step 4: Commit**

```bash
git add run_system/core/run_manager.gd
git commit -m "RunManager: run_ended signal carries summary dict (hero_id, floor, core_earned, outcome, timestamp)"
```

---

## Task 10: S4.b — battle_scene passes core_earned to run-end calls

**Files:**
- Modify: `battle_scene/battle_scene.gd` — `_victory` final-boss branch + `_on_extract_chosen` extract branch

- [ ] **Step 1: Update final-boss path**

Find:

```gdscript
		# Final boss path.
		MetaProgress.add_core(BOSS_VICTORY_CORE)
		RunManager.end_run_victory()
		get_tree().change_scene_to_file(HOME_BASE_PATH)
		return
```

Replace with:

```gdscript
		# Final boss path.
		MetaProgress.add_core(BOSS_VICTORY_CORE)
		RunManager.end_run_victory(BOSS_VICTORY_CORE, "victory")
		get_tree().change_scene_to_file(HOME_BASE_PATH)
		return
```

- [ ] **Step 2: Update extract path**

Find:

```gdscript
	if extract:
		MetaProgress.add_core(int(rewards.get("extract", 0)))
		RunManager.end_run_victory()
		get_tree().change_scene_to_file(HOME_BASE_PATH)
```

Replace with:

```gdscript
	if extract:
		var earned: int = int(rewards.get("extract", 0))
		MetaProgress.add_core(earned)
		RunManager.end_run_victory(earned, "extracted")
		get_tree().change_scene_to_file(HOME_BASE_PATH)
```

- [ ] **Step 3: Smoke**

Run: `bash scripts/smoke_test.sh`
Expected: `[OK]`

- [ ] **Step 4: Commit**

```bash
git add battle_scene/battle_scene.gd
git commit -m "battle_scene: pass core_earned + outcome to end_run_victory (final=150 'victory', extract=N 'extracted')"
```

---

## Task 11: S4.c — MetaProgress run_history persistence + listener

**Files:**
- Modify: `run_system/core/meta_progress.gd`

- [ ] **Step 1: Add fields + helpers**

Find:

```gdscript
var core: int = 0
var upgrades: Dictionary = {}
```

Replace with:

```gdscript
var core: int = 0
var upgrades: Dictionary = {}
## Last 50 run summaries (newest at end). Persisted to meta.json.
## Each entry: { hero_id, floor, core_earned, outcome, timestamp }
var run_history: Array = []
## Highest difficulty completed. 0 means no ascension cleared.
var max_ascension: int = 0
## Card ids unlocked beyond the INITIAL_CARD_POOL (added via card_research).
var unlocked_cards: Array[String] = []

const RUN_HISTORY_CAP := 50
const ASCENSION_CAP := 5
## Cards available before any card_research is purchased. The 5 omitted
## ids (flash_bang, last_breath, bone_breaker, junk_bomb, preemptive_strike)
## unlock via the card_research upgrade.
const INITIAL_CARD_POOL: Array[String] = [
	"strike", "weak_strike", "defend", "stun_baton", "static_coil",
	"tinker", "hot_swap", "adrenaline", "brace", "double_tap",
	"scrap_strike", "siphon", "override", "charged_shot", "emp_burst",
	"salvo", "cascade", "last_stand", "acid_splash", "focus",
	"chain_link", "iron_will", "overdrive", "overload", "carapace",
]
```

- [ ] **Step 2: Listen to run_ended at _ready**

Find:

```gdscript
func _ready() -> void:
	load_progress()
```

Replace with:

```gdscript
func _ready() -> void:
	load_progress()
	RunManager.run_ended.connect(_on_run_ended)


func _on_run_ended(victory: bool, summary: Dictionary) -> void:
	append_run_history(summary)
	# Bump max_ascension only on FULL victory (final boss kill, not extract).
	# Compare RunManager.ascension to current max so unlocking requires
	# clearing at the highest unlocked difficulty.
	if victory and str(summary.get("outcome", "")) == "victory":
		var run_asc: int = int(RunManager.ascension)
		if run_asc >= max_ascension and max_ascension < ASCENSION_CAP:
			max_ascension = run_asc + 1
			save_progress()


func append_run_history(entry: Dictionary) -> void:
	run_history.append(entry)
	while run_history.size() > RUN_HISTORY_CAP:
		run_history.pop_front()
	save_progress()


## Returns the union of INITIAL_CARD_POOL and unlocked_cards.
func get_unlocked_card_pool() -> Array[String]:
	var pool: Array[String] = INITIAL_CARD_POOL.duplicate()
	for c in unlocked_cards:
		if not c in pool:
			pool.append(c)
	return pool
```

- [ ] **Step 3: Extend save / load to round-trip new fields**

Find:

```gdscript
func save_progress() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not f:
		push_warning("MetaProgress: failed to open save file for write")
		return
	f.store_string(JSON.stringify({"core": core, "upgrades": upgrades}, "  "))
	f.close()
```

Replace with:

```gdscript
func save_progress() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not f:
		push_warning("MetaProgress: failed to open save file for write")
		return
	var payload := {
		"core": core,
		"upgrades": upgrades,
		"run_history": run_history,
		"max_ascension": max_ascension,
		"unlocked_cards": unlocked_cards,
	}
	f.store_string(JSON.stringify(payload, "  "))
	f.close()
```

Find:

```gdscript
	core = int(parsed.get("core", 0))
	var raw_upgrades = parsed.get("upgrades", {})
	if typeof(raw_upgrades) == TYPE_DICTIONARY:
		upgrades = raw_upgrades
```

Replace with:

```gdscript
	core = int(parsed.get("core", 0))
	var raw_upgrades = parsed.get("upgrades", {})
	if typeof(raw_upgrades) == TYPE_DICTIONARY:
		upgrades = raw_upgrades
	var raw_history = parsed.get("run_history", [])
	if typeof(raw_history) == TYPE_ARRAY:
		run_history = raw_history
	max_ascension = clampi(int(parsed.get("max_ascension", 0)), 0, ASCENSION_CAP)
	var raw_unlocked = parsed.get("unlocked_cards", [])
	if typeof(raw_unlocked) == TYPE_ARRAY:
		unlocked_cards.clear()
		for c in raw_unlocked:
			unlocked_cards.append(str(c))
```

- [ ] **Step 4: Smoke**

Run: `bash scripts/smoke_test.sh`
Expected: `[OK]`

- [ ] **Step 5: Commit**

```bash
git add run_system/core/meta_progress.gd
git commit -m "MetaProgress: persist run_history + max_ascension + unlocked_cards; listen to run_ended; bump ascension on full victory"
```

---

## Task 12: S4.d — home_base Recent Runs panel

**Files:**
- Modify: `run_system/ui/home_base_scene.gd` — add a side panel showing last 5 runs

- [ ] **Step 1: Add the panel builder**

Find the existing `func _build() -> void:` body. After the line that builds the upgrade `grid` (find `for upgrade_id in UPGRADE_ORDER:` and the loop that follows it), add — just BEFORE the "Spacer push START to bottom" block:

```gdscript
	# Recent runs panel — last 5 entries from MetaProgress.run_history.
	var history_label := Label.new()
	history_label.text = "RECENT RUNS"
	history_label.add_theme_font_size_override("font_size", 22)
	history_label.add_theme_color_override("font_color", Color(1, 0.92, 0.55))
	vbox.add_child(history_label)
	var history_panel := _build_recent_runs_panel()
	vbox.add_child(history_panel)
```

- [ ] **Step 2: Implement the builder**

Append these two functions to the end of `home_base_scene.gd`:

```gdscript
func _build_recent_runs_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.panel_textured("dark"))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var history: Array = MetaProgress.run_history
	if history.is_empty():
		var none := Label.new()
		none.text = "(no runs yet)"
		none.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		vbox.add_child(none)
		return panel

	# Show newest first, max 5 entries.
	var slice_start: int = max(0, history.size() - 5)
	var to_show: Array = history.slice(slice_start)
	to_show.reverse()
	for entry in to_show:
		vbox.add_child(_build_history_row(entry))
	return panel


func _build_history_row(entry: Dictionary) -> Label:
	var outcome: String = str(entry.get("outcome", "?"))
	var icon: String = "✓" if outcome == "victory" else ("⤴" if outcome == "extracted" else "✗")
	var color: Color = {
		"victory": Color(0.4, 1.0, 0.5),
		"extracted": Color(1.0, 0.9, 0.4),
	}.get(outcome, Color(1.0, 0.4, 0.4))

	var hero: String = _humanize_hero_id(str(entry.get("hero_id", "?")))
	var floor: int = int(entry.get("floor", 0))
	var core_earned: int = int(entry.get("core_earned", 0))

	var row := Label.new()
	row.text = "%s  %s  Floor %d  +%d Core" % [icon, hero, floor + 1, core_earned]
	row.add_theme_color_override("font_color", color)
	return row


func _humanize_hero_id(hero_id: String) -> String:
	# Quick lookup table — covers the two heroes we ship.
	var names := {"cowboy_bill": "Bill", "hero_jerry_killer": "Jerry"}
	if names.has(hero_id):
		return names[hero_id]
	return hero_id.replace("_", " ").capitalize()
```

- [ ] **Step 3: Smoke**

Run: `bash scripts/smoke_test.sh`
Expected: `[OK]`

- [ ] **Step 4: Commit**

```bash
git add run_system/ui/home_base_scene.gd
git commit -m "home_base: Recent Runs panel showing last 5 entries (outcome icon + hero + floor + core)"
```

---

## Task 13: S5.a — RunManager ascension field already added (Task 4 step 1)

This is already done as part of Task 4 — the `var ascension: int = 0` field was added with `current_hero_data`.

- [ ] **Step 1: Verify**

```bash
grep -n "var ascension" run_system/core/run_manager.gd
```

Expected: one match line, around the `current_hero_data` field.

- [ ] **Step 2: No commit needed — confirm via smoke**

```bash
bash scripts/smoke_test.sh
```

Expected: `[OK]`

---

## Task 14: S5.b — Ascension A1: enemy HP +10% per level

**Files:**
- Modify: `battle_scene/enemy_entity.gd` — `_build_from_json` or the HP-load line

- [ ] **Step 1: Find the HP load**

```bash
grep -n "max_health\|max_hp" battle_scene/enemy_entity.gd | head -10
```

Look for the line where the enemy's `max_health` is set from JSON (typically `max_health = int(data.get("max_health", 30))` or similar in a `_load_from_json` / `_build_from_json` function).

- [ ] **Step 2: Apply ascension multiplier**

After the line that sets `max_health` from JSON, insert:

```gdscript
	# Ascension A1+: enemy HP scales +10% per level.
	if RunManager.ascension > 0:
		max_health = int(round(max_health * (1.0 + 0.1 * RunManager.ascension)))
	health = max_health
```

Make sure `health = max_health` is set AFTER the multiplier so the enemy starts at full scaled HP (this line may already exist — if so just leave it where it is and add the multiplier above it).

- [ ] **Step 3: Smoke**

Run: `bash scripts/smoke_test.sh`
Expected: `[OK]`

- [ ] **Step 4: Commit**

```bash
git add battle_scene/enemy_entity.gd
git commit -m "Ascension A1+: enemy max_health scales +10% per ascension level"
```

---

## Task 15: S5.c — Ascension A2: player -5 max HP per level

**Files:**
- Modify: `run_system/core/run_manager.gd` — `_apply_meta_upgrades`

- [ ] **Step 1: Add ascension HP penalty**

Find `func _apply_meta_upgrades() -> void:` (the function added in Phase 4 MVP). At the very TOP of the function body, BEFORE the Med Bay block, insert:

```gdscript
	# Ascension A2+: -5 max HP per level. Applied BEFORE Med Bay so the
	# upgrade can partially offset the penalty (intentional — investing
	# in meta unlocks softer ramps).
	if ascension >= 2:
		var penalty: int = (ascension - 1) * 5  # A2=-5, A3=-10, A4=-15, A5=-20
		max_health = max(10, max_health - penalty)
		current_health = max_health
```

- [ ] **Step 2: Smoke**

Run: `bash scripts/smoke_test.sh`
Expected: `[OK]`

- [ ] **Step 3: Commit**

```bash
git add run_system/core/run_manager.gd
git commit -m "Ascension A2+: -5 max HP per level applied at run start (before Med Bay offset)"
```

---

## Task 16: S5.d — Ascension A3: first turn -1 energy

**Files:**
- Modify: `battle_scene/turn_manager.gd` — first-turn energy budget

- [ ] **Step 1: Find the first-turn energy logic**

```bash
grep -n "energy\|first_turn\|round_number" battle_scene/turn_manager.gd | head -15
```

Look for the function that begins the player's first turn (typically `_start_player_turn` or `start_combat`) and the line that resets / sets the energy budget at round 1.

- [ ] **Step 2: Apply the penalty**

In the start-of-combat / start-of-turn block, after the existing energy assignment for the first turn, insert:

```gdscript
	# Ascension A3+: first turn of each combat starts with -1 energy.
	if RunManager.ascension >= 3 and round_number == 1:
		if main_scene and main_scene.player and main_scene.player.has_method("pay_energy"):
			main_scene.player.pay_energy(1)
```

(Replace `round_number` with whatever the actual var is — `_round` / `current_round` / etc. — based on grep output. Replace `main_scene` reference with however turn_manager references the battle scene.)

If the exact symbol names differ, the verifying agent should adapt the call to match — the intent is: at the start of round 1, subtract 1 from the player's energy.

- [ ] **Step 3: Smoke**

Run: `bash scripts/smoke_test.sh`
Expected: `[OK]`

- [ ] **Step 4: Commit**

```bash
git add battle_scene/turn_manager.gd
git commit -m "Ascension A3+: first turn of each combat starts with -1 energy"
```

---

## Task 17: S5.e — Ascension A4: shop prices +10%

**Files:**
- Modify: `run_system/ui/shop_scene.gd` — `_discounted_price`

- [ ] **Step 1: Apply ascension surcharge AFTER scrap_workshop discount**

Find:

```gdscript
func _discounted_price(base_cost: int) -> int:
	var bias = RunManager._get_meta_effect_value("scrap_workshop")
	var multiplier := float(bias.get("multiplier", 1.0))
	if multiplier >= 1.0:
		return base_cost
	return int(ceil(base_cost * multiplier))
```

Replace with:

```gdscript
func _discounted_price(base_cost: int) -> int:
	var bias = RunManager._get_meta_effect_value("scrap_workshop")
	var multiplier := float(bias.get("multiplier", 1.0))
	var price: float = float(base_cost) * multiplier
	# Ascension A4+: +10% surcharge ON TOP of any Scrap Workshop discount.
	if RunManager.ascension >= 4:
		price *= 1.10
	return int(ceil(price))
```

- [ ] **Step 2: Smoke**

Run: `bash scripts/smoke_test.sh`
Expected: `[OK]`

- [ ] **Step 3: Commit**

```bash
git add run_system/ui/shop_scene.gd
git commit -m "Ascension A4+: shop prices +10% surcharge on top of Scrap Workshop discount"
```

---

## Task 18: S5.f — Ascension A5: elite roll boost

**Files:**
- Modify: `run_system/core/run_manager.gd` — `_pick_node_type` mid/late floors

- [ ] **Step 1: Find the elite threshold**

Find `func _pick_node_type(floor_idx: int, total: int, treasure_extras_used: int = 0) -> String:` and locate the "Mid/late floors" branch (after the early floors block, around line 320). Look for the final `return "elite"` and the surrounding probability rolls.

- [ ] **Step 2: Apply boost**

Just after the `var roll = randf()` line, before the existing probability comparisons in the mid/late floors block, insert:

```gdscript
	# Ascension A5+: pull 50% of the bottom of the roll-space into elite
	# territory by squashing the roll. Effectively boosts elite rate.
	if ascension >= 5:
		roll = roll * 0.5 + 0.5  # range now 0.5..1.0 → most rolls land in the elite/treasure tail
```

(This is a coarse but effective bias — for the existing mid/late table where `elite` is the final fallback past 0.93, this guarantees most rolls hit it.)

- [ ] **Step 3: Smoke**

Run: `bash scripts/smoke_test.sh`
Expected: `[OK]`

- [ ] **Step 4: Commit**

```bash
git add run_system/core/run_manager.gd
git commit -m "Ascension A5: bias mid/late map rolls into the elite-heavy tail"
```

---

## Task 19: S5.g — hero_select shows ascension slider when max > 0

**Files:**
- Modify: `run_system/ui/hero_select.gd` — add slider construction in `_setup_buttons`

- [ ] **Step 1: Add an ascension slider state field**

Near the top of hero_select.gd (after `var _hero_buttons: Dictionary = {}`), add:

```gdscript
var _ascension_slider: HSlider = null
var _ascension_value_label: Label = null
```

- [ ] **Step 2: Build slider in _setup_buttons after the button loop**

At the end of `_setup_buttons()`, append:

```gdscript
	_build_ascension_slider()


func _build_ascension_slider() -> void:
	if MetaProgress.max_ascension <= 0:
		return  # nothing to choose

	# Insert below the HBoxContainer with the hero buttons.
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	vbox.position.y = -100
	add_child(vbox)

	var label := Label.new()
	label.text = "ASCENSION"
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	_ascension_slider = HSlider.new()
	_ascension_slider.min_value = 0
	_ascension_slider.max_value = MetaProgress.max_ascension
	_ascension_slider.step = 1
	_ascension_slider.value = MetaProgress.max_ascension  # default to highest
	_ascension_slider.custom_minimum_size = Vector2(240, 24)
	_ascension_slider.value_changed.connect(_on_ascension_changed)
	row.add_child(_ascension_slider)

	_ascension_value_label = Label.new()
	_ascension_value_label.text = "A%d" % int(_ascension_slider.value)
	_ascension_value_label.custom_minimum_size = Vector2(40, 0)
	row.add_child(_ascension_value_label)


func _on_ascension_changed(value: float) -> void:
	if _ascension_value_label:
		_ascension_value_label.text = "A%d" % int(value)
```

- [ ] **Step 3: Pass slider value to start_new_run**

Find `func _select_hero(hero_id: String) -> void:` and replace its body with:

```gdscript
func _select_hero(hero_id: String) -> void:
	print("Selected Commander: ", hero_id)
	var asc: int = MetaProgress.max_ascension
	if _ascension_slider:
		asc = int(_ascension_slider.value)
	RunManager.start_new_run(hero_id, [], asc)
	get_tree().change_scene_to_packed(MAP_PACKED)
```

- [ ] **Step 4: Smoke**

Run: `bash scripts/smoke_test.sh`
Expected: `[OK]`

- [ ] **Step 5: Commit**

```bash
git add run_system/ui/hero_select.gd
git commit -m "hero_select: ascension slider 0..max_ascension when max > 0; default to highest"
```

---

## Task 20: S6.a — Starter Boost upgrade JSON

**Files:**
- Create: `run_system/data/base_upgrades/starter_boost.json`

- [ ] **Step 1: Create JSON**

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

- [ ] **Step 2: Smoke (validator already whitelists starter_attributes in Task 7)**

Run: `bash scripts/smoke_test.sh`
Expected: `[OK]`

- [ ] **Step 3: Commit**

```bash
git add run_system/data/base_upgrades/starter_boost.json
git commit -m "Base upgrade: starter_boost (3 tiers, +N random attribute points at run start)"
```

---

## Task 21: S6.b — RunManager applies starter_boost in _apply_meta_upgrades

**Files:**
- Modify: `run_system/core/run_manager.gd` — `_apply_meta_upgrades`

- [ ] **Step 1: Add the points distribution**

Find `func _apply_meta_upgrades() -> void:` and locate the existing block that ends with the comment about loot_rarity_bias / shop_discount being read on-demand. Insert this BEFORE that comment:

```gdscript
	# Starter Boost → +N random attribute points (each picks a random
	# attribute from STR/CON/INT/LCK/CHA and increments by 1).
	var starter := _get_meta_effect_value("starter_boost")
	if not starter.is_empty():
		var points: int = int(starter.get("points", 0))
		var attr_keys: Array = ["strength", "constitution", "intelligence", "luck", "charm"]
		for i in range(points):
			var pick: String = attr_keys[randi() % attr_keys.size()]
			base_attributes[pick] = int(base_attributes.get(pick, 3)) + 1
		# Recompute derived stats after attribute mutation.
		player_attributes = base_attributes.duplicate()
```

- [ ] **Step 2: Smoke**

Run: `bash scripts/smoke_test.sh`
Expected: `[OK]`

- [ ] **Step 3: Commit**

```bash
git add run_system/core/run_manager.gd
git commit -m "RunManager: apply starter_boost — +N random attribute points at run start"
```

---

## Task 22: S7.a — Card Research upgrade JSON

**Files:**
- Create: `run_system/data/base_upgrades/card_research.json`

- [ ] **Step 1: Create JSON**

```json
{
  "id": "card_research",
  "name": "CARD RESEARCH",
  "description": "Salvage research notes to add stronger cards to the draft pool.",
  "effect_key": "card_pool_unlock",
  "tiers": [
    {"level": 1, "cost": 30, "effect_value": {"unlocks": ["flash_bang", "bone_breaker"]}, "effect_text": "Unlock Flash Bang + Bone Breaker"},
    {"level": 2, "cost": 60, "effect_value": {"unlocks": ["last_breath", "preemptive_strike"]}, "effect_text": "Unlock Last Breath + Preemptive Strike"},
    {"level": 3, "cost": 100, "effect_value": {"unlocks": ["junk_bomb"]}, "effect_text": "Unlock Junk Bomb"}
  ]
}
```

- [ ] **Step 2: Smoke**

Run: `bash scripts/smoke_test.sh`
Expected: `[OK]`

- [ ] **Step 3: Commit**

```bash
git add run_system/data/base_upgrades/card_research.json
git commit -m "Base upgrade: card_research (3 tiers, unlocks 5 locked cards across all tiers)"
```

---

## Task 23: S7.b — MetaProgress.purchase_upgrade applies card_pool_unlock effect

**Files:**
- Modify: `run_system/core/meta_progress.gd` — `purchase_upgrade`

- [ ] **Step 1: Add effect-application step**

Find `func purchase_upgrade(id: String, definition: Dictionary) -> bool:` and replace its body with:

```gdscript
func purchase_upgrade(id: String, definition: Dictionary) -> bool:
	if not can_purchase(id, definition):
		return false
	var lvl := get_upgrade_level(id)
	var tier: Dictionary = definition["tiers"][lvl]
	var cost := int(tier["cost"])
	core -= cost
	upgrades[id] = lvl + 1

	# Apply purchase-time side effects (currently just card_pool_unlock —
	# everything else is read on demand at run start).
	var effect_key: String = str(definition.get("effect_key", ""))
	if effect_key == "card_pool_unlock":
		var effect_value: Dictionary = tier.get("effect_value", {})
		var unlocks: Array = effect_value.get("unlocks", [])
		for c in unlocks:
			if not str(c) in unlocked_cards:
				unlocked_cards.append(str(c))

	save_progress()
	emit_signal("core_changed", core)
	emit_signal("upgrades_changed")
	return true
```

- [ ] **Step 2: Smoke**

Run: `bash scripts/smoke_test.sh`
Expected: `[OK]`

- [ ] **Step 3: Commit**

```bash
git add run_system/core/meta_progress.gd
git commit -m "MetaProgress: apply card_pool_unlock on purchase (append unlocked card ids)"
```

---

## Task 24: S7.c — loot_reward draft_pool reads from MetaProgress

**Files:**
- Modify: `run_system/ui/loot_reward.gd` — replace static draft_pool with dynamic lookup

- [ ] **Step 1: Replace the const draft_pool with a getter**

Find:

```gdscript
var draft_pool = [
	# Existing pool
	"strike", "defend", "override", "preemptive_strike", "weak_strike",
	# Tactical Toolkit — Control
	"stun_baton", "static_coil", "emp_burst", "overload",
	# Tactical Toolkit — Combo
	"cascade", "salvo", "tinker", "hot_swap",
	# Tactical Toolkit — Burst
	"overdrive", "charged_shot", "junk_bomb", "adrenaline",
	# Phase 5 expansion
	"siphon", "last_stand", "acid_splash", "focus", "carapace", "flash_bang",
	# Phase 5 expansion wave 2
	"brace", "double_tap", "chain_link", "iron_will", "bone_breaker", "last_breath",
	# Phase 5 cap to 30
	"scrap_strike",
]
```

Replace with:

```gdscript
## The card pool from which draft choices are rolled. Populated at _ready
## from MetaProgress.get_unlocked_card_pool() — the union of the always-
## available INITIAL_CARD_POOL (25 cards) and any cards unlocked via
## card_research base upgrades.
var draft_pool: Array = []
```

- [ ] **Step 2: Populate draft_pool in _ready**

Find `func _ready() -> void:` and insert at the top of its body:

```gdscript
	draft_pool = MetaProgress.get_unlocked_card_pool()
```

- [ ] **Step 3: Smoke**

Run: `bash scripts/smoke_test.sh`
Expected: `[OK]`

- [ ] **Step 4: Commit**

```bash
git add run_system/ui/loot_reward.gd
git commit -m "loot_reward: draft_pool sourced from MetaProgress.get_unlocked_card_pool() (25 base + card_research unlocks)"
```

---

## Task 25: End-to-end smoke + PRD doc update

**Files:**
- Modify: `docs/PRD.md` Phase 4 section

- [ ] **Step 1: Final headless smoke**

```bash
bash scripts/smoke_test.sh
```

Expected: `[OK]`

- [ ] **Step 2: Update PRD Phase 4 status**

Find the Phase 4 block (line ~394). Update the deferred bullets:

Replace:
```markdown
- ⬜ Hero unlock system via base upgrades (deferred — both heroes already selectable in MVP)
```

With:
```markdown
- ✅ Hero JSON schema + dynamic loader: heroes/*.json (cowboy_bill + hero_jerry_killer); player.gd reads sprite/tint/stats from RunManager.current_hero_data
- ✅ Hero unlock: jerry_unlock base upgrade (100 Core, single tier)
- ✅ Run history panel: home base shows last 5 runs (outcome icon + hero + floor + core)
- ✅ Ascension difficulty: 5 levels, each adds a negative modifier (enemy HP+10%, player -5 max HP, -1 first-turn energy, +10% shop prices, elite-heavy maps)
- ✅ Starter Boost upgrade: 3 tiers, +N random attribute points at run start
- ✅ Card Research upgrade: 3 tiers unlocking 5 cards (flash_bang, bone_breaker, last_breath, preemptive_strike, junk_bomb)
```

- [ ] **Step 3: Commit + push**

```bash
git add docs/PRD.md
git commit -m "PRD: mark Phase 4 v2 complete (hero arch + meta expansion)"
git push origin hero-refinement-v2
```

Expected: push succeeds.

---

## Self-review

**Spec coverage:**
- ✅ S1 Hero JSON + loader — Tasks 1-6
- ✅ S2 Jerry placeholder sprite — Task 2 (tint in JSON) + Task 5 (player.gd applies tint)
- ✅ S3 Jerry Unlock — Tasks 7-8
- ✅ S4 Run history — Tasks 9-12 (signal extension + listener + UI panel)
- ✅ S5 Ascension — Tasks 13-19 (all 5 modifiers + hero_select slider)
- ✅ S6 Starter Boost — Tasks 20-21
- ✅ S7 Card pool gating — Tasks 22-24

**Placeholder scan:** Task 16 says "If the exact symbol names differ, the verifying agent should adapt" — this is the only place that defers to runtime decision-making and is bounded ("the intent is: at the start of round 1, subtract 1 from the player's energy"). All other tasks have full code.

**Type consistency:**
- `current_hero_data: Dictionary` declared in Task 4 step 1, read in Task 5 helpers ✓
- `ascension: int` declared in Task 4 step 1, read in Tasks 14-18 + Task 21 (`_get_meta_effect_value("starter_boost")` indirectly via `_apply_meta_upgrades`) ✓
- `run_ended(victory: bool, summary: Dictionary)` shape consistent across Task 9 (decl), Task 10 (emit args), Task 11 (listener handler signature) ✓
- `get_unlocked_card_pool()` returns `Array[String]` in Task 11, consumed as `Array` in Task 24 step 1 — compatible ✓
- `INITIAL_CARD_POOL` 25 ids in Task 11 — matches the spec's count (30 total - 5 locked) ✓

**Scope check:** 25 tasks. Each ~2-10 minutes. Total ~3-5 hours implementation. Fits overnight.
